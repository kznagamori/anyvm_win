# 01. 現状（Dart 版）アーキテクチャ分析

移植の出発点として、現行 Dart 実装の構造・規約・「組み込みコード」の多様性を分析します。

## 1. プロジェクト構成

```text
anyvm_win/
├── bin/
│   ├── anyvm_win.dart          # main。CommandRunner にコマンドを登録
│   ├── anyvm_win.exe           # dart compile exe の成果物
│   ├── anyvm.bat / anyvm.ps1   # ラッパー（rehash/update/unset/version の集約処理）
│   ├── *_vm_version_cache.json # 各ツールの「導入可能バージョン」キャッシュ（16 個。AndroidSDK は update 非対応のため無し）
│   └── anyvm_win.json          # 「現在アクティブなバージョン」マップ（実行時生成）
├── lib/
│   ├── anyvm_util.dart         # 共通ユーティリティ（DL・解凍・JSON・ログ・バージョン比較）
│   ├── anyvm_init.dart         # init コマンド（scripts/ 配下の集約スクリプト生成）
│   └── anyvm_<tool>vm.dart     # 各ツール実装（17 ファイル）
├── scripts/                    # 実行時生成（.gitignore 対象）。activate/deactivate 群
├── envs/                       # 実行時生成（.gitignore 対象）。インストール済みツール実体
├── tools/symexe.exe            # Ninja 用の実行ラッパー
├── setup_jp.bat                # シェル起動時自動実行のセットアップ（対話式）
├── Copy-AnyVmStructure.ps1     # 配布物の収集スクリプト
├── build.bat                   # dart compile exe …
└── pubspec.yaml                # 依存: path, logger, args, http, archive, charset, html
```

### 依存パッケージ（pubspec.yaml）と Go 移植時の対応

| Dart パッケージ | 用途 | Go での対応 |
|-----------------|------|-------------|
| `args` (command_runner) | 引数解析・サブコマンド | **cobra**（要求仕様） |
| `logger` | ロギング | **log/slog**（要求仕様） |
| `http` | HTTP 取得 | 標準 `net/http` |
| `html` | HTML スクレイピング | `golang.org/x/net/html` または `goquery` |
| `archive` | zip 解凍 | 標準 `archive/zip`、7z は pure-Go `bodgit/sevenzip` |
| `charset` | SJIS エンコード | `golang.org/x/text/encoding/japanese` |
| `path` | パス操作 | 標準 `path/filepath` |
| （TOML） | — | `BurntSushi/toml` または `pelletier/go-toml/v2` |

## 2. 実行時ディレクトリレイアウト

実行ファイルは `bin/` に置かれ、`Platform.script`（exe パス）から相対的にディレクトリを解決します。

```text
<anyvm ルート>/              # = アプリディレクトリ(bin)の親
├── bin/                     # アプリディレクトリ（getApplicationDirectory）
│   ├── anyvm_win.exe
│   ├── anyvm_win.json       # アクティブバージョン: { "GoVm": "1.22.0", ... }
│   └── *_vm_version_cache.json
├── scripts/                 # getScriptsDirectory
│   ├── AnyVmActivate.bat/.ps1     # 全ツールの <Tool>VmActivate を CALL/. する集約
│   ├── AnyVmDeactivate.bat/.ps1
│   └── <Tool>VmActivate.bat/.ps1  # set 時に各ツールが生成（unset 時は空に）
├── envs/
│   └── <tool>/                    # 例: go, python, rust（小文字のツール識別子）
│       ├── <version>/             # 例: 1.22.0（インストール実体）
│       ├── current               # ジャンクション → <version>
│       └── install-cache/        # ダウンロード一時領域
└── tools/symexe.exe
```

> **観察された脆さ**: ディレクトリ解決が exe の物理位置に固定されている。移植版では `ANYVM_ROOT` 環境変数で明示できるようにする（[09](09-directory-layout.md)）。

## 3. エントリポイントと共通処理

### 3.1 main（bin/anyvm_win.dart）

`CommandRunner('anyvm', ...)` を生成し、`--version` / `--verbose` フラグと 17 ツール + `init` コマンドを登録して `run(args)` するだけの薄い構造です。

```dart
runner.argParser.addFlag('verbose', negatable: false, callback: (verbose) {
  anyvm_util.setupLogging(verbose ? Level.all : Level.info);
});
runner.addCommand(anyvm_govm.GoVm());
// ... 17 ツール ...
```

### 3.2 共通ユーティリティ（lib/anyvm_util.dart）

| 関数 | 役割 | Go 移植時の論点 |
|------|------|-----------------|
| `getApplicationDirectory()` / `getScriptsDirectory()` / `getToolsDirectory()` | exe 位置からの相対パス解決 | `ANYVM_ROOT` ベースに再設計 |
| `getAnyVmFile()` | `anyvm_win.json` のパス | `state/active.toml` に変更 |
| `getVmVersion` / `setVmVersion` / `clearVmVersion` | アクティブバージョン JSON の読み書き | TOML 化・状態リポジトリに集約 |
| `writeStringWithSjisEncoding()` | `.bat`/`.ps1` を SJIS で書き出し | Platform 抽象化（エンコーダ注入） |
| `downloadFileWithProgress()` | 進捗バー付き HTTP DL | `net/http` + 進捗コールバック |
| `unzipWithProgress()` | 進捗バー付き zip 解凍 | `archive/zip` + 進捗コールバック |
| `compareVersion()` | `1.2.3` 形式の数値比較 | 専用バージョン型 or `semver` |
| `setupLogging()` / `logger` | グローバル Logger とハンドラ | slog + カスタム Handler に置換 |

`setupLogging` は **info/warning はメッセージのみ stdout**、**error はスタックトレース付きでファイル `error.log`** へ、という二重リスナ構成です。**ユーザー向け出力（info）と診断ログが同一経路**である点が、移植時に整理すべき最大の負債です（[06](06-logging.md)）。

### 3.3 アクティブバージョンの記録（anyvm_win.json）

```json
{ "GoVm": "1.22.0", "PythonVm": "3.11.8" }
```

`set` で追記、`unset` で削除されるフラットなマップです。

## 4. ツール実装の共通テンプレート

各 `anyvm_<tool>vm.dart` は次の構造を共有します。

```text
定数         : versionCacheJsonName, vmName, langName, vmActivate, vmDeactivate, 各種 URL
パス関数     : getEnvDirectory(), getEnvCacheDirectory(), getVersionDirectory()
状態遷移     : setVersion(version) / unSetVersion()
Command 群   : <Tool>Vm（親）
              ├ Install   (install -l / --latest / -v)
              ├ Update    (バージョン一覧の取得とキャッシュ生成)
              ├ Versions  (インストール済み一覧。アクティブに * を付与)
              ├ Version   (アクティブ版の表示)
              ├ Set       (-v でバージョン有効化)
              ├ Unset     (無効化)
              └ UnInstall (-v でバージョン削除)
```

### 4.1 `setVersion`（有効化）の典型的な流れ

1. 先に `unSetVersion()` を呼ぶ
2. `current` ジャンクションがあれば `cmd /C RMDIR` で削除
3. `cmd /C MKLINK /J current <version>` でジャンクション再作成
4. `scripts/<Tool>VmActivate.bat` / `.ps1` と `<Tool>VmDeactivate.bat` / `.ps1` を SJIS で生成
5. `setVmVersion(vmName, version)` で `anyvm_win.json` を更新

生成されるアクティベートスクリプトは、**`_<VmName>_ENV_VAL` ガード変数**で二重適用を防ぎ、**`_OLD_<VAR>`** に旧値を退避してから PATH と固有環境変数を設定する規約です（例: Go の `.bat`）。

```bat
@ECHO OFF
IF DEFINED _GoVm_ENV_VAL GOTO END_SET_ENV_VAL
SET _GoVm_ENV_VAL={"yes"}
SET PATH=<bin>;<gopath/bin>;%PATH%
SET _OLD_GOROOT=%GOROOT%
SET GOROOT=<current>
...
:END_SET_ENV_VAL
```

`unSetVersion` はジャンクションを削除し、アクティベートスクリプトを空（`@ECHO OFF` のみ／空行）に上書きして無効化します。

## 5. ラッパースクリプト（bin/anyvm.bat・anyvm.ps1）

exe は単一ツールのサブコマンドしか扱えないため、**全体コマンドはラッパーが複数回 exe を呼ぶ**構造です。

| 引数 | 動作 |
|------|------|
| `rehash` | `AnyVmDeactivate` → `AnyVmActivate` を呼び、現在のシェルに反映 |
| `update` | 全ツールの `update` を順次実行 |
| `unset` | 全ツールの `unset` を順次実行 |
| `version` | 全ツールの `version` をラベル付きで表示 |
| その他 | `anyvm_win.exe %*` に委譲 |

> **観察された不整合**: ラッパー内のツール列挙がハードコードで、`update` では 17 ツール中 15 ツールのみ列挙され `AndroidSDKVm` と `RustVm` が**欠落**、`unset`/`version` では 17 ツール全てが含まれる、といった差異がある。移植版では**マニフェストから動的に**全ツールを列挙し、この種の取りこぼしを構造的に排除する（[05](05-cli-design.md)）。

## 6. 補助スクリプト

| ファイル | 役割 | 移植方針 |
|----------|------|----------|
| `setup_jp.bat` | PowerShell 実行ポリシー変更、`$PROFILE`/CmdProfile.bat への追記、レジストリ `Command Processor\AutoRun` 登録を対話式に行う | `anyvm setup` サブコマンド（Go 実装、対話 or フラグ）として再実装。SJIS の文字化けも解消 |
| `Copy-AnyVmStructure.ps1` | 配布物（exe・キャッシュ・scripts・tools）を収集 | リリースワークフロー（CI）に置換 |
| `tools/symexe.exe` | Ninja の実行ラッパー（`.ini` で実体パスを指定） | Ninja ストラテジで同梱・配置（[04](04-tool-migration-catalog.md)） |

## 7. 「組み込みコード」の多様性カタログ（外部化の対象）

移植の核心は、以下にカタログ化した**ツールごとの差異**を、TOML マニフェスト（データ）と Go ストラテジ（手続き）へ振り分けることです。

### 7.1 バージョン検出（update）方式

| 方式 | 対象ツール | 備考 |
|------|-----------|------|
| `git ls-remote --tags` | Go, dotnet, Flutter, Nodejs, MinGW, LLVM, CMake, Bazel, Gradle, Kotlin, Ninja, Dart, WinLibs | 最多。タグ接頭辞の除去規則・最小バージョン・正規表現が個別 |
| HTML スクレイピング | Python（python.org）, AndroidSDK（developer.android.com・install 時に実施） | `<a>` タグ解析 |
| GitHub API（releases JSON） | JDK（adoptium temurin 11/17/21） | アセット名から正規表現抽出 |
| なし | Rust（rustup が管理）, AndroidSDK（update コマンド未実装） | — |

タグ接頭辞の除去規則の例: `v`（Nodejs/CMake/Gradle/Kotlin/Ninja）、`go`（Go）、`llvmorg-`（LLVM）、無し（dotnet/Bazel/Dart）。最小バージョンフィルタの例: Go=1.13.0、dotnet=6.0.0、Flutter=2.0.0、Nodejs/LLVM=14.0.0。

### 7.2 インストール（install）方式

| 方式 | 対象ツール | 展開後リネーム元 → 先 |
|------|-----------|------------------------|
| zip 展開 + 内部ディレクトリをリネーム | Go(`go`), JDK(`jdk-<ver>`), Flutter(`flutter`), Nodejs(`node-v<ver>-win-x64`), CMake(`cmake-<ver>-windows-x86_64`), Kotlin(`kotlinc`), Dart(`dart-sdk`), Gradle(`gradle-<shortVer>`), dotnet(`<ver>` + nuget.exe 同梱) | → `envs/<tool>/<version>` |
| zip 展開 + 単一実行ファイル配置 | Bazel(`bazel.exe`), Ninja(`ninja.exe` + symexe ラッパー + `.ini`) | → `<version>/<exe>` |
| 7z 展開 | MinGW(`mingw64`), LLVM(`llvm`・exe から抽出), WinLibs(`mingw64`) | → `<version>` |
| 専用インストーラ | Python（WiX `dark.exe` で展開 → `msiexec /a` → `ensurepip`）, Rust（`rustup-init.exe` + `config.toml` 生成） | — |
| HTML 動的取得 + zip | AndroidSDK（`cmdline-tools` を `<version>/cmdline-tools/latest` へ） | 複雑な内部構造 |

### 7.3 有効化時の環境変数

| ツール | PATH 追加（current 相対） | 固有環境変数 |
|--------|---------------------------|--------------|
| Python | `current`; `current/Scripts` | — |
| Nodejs | `current` | — |
| Go | `current/bin`; `<env>/go/bin` | GOROOT, GOPATH, GOBIN, GOCACHE, GOENV, GO111MODULE, GOMODCACHE |
| Rust | `<env>/.cargo/bin` | RUSTUP_HOME, CARGO_HOME, (sccache: RUSTC_WRAPPER, SCCACHE_*), RUSTUP_DIST_SERVER, RUSTUP_DIST_ROOT |
| JDK | `current/bin` | JAVA_HOME |
| dotnet | `current`; `<env>/.dotnet/tools` | DOTNET_ROOT, DOTNET_ROOT(x86), DOTNET_CLI_HOME, DOTNET_ADD_GLOBAL_TOOLS_TO_PATH, DOTNET_CLI_TELEMETRY_OPTOUT, NUGET_PACKAGES, NUGET_FALLBACK_PACKAGES, NUGET_HTTP_CACHE_PATH, NUGET_PERSIST_DG |
| Flutter | `current/bin`; `current/.pub-cache/bin` | PUB_CACHE |
| Dart | `current/bin`; `current/.pub-cache/bin` | PUB_CACHE |
| Gradle | `current/bin` | GRADLE_HOME, GRADLE_USER_HOME(=`<env>/cache`) |
| LLVM | `current/bin` | LIBCLANG_PATH |
| WinLibs | `current/bin`; `current/bin/x86_64-w64-mingw32/bin` | LIBCLANG_PATH |
| MinGW | `current/bin`; `current/x86_64-w64-mingw32/bin` | — |
| AndroidSDK | `current/platform-tools`; `current/cmdline-tools/latest/bin`; `current/emulator` | ANDROID_SDK_ROOT, ANDROID_HOME |
| CMake | `current/bin` | — |
| Kotlin | `current/bin` | — |
| Bazel | `current` | — |
| Ninja | `current` | — |

### 7.4 バージョンディレクトリ判定の正規表現

| 正規表現 | 対象 |
|----------|------|
| `^\d+\.\d+\.\d+$` | 大多数 |
| `^\d+\.\d+\.\d+.*$`（サフィックス許可） | MinGW, LLVM, WinLibs |
| `^\d+\.\d+\.\d+(_\d+)?` | JDK |
| `^\d+$`（整数のみ） | AndroidSDK |

### 7.5 標準テンプレート vs 特殊扱い

| 区分 | ツール | 特殊性 |
|------|--------|--------|
| 標準（最小差分で移植可能） | Flutter, Nodejs, CMake, Kotlin, Dart, Go, JDK, Gradle | zip + ジャンクション + 環境変数の素直な組み合わせ |
| 準標準（環境変数が多いが手続きは標準） | dotnet | 多数の DOTNET_/NUGET_ + nuget.exe 同梱 |
| 特殊（専用手続きが必要） | Python | WiX/dark + msiexec + ensurepip |
| 特殊 | Rust | rustup-init + config.toml、versions/version の意味が他と異なる |
| 特殊 | MinGW, LLVM, WinLibs | 7z 依存、複雑なバージョン解析 |
| 特殊 | Bazel, Ninja | 単一実行ファイル、Ninja は symexe ラッパー + `.ini` |
| 特殊 | AndroidSDK | update 無し・HTML 動的取得・多段 PATH・整数バージョン |

このカタログを、[03 マニフェスト仕様](03-plugin-manifest-spec.md)のスキーマと [04 移植カタログ](04-tool-migration-catalog.md)の TOML へ写し取ります。

## 8. 移植で解消すべき技術的負債（まとめ）

1. **ユーザー出力と診断ログの混在** → slog + カスタム Handler で責務分離（[06](06-logging.md)）
2. **ツール列挙のハードコードと取りこぼし** → マニフェスト駆動の動的列挙（[05](05-cli-design.md)）
3. **exe 物理位置依存のパス解決** → `ANYVM_ROOT` 明示（[09](09-directory-layout.md)）
4. **組み込みされた各ツール固有ロジック** → TOML マニフェスト + ストラテジへ外部化（[03](03-plugin-manifest-spec.md), [04](04-tool-migration-catalog.md)）
5. **多数の外部コマンド依存（git/7z/WiX/msiexec/cmd）** → API・pure-Go・OS API へ削減（[04](04-tool-migration-catalog.md)）
6. **SJIS 直書き・`.bat`/`.ps1` 文字列連結** → Platform 抽象 + テンプレート化（[08](08-os-abstraction.md)）
