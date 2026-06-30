// Package cli は anyvm CLI のコマンド木を構築する（cobra 利用。.doc/05）。
package cli

import (
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/spf13/pflag"

	"github.com/kznagamori/anyvm_win/pkg/anyvm"
)

// appVersion はアプリのバージョン（リリース時にビルドフラグで上書き可能）。
var appVersion = "2.0.0-dev"

// globalOpts はグローバルフラグの値。
type globalOpts struct {
	verbose   bool
	logFormat string
	logFile   string
	root      string
	showVer   bool
}

// NewRootCmd はルートコマンドを構築して返す。
//
// ツールごとのサブコマンドはマニフェストから動的生成するため、コマンド木を組む前に
// グローバルフラグを事前解析して Engine を先に構築する（.doc/05 §2-3）。
func NewRootCmd() (*cobra.Command, error) {
	g := preparseGlobals(os.Args[1:])

	root := resolveRoot(g.root)
	logFile := g.logFile
	if logFile == "" {
		logFile = filepath.Join(root, "logs", "anyvm.log")
	}

	// ロギングを初期化（以後 slog.Default() が使える）。進捗バーはコンソールハンドラと共有する。
	pbar := setupLogging(g.verbose, g.logFormat, logFile)

	eng, err := anyvm.NewEngine(anyvm.Config{Root: root})
	if err != nil {
		return nil, err
	}
	// 数値進捗は slog とは別系統でバーに流す（.doc/06 §6）。
	// 完了（done>=total>0）時は Done() で改行確定し、後続の slog 出力が進捗行へ食い込むのを防ぐ。
	if pbar != nil {
		eng.SetProgress(func(done, total int64) {
			pbar.Update(done, total)
			if total > 0 && done >= total {
				pbar.Done()
			}
		})
	}

	cmd := &cobra.Command{
		Use:           "anyvm",
		Short:         "Windows 用 開発ツールバージョン管理システム",
		Long:          "anyvm は Windows 上で各種開発ツールのバージョンを導入・切り替え・削除する CLI です。",
		SilenceUsage:  true,
		SilenceErrors: true,
		RunE: func(c *cobra.Command, _ []string) error {
			if g.showVer {
				fmt.Println("anyvm version " + appVersion)
				return nil
			}
			return c.Help()
		},
	}

	pf := cmd.PersistentFlags()
	// verbose は -v 短縮形を付けない（ツールの -v/--version と衝突するため）。
	pf.BoolVar(&g.verbose, "verbose", g.verbose, "冗長出力（診断ログを Debug まで出す）")
	pf.StringVar(&g.logFormat, "log-format", g.logFormat, "ログ整形 text|json")
	pf.StringVar(&g.logFile, "log-file", g.logFile, "追加のログ出力先ファイル")
	pf.StringVar(&g.root, "root", root, "ANYVM_ROOT（ルートディレクトリ）")
	// --version はルート専用フラグにする（サブコマンドへ継承させず、ツールの --version と分離）。
	cmd.Flags().BoolVar(&g.showVer, "version", false, "バージョンを表示して終了")

	// 全体コマンド。
	cmd.AddCommand(
		newInitCmd(eng),
		newRehashCmd(eng),
		newUpdateAllCmd(eng),
		newUnsetAllCmd(eng),
		newVersionAllCmd(eng),
		newListCmd(eng),
	)

	// ツールごとのサブコマンドをマニフェストから動的生成する。
	for _, m := range eng.Manifests() {
		cmd.AddCommand(newToolCmd(eng, m))
	}
	return cmd, nil
}

// preparseGlobals は os.Args からグローバルフラグだけを先読みする（未知フラグは無視）。
func preparseGlobals(args []string) globalOpts {
	g := globalOpts{logFormat: "text"}
	fs := pflag.NewFlagSet("global", pflag.ContinueOnError)
	fs.ParseErrorsWhitelist.UnknownFlags = true // サブコマンドのフラグは無視する
	fs.SetOutput(io.Discard)
	// verbose には -v 短縮形を付けない（ツールの -v/--version と衝突するため）。
	fs.BoolVar(&g.verbose, "verbose", false, "")
	fs.StringVar(&g.logFormat, "log-format", "text", "")
	fs.StringVar(&g.logFile, "log-file", "", "")
	fs.StringVar(&g.root, "root", "", "")
	_ = fs.Parse(args)
	return g
}

// resolveRoot は ANYVM_ROOT を解決する（フラグ > 環境変数 > exe の親の親。.doc/09 §3）。
func resolveRoot(flag string) string {
	if flag != "" {
		return flag
	}
	if v := os.Getenv("ANYVM_ROOT"); v != "" {
		return v
	}
	if exe, err := os.Executable(); err == nil {
		return filepath.Dir(filepath.Dir(exe)) // <root>/bin/anyvm.exe -> <root>
	}
	wd, _ := os.Getwd()
	return wd
}
