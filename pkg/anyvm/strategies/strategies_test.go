package strategies

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// TestGitTagsDiscover は GitHub Tags API をフェイクして、接頭辞除去・正規表現・
// min_version の絞り込みと artifact テンプレート展開を検証する（.doc/12 §6）。
func TestGitTagsDiscover(t *testing.T) {
	// ページ 1 で 4 件、以降は空（ページング終了）を返すフェイク API。
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("page") == "1" {
			_, _ = w.Write([]byte(`[{"name":"go1.22.0"},{"name":"go1.12.0"},{"name":"go1.21.5"},{"name":"weird-tag"}]`))
			return
		}
		_, _ = w.Write([]byte(`[]`))
	}))
	defer srv.Close()

	// API ベースをフェイクに差し替える。
	old := githubAPIBase
	githubAPIBase = srv.URL
	defer func() { githubAPIBase = old }()

	m := &types.Manifest{
		Name: "go",
		Discover: types.DiscoverSpec{
			Type:        "git_tags",
			Source:      "https://github.com/golang/go",
			StripPrefix: "go",
			Include:     `^\d+\.\d+\.\d+$`,
			MinVersion:  "1.13.0",
		},
		Artifact: types.ArtifactSpec{
			URL:  "https://go.dev/dl/go{{.Version}}.windows-amd64.zip",
			File: "go{{.Version}}.windows-amd64.zip",
		},
	}
	deps := types.Deps{HTTP: http.DefaultClient}

	got, err := (GitTags{}).Discover(context.Background(), m, deps)
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	// 1.12.0 は min_version 未満、weird-tag は include 不一致で除外 → 1.21.5, 1.22.0 が昇順で残る。
	if len(got) != 2 {
		t.Fatalf("件数 = %d, want 2: %+v", len(got), got)
	}
	if got[0].Version != "1.21.5" || got[1].Version != "1.22.0" {
		t.Fatalf("順序が想定外: %+v", got)
	}
	if got[1].URL != "https://go.dev/dl/go1.22.0.windows-amd64.zip" {
		t.Fatalf("URL テンプレート展開が想定外: %q", got[1].URL)
	}
}

// TestBuildActivation は PATH の順序保持・環境変数のソート・テンプレート展開を検証する。
func TestBuildActivation(t *testing.T) {
	m := &types.Manifest{
		Name: "go",
		Activate: types.ActivateSpec{
			Path: []string{"{{.Current}}/bin", "{{.Env}}/go/bin"},
			Env: map[string]string{
				"GOROOT": "{{.Current}}",
				"GOPATH": "{{.Env}}/go",
			},
		},
	}
	env := types.Env{Root: "R", Tool: "go", EnvDir: "R/envs/go", Current: "R/envs/go/current"}
	act := BuildActivation(m, "1.22.0", env)

	// PATH は順序保持。
	if len(act.Path) != 2 || act.Path[0] != "R/envs/go/current/bin" || act.Path[1] != "R/envs/go/go/bin" {
		t.Fatalf("PATH が想定外: %v", act.Path)
	}
	// 環境変数はキー名でソート（GOPATH, GOROOT）。
	if len(act.Env) != 2 || act.Env[0].Key != "GOPATH" || act.Env[1].Key != "GOROOT" {
		t.Fatalf("環境変数の順序が想定外: %v", act.Env)
	}
	if act.Env[1].Value != "R/envs/go/current" {
		t.Fatalf("GOROOT 値が想定外: %q", act.Env[1].Value)
	}
}

// TestParseGitHubRepo は owner/repo の抽出を検証する。
func TestParseGitHubRepo(t *testing.T) {
	owner, repo, err := parseGitHubRepo("https://github.com/golang/go")
	if err != nil || owner != "golang" || repo != "go" {
		t.Fatalf("parseGitHubRepo = %q/%q err=%v", owner, repo, err)
	}
	if _, _, err := parseGitHubRepo("https://example.com/x/y"); err == nil {
		t.Fatal("非 GitHub URL がエラーにならなかった")
	}
}
