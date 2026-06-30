# 04. ツール移植カタログ（17 ツール）

[01 §7 の組み込みコードカタログ](01-current-architecture.md)を、[03 マニフェスト仕様](03-plugin-manifest-spec.md)へ落とし込んだ実装リファレンスです。

## 1. 外部依存の削減方針（決定: 可能な限り削減）

| 現状の外部依存 | 用途 | 移植後 | 残置 |
|----------------|------|--------|------|
| `git ls-remote --tags` | 約 13 ツールの版列挙 | **GitHub HTTP API / スマート HTTP** で `git_tags` ストラテジが取得 | — |
| `cmd.exe MKLINK /J` | ジャンクション生成 | **`os`/`syscall`**（`CreateSymbolicLink`/ reparse point）で生成（[08](08-os-abstraction.md)） | — |
| `cmd.exe RMDIR` | ジャンクション削除 | **`os.Remove`** | — |
| zip 解凍（archive pkg） | 多数 | 標準 **`archive/zip`** | — |
| `7z.exe` | MinGW/LLVM/WinLibs 展開 | **pure-Go `github.com/bodgit/sevenzip`**（読み取り） | — |
| WiX `dark.exe` + `msiexec` | Python 展開 | — | **残置**（本質的に必要。subprocess） |
| `rustup-init.exe` | Rust 導入 | — | **残置**（Rust の正規導入手段） |
| `symexe.exe` | Ninja ランチャ | — | **残置**（同梱ツール。配置のみ） |

> **GitHub API レート制限への配慮**: 未認証は 60 req/h。対策として (1) `update` の同時実行数を `semaphore` で制限、(2) `GITHUB_TOKEN` 環境変数があれば認証ヘッダを付与（5000 req/h）、(3) ETag による条件付き取得でキャッシュ、(4) スマート HTTP（`info/refs`）はレート対象外のため、タグ列挙のフォールバックとして利用。詳細は `git_tags` ストラテジ実装で吸収。

## 2. 必要なストラテジ type の一覧

| 分類 | type | 実装 | 使用ツール数 |
|------|------|------|--------------|
| discover | `git_tags` | GitHub API/スマート HTTP でタグ列挙 | 13 |
| discover | `github_releases` | Releases アセット列挙 | 1（JDK） |
| discover | `html_scrape` | HTML 解析 | 1（Python）※AndroidSDK は install 内 |
| discover | `none` | 列挙なし | 2（Rust, AndroidSDK） |
| install | `archive_extract` | zip/7z 展開 + リネーム | 12 |
| install | `single_binary` | 単一 exe 配置（+symexe） | 2（Bazel, Ninja） |
| install | `python_msi` | WiX+msiexec+ensurepip | 1（Python） |
| install | `rustup` | rustup-init+config | 1（Rust） |
| install | `android_sdk` | HTML 取得 + 再配置 | 1（AndroidSDK） |

ビルトインで実装すべきストラテジは discover 4 種・install 5 種の計 **9 実装**。標準ツールはこの組み合わせ + データのみで成立します。

## 3. 全 17 ツール対応表

| # | name（新） | 旧 vmName | discover | install | archive | 固有環境変数 | version_pattern | link |
|---|-----------|-----------|----------|---------|---------|--------------|-----------------|------|
| 1 | go | GoVm | git_tags | archive_extract | zip | GOROOT,GOPATH,GOBIN,GOCACHE,GOENV,GO111MODULE,GOMODCACHE | `^\d+\.\d+\.\d+$` | junction |
| 2 | python | PythonVm | html_scrape | python_msi | — | （PATH のみ） | `^\d+\.\d+\.\d+$` | junction |
| 3 | nodejs | NodejsVm | git_tags | archive_extract | zip | — | `^\d+\.\d+\.\d+$` | junction |
| 4 | rust | RustVm | none | rustup | — | RUSTUP_HOME,CARGO_HOME,(sccache),RUSTUP_DIST_* | （特殊） | none |
| 5 | dart | DartVm | git_tags | archive_extract | zip | PUB_CACHE | `^\d+\.\d+\.\d+$` | junction |
| 6 | flutter | FlutterVm | git_tags | archive_extract | zip | PUB_CACHE | `^\d+\.\d+\.\d+$` | junction |
| 7 | jdk | JDKVm | github_releases | archive_extract | zip | JAVA_HOME | `^\d+\.\d+\.\d+(_\d+)?` | junction |
| 8 | dotnet | dotnetVm | git_tags | archive_extract | zip | DOTNET_*,NUGET_* | `^\d+\.\d+\.\d+$` | junction |
| 9 | cmake | CMakeVm | git_tags | archive_extract | zip | — | `^\d+\.\d+\.\d+$` | junction |
| 10 | bazel | BazelVm | git_tags | single_binary | zip | — | `^\d+\.\d+\.\d+$` | none |
| 11 | gradle | GradleVm | git_tags | archive_extract | zip | GRADLE_HOME,GRADLE_USER_HOME | `^\d+\.\d+\.\d+$` | junction |
| 12 | mingw | MinGWVm | git_tags | archive_extract | 7z | — | `^\d+\.\d+\.\d+.*$` | junction |
| 13 | llvm | LLVMVm | git_tags | archive_extract | 7z | LIBCLANG_PATH | `^\d+\.\d+\.\d+.*$` | junction |
| 14 | ninja | NinjaVm | git_tags | single_binary | zip | — | `^\d+\.\d+\.\d+$` | none |
| 15 | kotlin | KotlinVm | git_tags | archive_extract | zip | — | `^\d+\.\d+\.\d+$` | junction |
| 16 | androidsdk | AndroidSDKVm | none | android_sdk | zip | ANDROID_SDK_ROOT,ANDROID_HOME | `^\d+$` | junction |
| 17 | winlibs | WinLibsVm | git_tags | archive_extract | 7z | LIBCLANG_PATH | `^\d+\.\d+\.\d+.*$` | junction |

> 注: 旧コードには `langName` 定数があるが新設計では不要。`dotnetVm` の不統一な casing は `dotnet` に正規化。

## 4. 標準ツールの落とし込み（TOML 抜粋）

[03 §10.1（Go）](03-plugin-manifest-spec.md)と同型。差分のみ示します。

### nodejs
```toml
[discover]
type = "git_tags"
source = "https://github.com/nodejs/node"
strip_prefix = "v"
include = '^\d+\.\d+\.\d+$'
min_version = "14.0.0"
[artifact]
url  = "https://nodejs.org/dist/v{{.Version}}/node-v{{.Version}}-win-x64.zip"
file = "node-v{{.Version}}-win-x64.zip"
[install]
type = "archive_extract"
archive = "zip"
strip_component = "node-v{{.Version}}-win-x64"
[layout]
version_pattern = '^\d+\.\d+\.\d+$'
link = "junction"
[activate]
path = ["{{.Current}}"]   # bin 無し。直下に node.exe
```

### dart / flutter（PUB_CACHE 系）
```toml
# dart
[discover]
type = "git_tags"
source = "https://github.com/dart-lang/sdk"
include = '^\d+\.\d+\.\d+$'
min_version = "2.0.0"
[artifact]
url  = "https://storage.googleapis.com/dart-archive/channels/stable/release/{{.Version}}/sdk/dartsdk-windows-x64-release.zip"
file = "dartsdk-{{.Version}}-windows-x64.zip"
[install]
type = "archive_extract"
archive = "zip"
strip_component = "dart-sdk"
[activate]
path = ["{{.Current}}/bin", "{{.Current}}/.pub-cache/bin"]
[activate.env]
PUB_CACHE = "{{.Current}}/.pub-cache"
```
flutter は `source=flutter/flutter`、`strip_component="flutter"`、min_version=2.0.0、`url` は flutter のリリースアーカイブ。PATH/PUB_CACHE は dart と同型。

### cmake / kotlin / gradle
```toml
# cmake: strip_component="cmake-{{.Version}}-windows-x86_64", strip_prefix="v"
#        url=https://github.com/Kitware/CMake/releases/download/v{{.Version}}/cmake-{{.Version}}-windows-x86_64.zip
# kotlin: source=JetBrains/kotlin, strip_prefix="v", strip_component="kotlinc"
#        url=https://github.com/JetBrains/kotlin/releases/download/v{{.Version}}/kotlin-compiler-{{.Version}}.zip
# gradle: source=gradle/gradle-distributions, strip_prefix="v"
#        strip_component="gradle-{{ shortver .Version }}"  ← 末尾 ".0" を除去するテンプレート関数
[activate.env]   # gradle のみ
GRADLE_HOME = "{{.Current}}"
GRADLE_USER_HOME = "{{.Env}}/cache"
```
> Gradle の `shortver` は `version.replaceAll(/\.0$/, '')`（例 8.5.0 → 8.5）を行う FuncMap 関数として実装。

### dotnet（環境変数が多い・nuget 同梱）
```toml
[discover]
type = "git_tags"
source = "https://github.com/dotnet/sdk"
strip_prefix = "v"
include = '^\d+\.\d+\.\d+$'
min_version = "6.0.0"
[artifact]
url  = "https://builds.dotnet.microsoft.com/dotnet/Sdk/{{.Version}}/dotnet-sdk-{{.Version}}-win-x64.zip"
file = "dotnet-sdk-{{.Version}}-win-x64.zip"
[install]
type = "archive_extract"
archive = "zip"
strip_component = ""    # zip 直下が SDK ルート。展開先=VersionDir
post_download = [
  { url = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe", dest = "{{.VersionDir}}/nuget.exe" },
]
[activate]
path = ["{{.Current}}", "{{.Env}}/.dotnet/tools"]
[activate.env]
DOTNET_ROOT = "{{.Current}}"
"DOTNET_ROOT(x86)" = "{{.Current}}"
DOTNET_CLI_HOME = "{{.Env}}"
DOTNET_ADD_GLOBAL_TOOLS_TO_PATH = "false"
DOTNET_CLI_TELEMETRY_OPTOUT = "true"
NUGET_PACKAGES = "{{.Env}}/nuget/packages"
NUGET_FALLBACK_PACKAGES = "{{.Env}}/nuget/fallback_packages"
NUGET_HTTP_CACHE_PATH = "{{.Env}}/nuget/http_cache_path"
NUGET_PERSIST_DG = "{{.Env}}/nuget/persist_dg"
```
> `DOTNET_ROOT(x86)` のように括弧を含む環境変数名は、スクリプト生成側で適切にクォートする（[08](08-os-abstraction.md)）。旧 `.ps1` には `$env:OLD_DOTNET_ROOT` の typo 等のバグがあったが、移植版はテンプレートで一貫生成し解消する。

## 5. 7z 系（MinGW / LLVM / WinLibs）

`archive = "7z"` を指定し、`bodgit/sevenzip` で展開（外部 `7z.exe` 不要）。

```toml
# mingw
name = "mingw"
[discover]
type = "git_tags"
source = "https://github.com/niXman/mingw-builds-binaries"
include = '^\d+\.\d+\.\d+.*$'
[artifact]
url  = "https://github.com/niXman/mingw-builds-binaries/releases/download/{{.Version}}/...x86_64...7z"
file = "mingw-{{.Version}}-x86_64.7z"
[install]
type = "archive_extract"
archive = "7z"
strip_component = "mingw64"
[layout]
version_pattern = '^\d+\.\d+\.\d+.*$'
link = "junction"
[activate]
path = ["{{.Current}}/bin", "{{.Current}}/x86_64-w64-mingw32/bin"]

# llvm: source=llvm/llvm-project, strip_prefix="llvmorg-", アセットは exe だが内部 7z 抽出
#       strip_component="llvm", LIBCLANG_PATH="{{.Current}}/bin"
# winlibs: source=brechtsanders/winlibs_mingw, 複雑な複数パターン版解析
#       path=[{{.Current}}/bin, {{.Current}}/bin/x86_64-w64-mingw32/bin], LIBCLANG_PATH
```
> **WinLibs / MinGW の複雑なバージョン解析**: 旧コードは複数の正規表現パターンで GCC/LLVM/MinGW/Revision を解析していた。これは `git_tags` の `include`/`version_subst` だけでは表現しきれない場合がある。その場合は discover に専用の軽量パーサ（`type="winlibs_tags"` 等のサブ実装）を追加するか、`static` で curated リストを同梱する。移植初期は `static` で確実な版を提供し、段階的に自動化するのが安全（[11 ロードマップ](11-roadmap.md)）。

## 6. 単一実行ファイル系（Bazel / Ninja）

### bazel
```toml
[discover]
type = "git_tags"
source = "https://github.com/bazelbuild/bazel"
include = '^\d+\.\d+\.\d+$'
min_version = "6.0.0"
[artifact]
url  = "https://github.com/bazelbuild/bazel/releases/download/{{.Version}}/bazel-{{.Version}}-windows-x86_64.exe"
file = "bazel-{{.Version}}-windows-x86_64.exe"
[install]
type = "single_binary"
archive = "none"     # exe 直 DL（zip でない）
binary = "bazel.exe"
wrapper = "none"
[layout]
link = "none"
[activate]
path = ["{{.Current}}"]
```
> Bazel は zip でなく exe 直リンクのため `archive="none"`（DL したものをそのまま `<version>/bazel.exe` に配置）。

### ninja
[03 §10.3](03-plugin-manifest-spec.md) 参照。`wrapper="symexe"` で、`tools/symexe.exe` を `<version>/ninja.exe` の隣に配置し `.ini` に実体パスを書く（旧仕様踏襲）。

## 7. 専用ストラテジ系

### python（python_msi）
```toml
name = "python"
[discover]
type = "html_scrape"
url = "https://www.python.org/downloads/windows/"
anchor_text = "Windows installer (64-bit)"
href_regex = '/python/(\d+\.\d+\.\d+)/python-\1-amd64\.exe$'
[artifact]
url  = "https://www.python.org/ftp/python/{{.Version}}/python-{{.Version}}-amd64.exe"
file = "python-{{.Version}}-amd64.exe"
[install]
type = "python_msi"
wix_url = "https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip"
exclude_msi = ["appendpath.msi", "launcher.msi", "path.msi", "pip.msi"]
run_ensurepip = true
[layout]
version_pattern = '^\d+\.\d+\.\d+$'
link = "junction"
[activate]
path = ["{{.Current}}", "{{.Current}}/Scripts"]
```

### rust（rustup）
```toml
name = "rust"
[discover]
type = "none"
[install]
type = "rustup"
installer_url = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
default_host = "x86_64-pc-windows-gnu"
toolchain = "stable"
cargo_config = """
[target.x86_64-pc-windows-gnu]
rustflags = [
  "-C", "link-arg=-Wl,--exclude-libs=ALL",
  "-C", "link-arg=-Wl,--exclude-all-symbols",
  "-C", "link-arg=-Wl,--allow-multiple-definition",
]
"""
[layout]
link = "none"
[activate]
path = ["{{.Env}}/.cargo/bin"]
[activate.env]
RUSTUP_HOME = "{{.Env}}/.rustup"
CARGO_HOME = "{{.Env}}/.cargo"
RUSTUP_DIST_SERVER = "https://static.rust-lang.org"
RUSTUP_DIST_ROOT = "https://static.rust-lang.org/rustup"
[[activate.env_if]]
exists = "{{.Env}}/.cargo/bin/sccache.exe"
[activate.env_if.env]
RUSTC_WRAPPER = "sccache"
SCCACHE_CACHE_SIZE = "1G"
SCCACHE_DIR = "{{.Env}}/.sccache"
```
> Rust の `versions`/`version` は他ツールと意味が異なる（版ディレクトリでなく導入有無・`rustc --version`）。Engine 側で `layout.link="none"` かつ `discover.type="none"` のツールは「単一インストール型」として扱い、`versions` は導入有無を表示する分岐を設ける（[07](07-library-api.md)）。

### androidsdk（android_sdk）
```toml
name = "androidsdk"
[discover]
type = "none"          # update コマンドは no-op
[install]
type = "android_sdk"
relocate_to = "cmdline-tools/latest"
# install 時に https://developer.android.com/studio から commandlinetools-win-*.zip を HTML 取得
[layout]
version_pattern = '^\d+$'
link = "junction"
[activate]
path = ["{{.Current}}/platform-tools", "{{.Current}}/cmdline-tools/latest/bin", "{{.Current}}/emulator"]
[activate.env]
ANDROID_SDK_ROOT = "{{.Current}}"
ANDROID_HOME = "{{.Current}}"
```
> AndroidSDK は JDK に実行依存する（sdkmanager 実行に Java 必須）。これはツール間依存として `requires = ["jdk"]` を将来追加し、`set` 時に警告する余地を残す（初期は文書注意に留める）。

## 8. 移植時の検証ポイント（ツール横断）

1. **URL の現存性**: 旧キャッシュ JSON（`bin/*_vm_version_cache.json`）と新 discover 結果を突き合わせ、URL テンプレートが実在 URL を生成するか検証（[12 テスト](12-testing.md)）。
2. **strip_component のテンプレート**: Node/CMake/JDK/Gradle は版を含む。テンプレート展開を単体テスト。
3. **7z 展開の互換**: `bodgit/sevenzip` が対象アーカイブを展開できるか実アーカイブで確認。不可なら当該ツールのみ `7z.exe` フォールバックを許容（折衷）。
4. **環境変数名の特殊文字**: `DOTNET_ROOT(x86)` 等のクォート。
5. **バージョン比較**: サフィックス付き（MinGW/LLVM/WinLibs）・アンダースコア（JDK）・整数（AndroidSDK）の比較規則（[07 version.go]）。
