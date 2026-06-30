# 03. プラグイン／マニフェスト仕様（TOML）

各開発ツールの「組み込みコード」を外部化する中核仕様です。1 ツール = 1 TOML マニフェストで宣言し、`type` フィールドで Go ストラテジ実装を選択します（ハイブリッド方式）。

## 1. 全体構造

```toml
# manifests/<name>.toml
name         = "go"             # 必須。CLI のサブコマンド名（小文字・ハイフン可）
display_name = "Go"             # 任意。表示名
description  = "Go programming language"   # 任意
homepage     = "https://go.dev/"           # 任意
aliases      = ["golang"]       # 任意。別名サブコマンド

[discover]   # バージョン列挙の方法
[artifact]   # バージョン → ダウンロード URL/ファイル名 の生成（discover が直接 URL を返す場合は省略可）
[install]    # インストール手続き
[layout]     # インストール後のディレクトリ判定とリンク方式
[activate]   # 有効化時の PATH と環境変数
```

## 2. テンプレート変数

`url` / `file` / `path` / `env` の各値では Go の `text/template` 構文が使えます。利用可能な変数:

| 変数 | 意味 | 例（tool=go, version=1.22.0, ANYVM_ROOT=D:\anyvm） |
|------|------|---------------------------------------------------|
| `{{.Version}}` | 対象バージョン | `1.22.0` |
| `{{.Tool}}` | ツール名 | `go` |
| `{{.Root}}` | ルートディレクトリ | `D:\anyvm` |
| `{{.Env}}` | `envs/<tool>` | `D:\anyvm\envs\go` |
| `{{.VersionDir}}` | `envs/<tool>/<version>` | `D:\anyvm\envs\go\1.22.0` |
| `{{.Current}}` | `envs/<tool>/current`（ジャンクション） | `D:\anyvm\envs\go\current` |
| `{{.Cache}}` | `envs/<tool>/install-cache` | `D:\anyvm\envs\go\install-cache` |
| `{{.Scripts}}` | `scripts/` | `D:\anyvm\scripts` |
| `{{.Tools}}` | `tools/`（symexe 等） | `D:\anyvm\tools` |

補助関数（テンプレート FuncMap）: `{{.Version | major}}`（メジャー番号）、`{{.Version | replace "." "_"}}` 等を提供（詳細は実装時に拡張）。

## 3. `[discover]` — バージョン列挙

```toml
[discover]
type = "git_tags"   # git_tags | github_releases | html_scrape | static | none
```

### type 別パラメータ

#### `git_tags`
Git タグからバージョンを列挙。**外部 `git` には依存せず、GitHub の REST/HTTP API（`/repos/{owner}/{repo}/tags` ページング、または `info/refs?service=git-upload-pack` のスマート HTTP）で取得**します（[04 §外部依存削減](04-tool-migration-catalog.md)）。

```toml
[discover]
type         = "git_tags"
source       = "https://github.com/golang/go"
strip_prefix = "go"                 # タグ先頭から除去（例 go1.22.0 → 1.22.0）
include      = '^\d+\.\d+\.\d+$'     # 採用する版の正規表現
exclude      = ''                   # 任意。除外正規表現
min_version  = "1.13.0"             # 任意。これ未満を除外
```
この type は `[artifact]` の `url`/`file` テンプレートで各版のダウンロード URL を生成します。

#### `github_releases`
GitHub Releases のアセットから列挙。

```toml
[discover]
type          = "github_releases"
sources       = ["adoptium/temurin11-binaries", "adoptium/temurin17-binaries", "adoptium/temurin21-binaries"]
asset_pattern = 'jdk_x64_windows_hotspot_(\d+\.\d+\.\d+(_\d+)?)\.zip$'  # group(1)=version
version_subst = { "_" = "+" }       # 任意。version 文字列の置換（JDK: 11.0.2_7 → 11.0.2+7）
min_version   = ""
```
`url`/`file` はマッチしたアセットから直接取得（`[artifact]` 省略可）。

> **応答サイズへの配慮**: Temurin のように 1 リリースあたりのアセット数が多いリポジトリでは
> `releases` API の応答が 1 ページ数十 MB に達する。実装は応答を小さく保つため per_page を
> 小さく（10）し、**直近数ページに限定**して取得する（最新の patch 版が実用上重要）。
> 大容量応答の途中切断(unexpected EOF)には再試行で対処する。
> なお Adoptium 専用 API(api.adoptium.net) はより軽量だが、ネットワークポリシーで到達不可の
> 環境があるため、到達可能な GitHub API を一次手段とする。

#### `html_scrape`
HTML ページを解析して列挙。

```toml
[discover]
type          = "html_scrape"
url           = "https://www.python.org/downloads/windows/"
anchor_text   = "Windows installer (64-bit)"   # この文言の <a> を対象
href_regex    = 'python/(\d+\.\d+\.\d+)/python-\1-amd64\.exe$'  # group(1)=version
min_version   = ""
```
`url`/`file` は `[artifact]` テンプレート、または `href` から直接。

#### `static`
マニフェストに版を直書き（更新が稀／API の無いツール向け）。

```toml
[discover]
type = "static"
[[discover.versions]]
version = "1.0.0"
url     = "https://example.com/tool-1.0.0-win64.zip"
file    = "tool-1.0.0-win64.zip"
```

#### `none`
列挙しない（Rust など、外部インストーラが版を管理）。`update` は no-op。

```toml
[discover]
type = "none"
```

## 4. `[artifact]` — URL/ファイル名生成

`git_tags` / `html_scrape`（href 非使用時）で、版からダウンロード対象を作ります。

```toml
[artifact]
url  = "https://go.dev/dl/go{{.Version}}.windows-amd64.zip"
file = "go{{.Version}}.windows-amd64.zip"
```

## 5. `[install]` — インストール手続き

```toml
[install]
type = "archive_extract"   # archive_extract | single_binary | python_msi | rustup | android_sdk
```

### type 別パラメータ

#### `archive_extract`（標準）
アーカイブを展開し、内部の特定ディレクトリを `<version>` にリネーム。

```toml
[install]
type            = "archive_extract"
archive         = "zip"        # zip | 7z
strip_component = "go"         # 展開後の最上位ディレクトリ名（テンプレート可）
# 例: node-v{{.Version}}-win-x64 / cmake-{{.Version}}-windows-x86_64 / jdk-{{.Version}}
post_download   = []           # 任意。追加 DL（dotnet の nuget.exe 同梱など）
```
`post_download` の例（dotnet）:
```toml
post_download = [
  { url = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe", dest = "{{.VersionDir}}/nuget.exe" },
]
```

#### `single_binary`
アーカイブから単一実行ファイルを取り出して `<version>/` に配置。`wrapper` でランチャを併設。

```toml
[install]
type    = "single_binary"
archive = "zip"
binary  = "bazel.exe"         # 取り出す実行ファイル
wrapper = "none"              # none | symexe（Ninja は symexe ラッパー + .ini）
```

#### `python_msi`（Python 専用ストラテジ）
WiX `dark.exe` で展開 → `msiexec /a` で抽出 → `ensurepip`。WiX/msiexec は本質的に必要なため外部実行として残します。

```toml
[install]
type          = "python_msi"
wix_url       = "https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip"
exclude_msi   = ["appendpath.msi", "launcher.msi", "path.msi", "pip.msi"]
run_ensurepip = true
```

#### `rustup`（Rust 専用ストラテジ）
`rustup-init.exe` を実行し、`config.toml` を生成。

```toml
[install]
type          = "rustup"
installer_url = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
default_host  = "x86_64-pc-windows-gnu"
toolchain     = "stable"
cargo_config  = """
[target.x86_64-pc-windows-gnu]
rustflags = [
  "-C", "link-arg=-Wl,--exclude-libs=ALL",
  "-C", "link-arg=-Wl,--exclude-all-symbols",
  "-C", "link-arg=-Wl,--allow-multiple-definition",
]
"""
```

#### `android_sdk`（AndroidSDK 専用ストラテジ）
HTML から commandline-tools を取得し、`<version>/cmdline-tools/latest` へ再配置。

```toml
[install]
type        = "android_sdk"
relocate_to = "cmdline-tools/latest"   # 展開した cmdline-tools の移設先
```

## 6. `[layout]` — ディレクトリ判定とリンク

```toml
[layout]
version_pattern = '^\d+\.\d+\.\d+$'   # versions コマンドで版ディレクトリと判定する正規表現
link            = "junction"          # junction | none（Ninja は none＝実体配置）
```

| ツール例 | version_pattern | link |
|----------|-----------------|------|
| 標準 | `^\d+\.\d+\.\d+$` | junction |
| MinGW/LLVM/WinLibs | `^\d+\.\d+\.\d+.*$` | junction |
| JDK | `^\d+\.\d+\.\d+(_\d+)?` | junction |
| AndroidSDK | `^\d+$` | junction |

> **アンカーの規約**: `version_pattern` は先頭 `^` で固定し、Go の `regexp` で評価する。末尾 `$` の有無は Dart 実装を忠実に再現する — `^\d+\.\d+\.\d+$`（標準）と `^\d+$`（AndroidSDK）は前後を固定し、`^\d+\.\d+\.\d+.*$`（MinGW/LLVM/WinLibs）と `^\d+\.\d+\.\d+(_\d+)?`（JDK・末尾 `$` 無し）は**末尾サフィックスを許容**する意図。新規マニフェストで完全一致させたい場合は必ず `$` を付けること。

## 7. `[activate]` — PATH と環境変数

```toml
[activate]
path = ["{{.Current}}/bin", "{{.Env}}/go/bin"]   # 先頭から順に PATH へ前置

[activate.env]
GOROOT      = "{{.Current}}"
GOPATH      = "{{.Env}}/go"
GOBIN       = "{{.Env}}/go/bin"
GOCACHE     = "{{.Current}}/go-build"
GOENV       = "{{.Current}}/env"
GO111MODULE = "on"
GOMODCACHE  = "{{.Current}}/pkg/mod"
```

有効化スクリプト生成時、各環境変数は `_OLD_<NAME>` に旧値を退避してから設定し、無効化時に復元します（[08](08-os-abstraction.md) でスクリプトテンプレートを定義）。

### 条件付き環境変数（Rust の sccache 等）

```toml
[[activate.env_if]]
exists = "{{.Env}}/.cargo/bin/sccache.exe"   # このパスが存在する時のみ適用
[activate.env_if.env]
RUSTC_WRAPPER     = "sccache"
SCCACHE_CACHE_SIZE = "1G"
SCCACHE_DIR        = "{{.Env}}/.sccache"
```

## 8. 同梱と上書き（プラグインのロード）

```text
1. go:embed された manifests/*.toml（ビルトイン）をロード
2. <ANYVM_ROOT>/manifests/*.toml（ユーザー定義）をロード
3. name が重複した場合はユーザー定義で上書き（後勝ち）
4. 検証 → Registry 登録
```

- **新ツール追加（プラグイン）**: 既存の `type` で表現できるなら、`<ANYVM_ROOT>/manifests/mytool.toml` を置くだけ。再ビルド不要。
- **既存ツールの微修正**: 同名 TOML を置いて URL や環境変数だけ差し替え。
- **全く新しい手続き**: 新しいストラテジ `type` を Go で実装して登録（フォーク/再ビルド）。これは稀。

## 9. 検証（ロード時バリデーション）

| 規則 | 内容 |
|------|------|
| 必須 | `name`、`[discover].type`、`[install].type`、`[layout].version_pattern` |
| type 存在 | `discover/install` の `type` がレジストリに存在 |
| 正規表現 | `include`/`exclude`/`asset_pattern`/`version_pattern` がコンパイル可能 |
| テンプレート | `url`/`file`/`path`/`env` 値がパース可能（未知変数を検出） |
| 一意性 | `name` と `aliases` の衝突がない |
| 参照整合 | `git_tags`/`html_scrape`(href 非使用) は `[artifact]` 必須 |

検証失敗時は当該マニフェストを無効化し、`slog.Warn` で理由を出力（他ツールの動作は継続）。

## 10. 代表マニフェストの完全例

### 10.1 Go（標準・git_tags + archive_extract）
```toml
name = "go"
display_name = "Go"
description = "Go programming language"
homepage = "https://go.dev/"
aliases = ["golang"]

[discover]
type = "git_tags"
source = "https://github.com/golang/go"
strip_prefix = "go"
include = '^\d+\.\d+\.\d+$'
min_version = "1.13.0"

[artifact]
url  = "https://go.dev/dl/go{{.Version}}.windows-amd64.zip"
file = "go{{.Version}}.windows-amd64.zip"

[install]
type = "archive_extract"
archive = "zip"
strip_component = "go"

[layout]
version_pattern = '^\d+\.\d+\.\d+$'
link = "junction"

[activate]
path = ["{{.Current}}/bin", "{{.Env}}/go/bin"]
[activate.env]
GOROOT = "{{.Current}}"
GOPATH = "{{.Env}}/go"
GOBIN = "{{.Env}}/go/bin"
GOCACHE = "{{.Current}}/go-build"
GOENV = "{{.Current}}/env"
GO111MODULE = "on"
GOMODCACHE = "{{.Current}}/pkg/mod"
```

### 10.2 JDK（github_releases）
```toml
name = "jdk"
display_name = "OpenJDK (Temurin)"
homepage = "https://adoptium.net/"

[discover]
type = "github_releases"
source = ["adoptium/temurin11-binaries", "adoptium/temurin17-binaries", "adoptium/temurin21-binaries"]
asset_pattern = 'jdk_x64_windows_hotspot_(\d+\.\d+\.\d+(_\d+)?)\.zip$'
version_subst = { "_" = "+" }

[install]
type = "archive_extract"
archive = "zip"
strip_component = "jdk-{{.Version}}"

[layout]
version_pattern = '^\d+\.\d+\.\d+(_\d+)?'
link = "junction"

[activate]
path = ["{{.Current}}/bin"]
[activate.env]
JAVA_HOME = "{{.Current}}"
```

### 10.3 Ninja（single_binary + symexe ラッパー）
```toml
name = "ninja"
display_name = "Ninja"
homepage = "https://ninja-build.org/"

[discover]
type = "git_tags"
source = "https://github.com/ninja-build/ninja"
strip_prefix = "v"
include = '^\d+\.\d+\.\d+$'
min_version = "1.0.0"

[artifact]
url  = "https://github.com/ninja-build/ninja/releases/download/v{{.Version}}/ninja-win.zip"
file = "ninja-{{.Version}}-win.zip"

[install]
type = "single_binary"
archive = "zip"
binary = "ninja.exe"
wrapper = "symexe"

[layout]
version_pattern = '^\d+\.\d+\.\d+$'
link = "none"

[activate]
path = ["{{.Current}}"]
```

> 17 ツールすべての TOML 落とし込みは [04. ツール移植カタログ](04-tool-migration-catalog.md) を参照。
