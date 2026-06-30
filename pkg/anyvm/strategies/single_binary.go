package strategies

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// SingleBinary は単一実行ファイルを <version>/<binary> に配置する Installer
// （.doc/03 §5, .doc/04 §6。Bazel / Ninja）。
//
//   - archive="zip": zip を展開して binary を取り出し配置（bazel/ninja。両者とも zip 配布）。
//   - archive="none": ダウンロードした exe をそのまま <version>/<binary> として配置。
//
// symexe ラッパー（ninja）は activate 時に張るため、ここでは binary 配置のみ行う。
type SingleBinary struct{}

// Install は単一実行ファイルを導入する。
func (SingleBinary) Install(ctx context.Context, m *types.Manifest, v types.VersionInfo, env types.Env, deps types.Deps) error {
	binary := m.Install.Binary
	if binary == "" {
		return fmt.Errorf("single_binary: install.binary が必要です")
	}
	verDir := env.VersionDir(v.Version)
	if err := os.MkdirAll(env.Cache, 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(verDir, 0o755); err != nil {
		return err
	}
	dstBinary := filepath.Join(verDir, binary)

	// archive="none": exe を直接 <version>/<binary> へダウンロード。
	if m.Install.Archive == "none" || m.Install.Archive == "" {
		logInfo(deps, "%s をダウンロード中...", v.File)
		if err := deps.Download.Download(ctx, v.URL, dstBinary, deps.Progress); err != nil {
			_ = os.RemoveAll(verDir)
			return err
		}
		return nil
	}

	// archive="zip": install-cache へ DL → 一時展開 → binary を取り出して配置。
	file := filepath.Join(env.Cache, v.File)
	if !fileExists(file) {
		logInfo(deps, "%s をダウンロード中...", v.File)
		if err := deps.Download.Download(ctx, v.URL, file, deps.Progress); err != nil {
			return err
		}
	}
	tmp := filepath.Join(env.Cache, "_extract_"+v.Version)
	_ = os.RemoveAll(tmp)
	logInfo(deps, "%s を展開中...", v.File)
	if err := deps.Extract.Extract(ctx, file, tmp, m.Install.Archive, deps.Progress); err != nil {
		_ = os.RemoveAll(tmp)
		return err
	}
	defer os.RemoveAll(tmp)

	// binary を tmp 直下→（無ければ）再帰探索で見つけて配置。
	src := filepath.Join(tmp, binary)
	if !fileExists(src) {
		found, ferr := findFile(tmp, binary)
		if ferr != nil || found == "" {
			_ = os.RemoveAll(verDir)
			return fmt.Errorf("アーカイブ内に %s が見つかりません", binary)
		}
		src = found
	}
	if err := copyFile(src, dstBinary); err != nil {
		_ = os.RemoveAll(verDir)
		return err
	}
	_ = os.Remove(file)
	return nil
}

// Uninstall は version の導入ディレクトリを削除する。
func (SingleBinary) Uninstall(_ context.Context, _ *types.Manifest, version string, env types.Env, _ types.Deps) error {
	verDir := env.VersionDir(version)
	if !fileExists(verDir) {
		return fmt.Errorf("%w: %s", types.ErrNotInstalled, version)
	}
	return os.RemoveAll(verDir)
}
