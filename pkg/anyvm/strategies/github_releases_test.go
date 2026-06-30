package strategies

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// TestGithubReleasesDiscover は asset_pattern によるアセット抽出・version_subst(_→+)・
// 非対象アセット(.msi)の除外・昇順ソートと、URL/File の取得を検証する（.doc/12）。
func TestGithubReleasesDiscover(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("page") == "1" {
			_, _ = w.Write([]byte(`[
				{"assets":[
					{"name":"OpenJDK17U-jdk_x64_windows_hotspot_17.0.9_9.zip","browser_download_url":"https://ex/17.0.9_9.zip"},
					{"name":"OpenJDK17U-jdk_x64_windows_hotspot_17.0.9_9.msi","browser_download_url":"https://ex/x.msi"}
				]},
				{"assets":[
					{"name":"OpenJDK17U-jdk_x64_windows_hotspot_17.0.1_12.zip","browser_download_url":"https://ex/17.0.1_12.zip"}
				]}
			]`))
			return
		}
		_, _ = w.Write([]byte("[]"))
	}))
	defer srv.Close()
	old := githubAPIBase
	githubAPIBase = srv.URL
	defer func() { githubAPIBase = old }()

	m := &types.Manifest{
		Name: "jdk",
		Discover: types.DiscoverSpec{
			Type:         "github_releases",
			Sources:      []string{"adoptium/temurin17-binaries"},
			AssetPattern: `jdk_x64_windows_hotspot_(\d+\.\d+\.\d+(_\d+)?)\.zip$`,
			VersionSubst: map[string]string{"_": "+"},
		},
	}
	deps := types.Deps{HTTP: http.DefaultClient}

	got, err := (GithubReleases{}).Discover(context.Background(), m, deps)
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	// .msi は除外、_→+ 置換、昇順（17.0.1+12 < 17.0.9+9）。
	if len(got) != 2 {
		t.Fatalf("件数 = %d, want 2: %+v", len(got), got)
	}
	if got[0].Version != "17.0.1+12" || got[1].Version != "17.0.9+9" {
		t.Fatalf("バージョン/順序が想定外: %+v", got)
	}
	if got[1].URL != "https://ex/17.0.9_9.zip" {
		t.Fatalf("URL が想定外: %q", got[1].URL)
	}
	if got[1].File != "OpenJDK17U-jdk_x64_windows_hotspot_17.0.9_9.zip" {
		t.Fatalf("File が想定外: %q", got[1].File)
	}
}
