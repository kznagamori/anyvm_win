# 07. ライブラリ API 設計（pkg/anyvm）

CLI も将来の GUI も利用する公開ライブラリの API です。**副作用は注入**し、**ctx 透過**、**構造化された戻り値**を原則とします。

## 1. 公開型

```go
// pkg/anyvm/types.go
package anyvm

// VersionInfo は導入可能な 1 バージョン。
type VersionInfo struct {
	Version string `toml:"version"`
	URL     string `toml:"url"`
	File    string `toml:"file"`
}

// InstalledVersion はインストール済みの 1 バージョン。
type InstalledVersion struct {
	Version string
	Active  bool // 現在有効か
}

// ManifestMeta は CLI のサブコマンド生成に使う軽量メタ情報。
type ManifestMeta struct {
	Name        string
	Aliases     []string
	Description string
	SingleInstall bool // discover=none かつ link=none（Rust 型）
}

// Env は 1 ツールの実行時ディレクトリ群（テンプレート変数の実体）。
type Env struct {
	Root       string // ANYVM_ROOT
	Tool       string
	EnvDir     string // <Root>/envs/<tool>
	Current    string // <EnvDir>/current
	Cache      string // <EnvDir>/install-cache
	Scripts    string // <Root>/scripts
	Tools      string // <Root>/tools
}

// ProgressFunc はダウンロード・展開の進捗（done/total バイト or 件数）。
type ProgressFunc func(done, total int64)
```

## 2. Engine

```go
// pkg/anyvm/engine.go
type Config struct {
	Root         string         // 必須。ANYVM_ROOT
	ExtraDirs    []string       // 追加のマニフェスト探索先（既定は <Root>/manifests）
	HTTP         HTTPClient     // 注入可（既定 net/http）
	Platform     platform.Platform // 注入可（既定 windows 実装）
	GitHubToken  string         // 任意。API レート緩和
}

type Engine struct {
	cfg      Config
	reg      *Registry      // マニフェスト + ストラテジ
	state    StateStore     // active.toml
	cache    CacheStore     // cache/<tool>.toml
	plat     platform.Platform
	progress ProgressFunc
}

func NewEngine(cfg Config) (*Engine, error) // マニフェストをロード・検証して構築

// 進捗コールバックの差し替え（CLI=バー, GUI=ウィジェット）。
func (e *Engine) SetProgress(fn ProgressFunc)

// CLI のサブコマンド生成用。
func (e *Engine) Manifests() []ManifestMeta
```

## 3. ユースケース API（Engine メソッド）

```go
// バージョン検出
func (e *Engine) Update(ctx context.Context, tool string) error       // 1 ツールの版を再取得し cache 保存
func (e *Engine) UpdateAll(ctx context.Context) error                 // 全ツール（errgroup + semaphore）

// 導入可能一覧
func (e *Engine) ListInstallable(ctx context.Context, tool string) ([]VersionInfo, error)

// インストール
func (e *Engine) Install(ctx context.Context, tool, version string) error
func (e *Engine) InstallLatest(ctx context.Context, tool string) error
func (e *Engine) Uninstall(ctx context.Context, tool, version string) error

// 有効化
func (e *Engine) Set(ctx context.Context, tool, version string) error
func (e *Engine) Unset(ctx context.Context, tool string) error

// 参照
func (e *Engine) ActiveVersion(tool string) (string, bool)
func (e *Engine) InstalledVersions(tool string) ([]InstalledVersion, error)

// 全体
func (e *Engine) RehashAll(ctx context.Context) error  // 集約スクリプト再生成
func (e *Engine) UnsetAll(ctx context.Context) error
func (e *Engine) AllActiveVersions() map[string]string
func (e *Engine) Init(ctx context.Context) error       // scripts/ と集約スクリプト生成
```

> **設計判断**: 戻り値は構造化データ（`[]VersionInfo` 等）。表示は呼び出し側（CLI/GUI）が担う。ただし「slog 集約」方針に従い、Engine 内の節目メッセージは `slog.Info/Debug` で流す（[06](06-logging.md)）。CLI はそれをそのまま画面表示に使い、GUI はハンドラ差し替えで取得する。両立のため、**一覧系 API は戻り値も返しつつ Info ログにも出す**二重提供とする（CLI は戻り値を整形 or ログ任せのどちらでも可）。

## 4. ストラテジ・インターフェースとレジストリ

```go
// pkg/anyvm/strategy.go

// Discoverer: 版の列挙。
type Discoverer interface {
	Discover(ctx context.Context, m *Manifest, deps Deps) ([]VersionInfo, error)
}

// Installer: 版の導入と削除。
type Installer interface {
	Install(ctx context.Context, m *Manifest, v VersionInfo, env Env, deps Deps) error
	Uninstall(ctx context.Context, m *Manifest, version string, env Env, deps Deps) error
}

// Activator: 有効化スクリプト生成（標準実装は 1 つで全ツールを賄う）。
type Activator interface {
	Activate(ctx context.Context, m *Manifest, version string, env Env, deps Deps) error
	Deactivate(ctx context.Context, m *Manifest, env Env, deps Deps) error
}

// Deps: ストラテジが使う注入済み副作用一式。
type Deps struct {
	HTTP     HTTPClient
	Download Downloader   // 進捗付き DL（internal/download）
	Extract  Extractor    // zip/7z（internal/extract）
	Platform platform.Platform
	Progress ProgressFunc
	Logger   *slog.Logger
}

// レジストリ（type 文字列 → 実装）。
type Registry struct {
	manifests  map[string]*Manifest
	discoverers map[string]Discoverer
	installers  map[string]Installer
	activator   Activator // 標準 1 実装
}

func (r *Registry) RegisterDiscoverer(typ string, d Discoverer)
func (r *Registry) RegisterInstaller(typ string, i Installer)
```

ビルトイン登録（`NewEngine` 内）:

```go
reg.RegisterDiscoverer("git_tags", strategies.GitTags{})
reg.RegisterDiscoverer("github_releases", strategies.GitHubReleases{})
reg.RegisterDiscoverer("html_scrape", strategies.HTMLScrape{})
reg.RegisterDiscoverer("static", strategies.Static{})
reg.RegisterDiscoverer("none", strategies.NoDiscover{})

reg.RegisterInstaller("archive_extract", strategies.ArchiveExtract{})
reg.RegisterInstaller("single_binary", strategies.SingleBinary{})
reg.RegisterInstaller("python_msi", strategies.PythonMSI{})
reg.RegisterInstaller("rustup", strategies.Rustup{})
reg.RegisterInstaller("android_sdk", strategies.AndroidSDK{})
```

## 5. Set（有効化）の実装スケッチ

標準 Activator が全ツール共通で動きます。

```go
// pkg/anyvm/strategies/activate.go
func (StdActivator) Activate(ctx context.Context, m *anyvm.Manifest, version string, env anyvm.Env, d anyvm.Deps) error {
	// 1) 既存 current を後始末
	if err := unlinkCurrent(env, d.Platform); err != nil { return err }
	// 2) link=junction の場合のみ current → version リンク
	if m.Layout.Link == "junction" {
		target := filepath.Join(env.EnvDir, version)
		if err := d.Platform.CreateLink(env.Current, target); err != nil {
			return fmt.Errorf("link 作成失敗: %w", err)
		}
	}
	// 3) PATH と env を計算（テンプレート展開 + env_if 条件）
	act := buildActivation(m, version, env) // {Path []string, Env map[string]string}
	// 4) <tool>Activate/Deactivate .bat/.ps1 を生成（[08]）
	if err := d.Platform.WriteActivationScripts(env, m.Name, act); err != nil { return err }
	return nil
}
```

`buildActivation` はテンプレート変数（[03 §2](03-plugin-manifest-spec.md)）を解決し、`[[activate.env_if]]` の `exists` を `os.Stat` で判定して条件付き環境変数を合成します。

## 6. 単一インストール型（Rust）の分岐

`SingleInstall == (discover=none && link=none)` のツールは「版ディレクトリを持たない」ため、`InstalledVersions`/`ActiveVersion` の意味が異なります。

```go
func (e *Engine) InstalledVersions(tool string) ([]InstalledVersion, error) {
	m := e.reg.manifests[tool]
	if m.SingleInstall() {
		// 例: Rust。cargo/rustc の存在で「導入済み」を判定
		if installed := e.plat.Exists(filepath.Join(env.EnvDir, ".cargo", "bin", "cargo.exe")); installed {
			return []InstalledVersion{{Version: "installed", Active: true}}, nil
		}
		return nil, nil
	}
	// 通常: envs/<tool>/ を走査し version_pattern にマッチするものを列挙
	return scanVersionDirs(env.EnvDir, m.Layout.VersionPattern, e.state.Active(tool)), nil
}
```

## 7. StateStore / CacheStore

```go
// pkg/anyvm/state.go — active.toml（旧 anyvm_win.json）
type StateStore interface {
	Active(tool string) (string, bool)
	SetActive(tool, version string) error
	ClearActive(tool string) error
	All() map[string]string
}

// pkg/anyvm/cache.go — cache/<tool>.toml（旧 *_vm_version_cache.json）
type CacheStore interface {
	Load(tool string) ([]VersionInfo, error)
	Save(tool string, vs []VersionInfo) error
	Find(tool, version string) (VersionInfo, bool)
	Latest(tool string) (VersionInfo, bool)
}
```

ファイル形式（TOML）:

```toml
# state/active.toml
go = "1.22.0"
python = "3.11.8"
```
```toml
# state/cache/go.toml
[[version]]
version = "1.22.0"
url = "https://go.dev/dl/go1.22.0.windows-amd64.zip"
file = "go1.22.0.windows-amd64.zip"
```

## 8. バージョン比較（version.go）

```go
// pkg/anyvm/version.go
// Compare は "1.22.0"・"11.0.2_7"・"19" 等を数値比較。
// サフィックス（-rc1 等）は基底のみ比較（旧 RustVm.compareVersion 踏襲）。
func Compare(a, b string) int

// ParseFlexible は区切り [._] と先頭の非数値接頭辞を許容してパース（JDK/MinGW 対応）。
func ParseFlexible(s string) (Version, error)
```

## 9. 番兵エラー

```go
// pkg/anyvm/errors.go
var (
	ErrToolNotFound     = errors.New("tool not found")
	ErrVersionNotFound  = errors.New("version not found")
	ErrAlreadyInstalled = errors.New("already installed")
	ErrNotInstalled     = errors.New("not installed")
	ErrManifestInvalid  = errors.New("manifest invalid")
)
```

CLI はこれらを終了コードへ写像（[05 §6](05-cli-design.md)）。

## 10. GUI からの利用例（API 境界の確認）

```go
eng, _ := anyvm.NewEngine(anyvm.Config{Root: root, GitHubToken: tok})
eng.SetProgress(func(done, total int64) { widget.SetProgress(done, total) })
slog.SetDefault(slog.New(myUIHandler))           // メッセージを UI へ

versions, _ := eng.ListInstallable(ctx, "go")    // 構造化データを直接取得
_ = eng.Install(ctx, "go", versions[len(versions)-1].Version)
_ = eng.Set(ctx, "go", "1.22.0")
active := eng.AllActiveVersions()                // map[tool]version
```

CLI と GUI が**同一の Engine API**を共有することを保証します。
