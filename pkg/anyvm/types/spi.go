package types

import (
	"context"
	"io"
	"log/slog"
	"net/http"
)

// Platform は OS 依存処理を抽象化するインターフェース（.doc/08-os-abstraction.md）。
// 実装は internal/platform（Windows 実装・POSIX スタブ・テスト用 Fake）が提供する。
// このインターフェースをリーフパッケージ types に置くことで、
// pkg/anyvm ⇄ internal/platform の import 循環を避ける。
type Platform interface {
	// CreateLink は current → target の実体リンク（Windows: ジャンクション）を作る。
	CreateLink(linkPath, targetPath string) error
	// RemoveLink はリンクを外す（リンク先の実体は削除しない）。
	RemoveLink(linkPath string) error
	// IsLink は path がリンクかどうかを返す。
	IsLink(path string) (bool, error)

	// WriteActivationScripts は <tool>Activate/Deactivate の .bat/.ps1 を生成する。
	WriteActivationScripts(env Env, tool string, act Activation) error
	// ClearActivationScripts は無効化時にスクリプトを空（実質 no-op）に上書きする。
	ClearActivationScripts(env Env, tool string) error
	// WriteAggregateScripts は全ツールを束ねる AnyVm{Activate,Deactivate} を生成する。
	WriteAggregateScripts(env Env, tools []string) error

	// Run は外部プロセスを実行する（rustup/msiexec 等の残置依存用）。
	Run(ctx context.Context, name string, args []string, opt RunOpt) (RunResult, error)

	// Exists は path の存在を返す。
	Exists(path string) bool
}

// RunOpt は Run の実行オプション。
type RunOpt struct {
	Env    map[string]string // 追加で設定する環境変数
	Dir    string            // 作業ディレクトリ（空ならカレント）
	Stdout io.Writer         // 標準出力の転送先（nil なら捕捉のみ）
}

// RunResult は Run の実行結果。
type RunResult struct {
	ExitCode int
	Stdout   string
	Stderr   string
}

// HTTPDoer は HTTP クライアントの最小インターフェース（テスト時に差し替え可能）。
type HTTPDoer interface {
	Do(req *http.Request) (*http.Response, error)
}

// Downloader は進捗付きダウンロードの抽象。
type Downloader interface {
	Download(ctx context.Context, url, dest string, progress ProgressFunc) error
}

// Extractor はアーカイブ展開の抽象（format: "zip" | "7z"）。
type Extractor interface {
	Extract(ctx context.Context, archivePath, destDir, format string, progress ProgressFunc) error
}

// Deps はストラテジ実装に注入する副作用一式（.doc/07-library-api.md §4）。
// テスト時はそれぞれをフェイクに差し替えることで、実ネットワーク・実 OS なしに検証できる。
type Deps struct {
	HTTP        HTTPDoer
	Download    Downloader
	Extract     Extractor
	Platform    Platform
	Progress    ProgressFunc
	Logger      *slog.Logger
	GitHubToken string // GitHub API のレート制限緩和用トークン（任意）
}

// Discoverer は版の列挙（update）を行うストラテジ（.doc/07）。
type Discoverer interface {
	Discover(ctx context.Context, m *Manifest, deps Deps) ([]VersionInfo, error)
}

// Installer は版の導入と削除を行うストラテジ。
type Installer interface {
	Install(ctx context.Context, m *Manifest, v VersionInfo, env Env, deps Deps) error
	Uninstall(ctx context.Context, m *Manifest, version string, env Env, deps Deps) error
}

// Activator は有効化/無効化（PATH・環境変数スクリプト生成）を行うストラテジ。
// 標準実装 1 つで全ツールを賄う。
type Activator interface {
	Activate(ctx context.Context, m *Manifest, version string, env Env, deps Deps) error
	Deactivate(ctx context.Context, m *Manifest, env Env, deps Deps) error
}
