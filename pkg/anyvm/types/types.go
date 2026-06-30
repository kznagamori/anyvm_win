// Package types は anyvm ライブラリ全体で共有する値型とサービスインターフェースを
// 定義する「リーフパッケージ」である。
//
// このパッケージは他の anyvm パッケージへ依存しない（標準ライブラリのみを import する）。
// これにより pkg/anyvm（高レベル API）・internal/platform（OS 実装）・
// pkg/anyvm/strategies（ストラテジ実装）が、互いに import 循環を起こさずに
// 同じ型・インターフェースを共有できる（.doc/07-library-api.md, .doc/08-os-abstraction.md 参照）。
//
// pkg/anyvm はここで定義した主要な型を型エイリアスで再公開するため、
// 公開 API の利用者は anyvm.Env / anyvm.VersionInfo などとして参照できる。
package types

import "path/filepath"

// VersionInfo は、あるツールの「導入可能な 1 バージョン」を表す。
// update（バージョン検出）の結果としてキャッシュ（state/cache/<tool>.toml）に保存される。
type VersionInfo struct {
	// Version は正規化済みのバージョン文字列（例: "1.22.0"）。
	Version string `toml:"version"`
	// URL はダウンロード元の完全な URL。
	URL string `toml:"url"`
	// File はダウンロード先のファイル名。
	File string `toml:"file"`
}

// InstalledVersion は、ローカルに導入済みの 1 バージョンを表す。
type InstalledVersion struct {
	// Version は導入済みバージョン（envs/<tool>/<version> のディレクトリ名）。
	Version string
	// Active は、そのバージョンが現在 set されている（current が指している）かどうか。
	Active bool
}

// ManifestMeta は CLI のサブコマンド動的生成に使う軽量メタ情報。
// 完全な Manifest を渡さずに、名前・別名・説明だけを取り回すために用いる。
type ManifestMeta struct {
	Name        string
	Aliases     []string
	Description string
	// SingleInstall は discover=none かつ link=none のツール（Rust 型）を示す。
	SingleInstall bool
	// NoDiscover は discover=none のツール（Rust/AndroidSDK 型）を示す。
	// version 指定なしの `install` で導入する（版リストを持たない）。
	NoDiscover bool
}

// ProgressFunc はダウンロード・展開などの進捗を受け取るコールバック。
// done は処理済み量、total は総量（不明な場合は負値）を表す。
// CLI はプログレスバー描画に、GUI は進捗ウィジェット更新に用いる。
type ProgressFunc func(done, total int64)

// EnvVar は有効化時に設定する 1 つの環境変数。
// マップではなくスライス要素にすることで、生成スクリプトの出力順を決定的にする
// （ゴールデンテストの安定化。.doc/12-testing.md 参照）。
type EnvVar struct {
	Key   string
	Value string
}

// Activation は、あるバージョンを有効化するために必要な PATH と環境変数を、
// テンプレート展開済みの最終値として保持する。
type Activation struct {
	// Path は PATH の先頭に前置するディレクトリ（順序保持）。
	Path []string
	// Env は設定する環境変数（キー名でソートした決定的順序）。
	Env []EnvVar
}

// Env は 1 ツール分の実行時ディレクトリ群（テンプレート変数の実体）。
type Env struct {
	Root    string // ANYVM_ROOT
	Tool    string // ツール名（例: "go"）
	EnvDir  string // <Root>/envs/<tool>
	Current string // <EnvDir>/current（ジャンクション）
	Cache   string // <EnvDir>/install-cache
	Scripts string // <Root>/scripts
	Tools   string // <Root>/tools
}

// VersionDir は、指定バージョンの導入先ディレクトリ <EnvDir>/<version> を返す。
func (e Env) VersionDir(version string) string {
	return filepath.Join(e.EnvDir, version)
}

// TemplateData は、マニフェストのテンプレート（url/file/path/env）展開に渡す
// 変数集合を生成する（.doc/03-plugin-manifest-spec.md §2）。
func (e Env) TemplateData(version string) TemplateData {
	return TemplateData{
		Version:    version,
		Tool:       e.Tool,
		Root:       e.Root,
		Env:        e.EnvDir,
		VersionDir: e.VersionDir(version),
		Current:    e.Current,
		Cache:      e.Cache,
		Scripts:    e.Scripts,
		Tools:      e.Tools,
	}
}

// TemplateData は text/template に渡すテンプレート変数（.doc/03 §2）。
// フィールド名がそのままテンプレート内の {{.Xxx}} に対応する。
type TemplateData struct {
	Version    string
	Tool       string
	Root       string
	Env        string // = envs/<tool>
	VersionDir string // = envs/<tool>/<version>
	Current    string // = envs/<tool>/current
	Cache      string
	Scripts    string
	Tools      string
}
