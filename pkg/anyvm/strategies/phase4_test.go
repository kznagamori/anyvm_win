package strategies

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/kznagamori/anyvm_win/internal/download"
	"github.com/kznagamori/anyvm_win/internal/extract"
	"github.com/kznagamori/anyvm_win/internal/platform"
	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// --- フェイク Downloader（ネットワークなしで dest を生成する） ---

// fakeDownloader は dest にダミー内容を書く。url に "wix" を含む場合は dark.exe を含む zip を書く。
type fakeDownloader struct{}

func (fakeDownloader) Download(_ context.Context, url, dest string, _ types.ProgressFunc) error {
	_ = os.MkdirAll(filepath.Dir(dest), 0o755)
	if strings.Contains(url, "wix") {
		return os.WriteFile(dest, makeZip(map[string]string{"dark.exe": "DARK"}), 0o644)
	}
	return os.WriteFile(dest, []byte("payload"), 0o644)
}

// --- winlibs / mingw / html_scrape discover ---

func TestParseWinlibsTag(t *testing.T) {
	// pattern2（新, LLVM あり, posix & ucrt）
	gcc, llvm, mingw, rev, ok := parseWinlibsTag("13.2.0posix-16.0.6-11.0.1-ucrt-r1")
	if !ok || gcc != "13.2.0" || llvm != "16.0.6" || mingw != "11.0.1" || rev != "1" {
		t.Fatalf("pattern2: %s %s %s %s ok=%v", gcc, llvm, mingw, rev, ok)
	}
	// pattern3（新, LLVM なし → 0.0.0）
	gcc, llvm, mingw, rev, ok = parseWinlibsTag("12.2.0posix-10.0.0-ucrt-r3")
	if !ok || gcc != "12.2.0" || llvm != "0.0.0" || mingw != "10.0.0" || rev != "3" {
		t.Fatalf("pattern3: %s %s %s %s ok=%v", gcc, llvm, mingw, rev, ok)
	}
	// pattern1（旧, LLVM あり, threading 無し, ucrt）
	if _, _, _, _, ok := parseWinlibsTag("11.2.0-12.0.0-9.0.0-ucrt-r1"); !ok {
		t.Fatal("pattern1 (ucrt) を採用すべき")
	}
	// win32 / msvcrt は不採用
	if _, _, _, _, ok := parseWinlibsTag("13.2.0win32-16.0.6-11.0.1-ucrt-r1"); ok {
		t.Fatal("win32 は不採用にすべき")
	}
	if _, _, _, _, ok := parseWinlibsTag("13.2.0posix-16.0.6-11.0.1-msvcrt-r1"); ok {
		t.Fatal("msvcrt は不採用にすべき")
	}
}

// githubTagsServer は GitHub tags API を模し、1 ページ目に与えたタグ名を返す。
func githubTagsServer(t *testing.T, names ...string) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("page") != "1" {
			_, _ = w.Write([]byte("[]"))
			return
		}
		var sb strings.Builder
		sb.WriteByte('[')
		for i, n := range names {
			if i > 0 {
				sb.WriteByte(',')
			}
			sb.WriteString(`{"name":"` + n + `"}`)
		}
		sb.WriteByte(']')
		_, _ = w.Write([]byte(sb.String()))
	}))
}

func TestMingwTagsDiscover(t *testing.T) {
	srv := githubTagsServer(t, "13.2.0-rt_v11-rev1", "12.2.0-rt_v10-rev2", "not-a-version")
	defer srv.Close()
	old := githubAPIBase
	githubAPIBase = srv.URL
	defer func() { githubAPIBase = old }()

	m := &types.Manifest{Discover: types.DiscoverSpec{Type: "mingw_tags", Source: "https://github.com/niXman/mingw-builds-binaries"}}
	got, err := (MingwTags{}).Discover(context.Background(), m, types.Deps{HTTP: http.DefaultClient})
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("件数=%d, want 2: %+v", len(got), got)
	}
	latest := got[1] // 昇順で最後 = 13.2.0-rt_v11-rev1
	if latest.Version != "13.2.0-rt_v11-rev1" {
		t.Fatalf("version=%q", latest.Version)
	}
	wantFile := "x86_64-13.2.0-release-posix-seh-ucrt-rt_v11-rev1.7z"
	if latest.File != wantFile {
		t.Fatalf("file=%q want %q", latest.File, wantFile)
	}
	wantURL := "https://github.com/niXman/mingw-builds-binaries/releases/download/13.2.0-rt_v11-rev1/" + wantFile
	if latest.URL != wantURL {
		t.Fatalf("url=%q", latest.URL)
	}
}

func TestWinlibsTagsDiscover(t *testing.T) {
	// LLVM あり と LLVM なし、win32（除外）を混ぜる。
	srv := githubTagsServer(t,
		"13.2.0posix-16.0.6-11.0.1-ucrt-r1",
		"12.2.0posix-10.0.0-ucrt-r3",
		"13.2.0win32-16.0.6-11.0.1-ucrt-r1",
	)
	defer srv.Close()
	old := githubAPIBase
	githubAPIBase = srv.URL
	defer func() { githubAPIBase = old }()

	m := &types.Manifest{Discover: types.DiscoverSpec{Type: "winlibs_tags", Source: "https://github.com/brechtsanders/winlibs_mingw"}}
	got, err := (WinlibsTags{}).Discover(context.Background(), m, types.Deps{HTTP: http.DefaultClient})
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("件数=%d, want 2 (win32除外): %+v", len(got), got)
	}
	// 昇順: 12.2.0-0.0.0-10.0.0-3 < 13.2.0-16.0.6-11.0.1-1
	latest := got[1]
	if latest.Version != "13.2.0-16.0.6-11.0.1-1" {
		t.Fatalf("version=%q", latest.Version)
	}
	wantFile := "winlibs-x86_64-posix-seh-gcc-13.2.0-llvm-16.0.6-mingw-w64ucrt-11.0.1-r1.7z"
	if latest.File != wantFile {
		t.Fatalf("file=%q", latest.File)
	}
	// LLVM なし版の file（0.0.0 → llvm セグメント無し）
	noLLVM := got[0]
	wantNoLLVM := "winlibs-x86_64-posix-seh-gcc-12.2.0-mingw-w64ucrt-10.0.0-r3.7z"
	if noLLVM.File != wantNoLLVM {
		t.Fatalf("LLVMなし file=%q want %q", noLLVM.File, wantNoLLVM)
	}
}

func TestHTMLScrapeDiscover(t *testing.T) {
	page := `<html><body>
		<a href="https://www.python.org/ftp/python/3.12.1/python-3.12.1-amd64.exe">Windows installer (64-bit)</a>
		<a href="https://www.python.org/ftp/python/3.11.5/python-3.11.5-amd64.exe">Windows installer (64-bit)</a>
		<a href="https://www.python.org/ftp/python/3.12.1/python-3.12.1-embed-amd64.zip">Windows embeddable package (64-bit)</a>
	</body></html>`
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(page))
	}))
	defer srv.Close()

	m := &types.Manifest{
		Discover: types.DiscoverSpec{
			Type:       "html_scrape",
			URL:        srv.URL,
			AnchorText: "Windows installer (64-bit)",
			HrefRegex:  `/python/(\d+\.\d+\.\d+)/python-\d+\.\d+\.\d+-amd64\.exe$`,
		},
		Artifact: types.ArtifactSpec{
			URL:  "https://www.python.org/ftp/python/{{.Version}}/python-{{.Version}}-amd64.exe",
			File: "python-{{.Version}}-amd64.exe",
		},
	}
	got, err := (HTMLScrape{}).Discover(context.Background(), m, types.Deps{HTTP: http.DefaultClient})
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	// embeddable(.zip) は anchor_text 不一致で除外 → 2 件、昇順。
	if len(got) != 2 || got[0].Version != "3.11.5" || got[1].Version != "3.12.1" {
		t.Fatalf("discover=%+v", got)
	}
	if got[1].URL != "https://www.python.org/ftp/python/3.12.1/python-3.12.1-amd64.exe" {
		t.Fatalf("url=%q", got[1].URL)
	}
}

// --- single_binary install ---

func TestSingleBinaryInstallZip(t *testing.T) {
	zipBytes := makeZip(map[string]string{"ninja.exe": "fake-ninja"})
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(zipBytes)
	}))
	defer srv.Close()

	root := t.TempDir()
	envDir := filepath.Join(root, "envs", "ninja")
	env := types.Env{Root: root, Tool: "ninja", EnvDir: envDir, Cache: filepath.Join(envDir, "install-cache")}
	m := &types.Manifest{Name: "ninja", Install: types.InstallSpec{Type: "single_binary", Archive: "zip", Binary: "ninja.exe"}}
	v := types.VersionInfo{Version: "1.11.1", URL: srv.URL + "/ninja.zip", File: "ninja-1.11.1-win.zip"}
	deps := types.Deps{HTTP: http.DefaultClient, Download: download.New(http.DefaultClient), Extract: extract.New()}

	if err := (SingleBinary{}).Install(context.Background(), m, v, env, deps); err != nil {
		t.Fatalf("Install: %v", err)
	}
	if b, err := os.ReadFile(filepath.Join(envDir, "1.11.1", "ninja.exe")); err != nil || string(b) != "fake-ninja" {
		t.Fatalf("ninja.exe 配置失敗: err=%v content=%q", err, string(b))
	}
}

// --- symexe wrapper（ninja の activate） ---

func TestSymexeWrapper(t *testing.T) {
	root := t.TempDir()
	tools := filepath.Join(root, "tools")
	_ = os.MkdirAll(tools, 0o755)
	_ = os.WriteFile(filepath.Join(tools, "symexe.exe"), []byte("SYMEXE"), 0o755)

	envDir := filepath.Join(root, "envs", "ninja")
	env := types.Env{
		Root: root, Tool: "ninja", EnvDir: envDir,
		Current: filepath.Join(envDir, "current"),
		Tools:   tools,
		Scripts: filepath.Join(root, "scripts"),
	}
	_ = os.MkdirAll(env.Scripts, 0o755)
	m := &types.Manifest{
		Name:     "ninja",
		Install:  types.InstallSpec{Type: "single_binary", Binary: "ninja.exe", Wrapper: "symexe"},
		Layout:   types.LayoutSpec{Link: "none"},
		Activate: types.ActivateSpec{Path: []string{"{{.Current}}"}},
	}
	deps := types.Deps{Platform: platform.NewFake()}

	if err := (StdActivator{}).Activate(context.Background(), m, "1.11.1", env, deps); err != nil {
		t.Fatalf("Activate(symexe): %v", err)
	}
	// current/ninja.exe は symexe.exe のコピー。
	if b, err := os.ReadFile(filepath.Join(env.Current, "ninja.exe")); err != nil || string(b) != "SYMEXE" {
		t.Fatalf("current/ninja.exe: err=%v content=%q", err, string(b))
	}
	// current/ninja.ini に実体(<version>)へのパスが書かれている。
	ini, err := os.ReadFile(filepath.Join(env.Current, "ninja.ini"))
	if err != nil {
		t.Fatalf("ninja.ini: %v", err)
	}
	verDir := filepath.Join(envDir, "1.11.1")
	if !strings.Contains(string(ini), "[EXE]") || !strings.Contains(string(ini), filepath.Join(verDir, "ninja.exe")) {
		t.Fatalf("ninja.ini 内容が想定外:\n%s", ini)
	}
}

// --- rustup install（サブプロセス引数の検証） ---

func TestRustupInstall(t *testing.T) {
	root := t.TempDir()
	envDir := filepath.Join(root, "envs", "rust")
	env := types.Env{Root: root, Tool: "rust", EnvDir: envDir, Cache: filepath.Join(envDir, "install-cache")}
	m := &types.Manifest{
		Name: "rust",
		Install: types.InstallSpec{
			Type:         "rustup",
			InstallerURL: "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe",
			DefaultHost:  "x86_64-pc-windows-gnu",
			Toolchain:    "stable",
			CargoConfig:  "[target.x86_64-pc-windows-gnu]\nrustflags = []\n",
		},
	}
	fake := platform.NewFake()
	deps := types.Deps{Platform: fake, Download: fakeDownloader{}}

	if err := (Rustup{}).Install(context.Background(), m, types.VersionInfo{}, env, deps); err != nil {
		t.Fatalf("Install: %v", err)
	}
	if len(fake.Runs) != 1 {
		t.Fatalf("Run 回数=%d, want 1", len(fake.Runs))
	}
	r := fake.Runs[0]
	args := strings.Join(r.Args, " ")
	for _, want := range []string{"-y", "--no-modify-path", "--default-host x86_64-pc-windows-gnu", "--default-toolchain stable"} {
		if !strings.Contains(args, want) {
			t.Errorf("rustup-init 引数に %q が無い: %v", want, r.Args)
		}
	}
	if r.Opt.Env["CARGO_HOME"] != filepath.Join(envDir, ".cargo") || r.Opt.Env["RUSTUP_HOME"] != filepath.Join(envDir, ".rustup") {
		t.Errorf("環境変数が想定外: %v", r.Opt.Env)
	}
	if b, err := os.ReadFile(filepath.Join(envDir, ".cargo", "config.toml")); err != nil || !strings.Contains(string(b), "rustflags") {
		t.Errorf("config.toml が想定外: err=%v content=%q", err, string(b))
	}
}

// --- python_msi install（dark/msiexec/ensurepip と除外リストの検証） ---

type pythonPlat struct{ *platform.Fake }

func (p *pythonPlat) Run(ctx context.Context, name string, args []string, opt types.RunOpt) (types.RunResult, error) {
	_, _ = p.Fake.Run(ctx, name, args, opt)
	switch {
	case strings.HasSuffix(name, "dark.exe"):
		ac := filepath.Join(args[2], "AttachedContainer") // args = [exe, "-x", out]
		_ = os.MkdirAll(ac, 0o755)
		for _, n := range []string{"core.msi", "appendpath.msi", "dev.msi", "pip.msi"} {
			_ = os.WriteFile(filepath.Join(ac, n), []byte("msi"), 0o644)
		}
	case name == "msiexec.exe":
		for _, a := range args {
			if strings.HasPrefix(a, "targetdir=") {
				dir := strings.TrimPrefix(a, "targetdir=")
				_ = os.MkdirAll(dir, 0o755)
				_ = os.WriteFile(filepath.Join(dir, "python.exe"), []byte("py"), 0o755)
			}
		}
	}
	return types.RunResult{}, nil
}

func TestPythonMsiInstall(t *testing.T) {
	root := t.TempDir()
	envDir := filepath.Join(root, "envs", "python")
	env := types.Env{Root: root, Tool: "python", EnvDir: envDir, Cache: filepath.Join(envDir, "install-cache")}
	m := &types.Manifest{
		Name: "python",
		Install: types.InstallSpec{
			Type:         "python_msi",
			WixURL:       "https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip",
			ExcludeMSI:   []string{"appendpath.msi", "launcher.msi", "path.msi", "pip.msi"},
			RunEnsurePip: true,
		},
	}
	plat := &pythonPlat{platform.NewFake()}
	deps := types.Deps{Platform: plat, Download: fakeDownloader{}, Extract: extract.New()}
	v := types.VersionInfo{Version: "3.12.1", URL: "https://www.python.org/ftp/python/3.12.1/python-3.12.1-amd64.exe", File: "python-3.12.1-amd64.exe"}

	if err := (PythonMsi{}).Install(context.Background(), m, v, env, deps); err != nil {
		t.Fatalf("Install: %v", err)
	}
	// dark(1) + msiexec(core, dev) + ensurepip(1) = 4。appendpath/pip は除外。
	var dark, ensurepip int
	var msiArgs []string
	for _, r := range plat.Runs {
		switch {
		case strings.HasSuffix(r.Name, "dark.exe"):
			dark++
		case r.Name == "msiexec.exe":
			msiArgs = append(msiArgs, strings.Join(r.Args, " "))
		case strings.HasSuffix(r.Name, "python.exe"):
			ensurepip++
		}
	}
	if dark != 1 || ensurepip != 1 {
		t.Errorf("dark=%d ensurepip=%d (want 1,1)", dark, ensurepip)
	}
	if len(msiArgs) != 2 {
		t.Fatalf("msiexec 回数=%d, want 2（core/dev のみ）: %v", len(msiArgs), msiArgs)
	}
	joined := strings.Join(msiArgs, " | ")
	if !strings.Contains(joined, "core.msi") || !strings.Contains(joined, "dev.msi") {
		t.Errorf("core/dev が msiexec されていない: %v", msiArgs)
	}
	if strings.Contains(joined, "appendpath.msi") || strings.Contains(joined, "pip.msi") {
		t.Errorf("除外対象が msiexec された: %v", msiArgs)
	}
	for _, a := range msiArgs {
		if !strings.Contains(a, "/quiet") || !strings.Contains(a, "/a") || !strings.Contains(a, "targetdir=") {
			t.Errorf("msiexec 引数が想定外: %q", a)
		}
	}
}

// --- android_sdk install（HTML スクレイプ + cmdline-tools/latest 再配置） ---

func TestAndroidSDKInstall(t *testing.T) {
	zipBytes := makeZip(map[string]string{
		"cmdline-tools/bin/sdkmanager.bat": "x",
		"cmdline-tools/lib/foo.jar":        "y",
	})
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, ".zip") {
			_, _ = w.Write(zipBytes)
			return
		}
		_, _ = w.Write([]byte(`<html><body>
			<a href="/repo/commandlinetools-win-11076708_latest.zip">cmdline-tools</a>
		</body></html>`))
	}))
	defer srv.Close()

	oldStudio, oldRepo := androidStudioURL, androidRepoBase
	androidStudioURL = srv.URL + "/studio"
	androidRepoBase = srv.URL + "/repo/"
	defer func() { androidStudioURL, androidRepoBase = oldStudio, oldRepo }()

	root := t.TempDir()
	envDir := filepath.Join(root, "envs", "androidsdk")
	env := types.Env{Root: root, Tool: "androidsdk", EnvDir: envDir, Cache: filepath.Join(envDir, "install-cache")}
	m := &types.Manifest{Name: "androidsdk", Install: types.InstallSpec{Type: "android_sdk", RelocateTo: "cmdline-tools/latest"}}
	deps := types.Deps{HTTP: http.DefaultClient, Download: download.New(http.DefaultClient), Extract: extract.New()}

	if err := (AndroidSDK{}).Install(context.Background(), m, types.VersionInfo{}, env, deps); err != nil {
		t.Fatalf("Install: %v", err)
	}
	// envs/androidsdk/11076708/cmdline-tools/latest/bin/sdkmanager.bat へ再配置されている。
	got := filepath.Join(envDir, "11076708", "cmdline-tools", "latest", "bin", "sdkmanager.bat")
	if b, err := os.ReadFile(got); err != nil || string(b) != "x" {
		t.Fatalf("cmdline-tools/latest 再配置失敗: err=%v content=%q", err, string(b))
	}
}
