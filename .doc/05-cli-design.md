# 05. CLI 設計（cobra）

要求仕様「引数解析は cobra を使用」に基づく CLI（`cmd/anyvm`）の設計です。CLI は薄いアダプタで、実処理は `pkg/anyvm.Engine`（[07](07-library-api.md)）へ委譲します。

## 1. コマンド木

```text
anyvm                                  # ルート
├─ (global flags)
│   --verbose, -v          冗長出力（slog 最小レベルを Debug に）
│   --log-format <text|json>   ログ整形（既定 text）
│   --log-file <path>      追加のログ出力先（既定 <ROOT>/logs/anyvm.log）
│   --root <path>          ANYVM_ROOT の明示（既定: 環境変数 or exe 親の親）
│   --version              アプリのバージョンを表示して終了
│
├─ init                    scripts/ と集約スクリプトを生成（[08]）
├─ rehash                  全ツールを Deactivate→Activate（現シェルへ反映）
├─ update                  全ツールの版を再取得（並行・レート制限付き）
├─ unset                   全ツールを無効化
├─ version                 全ツールのアクティブ版を一覧表示
├─ list                    管理可能なツール（マニフェスト）を一覧
├─ setup                   シェル起動時自動実行の設定（旧 setup_jp.bat 相当）
├─ migrate                 旧 Dart 版データからの移行（[10]）
│
└─ <tool>                  ★ マニフェストから動的生成（go, python, rust, ...）
    ├─ install   -l/--list  --latest  -v/--version <X>
    ├─ uninstall -v/--version <X>
    ├─ set       -v/--version <X>
    ├─ unset
    ├─ version
    ├─ versions
    └─ update
```

> **動的生成が鍵**: 旧版はラッパー（anyvm.bat/.ps1）でツールを**ハードコード列挙**しており、`update` で AndroidSDK/Rust が欠落するなどの取りこぼしがあった。新版は Registry の全マニフェストから per-tool サブコマンドと全体コマンドの対象を生成し、構造的に防ぐ。

## 2. ルートコマンドと初期化

```go
// cmd/anyvm/main.go
package main

import (
	"context"
	"os"
	"os/signal"

	"github.com/kznagamori/anyvm_win/cmd/anyvm/cli"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	if err := cli.NewRootCmd().ExecuteContext(ctx); err != nil {
		os.Exit(cli.ExitCode(err)) // エラー種別 → 終了コード
	}
}
```

```go
// cmd/anyvm/cli/root.go
package cli

import (
	"github.com/spf13/cobra"
	"github.com/kznagamori/anyvm_win/pkg/anyvm"
)

type globalOpts struct {
	verbose   bool
	logFormat string
	logFile   string
	root      string
	showVer   bool
}

func NewRootCmd() *cobra.Command {
	g := &globalOpts{}
	root := &cobra.Command{
		Use:           "anyvm",
		Short:         "Windows 用 開発ツールバージョン管理システム",
		SilenceUsage:  true,
		SilenceErrors: true, // エラーは slog に集約（[06]）
		PersistentPreRunE: func(cmd *cobra.Command, _ []string) error {
			// 1) slog を初期化（[06]）
			setupLogging(g.verbose, g.logFormat, g.logFile)
			if g.showVer {
				printAppVersion()
				return errStopAfterVersion
			}
			// 2) Engine を構築し cmd の Context に格納
			eng, err := anyvm.NewEngine(anyvm.Config{Root: resolveRoot(g.root)})
			if err != nil {
				return err
			}
			cmd.SetContext(withEngine(cmd.Context(), eng))
			return nil
		},
	}
	pf := root.PersistentFlags()
	pf.BoolVarP(&g.verbose, "verbose", "v", false, "冗長出力")
	pf.StringVar(&g.logFormat, "log-format", "text", "ログ整形 text|json")
	pf.StringVar(&g.logFile, "log-file", "", "ログ出力先ファイル")
	pf.StringVar(&g.root, "root", "", "ANYVM_ROOT")
	pf.BoolVar(&g.showVer, "version", false, "バージョン表示")

	// 全体コマンド
	root.AddCommand(newInitCmd(), newRehashCmd(), newUpdateAllCmd(),
		newUnsetAllCmd(), newVersionAllCmd(), newListCmd(),
		newSetupCmd(), newMigrateCmd())

	// ★ ツールごとのサブコマンドを動的生成
	for _, m := range loadManifestsForCLI(g) {
		root.AddCommand(newToolCmd(m))
	}
	return root
}
```

> `loadManifestsForCLI` は cobra のコマンド構築時（Execute 前）に走る必要があるため、Engine 構築とは別に**マニフェストのメタ情報だけ**を先読みする軽量ローダを用意する。あるいは Engine を `init()` 相当で早期構築し、`PersistentPreRunE` では再利用する設計でもよい。

## 3. ツールサブコマンドの動的生成

```go
// cmd/anyvm/cli/tool.go
func newToolCmd(m anyvm.ManifestMeta) *cobra.Command {
	tc := &cobra.Command{
		Use:     m.Name,
		Short:   m.Description,
		Aliases: m.Aliases,
	}
	tc.AddCommand(
		newToolInstall(m.Name),
		newToolUninstall(m.Name),
		newToolSet(m.Name),
		newToolUnset(m.Name),
		newToolVersion(m.Name),
		newToolVersions(m.Name),
		newToolUpdate(m.Name),
	)
	return tc
}

func newToolInstall(tool string) *cobra.Command {
	var (
		list    bool
		latest  bool
		version string
	)
	c := &cobra.Command{
		Use:   "install",
		Short: "インストール（-l 一覧 / --latest 最新 / -v 指定）",
		RunE: func(cmd *cobra.Command, _ []string) error {
			eng := engineFrom(cmd.Context())
			switch {
			case list:
				return eng.ListInstallable(cmd.Context(), tool)
			case latest:
				return eng.InstallLatest(cmd.Context(), tool)
			case version != "":
				return eng.Install(cmd.Context(), tool, version)
			default:
				return cmd.Usage()
			}
		},
	}
	f := c.Flags()
	f.BoolVarP(&list, "list", "l", false, "導入可能な版の一覧")
	f.BoolVar(&latest, "latest", false, "最新版を導入")
	f.StringVarP(&version, "version", "v", "", "導入する版")
	return c
}
```

他のサブコマンド（set/unset/version/versions/uninstall/update）も同様に Engine のメソッドへ委譲します。`-v/--version` の短縮形はツールサブコマンド配下にのみ束縛し、ルートの `--version`（アプリ版）とは名前空間が分かれるため衝突しません。

## 4. 全体コマンドの動的対象

```go
// cmd/anyvm/cli/global.go
func newUpdateAllCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "update",
		Short: "全ツールの版情報を再取得",
		RunE: func(cmd *cobra.Command, _ []string) error {
			// Engine が Registry 全体を走査（取りこぼし無し）
			return engineFrom(cmd.Context()).UpdateAll(cmd.Context())
		},
	}
}
```

`rehash` / `unset` / `version` も `engineFrom(ctx).RehashAll/UnsetAll/ShowAllVersions` を呼ぶだけ。旧ラッパー（anyvm.bat/.ps1）の役割は**全て CLI 本体に内包**され、`.bat`/`.ps1` ラッパーは不要になります（ただし `rehash` は現シェルへの環境反映のため、生成済み Activate スクリプトを呼ぶ薄いシェル連携が残る。[08](08-os-abstraction.md)）。

## 5. `rehash` の特別扱い

`set`/`unset` はスクリプトを生成するだけで、**現在のシェルの環境変数は変わらない**（子プロセスから親シェルの環境は変えられない）。旧版同様、`rehash` は生成済みの集約 Deactivate→Activate スクリプトを**現シェルで dot-source** する必要があります。

- CLI の `anyvm rehash` は「スクリプトを最新化」する役割に限定。
- 実際の環境反映は、シェル起動プロファイルに仕込む薄い関数が担う（[08 §シェル連携](08-os-abstraction.md)）。`setup` コマンドがこの仕込みを行う。

## 6. 終了コードとエラー写像

```go
// cmd/anyvm/cli/exit.go
func ExitCode(err error) int {
	switch {
	case err == nil, errors.Is(err, errStopAfterVersion):
		return 0
	case errors.Is(err, anyvm.ErrVersionNotFound):
		return 2
	case errors.Is(err, anyvm.ErrAlreadyInstalled):
		return 0 // 冪等成功扱い
	case errors.Is(err, context.Canceled):
		return 130 // Ctrl+C
	default:
		return 1
	}
}
```

エラーは CLI 層で `slog.Error` に記録（[06](06-logging.md)）。`SilenceErrors=true` により cobra の二重出力を防ぎます。

## 7. ヘルプ・補完・体験

- `anyvm`／`anyvm <tool>` 単体はヘルプを表示（旧 `run` の `logger.d` no-op を改善）。
- cobra の `GenZshCompletion`/`GenPowerShellCompletion` でシェル補完を提供可能（任意）。
- `list` はマニフェスト由来でツール・別名・説明・現在の有効版を表形式表示。

## 8. cobra 採用時の注意点

| 項目 | 方針 |
|------|------|
| グローバル `--version` と tool の `-v` | 名前空間分離で衝突回避（§3） |
| 動的サブコマンド | Execute 前にマニフェスト先読みして AddCommand |
| Context 伝播 | `ExecuteContext` + `cmd.SetContext` で Engine と ctx を伝播 |
| エラー出力 | `SilenceErrors/SilenceUsage=true`、slog に一元化 |
| 並行コマンド | `update`/`unset`/`version` は Engine 内で errgroup 制御 |
