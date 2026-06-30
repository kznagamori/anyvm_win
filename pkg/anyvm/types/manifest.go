package types

// Manifest は 1 ツールの宣言的定義（TOML マニフェスト）を表す（.doc/03-plugin-manifest-spec.md）。
// データ（URL・正規表現・環境変数 等）と「どのストラテジを使うか」(各 Spec の Type) を保持し、
// 手続きそのものは pkg/anyvm/strategies の実装側が担う（ハイブリッド方式）。
type Manifest struct {
	Name        string   `toml:"name"`
	DisplayName string   `toml:"display_name"`
	Description string   `toml:"description"`
	Homepage    string   `toml:"homepage"`
	Aliases     []string `toml:"aliases"`

	Discover DiscoverSpec `toml:"discover"`
	Artifact ArtifactSpec `toml:"artifact"`
	Install  InstallSpec  `toml:"install"`
	Layout   LayoutSpec   `toml:"layout"`
	Activate ActivateSpec `toml:"activate"`
}

// DiscoverSpec は update（バージョン列挙）の方式とパラメータ（.doc/03 §3）。
type DiscoverSpec struct {
	Type         string            `toml:"type"`          // git_tags | github_releases | html_scrape | static | none
	Source       string            `toml:"source"`        // 単一ソース（git_tags のリポジトリ URL, html_scrape のページ URL）
	Sources      []string          `toml:"sources"`       // 複数ソース（github_releases。例: adoptium/temurin11/17/21）
	StripPrefix  string            `toml:"strip_prefix"`  // タグ先頭から除去する接頭辞（例: "go", "v"）
	Include      string            `toml:"include"`       // 採用する版の正規表現
	Exclude      string            `toml:"exclude"`       // 除外する版の正規表現
	MinVersion   string            `toml:"min_version"`   // これ未満を除外
	URL          string            `toml:"url"`           // html_scrape 用の対象ページ URL
	AnchorText   string            `toml:"anchor_text"`   // html_scrape 用の対象アンカー文言
	HrefRegex    string            `toml:"href_regex"`    // html_scrape 用の href 抽出正規表現
	AssetPattern string            `toml:"asset_pattern"` // github_releases 用のアセット名正規表現
	VersionSubst map[string]string `toml:"version_subst"` // 版文字列の置換（例: "_" -> "+"）
	Versions     []VersionInfo     `toml:"versions"`      // static 用の版直書きリスト
}

// ArtifactSpec は版からダウンロード URL/ファイル名を生成するテンプレート（.doc/03 §4）。
type ArtifactSpec struct {
	URL  string `toml:"url"`
	File string `toml:"file"`
}

// InstallSpec はインストール手続きの方式とパラメータ（.doc/03 §5）。
type InstallSpec struct {
	Type           string         `toml:"type"`            // archive_extract | single_binary | python_msi | rustup | android_sdk
	Archive        string         `toml:"archive"`         // zip | 7z | none
	StripComponent string         `toml:"strip_component"` // 展開後の最上位ディレクトリ名（テンプレート可）
	Binary         string         `toml:"binary"`          // single_binary 用に取り出す実行ファイル名
	Wrapper        string         `toml:"wrapper"`         // none | symexe
	PostDownload   []PostDownload `toml:"post_download"`   // install 後の追加ダウンロード（dotnet の nuget 等）

	// 以下は専用ストラテジ用パラメータ（python_msi / rustup / android_sdk）。
	// 標準ツールでは未使用。
	WixURL       string   `toml:"wix_url"`
	ExcludeMSI   []string `toml:"exclude_msi"`
	RunEnsurePip bool     `toml:"run_ensurepip"`
	InstallerURL string   `toml:"installer_url"`
	DefaultHost  string   `toml:"default_host"`
	Toolchain    string   `toml:"toolchain"`
	CargoConfig  string   `toml:"cargo_config"`
	RelocateTo   string   `toml:"relocate_to"`
}

// PostDownload は install 後に追加で取得するファイル（.doc/04 dotnet 等）。
type PostDownload struct {
	URL  string `toml:"url"`
	Dest string `toml:"dest"`
}

// LayoutSpec はディレクトリ判定とリンク方式（.doc/03 §6）。
type LayoutSpec struct {
	// VersionPattern は versions コマンドで版ディレクトリと判定する正規表現。
	// 先頭 ^ で固定し、末尾 $ の有無で末尾サフィックスの許容を制御する（.doc/03 §6 のアンカー規約）。
	VersionPattern string `toml:"version_pattern"`
	// Link は current の実体リンク方式（junction | none）。
	Link string `toml:"link"`
}

// ActivateSpec は有効化時の PATH と環境変数（.doc/03 §7）。
type ActivateSpec struct {
	Path  []string          `toml:"path"`   // PATH へ前置するディレクトリ（順序保持）
	Env   map[string]string `toml:"env"`    // 設定する環境変数（キー名でソートして適用）
	EnvIf []EnvIf           `toml:"env_if"` // 条件付き環境変数
}

// EnvIf は、指定パスが存在する時のみ適用する条件付き環境変数（Rust の sccache 等）。
type EnvIf struct {
	Exists string            `toml:"exists"`
	Env    map[string]string `toml:"env"`
}

// SingleInstall は「単一インストール型」(discover=none かつ link=none, 例: Rust) を判定する。
// このようなツールは版ディレクトリを持たず、versions/version の意味が異なる（.doc/07 §6）。
func (m *Manifest) SingleInstall() bool {
	return m.Discover.Type == "none" && m.Layout.Link == "none"
}

// Meta は CLI 用の軽量メタ情報を返す。
func (m *Manifest) Meta() ManifestMeta {
	return ManifestMeta{
		Name:          m.Name,
		Aliases:       m.Aliases,
		Description:   m.Description,
		SingleInstall: m.SingleInstall(),
		NoDiscover:    m.Discover.Type == "none",
	}
}
