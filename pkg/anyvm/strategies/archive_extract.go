package strategies

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// ArchiveExtract はアーカイブ(zip/7z)を展開して導入する標準 Installer（.doc/03 §5, .doc/04 §4）。
//
// 手順:
//  1. install-cache へダウンロード（既存ならスキップ）
//  2. 一時ディレクトリへ展開
//  3. strip_component（テンプレート可）で指定された内部ディレクトリを <version> へリネーム
//     （strip_component が空ならアーカイブ直下をそのまま <version> として展開）
//  4. post_download の追加ファイルを取得（dotnet の nuget.exe 等）
//  5. ダウンロードファイルと一時ディレクトリを後始末
type ArchiveExtract struct{}

// Install は version を導入する。
func (ArchiveExtract) Install(ctx context.Context, m *types.Manifest, v types.VersionInfo, env types.Env, deps types.Deps) error {
	verDir := env.VersionDir(v.Version)

	// install-cache を準備し、アーカイブをダウンロードする。
	if err := os.MkdirAll(env.Cache, 0o755); err != nil {
		return err
	}
	file := filepath.Join(env.Cache, v.File)
	if !fileExists(file) {
		logInfo(deps, "%s をダウンロード中...", v.File)
		if err := deps.Download.Download(ctx, v.URL, file, deps.Progress); err != nil {
			return err
		}
	}

	// strip_component をテンプレート展開する（例: "node-v{{.Version}}-win-x64"）。
	sub, err := renderTemplate(m.Install.StripComponent, env.TemplateData(v.Version))
	if err != nil {
		return fmt.Errorf("strip_component テンプレート: %w", err)
	}

	if err := os.MkdirAll(filepath.Dir(verDir), 0o755); err != nil {
		return err
	}

	if sub == "" {
		// アーカイブ直下が導入ルート: 直接 <version> へ展開する。
		logInfo(deps, "%s を展開中...", v.File)
		if err := deps.Extract.Extract(ctx, file, verDir, m.Install.Archive, deps.Progress); err != nil {
			return err
		}
	} else {
		// 一旦一時ディレクトリへ展開し、内部の sub を <version> へリネームする。
		tmp := filepath.Join(env.Cache, "_extract_"+v.Version)
		_ = os.RemoveAll(tmp)
		logInfo(deps, "%s を展開中...", v.File)
		if err := deps.Extract.Extract(ctx, file, tmp, m.Install.Archive, deps.Progress); err != nil {
			return err
		}
		if err := os.Rename(filepath.Join(tmp, sub), verDir); err != nil {
			_ = os.RemoveAll(tmp)
			return fmt.Errorf("展開ディレクトリの移動(%s -> %s): %w", sub, verDir, err)
		}
		_ = os.RemoveAll(tmp)
	}

	// post_download（dotnet の nuget.exe 等）。
	for _, pd := range m.Install.PostDownload {
		dest, err := renderTemplate(pd.Dest, env.TemplateData(v.Version))
		if err != nil {
			return fmt.Errorf("post_download.dest テンプレート: %w", err)
		}
		if err := deps.Download.Download(ctx, pd.URL, dest, nil); err != nil {
			return err
		}
	}

	// ダウンロードしたアーカイブを後始末する。
	_ = os.Remove(file)
	return nil
}

// Uninstall は version の導入ディレクトリを削除する。
func (ArchiveExtract) Uninstall(_ context.Context, _ *types.Manifest, version string, env types.Env, _ types.Deps) error {
	verDir := env.VersionDir(version)
	if !fileExists(verDir) {
		return fmt.Errorf("%w: %s", types.ErrNotInstalled, version)
	}
	return os.RemoveAll(verDir)
}

// logInfo は deps.Logger があれば Info ログを出す簡易ヘルパー。
func logInfo(deps types.Deps, format string, args ...any) {
	if deps.Logger != nil {
		deps.Logger.Info(fmt.Sprintf(format, args...))
	}
}
