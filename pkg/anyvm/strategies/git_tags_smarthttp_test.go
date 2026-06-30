package strategies

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// pktLine は git の pkt-line 1 行を組み立てる（長さ4桁hex + データ）。
func pktLine(s string) string { return fmt.Sprintf("%04x%s", len(s)+4, s) }

// TestParsePktLineTags は pkt-line 形式から refs/tags を抽出し、peeled を畳むことを検証する。
func TestParsePktLineTags(t *testing.T) {
	body := pktLine("# service=git-upload-pack\n") + "0000" +
		pktLine("sha1 HEAD\x00caps\n") +
		pktLine("sha1 refs/tags/v1.0.0\n") +
		pktLine("sha2 refs/tags/v1.0.0^{}\n") + // peeled（基底へ畳む）
		pktLine("sha3 refs/tags/v2.0.0\n") +
		pktLine("sha4 refs/heads/main\n") + // tag でない参照は無視
		"0000"
	got := parsePktLineTags([]byte(body))
	if len(got) != 2 || got[0] != "v1.0.0" || got[1] != "v2.0.0" {
		t.Fatalf("parsePktLineTags = %v, want [v1.0.0 v2.0.0]", got)
	}
}

// TestGitTagsDiscoverFallback は REST が 403(レート制限)のとき、スマート HTTP へ
// フォールバックして版を取得することを検証する（.doc/04 §1）。
func TestGitTagsDiscoverFallback(t *testing.T) {
	// REST は常に 403 を返す（レート制限を模す）。
	restSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte("API rate limit exceeded"))
	}))
	defer restSrv.Close()
	old := githubAPIBase
	githubAPIBase = restSrv.URL
	defer func() { githubAPIBase = old }()

	// スマート HTTP サーバ（任意パスに pkt-line を返す）。
	body := pktLine("# service=git-upload-pack\n") + "0000" +
		pktLine("sha refs/tags/go1.21.0\n") +
		pktLine("sha refs/tags/go1.22.0\n") +
		pktLine("sha refs/tags/go1.12.0\n") + // min_version 未満で除外
		"0000"
	smartSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(body))
	}))
	defer smartSrv.Close()

	// source は parseGitHubRepo が owner/repo を取れるよう "github.com/golang/go" を含め、
	// かつスマート HTTP のリクエスト先がテストサーバになるようにする。
	m := &types.Manifest{
		Name: "go",
		Discover: types.DiscoverSpec{
			Type:        "git_tags",
			Source:      smartSrv.URL + "/github.com/golang/go",
			StripPrefix: "go",
			Include:     `^\d+\.\d+\.\d+$`,
			MinVersion:  "1.13.0",
		},
		Artifact: types.ArtifactSpec{URL: "https://go.dev/dl/go{{.Version}}.zip", File: "f"},
	}
	deps := types.Deps{HTTP: http.DefaultClient}

	got, err := (GitTags{}).Discover(context.Background(), m, deps)
	if err != nil {
		t.Fatalf("Discover(fallback): %v", err)
	}
	if len(got) != 2 || got[0].Version != "1.21.0" || got[1].Version != "1.22.0" {
		t.Fatalf("fallback discover = %+v, want 1.21.0,1.22.0", got)
	}
}
