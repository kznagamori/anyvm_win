package anyvm

import (
	"testing"

	"github.com/kznagamori/anyvm_win/manifests"
)

// TestEmbeddedManifestsValid は同梱マニフェストがすべて検証を通り、
// 想定ツールが登録されることを確認する（.doc/12 §2）。
func TestEmbeddedManifestsValid(t *testing.T) {
	reg := NewRegistry()
	registerBuiltins(reg)
	if err := LoadManifests(reg, manifests.FS, nil, nil); err != nil {
		t.Fatalf("LoadManifests: %v", err)
	}

	// 現フェーズの同梱ツール。
	if _, ok := reg.Manifest("go"); !ok {
		t.Fatal("go マニフェストが登録されていない")
	}
	// エイリアス解決。
	if m, ok := reg.Manifest("golang"); !ok || m.Name != "go" {
		t.Fatalf("golang エイリアスが go に解決されない: %v %v", m, ok)
	}

	m, _ := reg.Manifest("go")
	if m.Discover.Type != "git_tags" || m.Install.Type != "archive_extract" {
		t.Fatalf("go の type が想定外: discover=%s install=%s", m.Discover.Type, m.Install.Type)
	}
	if m.Artifact.URL == "" || m.Layout.VersionPattern == "" {
		t.Fatal("go の artifact.url / layout.version_pattern が空")
	}
}

// TestValidateManifestRejectsUnknownType は未登録 type を弾くことを確認する。
func TestValidateManifestRejectsUnknownType(t *testing.T) {
	reg := NewRegistry()
	registerBuiltins(reg)
	m := &Manifest{
		Name:     "x",
		Discover: Manifest{}.Discover, // 空
	}
	m.Discover.Type = "no_such_discover"
	m.Install.Type = "archive_extract"
	if err := validateManifest(reg, m); err == nil {
		t.Fatal("未登録の discover type が検証を通ってしまった")
	}
}
