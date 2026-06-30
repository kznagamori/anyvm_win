package strategies

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// Rustup は rustup-init.exe を実行して Rust を導入する Installer（.doc/03 §5, .doc/04 §7）。
// 単一インストール型（版ディレクトリ・junction を持たず、.cargo/.rustup/.sccache を直接管理）。
// rustup-init は外部実行（deps.Platform.Run）で残す（Rust の正規導入手段）。
type Rustup struct{}

// Install は Rust を導入する（rustup-init 実行 + .cargo/config.toml 生成）。
func (Rustup) Install(ctx context.Context, m *types.Manifest, _ types.VersionInfo, env types.Env, deps types.Deps) error {
	if m.Install.InstallerURL == "" {
		return fmt.Errorf("rustup: install.installer_url が必要です")
	}
	cargoHome := filepath.Join(env.EnvDir, ".cargo")
	rustupHome := filepath.Join(env.EnvDir, ".rustup")
	sccacheDir := filepath.Join(env.EnvDir, ".sccache")

	// .cargo と .rustup が両方あれば導入済みとみなす。
	if fileExists(cargoHome) && fileExists(rustupHome) {
		return fmt.Errorf("%w: rust は既に導入済みです", types.ErrAlreadyInstalled)
	}
	if err := os.MkdirAll(env.Cache, 0o755); err != nil {
		return err
	}
	for _, d := range []string{cargoHome, rustupHome, sccacheDir} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return err
		}
	}

	// rustup-init.exe を取得。
	initExe := filepath.Join(env.Cache, "rustup-init.exe")
	logInfo(deps, "rustup-init.exe をダウンロード中...")
	if err := deps.Download.Download(ctx, m.Install.InstallerURL, initExe, deps.Progress); err != nil {
		return err
	}

	// rustup-init を実行（環境変数で CARGO_HOME/RUSTUP_HOME 等を指定）。
	host := m.Install.DefaultHost
	if host == "" {
		host = "x86_64-pc-windows-gnu"
	}
	toolchain := m.Install.Toolchain
	if toolchain == "" {
		toolchain = "stable"
	}
	runEnv := map[string]string{
		"CARGO_HOME":         cargoHome,
		"RUSTUP_HOME":        rustupHome,
		"RUSTUP_DIST_SERVER": "https://static.rust-lang.org",
		"RUSTUP_DIST_ROOT":   "https://static.rust-lang.org/rustup",
	}
	args := []string{"-y", "--no-modify-path", "--default-host", host, "--default-toolchain", toolchain}
	logInfo(deps, "rustup-init を実行中...")
	if _, err := deps.Platform.Run(ctx, initExe, args, types.RunOpt{Env: runEnv}); err != nil {
		_ = os.RemoveAll(cargoHome)
		_ = os.RemoveAll(rustupHome)
		return fmt.Errorf("rustup-init 実行失敗: %w", err)
	}

	// .cargo/config.toml を生成（UTF-8）。
	if m.Install.CargoConfig != "" {
		if err := os.WriteFile(filepath.Join(cargoHome, "config.toml"), []byte(m.Install.CargoConfig), 0o644); err != nil {
			return err
		}
	}
	_ = os.Remove(initExe)
	logInfo(deps, "rust を導入しました（sccache を使う場合は `cargo install sccache` を実行してください）")
	return nil
}

// Uninstall は .cargo/.rustup/.sccache を削除する（単一インストール型）。
func (Rustup) Uninstall(_ context.Context, _ *types.Manifest, _ string, env types.Env, _ types.Deps) error {
	removed := false
	for _, d := range []string{
		filepath.Join(env.EnvDir, ".cargo"),
		filepath.Join(env.EnvDir, ".rustup"),
		filepath.Join(env.EnvDir, ".sccache"),
	} {
		if fileExists(d) {
			removed = true
		}
		_ = os.RemoveAll(d)
	}
	if !removed {
		return fmt.Errorf("%w: rust", types.ErrNotInstalled)
	}
	return nil
}
