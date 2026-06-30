# 10. データ移行ガイド（旧 Dart 版 → 新 Go 版）

決定方針「互換よりクリーン設計を優先」のため、データ形式・コマンド名・ディレクトリ構成を刷新します。本書は既存ユーザーの環境を**無停止に近い形で移行**するための互換性方針と `anyvm migrate` の仕様です。

## 1. 何が変わるか（対応表）

| 項目 | 旧（Dart） | 新（Go） | 移行 |
|------|------------|----------|------|
| アクティブ版 | `bin/anyvm_win.json`（JSON, `{ "GoVm": "1.22.0" }`） | `state/active.toml`（`go = "1.22.0"`） | 自動変換（キー名も小文字化） |
| 導入可能版キャッシュ | `bin/<tool>_vm_version_cache.json`（JSON 配列） | `state/cache/<tool>.toml`（`[[version]]`） | 自動変換 or 再 `update` |
| コマンド名 | `PythonVm`, `GoVm`, `dotnetVm`（不統一 casing） | `python`, `go`, `dotnet`（小文字統一） | エイリアス提供（§4） |
| ラッパー | `bin/anyvm.bat` / `anyvm.ps1` | 不要（CLI 本体に内包） | プロファイル書換（§5） |
| 実行体 | `bin/anyvm_win.exe`（Dart） | `bin/anyvm.exe`（Go） | 差し替え |
| 文字コード | スクリプト SJIS | SJIS 維持（[08]） | 影響なし |
| envs 実体 | `envs/<tool>/<version>` + `current` | **同一**（再利用可能） | そのまま流用 |

> **重要**: `envs/` 配下のインストール済み実体（各バージョンのディレクトリ）は**形式が同じ**ため再ダウンロード不要です。移行は主に「状態ファイル」と「起動プロファイル」の書換です。

## 2. `anyvm migrate` サブコマンド

```text
anyvm migrate [--from <旧 ROOT>] [--dry-run] [--keep-old]
```

| フラグ | 意味 |
|--------|------|
| `--from` | 旧 anyvm_win のルート（省略時は同一 ROOT を自動検出） |
| `--dry-run` | 変換結果を表示のみ（書き込まない） |
| `--keep-old` | 旧 JSON を削除せず残す |

### 処理内容

```text
1. 旧 bin/anyvm_win.json を読み、キー名を VM 名→新ツール名へ写像
   （GoVm→go, PythonVm→python, dotnetVm→dotnet, AndroidSDKVm→androidsdk ...）
   → state/active.toml を生成
2. 旧 bin/*_vm_version_cache.json を各 state/cache/<tool>.toml へ変換
   （または「初回 anyvm update を推奨」する案内のみ）
3. envs/<tool>/current ジャンクションの健全性を検査（壊れていれば set で再生成を促す）
4. anyvm init を実行し、scripts/ を新テンプレートで再生成（[08]）
5. 起動プロファイル（$PROFILE / CmdProfile.bat）の旧記述を検出し、置換案を提示（§5）
```

### VM 名 → 新ツール名 写像表

| 旧 vmName | 新 name | 旧 vmName | 新 name |
|-----------|---------|-----------|---------|
| GoVm | go | MinGWVm | mingw |
| PythonVm | python | LLVMVm | llvm |
| NodejsVm | nodejs | NinjaVm | ninja |
| RustVm | rust | KotlinVm | kotlin |
| DartVm | dart | AndroidSDKVm | androidsdk |
| FlutterVm | flutter | WinLibsVm | winlibs |
| JDKVm | jdk | CMakeVm | cmake |
| dotnetVm | dotnet | BazelVm | bazel |
| GradleVm | gradle | | |

## 3. 変換例

旧 `bin/anyvm_win.json`:
```json
{ "GoVm": "1.22.0", "PythonVm": "3.11.8", "dotnetVm": "8.0.100" }
```
新 `state/active.toml`:
```toml
go = "1.22.0"
python = "3.11.8"
dotnet = "8.0.100"
```

旧 `bin/go_vm_version_cache.json`:
```json
[ { "version": "1.22.0", "url": "https://go.dev/dl/go1.22.0.windows-amd64.zip", "file": "go1.22.0.windows-amd64.zip" } ]
```
新 `state/cache/go.toml`:
```toml
[[version]]
version = "1.22.0"
url = "https://go.dev/dl/go1.22.0.windows-amd64.zip"
file = "go1.22.0.windows-amd64.zip"
```

## 4. コマンド名の後方互換（任意のエイリアス）

クリーン設計で小文字へ統一しますが、移行期の混乱を避けるため**旧 PascalCase をエイリアスとして受理**する選択肢を用意します（既定 ON、`--strict` で無効化可能）。

```go
// 各マニフェスト name に対し、旧 vmName を alias として動的付与
//   go      ← alias: GoVm
//   python  ← alias: PythonVm
//   dotnet  ← alias: dotnetVm
```

これにより `anyvm GoVm versions` のような旧コマンドも当面動作します。ドキュメント・補完は新名を正とします。

## 5. 起動プロファイルの書換

旧プロファイルは次を含みます（`setup_jp.bat` が追記）。

```powershell
$env:Path = "<ROOT>\bin;" + $env:Path
. "<ROOT>\scripts\AnyVmActivate.ps1"
```

新版では実行体名が `anyvm.exe` になり、`rehash` 用の薄い関数を仕込みます（[08 §6](08-os-abstraction.md)）。`anyvm setup` が以下を行います。

```text
1. 旧 anyvm_win.exe への参照を検出
2. PATH 追記行はそのまま流用可（bin/ を指す）
3. AnyVmActivate.ps1 の dot-source は新 scripts/ でも有効（パス同一）
4. rehash 用 anyvm 関数を追記（無ければ）
5. cmd 用 CmdProfile.bat も同様に更新
```

## 6. 移行手順（ユーザー視点）

```text
1. 新 anyvm.exe を bin/ に配置（旧 anyvm_win.exe は残してよい）
2. anyvm migrate --dry-run   # 変換プレビュー
3. anyvm migrate             # state/ 生成・scripts/ 再生成
4. anyvm setup               # 起動プロファイル更新（必要なら）
5. 新シェルを起動し anyvm version で全ツールのアクティブ版を確認
6. 問題なければ旧 anyvm_win.json / *_vm_version_cache.json / anyvm.bat / anyvm.ps1 を削除
```

## 7. ロールバック

- `anyvm migrate` は既定で旧 JSON を**削除しない**（`--keep-old` 不要、削除は手順 6 の手動）。
- 旧 `anyvm_win.exe` とラッパーを残しておけば、いつでも旧運用へ戻せる。
- `envs/` は共通のため、どちらの版からでも同じインストール実体を参照できる。

## 8. 非互換の明示

| 非互換点 | 対応 |
|----------|------|
| 状態ファイルの形式（JSON→TOML） | `migrate` が自動変換 |
| 実行体名（anyvm_win→anyvm） | プロファイル書換（`setup`） |
| ラッパー廃止 | CLI 本体が全体コマンドを内包 |
| `update` の対象 | 全ツールへ拡大（旧欠落の Android/Rust も対象） |

これらは [00 §4.3](00-overview.md) のクリーン設計方針に沿った意図的変更です。
