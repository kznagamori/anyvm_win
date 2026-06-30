package anyvm

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"

	"golang.org/x/sync/errgroup"
	"golang.org/x/sync/semaphore"

	"github.com/kznagamori/anyvm_win/internal/download"
	"github.com/kznagamori/anyvm_win/internal/extract"
	"github.com/kznagamori/anyvm_win/internal/platform"
	"github.com/kznagamori/anyvm_win/manifests"
	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// updateConcurrency は UpdateAll の同時実行数（GitHub API レート制限への配慮。.doc/04 §1）。
const updateConcurrency = 4

// Config は Engine の構築設定。Root 以外は省略すると既定値が使われる。
type Config struct {
	// Root は ANYVM_ROOT（必須）。
	Root string
	// ExtraDirs は追加のマニフェスト探索先（既定は <Root>/manifests）。
	ExtraDirs []string
	// HTTP は HTTP クライアント（既定は http.DefaultClient。テスト時に差し替え可能）。
	HTTP types.HTTPDoer
	// Platform は OS 抽象（既定は platform.New()）。
	Platform types.Platform
	// GitHubToken は git_tags の API レート緩和用（空なら環境変数 GITHUB_TOKEN を使用）。
	GitHubToken string
	// Logger は出力先（既定は slog.Default()）。
	Logger *slog.Logger
}

// Engine はすべてのユースケース（update/install/set/...）の入口（.doc/07 §2）。
type Engine struct {
	cfg      Config
	reg      *Registry
	state    *FileStateStore
	cache    *FileCacheStore
	plat     types.Platform
	baseDeps types.Deps
	progress types.ProgressFunc
	logger   *slog.Logger
}

// NewEngine はマニフェストとストラテジを読み込んで Engine を構築する。
func NewEngine(cfg Config) (*Engine, error) {
	if cfg.Root == "" {
		return nil, fmt.Errorf("Config.Root が必要です")
	}
	logger := cfg.Logger
	if logger == nil {
		logger = slog.Default()
	}
	plat := cfg.Platform
	if plat == nil {
		plat = platform.New()
	}

	// ストラテジ登録 → マニフェスト読み込み（検証で type の存在を確認するため順序が重要）。
	reg := NewRegistry()
	registerBuiltins(reg)
	extra := cfg.ExtraDirs
	if extra == nil {
		extra = []string{filepath.Join(cfg.Root, "manifests")}
	}
	if err := LoadManifests(reg, manifests.FS, extra, logger); err != nil {
		return nil, err
	}

	token := cfg.GitHubToken
	if token == "" {
		token = os.Getenv("GITHUB_TOKEN")
	}

	httpClient := cfg.HTTP
	if httpClient == nil {
		httpClient = http.DefaultClient
	}

	e := &Engine{
		cfg:    cfg,
		reg:    reg,
		state:  NewFileStateStore(cfg.Root),
		cache:  NewFileCacheStore(cfg.Root),
		plat:   plat,
		logger: logger,
		baseDeps: types.Deps{
			HTTP:        httpClient,
			Download:    download.New(httpClient),
			Extract:     extract.New(),
			Platform:    plat,
			Logger:      logger,
			GitHubToken: token,
		},
	}
	return e, nil
}

// SetProgress は進捗コールバックを差し替える（CLI=バー, GUI=ウィジェット）。
func (e *Engine) SetProgress(fn types.ProgressFunc) { e.progress = fn }

// Manifests は CLI のサブコマンド生成に使うメタ情報一覧を返す。
func (e *Engine) Manifests() []types.ManifestMeta { return e.reg.Metas() }

// makeDeps は現在の進捗コールバックを反映した Deps を返す。
func (e *Engine) makeDeps() types.Deps {
	d := e.baseDeps
	d.Progress = e.progress
	return d
}

// envFor は tool の実行時ディレクトリ群を組み立てる。
func (e *Engine) envFor(tool string) types.Env {
	envDir := filepath.Join(e.cfg.Root, "envs", tool)
	return types.Env{
		Root:    e.cfg.Root,
		Tool:    tool,
		EnvDir:  envDir,
		Current: filepath.Join(envDir, "current"),
		Cache:   filepath.Join(envDir, "install-cache"),
		Scripts: filepath.Join(e.cfg.Root, "scripts"),
		Tools:   filepath.Join(e.cfg.Root, "tools"),
	}
}

// manifest は tool のマニフェストを取得する（未登録はエラー）。
func (e *Engine) manifest(tool string) (*types.Manifest, error) {
	m, ok := e.reg.Manifest(tool)
	if !ok {
		return nil, fmt.Errorf("%w: %s", ErrToolNotFound, tool)
	}
	return m, nil
}

// Update は 1 ツールの版を再取得して cache に保存する。
func (e *Engine) Update(ctx context.Context, tool string) error {
	m, err := e.manifest(tool)
	if err != nil {
		return err
	}
	if m.Discover.Type == "none" {
		// 列挙不要なツール（Rust 等）は no-op（既存キャッシュを消さない）。
		e.logger.Debug("update をスキップ（discover=none）", "tool", tool)
		return nil
	}
	d, err := e.reg.discoverer(m.Discover.Type)
	if err != nil {
		return err
	}
	vs, err := d.Discover(ctx, m, e.makeDeps())
	if err != nil {
		return fmt.Errorf("%s の update: %w", tool, err)
	}
	if err := e.cache.Save(tool, vs); err != nil {
		return err
	}
	e.logger.Info(fmt.Sprintf("%s: %d 件のバージョンを取得しました", tool, len(vs)))
	return nil
}

// UpdateAll は全ツールの版を並行に再取得する（同時実行数を制限）。
func (e *Engine) UpdateAll(ctx context.Context) error {
	g, gctx := errgroup.WithContext(ctx)
	sem := semaphore.NewWeighted(updateConcurrency)
	for _, name := range e.reg.Names() {
		name := name
		g.Go(func() error {
			if err := sem.Acquire(gctx, 1); err != nil {
				return err
			}
			defer sem.Release(1)
			return e.Update(gctx, name)
		})
	}
	return g.Wait()
}

// ListInstallable は cache に保存済みの導入可能バージョン一覧を返す。
func (e *Engine) ListInstallable(_ context.Context, tool string) ([]types.VersionInfo, error) {
	if _, err := e.manifest(tool); err != nil {
		return nil, err
	}
	return e.cache.Load(tool)
}

// Install は指定バージョンを導入する。
func (e *Engine) Install(ctx context.Context, tool, version string) error {
	m, err := e.manifest(tool)
	if err != nil {
		return err
	}
	env := e.envFor(tool)
	if !m.SingleInstall() && e.plat.Exists(env.VersionDir(version)) {
		return fmt.Errorf("%w: %s %s", ErrAlreadyInstalled, tool, version)
	}
	v, ok := e.cache.Find(tool, version)
	if !ok {
		return fmt.Errorf("%w: %s %s（先に `anyvm %s update` を実行してください）", ErrVersionNotFound, tool, version, tool)
	}
	inst, err := e.reg.installer(m.Install.Type)
	if err != nil {
		return err
	}
	if err := inst.Install(ctx, m, v, env, e.makeDeps()); err != nil {
		return err
	}
	e.logger.Info(fmt.Sprintf("%s %s を導入しました", tool, version))
	return nil
}

// InstallLatest は最新バージョンを導入する。
func (e *Engine) InstallLatest(ctx context.Context, tool string) error {
	if _, err := e.manifest(tool); err != nil {
		return err
	}
	v, ok := e.cache.Latest(tool)
	if !ok {
		return fmt.Errorf("%w: %s（先に `anyvm %s update` を実行してください）", ErrVersionNotFound, tool, tool)
	}
	return e.Install(ctx, tool, v.Version)
}

// Uninstall は指定バージョンを削除する。
func (e *Engine) Uninstall(ctx context.Context, tool, version string) error {
	m, err := e.manifest(tool)
	if err != nil {
		return err
	}
	inst, err := e.reg.installer(m.Install.Type)
	if err != nil {
		return err
	}
	if err := inst.Uninstall(ctx, m, version, e.envFor(tool), e.makeDeps()); err != nil {
		return err
	}
	e.logger.Info(fmt.Sprintf("%s %s を削除しました", tool, version))
	return nil
}

// Set は指定バージョンを有効化する（current 張り替え + スクリプト生成 + 状態保存）。
func (e *Engine) Set(ctx context.Context, tool, version string) error {
	m, err := e.manifest(tool)
	if err != nil {
		return err
	}
	env := e.envFor(tool)
	if !m.SingleInstall() && !e.plat.Exists(env.VersionDir(version)) {
		return fmt.Errorf("%w: %s %s", ErrVersionNotFound, tool, version)
	}
	if err := e.reg.activator.Activate(ctx, m, version, env, e.makeDeps()); err != nil {
		return err
	}
	if err := e.state.SetActive(tool, version); err != nil {
		return err
	}
	e.logger.Info(fmt.Sprintf("%s %s を有効化しました（`anyvm rehash` で現在のシェルに反映）", tool, version))
	return nil
}

// Unset は無効化する（current を外し、スクリプトを空にし、状態を削除）。
func (e *Engine) Unset(ctx context.Context, tool string) error {
	m, err := e.manifest(tool)
	if err != nil {
		return err
	}
	if err := e.reg.activator.Deactivate(ctx, m, e.envFor(tool), e.makeDeps()); err != nil {
		return err
	}
	if err := e.state.ClearActive(tool); err != nil {
		return err
	}
	e.logger.Info(fmt.Sprintf("%s を無効化しました（`anyvm rehash` で反映）", tool))
	return nil
}

// ActiveVersion は tool の現在のアクティブバージョンを返す。
func (e *Engine) ActiveVersion(tool string) (string, bool) {
	return e.state.Active(tool)
}

// AllActiveVersions は全ツールのアクティブバージョン（tool -> version）を返す。
func (e *Engine) AllActiveVersions() map[string]string {
	return e.state.All()
}

// InstalledVersions は tool の導入済みバージョン一覧を返す（昇順、アクティブ印付き）。
func (e *Engine) InstalledVersions(tool string) ([]types.InstalledVersion, error) {
	m, err := e.manifest(tool)
	if err != nil {
		return nil, err
	}
	env := e.envFor(tool)
	active, _ := e.state.Active(tool)

	if m.SingleInstall() {
		// 単一インストール型（Rust 等）: 版ディレクトリでなく導入有無で表す。
		if e.plat.Exists(env.EnvDir) {
			return []types.InstalledVersion{{Version: "installed", Active: active != ""}}, nil
		}
		return nil, nil
	}

	re, err := regexp.Compile(m.Layout.VersionPattern)
	if err != nil {
		return nil, err
	}
	entries, err := os.ReadDir(env.EnvDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var out []types.InstalledVersion
	for _, ent := range entries {
		if !ent.IsDir() {
			continue
		}
		name := ent.Name()
		if name == "current" || name == "install-cache" {
			continue
		}
		if !re.MatchString(name) {
			continue
		}
		out = append(out, types.InstalledVersion{Version: name, Active: name == active})
	}
	sort.Slice(out, func(i, j int) bool {
		return types.CompareVersions(out[i].Version, out[j].Version) < 0
	})
	return out, nil
}

// Init はスクリプトディレクトリと集約スクリプトを生成する（旧 init コマンド相当。.doc/01 §3.2）。
func (e *Engine) Init(ctx context.Context) error {
	if err := e.refreshAllScripts(ctx); err != nil {
		return err
	}
	e.logger.Info("初期化が完了しました")
	return nil
}

// RehashAll は全ツールのスクリプトを最新化する（set/unset 後の整合化。.doc/05 §5）。
func (e *Engine) RehashAll(ctx context.Context) error {
	return e.refreshAllScripts(ctx)
}

// UnsetAll は全ツールを無効化する。
func (e *Engine) UnsetAll(ctx context.Context) error {
	for _, name := range e.reg.Names() {
		if err := e.Unset(ctx, name); err != nil {
			return err
		}
	}
	return nil
}

// refreshAllScripts は各ツールのアクティブ状態に応じてスクリプトを再生成し、
// 集約スクリプト(AnyVm{Activate,Deactivate})を更新する。
func (e *Engine) refreshAllScripts(ctx context.Context) error {
	names := e.reg.Names()
	for _, name := range names {
		m, _ := e.reg.Manifest(name)
		env := e.envFor(name)
		if v, ok := e.state.Active(name); ok {
			// アクティブなツールはスクリプトを再生成する。
			if err := e.reg.activator.Activate(ctx, m, v, env, e.makeDeps()); err != nil {
				return err
			}
		} else {
			// 非アクティブなツールは空スクリプトにしておく（集約 CALL 先を用意するため）。
			if err := e.plat.ClearActivationScripts(env, name); err != nil {
				return err
			}
		}
	}
	// 集約スクリプトを全ツール名で生成する（Scripts ディレクトリは共通）。
	return e.plat.WriteAggregateScripts(e.envFor(""), names)
}
