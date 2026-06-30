package strategies

import (
	"archive/zip"
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"github.com/kznagamori/anyvm_win/internal/download"
	"github.com/kznagamori/anyvm_win/internal/extract"
	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// makeZip はテスト用に「名前 -> 内容」から zip バイト列を組み立てる。
func makeZip(files map[string]string) []byte {
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for name, content := range files {
		w, _ := zw.Create(name)
		_, _ = w.Write([]byte(content))
	}
	_ = zw.Close()
	return buf.Bytes()
}

// TestArchiveExtractInstall は install の全経路（実 HTTP ダウンロード → zip 展開 →
// strip_component リネーム → 後始末 → uninstall）を、ローカル HTTP サーバと
// 実 Downloader/Extractor を用いて検証する（フェーズ2 完了条件の install 部分）。
func TestArchiveExtractInstall(t *testing.T) {
	// go の windows zip を模した構成（最上位が "go/"）。
	zipBytes := makeZip(map[string]string{
		"go/bin/go.exe": "fake-binary",
		"go/VERSION":    "go1.22.0",
	})
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(zipBytes)
	}))
	defer srv.Close()

	root := t.TempDir()
	envDir := filepath.Join(root, "envs", "go")
	env := types.Env{
		Root:   root,
		Tool:   "go",
		EnvDir: envDir,
		Cache:  filepath.Join(envDir, "install-cache"),
	}
	m := &types.Manifest{
		Name:    "go",
		Install: types.InstallSpec{Type: "archive_extract", Archive: "zip", StripComponent: "go"},
	}
	v := types.VersionInfo{Version: "1.22.0", URL: srv.URL + "/go.zip", File: "go1.22.0-win.zip"}
	deps := types.Deps{
		HTTP:     http.DefaultClient,
		Download: download.New(http.DefaultClient),
		Extract:  extract.New(),
	}

	if err := (ArchiveExtract{}).Install(context.Background(), m, v, env, deps); err != nil {
		t.Fatalf("Install: %v", err)
	}

	// strip_component "go" の内部が <version> 直下へ移設されている。
	if !fileExists(filepath.Join(envDir, "1.22.0", "bin", "go.exe")) {
		t.Error("go.exe が <version>/bin に配置されていない")
	}
	if !fileExists(filepath.Join(envDir, "1.22.0", "VERSION")) {
		t.Error("VERSION が <version> 直下に配置されていない")
	}
	// ダウンロードアーカイブと一時展開ディレクトリが後始末されている。
	if fileExists(filepath.Join(env.Cache, v.File)) {
		t.Error("ダウンロードアーカイブが後始末されていない")
	}
	if fileExists(filepath.Join(env.Cache, "_extract_1.22.0")) {
		t.Error("一時展開ディレクトリが後始末されていない")
	}

	// Uninstall で版ディレクトリが削除される。
	if err := (ArchiveExtract{}).Uninstall(context.Background(), m, "1.22.0", env, deps); err != nil {
		t.Fatalf("Uninstall: %v", err)
	}
	if fileExists(filepath.Join(envDir, "1.22.0")) {
		t.Error("Uninstall 後も版ディレクトリが残っている")
	}
	// 未導入版の Uninstall は ErrNotInstalled。
	if err := (ArchiveExtract{}).Uninstall(context.Background(), m, "9.9.9", env, deps); err == nil {
		t.Error("未導入版の Uninstall がエラーにならなかった")
	}
}

// TestArchiveExtractInstallShortverStrip は shortver を含むテンプレート strip_component
// （gradle 相当: "gradle-{{shortver .Version}}"）が正しく展開・リネームされることを検証する。
func TestArchiveExtractInstallShortverStrip(t *testing.T) {
	// gradle の zip を模した構成（最上位が "gradle-8.5/"。shortver(8.5.0)=8.5）。
	zipBytes := makeZip(map[string]string{
		"gradle-8.5/bin/gradle": "fake",
		"gradle-8.5/LICENSE":    "lic",
	})
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(zipBytes)
	}))
	defer srv.Close()

	root := t.TempDir()
	envDir := filepath.Join(root, "envs", "gradle")
	env := types.Env{Root: root, Tool: "gradle", EnvDir: envDir, Cache: filepath.Join(envDir, "install-cache")}
	m := &types.Manifest{
		Name:    "gradle",
		Install: types.InstallSpec{Type: "archive_extract", Archive: "zip", StripComponent: "gradle-{{shortver .Version}}"},
	}
	v := types.VersionInfo{Version: "8.5.0", URL: srv.URL + "/g.zip", File: "gradle-8.5.0-bin.zip"}
	deps := types.Deps{HTTP: http.DefaultClient, Download: download.New(http.DefaultClient), Extract: extract.New()}

	if err := (ArchiveExtract{}).Install(context.Background(), m, v, env, deps); err != nil {
		t.Fatalf("Install: %v", err)
	}
	// strip_component "gradle-8.5" の内部が <version>=8.5.0 直下へ移設されている。
	if !fileExists(filepath.Join(envDir, "8.5.0", "bin", "gradle")) {
		t.Error("gradle バイナリが <version>/bin に配置されていない（shortver strip_component 不正）")
	}
}

// TestArchiveExtractInstallEmptyStripPostDownload は strip_component="" の直接展開と
// post_download（dotnet の nuget.exe 相当。dest に {{.VersionDir}})を検証する。
func TestArchiveExtractInstallEmptyStripPostDownload(t *testing.T) {
	// dotnet の zip を模した構成（最上位ディレクトリ無し。zip 直下が SDK ルート）。
	zipBytes := makeZip(map[string]string{
		"dotnet.exe":      "fake-sdk",
		"sdk/version.txt": "9.0.100",
	})
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/nuget.exe" {
			_, _ = w.Write([]byte("fake-nuget"))
			return
		}
		_, _ = w.Write(zipBytes)
	}))
	defer srv.Close()

	root := t.TempDir()
	envDir := filepath.Join(root, "envs", "dotnet")
	env := types.Env{Root: root, Tool: "dotnet", EnvDir: envDir, Cache: filepath.Join(envDir, "install-cache")}
	m := &types.Manifest{
		Name: "dotnet",
		Install: types.InstallSpec{
			Type: "archive_extract", Archive: "zip", StripComponent: "",
			PostDownload: []types.PostDownload{{URL: srv.URL + "/nuget.exe", Dest: "{{.VersionDir}}/nuget.exe"}},
		},
	}
	v := types.VersionInfo{Version: "9.0.100", URL: srv.URL + "/dotnet.zip", File: "dotnet-sdk-9.0.100-win-x64.zip"}
	deps := types.Deps{HTTP: http.DefaultClient, Download: download.New(http.DefaultClient), Extract: extract.New()}

	if err := (ArchiveExtract{}).Install(context.Background(), m, v, env, deps); err != nil {
		t.Fatalf("Install: %v", err)
	}
	// strip_component="" なので zip 直下が <version> 直下へ展開されている。
	if !fileExists(filepath.Join(envDir, "9.0.100", "dotnet.exe")) {
		t.Error("dotnet.exe が <version> 直下に配置されていない（空 strip_component 不正）")
	}
	// post_download の nuget.exe が <version>/nuget.exe に配置されている。
	if !fileExists(filepath.Join(envDir, "9.0.100", "nuget.exe")) {
		t.Error("post_download の nuget.exe が配置されていない")
	}
}
