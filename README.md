# anyvm_win

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-v1.2.0-green.svg)](https://github.com/kznagamori/anyvm_win/releases)
[![Platform](https://img.shields.io/badge/platform-Windows-blue.svg)](https://www.microsoft.com/windows)

> Windows用の開発ツールバージョン管理システム（anyenv for Windows）

anyvm_winは、LinuxのanyenvにインスパイアされたWindows用の開発ツールバージョン管理システムです。Python、Node.js、Go、Rust、Java、Flutter、Dartなど、様々な開発ツールのバージョンを簡単にインストール・管理・切り替えできます。

## ✨ 特徴

- 🔧 **多数のツールサポート**: Python、Node.js、Go、Rust、Java、Flutter、Dart等の複数ツールに対応
- 🎯 **最小限のシステム影響**: Windowsのレジストリやシステム全体のインストールを変更せずに動作
- 🚀 **シェル統合**: PowerShellやコマンドプロンプトの起動スクリプトで自動有効化
- 📦 **簡単インストール**: シンプルなダウンロードとセットアップ
- 🔄 **バージョン切り替え**: インストール済みバージョン間の素早い切り替え
- 🧹 **クリーンアンインストール**: システムに痕跡を残さない完全な削除

## 🎯 コンセプト

anyvm_winは以下の目標で作成されました：
- Windowsでプログラミングを快適に行いたい
- Linuxで使用される**anyenv**のように開発ツールのバージョン管理を統一的に行いたい
- Windowsの環境（レジストリやインストールアプリケーションなど）に影響を最小限に抑えたい
- **anyenv**が起動シェル（`.bashrc`など）でバージョンを管理しているように、Windowsでも起動シェルで管理したい


## 🏗️ 対応開発ツール

| ツール名 | 開発ツール | 説明 |
|----------|------------|------|
| PythonVm | Python | https://www.python.org/ |
| NodejsVm | Node.js | https://nodejs.org/ |
| GoVm | Go | https://go.dev/ |
| RustVm | Rust | https://www.rust-lang.org/ |
| DartVm | Dart | https://dart.dev/ |
| FlutterVm | Flutter | https://flutter.dev/ |
| JDKVm | OpenJDK | https://adoptium.net/ |
| dotnetVm | .NET | https://dotnet.microsoft.com/ |
| CMakeVm | CMake | https://cmake.org/ |
| BazelVm | Bazel | https://bazel.build/ |
| GradleVm | Gradle | https://gradle.org/ |
| その他 | MinGW, LLVM, Ninja, Kotlin, WinLibs, AndroidSDK | 各種開発ツール |

## 🚀 クイックスタート

### 1. インストール

最新版をダウンロードして展開：

```bash
# GitHubリリースページから anyvm_win.zip をダウンロード
# https://github.com/kznagamori/anyvm_win/releases

# 任意のディレクトリに展開
# 例: D:\anyvm_win
```

### 2. 初期設定

```cmd
# コマンドプロンプトで初期化
D:\anyvm_win> .\bin\anyvm.bat init

# セットアップスクリプト実行（自動起動設定）
D:\anyvm_win> .\setup_jp.bat
```

### 3. 使用例

```powershell
# インストール可能なPythonバージョンを確認
PS C:\> anyvm PythonVm install -l

# Python 3.11.8をインストール
PS C:\> anyvm PythonVm install --version 3.11.8

# インストール済みバージョンを確認
PS C:\> anyvm PythonVm versions

# バージョンを有効化
PS C:\> anyvm PythonVm set --version 3.11.8
PS C:\> anyvm rehash

# 確認
PS C:\> python --version
Python 3.11.8
```

## 🎮 システムイメージ

- **PowerShell（pwsh）** や **コマンドプロンプト** での使用を想定
- **VSCode** は PowerShell/コマンドプロンプトから起動することで本ツールの機能が利用可能
- **anyenv** の `global`/`local` ではなく、`set`/`unset` でのバージョン切り替えを採用
- 起動時自動実行スクリプトによる機能の有効化
- Windows環境への影響度を選択可能


## ⚙️ Windows環境への影響度

anyvm_winでは、使用方法によってWindows環境への影響レベルを選択できます。

### 🟢 影響度: 低
- 手動でスクリプトを実行してツールを有効化
- 実行しない限りツールは使用不可
- システムへの影響はほぼなし

```cmd
# 手動でスクリプト実行
<anyvm_winパス>\scripts\AnyVmActivate.bat
<anyvm_winパス>\scripts\AnyVmActivate.ps1
```

### 🟡 影響度: 中
- Shell起動時に自動でanyvm_winを実行
- ツールの有効・無効を動的に切り替え可能
- **推奨設定**

### 🔴 影響度: 高
- 環境変数PATHに直接パスを追加
- 常時ツールが使用可能
- 他のツールとのコンフリクトの可能性

```
# ジャンクションパス
anyvm_win\envs\<ツール名>\current
```


## 📦 インストール

### anyvm_winの取得

[anyvm_win.zip](https://github.com/kznagamori/anyvm_win/releases/latest)をダウンロードし、任意のディレクトリに展開します。

<details>
<summary>📁 ディレクトリ構造</summary>

```
anyvm_win/
├── bin/                        # 実行ファイルとキャッシュ
│   ├── anyvm.bat              # コマンドプロンプト用スクリプト
│   ├── anyvm.ps1              # PowerShell用スクリプト
│   ├── anyvm_win.exe          # メイン実行ファイル
│   └── *_vm_version_cache.json # 各ツールのバージョンキャッシュ
├── scripts/                    # 起動・終了スクリプト
│   ├── AnyVmActivate.bat
│   ├── AnyVmActivate.ps1
│   ├── AnyVmDeactivate.bat
│   └── AnyVmDeactivate.ps1
├── setup_jp.bat               # セットアップスクリプト
└── tools/                     # 補助ツール
    └── symexe.exe
```
</details>

### セットアップの準備

1. コマンドプロンプトを起動
2. anyvm_winを展開したディレクトリに移動


### 起動時自動実行スクリプトの設定

**⚠️ 影響度:中で使用する場合のみ、この手順を実行してください。**

シェル起動時に自動でanyvm_winを有効化するための設定です。この設定を行うことで、PowerShellやコマンドプロンプトを起動するたびにanyvm_winが自動的に使用可能になります。

#### セットアップの実行

以下のコマンドでセットアップスクリプトを実行します：

```cmd
D:\anyvm_win>.\setup_jp.bat
```

#### セットアップスクリプト実行時の質問項目

setup_jp.batを実行すると、以下の質問が順番に表示されます。各質問の意味と推奨回答について説明します：

##### 1. PowerShell実行ポリシーの変更
```
PowerShellの実行ポリシーをRemoteSignedに変更しますか？(Y=YES / N=NO):
```
- **目的:** PowerShellでスクリプトファイルの実行を許可します
- **実行されるコマンド:** `powershell -Command Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`
- **影響範囲:** 現在のユーザーのみ（システム全体には影響しません）
- **⚠️ セキュリティ注意:** スクリプト実行が可能になるため、セキュリティレベルが低下します
- **推奨:** 個人使用環境では「Y」、企業環境では管理者に確認後決定

##### 2. PowerShell起動スクリプトの作成
```
<PowerShellスクリプトのパス>を作成しますか？(Y=YES / N=NO):
```
- **目的:** PowerShell用のプロファイルスクリプト（起動時実行ファイル）を作成します
- **作成場所:** `$PROFILE`パス（例：`Documents\PowerShell\Microsoft.PowerShell_profile.ps1`）
- **効果:** PowerShell起動時に自動実行されるスクリプトファイルが準備されます
- **推奨:** 「Y」

##### 3. PowerShell起動スクリプトへの追記
```
<PowerShellスクリプトのパス>にパスを追記しますか？(Y=YES / N=NO):
```
- **目的:** 作成したPowerShellプロファイルにanyvm_winの初期化コードを追記します
- **効果:** PowerShell起動時に自動でanyvm_winが使用可能になります
- **追記内容:** anyvm_winのアクティベーションスクリプト呼び出し
- **推奨:** 「Y」

##### 4. コマンドプロンプト起動設定のレジストリ登録
```
レジストリにcmdの起動バッチファイルのパスを追加しますか？(Y=YES / N=NO):
```
- **目的:** コマンドプロンプト起動時に自動実行するバッチファイルをWindowsレジストリに登録します
- **レジストリキー:** `HKEY_CURRENT_USER\Software\Microsoft\Command Processor`の`AutoRun`
- **権限:** 管理者権限が要求される場合があります
- **影響範囲:** 現在のユーザーがコマンドプロンプトを起動する際のみ
- **推奨:** 「Y」（権限の問題がない場合）

##### 5. コマンドプロンプト起動バッチファイルへの追記
```
<起動バッチファイルのパス>にパスを追記しますか？(Y=YES / N=NO):
```
- **目的:** コマンドプロンプト用の起動バッチファイルにanyvm_winの初期化コードを追記します
- **効果:** コマンドプロンプト起動時に自動でanyvm_winが使用可能になります
- **追記内容:** anyvm_winのアクティベーションバッチ呼び出し
- **推奨:** 「Y」

##### 6. PowerShell Core (pwsh) 起動スクリプトの作成
```
<pwshスクリプトのパス>を作成しますか？(Y=YES / N=NO):
```
- **目的:** PowerShell Core（pwsh.exe）用の起動スクリプトを作成します
- **対象:** Windows PowerShell (powershell.exe) とは別の、PowerShell 7以降
- **補足:** PowerShell Coreをインストールしていない場合は「N」でも問題ありません
- **推奨:** PowerShell Coreを使用する場合は「Y」、使用しない場合は「N」

##### 7. PowerShell Core (pwsh) 起動スクリプトへの追記
```
<pwshスクリプトのパス>にパスを追記しますか？(Y=YES / N=NO):
```
- **目的:** PowerShell Core用のプロファイルにanyvm_winの初期化コードを追記します
- **効果:** PowerShell Core起動時に自動でanyvm_winが使用可能になります
- **推奨:** 前の質問で「Y」を選択した場合は「Y」、「N」を選択した場合は「N」

#### 💡 一般的な推奨設定

多くの場合、以下の回答が推奨されます：

| 質問内容 | 推奨回答 | 理由 |
|---------|---------|------|
| PowerShell実行ポリシー変更 | Y | スクリプト実行に必要 |
| PowerShellスクリプト作成 | Y | 自動起動に必要 |
| PowerShellスクリプト追記 | Y | 自動起動に必要 |
| レジストリ追加 | Y | 自動起動に必要 |
| 起動バッチファイル追記 | Y | 自動起動に必要 |
| pwshスクリプト作成 | Y/N | PowerShell Core使用時のみY |
| pwshスクリプト追記 | Y/N | PowerShell Core使用時のみY |

### anyvm_winの初期化

初期化コマンドを実行してセットアップを完了します：

```cmd
D:\anyvm_win>.\bin\anyvm.bat init
```

🎉 **インストール完了！**


## 💻 使用方法

基本的な使用方法：

```bash
anyvm <開発ツール名> <コマンド> <オプション> ...
```

**使用例:**
```powershell
# Pythonのインストール済みバージョン一覧を表示
PS C:\> anyvm PythonVm versions
 3.10.11
*3.11.8    # *印は現在有効なバージョン
 3.12.2
 3.8.10
```

### コマンド一覧

| コマンド | オプション | 説明 |
|----------|------------|------|
| `install -l` | | インストール可能なバージョン一覧を表示 |
| `install -v <バージョン>` | | 指定バージョンをインストール |
| `install --latest` | | 最新バージョンをインストール |
| `uninstall -v <バージョン>` | | 指定バージョンをアンインストール |
| `set -v <バージョン>` | | 指定バージョンを有効化 |
| `unset` | | ツールを無効化 |
| `version` | | 有効なバージョンを表示 |
| `versions` | | インストール済みバージョン一覧を表示 |
| `update` | | インストール可能なバージョンの検索を実行 |

### 全体コマンド

| コマンド | 説明 |
|----------|------|
| `anyvm init` | インストール・更新時の初期化 |
| `anyvm rehash` | 開発ツールの環境変数を更新（set/unset後に実行） |
| `anyvm unset` | すべての開発ツールを無効化 |
| `anyvm update` | すべてのツールのバージョン検索を実行 |

## 📝 使用例

### Python 3.11.8のインストールと設定

```powershell
# 1. インストール可能なバージョンを確認
PS C:\> anyvm PythonVm install -l
3.8.10
3.9.13
3.10.11
3.11.8
3.12.4
...

# 2. 指定バージョンをインストール
PS C:\> anyvm PythonVm install --version 3.11.8
Download python-3.11.8-amd64.exe...
[========================================] 100.00%
Installation complete.

# 3. インストール済みバージョンを確認
PS C:\> anyvm PythonVm versions
 3.10.11
*3.11.8
 3.12.4

# 4. バージョンを有効化
PS C:\> anyvm PythonVm set --version 3.11.8
PS C:\> anyvm rehash

# 5. 動作確認
PS C:\> python --version
Python 3.11.8

# 6. 無効化（必要に応じて）
PS C:\> anyvm PythonVm unset
```

## 🗑️ 完全なアンインストール

anyvm_winを完全に削除し、システムを元の状態に戻すための手順です。

### 🔄 事前準備（バックアップ推奨）

アンインストール前に、以下のバックアップを取ることを推奨します：

```powershell
# PowerShellプロファイルのバックアップ
if (Test-Path $PROFILE) {
    Copy-Item $PROFILE ($PROFILE + ".backup_$(Get-Date -Format 'yyyyMMdd')")
}

# pwshプロファイルのバックアップ（PowerShell Core使用時）
$pwshProfile = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $pwshProfile) {
    Copy-Item $pwshProfile ($pwshProfile + ".backup_$(Get-Date -Format 'yyyyMMdd')")
}
```

### 📋 完全アンインストール手順

#### 1. 全開発ツールの無効化

```cmd
# すべての開発ツールを無効化
anyvm unset

# 環境変数をクリア
anyvm rehash
```

#### 2. 起動時自動実行設定の削除

##### PowerShell起動スクリプトの修正

**Windows PowerShell (powershell.exe):**
```powershell
# プロファイルを確認
if (Test-Path $PROFILE) {
    # anyvm_win関連行を削除（手動編集）
    notepad $PROFILE
}
```

**PowerShell Core (pwsh.exe):**
```powershell
# pwshプロファイルを確認
$pwshProfile = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $pwshProfile) {
    # anyvm_win関連行を削除（手動編集）
    notepad $pwshProfile
}
```

**削除対象行の例:**
```powershell
# 以下のような anyvm_win 関連行を削除
. "D:\anyvm_win\scripts\AnyVmActivate.ps1"
# または
& "D:\anyvm_win\scripts\AnyVmActivate.ps1"
```

##### コマンドプロンプト起動設定の削除

**レジストリの確認と修正:**
```cmd
# レジストリエディターを開く
regedit
```

**修正箇所:**
- キー: `HKEY_CURRENT_USER\Software\Microsoft\Command Processor`
- 値: `AutoRun`
- 操作: anyvm_win関連のパスを削除、または値全体を削除

**または PowerShell で確認:**
```powershell
# 現在の設定を確認
Get-ItemProperty "HKCU:\Software\Microsoft\Command Processor" -Name AutoRun -ErrorAction SilentlyContinue

# AutoRun値を削除（完全に削除する場合）
Remove-ItemProperty "HKCU:\Software\Microsoft\Command Processor" -Name AutoRun -Force
```

**起動バッチファイルの修正:**
```cmd
# AutoRunで指定されているバッチファイルを編集
# anyvm_win関連行を削除し、以下のみに変更:
@ECHO OFF
```

#### 3. PowerShell実行ポリシーの復元（必要に応じて）

setup_jp.batでPowerShell実行ポリシーを変更した場合：

```powershell
# 実行ポリシーをより制限的な設定に戻す
Set-ExecutionPolicy Restricted -Scope CurrentUser -Force

# または元の設定に戻す（既定はRestricted）
Set-ExecutionPolicy Undefined -Scope CurrentUser -Force
```

#### 4. anyvm_winディレクトリの削除

```cmd
# anyvm_winディレクトリを完全削除
rd /s "D:\anyvm_win"
```

**注意:** 展開したパスに合わせてパスを変更してください。

#### 5. キャッシュとデータの削除

##### 開発ツール関連キャッシュの削除

**Node.js関連:**
```cmd
# npmキャッシュの削除
rmdir /s "%LOCALAPPDATA%\npm-cache"

# yarnキャッシュの削除
rmdir /s "%LOCALAPPDATA%\Yarn\Cache"

# pnpmキャッシュの削除（使用していた場合）
rmdir /s "%LOCALAPPDATA%\pnpm"
```

**Python関連:**
```cmd
# pipキャッシュの削除
rmdir /s "%LOCALAPPDATA%\pip\cache"
```

**Go関連:**
```cmd
# Goモジュールキャッシュの削除（anyvm_winで管理していた場合）
rmdir /s "%LOCALAPPDATA%\go-build"
```

##### Windows一時ファイルの削除

```cmd
# 一時ファイルの削除
del /q /s "%TEMP%\anyvm_win*"
del /q /s "%TMP%\anyvm_win*"
```

#### 6. システムの再起動

設定を完全に反映させるため、システムを再起動することを推奨します：

```cmd
shutdown /r /t 0
```

### 🔄 ロールバック（部分的な復元）

完全削除ではなく、設定を元に戻したい場合：

#### PowerShellプロファイルの復元

```powershell
# バックアップから復元
$backupFile = Get-ChildItem ($PROFILE + ".backup_*") | Sort-Object Name -Descending | Select-Object -First 1
if ($backupFile) {
    Copy-Item $backupFile.FullName $PROFILE -Force
    Write-Host "PowerShellプロファイルを復元しました: $($backupFile.Name)"
}
```

#### 段階的な無効化

```cmd
# 特定のツールのみ無効化
anyvm PythonVm unset
anyvm NodejsVm unset

# 起動スクリプトは維持してツールのみ削除
anyvm PythonVm uninstall -v 3.11.8
```

### ✅ アンインストール完了の確認

アンインストールが正しく完了したか確認：

```powershell
# 新しいPowerShellセッションで確認
powershell -NoProfile -Command "python --version"  # エラーになるはず
powershell -NoProfile -Command "node --version"    # エラーになるはず
powershell -NoProfile -Command "Get-Command anyvm" # エラーになるはず

# 環境変数PATHにanyvm_win関連パスが残っていないか確認
echo $env:PATH | Select-String "anyvm_win"  # 何も表示されないはず
```

### ⚠️ 注意事項

- **他のプログラムへの影響:** anyvm_win以外でインストールした同名の開発ツールがある場合、そちらが有効になる可能性があります
- **データの保護:** 開発プロジェクトのデータは削除されません（anyvm_winはツールのバージョン管理のみ）
- **設定の確認:** 企業環境の場合、PowerShell実行ポリシーの変更前に管理者に確認してください


## 📚 Appendix

<details>
<summary>A. Rust特有の設定</summary>

### Rustのインストール

anyvm_winでは、以下のコマンドでRustのインストールを行います：

```bash
rustup-init.exe -y --no-modify-path --default-host x86_64-pc-windows-gnu --default-toolchain stable
```

**設定の特徴：**
- Rustのツールチェインは**gcc(MinGW)**を使用する設定でインストール
- 本ツールで管理される**WinLibs**での動作確認済み

### sccacheサポート

`sccache`がインストールされている場合、`anyvm RustVm set`で設定される環境変数に、sccache関連の環境変数が自動的に追加されます。

### ビルド設定

本ツールでは、Rustのビルド設定（`.cargo/config`）に以下の設定を行っています：

```toml
[target.x86_64-pc-windows-gnu]
rustflags = [
  "-C", "link-arg=-Wl,--exclude-libs=ALL",
  "-C", "link-arg=-Wl,--exclude-all-symbols", 
  "-C", "link-arg=-Wl,--allow-multiple-definition",
]
```

### Rustのツールチェインについて

Rustのツールチェインは、Rustでクレート（外部パッケージ）をビルドする際に使用されるコンパイラです。

**重要な注意点：**
- Windows環境のRustでは、標準は**Microsoft Visual C++**
- 本ツールではgcc(MinGW)を使用するため、一部のクレートのビルドに失敗する場合があります

### Microsoft Visual C++の使用（推奨）

標準のMicrosoft Visual C++を使用する場合は、以下の手順が必要です。

#### Microsoft C++ Build Toolsのインストール

1. **ダウンロード：** https://aka.ms/vs/17/release/vs_BuildTools.exe
2. **インストール：** Microsoft C++ Build Tools（vs_BuildTools.exe）を実行

#### 必須コンポーネント

以下のコンポーネントをインストールしてください：

```
☑ MSVC v143 - VS 2022 C++ x64/x86 ビルド ツール (最新)
☑ Windows 10 SDK (10.0.19041.0) または最新版
☑ C++ Build Tools コア機能
☑ C++ 2022 最新の可再頒布パッケージの更新プログラム
☑ C++ コア デスクトップ機能
```

#### 推奨する追加コンポーネント

```
☑ C++ CMake tools for Visual Studio
☑ Windows 用 C++ Clang ツール
☑ C++ AddressSanitizer
```

#### コマンドライン インストール

上記コンポーネントは、以下のコマンドでも一括インストール可能です：

```bash
.\vs_BuildTools.exe \
  --add Microsoft.VisualStudio.Workload.VCTools \
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
  --add Microsoft.VisualStudio.Component.Windows10SDK.19041 \
  --add Microsoft.VisualStudio.Component.VC.Redist.14.Latest \
  --add Microsoft.VisualStudio.Component.VC.CMake.Project \
  --add Microsoft.VisualStudio.Component.VC.Llvm.Clang \
  --add Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset \
  --add Microsoft.VisualStudio.Component.VC.ASAN
```

#### MSVCツールチェインの設定

Microsoft Visual C++のコンパイラを使用するには、以下のコマンドを実行します：

```bash
# MSVCツールチェインをインストール
rustup toolchain install stable-msvc

# デフォルトツールチェインをMSVCに変更
rustup default stable-msvc
```

</details>

<details>
<summary>B. 環境変数一覧</summary>

各ツールで設定される主要な環境変数：

| ツール名 | PATH | その他の環境変数 |
|----------|------|------------------|
| PythonVm | `envs\python\current` | - |
| NodejsVm | `envs\nodejs\current` | - |
| GoVm | `envs\go\current\bin` | GOROOT, GOPATH等 |
| RustVm | `envs\rust\.cargo\bin` | CARGO_HOME, RUSTUP_HOME |
| DartVm | `envs\dart\current\bin` | PUB_CACHE |
| JDKVm | `envs\jdk\current\bin` | JAVA_HOME |

</details>

## 🤝 貢献

- 🐛 **バグ報告**: [Issues](https://github.com/kznagamori/anyvm_win/issues)
- 💡 **機能要望**: [Issues](https://github.com/kznagamori/anyvm_win/issues)
- 🔧 **プルリクエスト**: 大歓迎です！

## 📄 ライセンス

[MIT License](LICENSE) - 自由に使用、改変、配布できます。

## 📞 サポート

- **GitHub Issues**: [anyvm_win Issues](https://github.com/kznagamori/anyvm_win/issues)
- **リリースページ**: [Releases](https://github.com/kznagamori/anyvm_win/releases)

---

**anyvm_win** - Windows開発者のためのバージョン管理ツール 🚀
