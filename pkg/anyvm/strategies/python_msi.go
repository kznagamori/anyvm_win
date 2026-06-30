package strategies

import (
	"context"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// PythonMsi は Python 公式インストーラ(exe)を WiX dark.exe で展開し、msiexec の
// administrative install で <version>/ に抽出、ensurepip で pip を整える Installer
// （.doc/03 §5, .doc/04 §7）。WiX/msiexec/ensurepip は本質的に必要なため外部実行で残す。
//
// 外部プロセスは deps.Platform.Run 経由で実行する（Windows 実機でのみ動作。
// 非 Windows ではコマンドが見つからず失敗する＝設計どおり）。
type PythonMsi struct{}

// Install は Python を導入する。
func (PythonMsi) Install(ctx context.Context, m *types.Manifest, v types.VersionInfo, env types.Env, deps types.Deps) error {
	if m.Install.WixURL == "" {
		return fmt.Errorf("python_msi: install.wix_url が必要です")
	}
	verDir := env.VersionDir(v.Version)
	if err := os.MkdirAll(env.Cache, 0o755); err != nil {
		return err
	}

	// 1. WiX(dark.exe) を取得・展開（既存ならスキップ）。
	wixDir := filepath.Join(env.Cache, "Wix")
	if !fileExists(filepath.Join(wixDir, "dark.exe")) {
		wixZip := filepath.Join(env.Cache, "wix311-binaries.zip")
		logInfo(deps, "WiX (dark.exe) を取得中...")
		if err := deps.Download.Download(ctx, m.Install.WixURL, wixZip, deps.Progress); err != nil {
			return err
		}
		if err := deps.Extract.Extract(ctx, wixZip, wixDir, "zip", deps.Progress); err != nil {
			return err
		}
		_ = os.Remove(wixZip)
	}

	// 2. Python 公式 exe を取得。
	exe := filepath.Join(env.Cache, v.File)
	logInfo(deps, "%s をダウンロード中...", v.File)
	if err := deps.Download.Download(ctx, v.URL, exe, deps.Progress); err != nil {
		return err
	}

	// 3. dark.exe で exe を展開。
	darkOut := filepath.Join(env.Cache, v.Version)
	_ = os.RemoveAll(darkOut)
	logInfo(deps, "dark.exe で MSI コンテナを展開中...")
	if _, err := deps.Platform.Run(ctx, filepath.Join(wixDir, "dark.exe"), []string{exe, "-x", darkOut}, types.RunOpt{}); err != nil {
		return fmt.Errorf("dark.exe 実行失敗: %w", err)
	}

	// 4. AttachedContainer 配下の msi を列挙（除外リスト適用）。
	if err := os.MkdirAll(verDir, 0o755); err != nil {
		return err
	}
	excl := map[string]bool{}
	for _, e := range m.Install.ExcludeMSI {
		excl[strings.ToLower(e)] = true
	}
	var msis []string
	_ = filepath.WalkDir(filepath.Join(darkOut, "AttachedContainer"), func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if !d.IsDir() && strings.EqualFold(filepath.Ext(p), ".msi") && !excl[strings.ToLower(d.Name())] {
			msis = append(msis, p)
		}
		return nil
	})
	if len(msis) == 0 {
		_ = os.RemoveAll(verDir)
		return fmt.Errorf("python_msi: 展開対象の msi が見つかりません（dark.exe 展開を確認）")
	}

	// 5. 各 msi を administrative install（msiexec /a で targetdir に抽出）。
	for _, msi := range msis {
		logInfo(deps, "msiexec /a %s", filepath.Base(msi))
		args := []string{"/quiet", "/a", msi, "targetdir=" + verDir}
		if _, err := deps.Platform.Run(ctx, "msiexec.exe", args, types.RunOpt{}); err != nil {
			_ = os.RemoveAll(verDir)
			return fmt.Errorf("msiexec 実行失敗(%s): %w", filepath.Base(msi), err)
		}
	}

	// 6. 後始末（dark 展開物・DL exe）。
	_ = os.RemoveAll(darkOut)
	_ = os.Remove(exe)

	// 7. ensurepip。
	if m.Install.RunEnsurePip {
		py := filepath.Join(verDir, "python.exe")
		if fileExists(py) {
			logInfo(deps, "ensurepip を実行中...")
			if _, err := deps.Platform.Run(ctx, py, []string{"-E", "-s", "-m", "ensurepip", "-U", "--default-pip"}, types.RunOpt{}); err != nil {
				return fmt.Errorf("ensurepip 実行失敗: %w", err)
			}
		}
	}
	return nil
}

// Uninstall は version の導入ディレクトリを削除する。
func (PythonMsi) Uninstall(_ context.Context, _ *types.Manifest, version string, env types.Env, _ types.Deps) error {
	verDir := env.VersionDir(version)
	if !fileExists(verDir) {
		return fmt.Errorf("%w: %s", types.ErrNotInstalled, version)
	}
	return os.RemoveAll(verDir)
}
