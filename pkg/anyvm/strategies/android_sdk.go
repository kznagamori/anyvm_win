package strategies

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// AndroidSDK は developer.android.com から commandline-tools を取得し、
// <version>/cmdline-tools/latest へ再配置する Installer（.doc/03 §5, .doc/04 §7）。
// discover=none のため install 時に毎回ページをスクレイプして最新版（数値ビルド番号）を決める。
type AndroidSDK struct{}

// テストで差し替え可能にするため var にする。
var (
	androidStudioURL = "https://developer.android.com/studio"
	androidRepoBase  = "https://dl.google.com/android/repository/"
)

// androidToolRe は commandlinetools-win-<build>_latest.zip を抽出する（group2=ビルド番号=版）。
var androidToolRe = regexp.MustCompile(`(commandlinetools-win-(\d+)_latest\.zip)`)

// Install は最新の commandline-tools を導入する（version 引数は使わずスクレイプで決定）。
func (AndroidSDK) Install(ctx context.Context, _ *types.Manifest, _ types.VersionInfo, env types.Env, deps types.Deps) error {
	// 1. studio ページから最新の commandline-tools（最後のマッチ）を得る。
	body, err := httpGetBody(ctx, deps, androidStudioURL)
	if err != nil {
		return err
	}
	matches := androidToolRe.FindAllStringSubmatch(string(body), -1)
	if len(matches) == 0 {
		return fmt.Errorf("android_sdk: commandline-tools のリンクが見つかりません")
	}
	last := matches[len(matches)-1]
	toolName, toolVersion := last[1], last[2]

	verDir := env.VersionDir(toolVersion)
	if fileExists(verDir) {
		return fmt.Errorf("%w: androidsdk %s", types.ErrAlreadyInstalled, toolVersion)
	}
	if err := os.MkdirAll(env.Cache, 0o755); err != nil {
		return err
	}

	// 2. zip を DL。
	url := androidRepoBase + toolName
	file := filepath.Join(env.Cache, toolName)
	logInfo(deps, "%s をダウンロード中...", toolName)
	if err := deps.Download.Download(ctx, url, file, deps.Progress); err != nil {
		return err
	}

	// 3. 一時展開（install-cache/_extract_<ver>/cmdline-tools ができる）。
	tmp := filepath.Join(env.Cache, "_extract_"+toolVersion)
	_ = os.RemoveAll(tmp)
	logInfo(deps, "%s を展開中...", toolName)
	if err := deps.Extract.Extract(ctx, file, tmp, "zip", deps.Progress); err != nil {
		_ = os.RemoveAll(tmp)
		return err
	}
	defer os.RemoveAll(tmp)

	// 4. cmdline-tools を <version>/cmdline-tools/latest へ再配置。
	src := filepath.Join(tmp, "cmdline-tools")
	if !fileExists(src) {
		return fmt.Errorf("android_sdk: 展開物に cmdline-tools がありません")
	}
	dstParent := filepath.Join(verDir, "cmdline-tools")
	if err := os.MkdirAll(dstParent, 0o755); err != nil {
		return err
	}
	if err := os.Rename(src, filepath.Join(dstParent, "latest")); err != nil {
		_ = os.RemoveAll(verDir)
		return fmt.Errorf("cmdline-tools の再配置に失敗: %w", err)
	}
	_ = os.Remove(file)
	logInfo(deps, "androidsdk %s を導入しました", toolVersion)
	return nil
}

// Uninstall は version の導入ディレクトリを削除する。
func (AndroidSDK) Uninstall(_ context.Context, _ *types.Manifest, version string, env types.Env, _ types.Deps) error {
	verDir := env.VersionDir(version)
	if !fileExists(verDir) {
		return fmt.Errorf("%w: %s", types.ErrNotInstalled, version)
	}
	return os.RemoveAll(verDir)
}
