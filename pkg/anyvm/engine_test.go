package anyvm

import (
	"context"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"testing"

	"github.com/kznagamori/anyvm_win/internal/platform"
	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// quietLogger は出力を捨てるロガー（テスト用）。
func quietLogger() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

// TestEngineSetUnset は Fake Platform を用いて set/unset の主要効果を検証する
// （実 OS API・実ネットワークなし。.doc/12 §7）。
func TestEngineSetUnset(t *testing.T) {
	root := t.TempDir()
	verDir := filepath.Join(root, "envs", "go", "1.22.0")
	if err := os.MkdirAll(verDir, 0o755); err != nil {
		t.Fatal(err)
	}

	fp := platform.NewFake()
	fp.Files[verDir] = true // Set は導入済みか Exists で確認するため

	eng, err := NewEngine(Config{Root: root, Platform: fp, Logger: quietLogger()})
	if err != nil {
		t.Fatal(err)
	}

	if err := eng.Set(context.Background(), "go", "1.22.0"); err != nil {
		t.Fatalf("Set: %v", err)
	}

	// current -> version のリンクが張られている。
	cur := filepath.Join(root, "envs", "go", "current")
	if got := fp.Links[cur]; got != verDir {
		t.Fatalf("current リンク先 = %q, want %q", got, verDir)
	}
	// アクティブバージョンが保存されている。
	if v, ok := eng.ActiveVersion("go"); !ok || v != "1.22.0" {
		t.Fatalf("ActiveVersion = %q,%v", v, ok)
	}
	// 有効化スクリプトが生成されている。
	scriptPath := filepath.Join(root, "scripts", "goActivate.ps1")
	if _, ok := fp.Scripts[scriptPath]; !ok {
		t.Fatalf("goActivate.ps1 が生成されていない: %v", keys(fp.Scripts))
	}

	// 無効化。
	if err := eng.Unset(context.Background(), "go"); err != nil {
		t.Fatalf("Unset: %v", err)
	}
	if _, ok := fp.Links[cur]; ok {
		t.Fatal("Unset 後も current リンクが残っている")
	}
	if _, ok := eng.ActiveVersion("go"); ok {
		t.Fatal("Unset 後もアクティブバージョンが残っている")
	}
}

// TestEngineSetVersionNotInstalled は未導入版の set がエラーになることを確認する。
func TestEngineSetVersionNotInstalled(t *testing.T) {
	root := t.TempDir()
	eng, err := NewEngine(Config{Root: root, Platform: platform.NewFake(), Logger: quietLogger()})
	if err != nil {
		t.Fatal(err)
	}
	err = eng.Set(context.Background(), "go", "9.9.9")
	if err == nil {
		t.Fatal("未導入版の set がエラーにならなかった")
	}
}

// TestStateCacheRoundTrip は状態・キャッシュの読み書きを検証する。
func TestStateCacheRoundTrip(t *testing.T) {
	root := t.TempDir()

	s := NewFileStateStore(root)
	if err := s.SetActive("go", "1.22.0"); err != nil {
		t.Fatal(err)
	}
	if v, ok := s.Active("go"); !ok || v != "1.22.0" {
		t.Fatalf("Active = %q,%v", v, ok)
	}
	if err := s.ClearActive("go"); err != nil {
		t.Fatal(err)
	}
	if _, ok := s.Active("go"); ok {
		t.Fatal("ClearActive 後もアクティブが残っている")
	}

	c := NewFileCacheStore(root)
	vs := []types.VersionInfo{
		{Version: "1.21.0", URL: "u1", File: "f1"},
		{Version: "1.22.0", URL: "u2", File: "f2"},
	}
	if err := c.Save("go", vs); err != nil {
		t.Fatal(err)
	}
	if v, ok := c.Latest("go"); !ok || v.Version != "1.22.0" {
		t.Fatalf("Latest = %v,%v", v, ok)
	}
	if v, ok := c.Find("go", "1.21.0"); !ok || v.URL != "u1" {
		t.Fatalf("Find = %v,%v", v, ok)
	}
}

// keys はマップのキー一覧（テストのエラー表示用）。
func keys[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}
