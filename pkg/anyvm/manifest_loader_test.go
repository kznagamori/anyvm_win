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

// TestEmbeddedManifestsAllTools はフェーズ3時点の全9ツールが登録され、
// 特殊フィールド（jdk の github_releases/version_subst、dotnet の特殊キー/post_download、
// gradle の shortver テンプレート）が正しく読めることを確認する。
func TestEmbeddedManifestsAllTools(t *testing.T) {
	reg := NewRegistry()
	registerBuiltins(reg)
	if err := LoadManifests(reg, manifests.FS, nil, nil); err != nil {
		t.Fatalf("LoadManifests: %v", err)
	}

	want := []string{"go", "nodejs", "dart", "flutter", "cmake", "kotlin", "gradle", "jdk", "dotnet"}
	for _, n := range want {
		if _, ok := reg.Manifest(n); !ok {
			t.Errorf("%s マニフェストが登録されていない", n)
		}
	}

	// jdk: github_releases + sources(3) + version_subst(_→+)。
	jdk, _ := reg.Manifest("jdk")
	if jdk.Discover.Type != "github_releases" || len(jdk.Discover.Sources) != 3 {
		t.Errorf("jdk discover が想定外: type=%s sources=%v", jdk.Discover.Type, jdk.Discover.Sources)
	}
	if jdk.Discover.VersionSubst["_"] != "+" {
		t.Errorf("jdk version_subst が想定外: %v", jdk.Discover.VersionSubst)
	}

	// dotnet: 特殊キー DOTNET_ROOT(x86) + post_download(nuget.exe)。
	dn, _ := reg.Manifest("dotnet")
	if _, ok := dn.Activate.Env["DOTNET_ROOT(x86)"]; !ok {
		t.Errorf("dotnet に DOTNET_ROOT(x86) キーが無い: %v", dn.Activate.Env)
	}
	if len(dn.Install.PostDownload) != 1 || dn.Install.PostDownload[0].Dest == "" {
		t.Errorf("dotnet post_download が想定外: %v", dn.Install.PostDownload)
	}

	// gradle: shortver テンプレートを含む（検証は FuncMap で通る）。
	gr, _ := reg.Manifest("gradle")
	if gr.Install.StripComponent == "" || gr.Activate.Env["GRADLE_USER_HOME"] == "" {
		t.Errorf("gradle のフィールドが想定外: strip=%q env=%v", gr.Install.StripComponent, gr.Activate.Env)
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

// TestValidateManifestRejectsBadEnvTemplate は activate.env 値の不正テンプレートを
// ロード時に弾くことを確認する（#5 検証強化。post_download.dest も同一ループで検証される）。
func TestValidateManifestRejectsBadEnvTemplate(t *testing.T) {
	reg := NewRegistry()
	registerBuiltins(reg)
	m := &Manifest{Name: "x"}
	m.Discover.Type = "none"
	m.Install.Type = "archive_extract"
	m.Activate.Env = map[string]string{"FOO": "{{.Current"} // 閉じ括弧なしの不正テンプレート
	if err := validateManifest(reg, m); err == nil {
		t.Fatal("activate.env の不正テンプレートが検証を通ってしまった")
	}

	// 正常なテンプレートは通る。
	m.Activate.Env = map[string]string{"FOO": "{{.Env}}/x"}
	if err := validateManifest(reg, m); err != nil {
		t.Fatalf("正常な activate.env テンプレートが拒否された: %v", err)
	}
}
