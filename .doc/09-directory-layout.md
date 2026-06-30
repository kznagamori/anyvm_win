# 09. ディレクトリ構成（リポジトリ／ランタイム）

決定方針「標準レイアウト（cmd/ + pkg/ + internal/ + go:embed）」に基づくリポジトリ構成と、実行時のランタイム構成を定義します。

## 1. リポジトリ構成

```text
github.com/kznagamori/anyvm_win
├── go.mod                      # module github.com/kznagamori/anyvm_win
├── go.sum
├── cmd/
│   └── anyvm/                  # CLI 実行体（package main）
│       ├── main.go
│       └── cli/                # cobra コマンド群（[05]）
│           ├── root.go
│           ├── tool.go         # ツールサブコマンドの動的生成
│           ├── global.go       # init/rehash/update/unset/version/list/setup/migrate
│           ├── logging.go      # slog 初期化（[06]）
│           └── exit.go
├── pkg/
│   └── anyvm/                  # 公開ライブラリ（GUI からも import 可）[07]
│       ├── engine.go
│       ├── types/              # 横断値型 Env/Activation 等（leaf, import 循環回避）[07]
│       ├── manifest.go         # Manifest 型・ローダ・検証
│       ├── registry.go
│       ├── version.go
│       ├── state.go            # active.toml
│       ├── cache.go            # cache/<tool>.toml
│       ├── strategy.go         # Discoverer/Installer/Activator interface
│       ├── errors.go
│       └── strategies/         # ストラテジ実装（[03][04]）
│           ├── git_tags.go
│           ├── github_releases.go
│           ├── html_scrape.go
│           ├── static.go
│           ├── archive_extract.go
│           ├── single_binary.go
│           ├── python_msi.go
│           ├── rustup.go
│           ├── android_sdk.go
│           └── activate.go     # 標準 Activator
├── internal/
│   ├── platform/               # OS 抽象化（windows 実装）[08]
│   │   ├── platform.go
│   │   ├── link_windows.go
│   │   ├── scripts_windows.go
│   │   ├── encoding_windows.go
│   │   └── fake.go             # テスト用
│   ├── download/               # 進捗付き HTTP ダウンロード
│   ├── extract/                # zip（archive/zip）/ 7z（bodgit/sevenzip）
│   ├── scrape/                 # HTML 解析・GitHub API クライアント
│   └── logging/                # ConsoleHandler/Fanout/ProgressBar [06]
├── manifests/                  # 同梱マニフェスト（go:embed 対象）[03][04]
│   ├── manifests.go            # //go:embed *.toml
│   ├── go.toml
│   ├── python.toml
│   ├── ...（17 ツール分）
├── .doc/                       # 本ドキュメント群
├── testdata/                   # テスト用 HTML/JSON/アーカイブ [12]
└── .github/workflows/          # CI（lint/test/release）
```

### go:embed によるマニフェスト同梱

```go
// manifests/manifests.go
package manifests

import "embed"

//go:embed *.toml
var FS embed.FS
```

`pkg/anyvm` のローダはまず `manifests.FS` を読み、続いて `<ANYVM_ROOT>/manifests/*.toml` を読んで**同名上書き**します（[03 §8](03-plugin-manifest-spec.md)）。

## 2. ランタイム構成（クリーン設計）

旧版は `bin/`・`scripts/`・`envs/` がフラットに同居し、状態 JSON が `bin/` に置かれていました。新版は**状態・キャッシュ・ログを `state/`・`logs/` に分離**します。

```text
<ANYVM_ROOT>/                   # 既定: 環境変数 ANYVM_ROOT、無ければ exe の親の親
├── bin/
│   └── anyvm.exe               # 単一実行体（旧 anyvm.bat/.ps1 ラッパーは廃止）
├── manifests/                  # ユーザー追加・上書きマニフェスト（任意）
│   └── *.toml
├── state/
│   ├── active.toml             # 旧 anyvm_win.json（アクティブ版マップ）
│   └── cache/
│       └── <tool>.toml         # 旧 *_vm_version_cache.json（導入可能版）
├── scripts/                    # 生成される activate/deactivate（旧と同役割）
│   ├── AnyVmActivate.{bat,ps1}
│   ├── AnyVmDeactivate.{bat,ps1}
│   └── <tool>{Activate,Deactivate}.{bat,ps1}
├── envs/
│   └── <tool>/
│       ├── <version>/          # インストール実体
│       ├── current             # ジャンクション → <version>
│       └── install-cache/      # ダウンロード一時領域
├── logs/
│   └── anyvm.log               # Error 以上を追記（[06]）
└── tools/
    └── symexe.exe              # Ninja ランチャ（同梱配置）
```

## 3. ANYVM_ROOT の解決順

```text
1. --root フラグ（[05]）
2. 環境変数 ANYVM_ROOT
3. 実行ファイル（anyvm.exe）の親の親  ← 旧版互換のフォールバック
```

```go
func resolveRoot(flag string) string {
	if flag != "" { return flag }
	if v := os.Getenv("ANYVM_ROOT"); v != "" { return v }
	exe, _ := os.Executable()
	return filepath.Dir(filepath.Dir(exe)) // <root>/bin/anyvm.exe → <root>
}
```

> 旧版の「exe 物理位置依存」という脆さを、明示指定（フラグ/環境変数）で回避しつつ、未指定時は従来挙動にフォールバックします。

## 4. パス・テンプレート変数との対応

[03 §2](03-plugin-manifest-spec.md) のテンプレート変数は本構成にマップされます。

| 変数 | 実体 |
|------|------|
| `{{.Root}}` | `<ANYVM_ROOT>` |
| `{{.Env}}` | `<ROOT>/envs/<tool>` |
| `{{.VersionDir}}` | `<ROOT>/envs/<tool>/<version>` |
| `{{.Current}}` | `<ROOT>/envs/<tool>/current` |
| `{{.Cache}}` | `<ROOT>/envs/<tool>/install-cache` |
| `{{.Scripts}}` | `<ROOT>/scripts` |
| `{{.Tools}}` | `<ROOT>/tools` |

## 5. .gitignore（リポジトリ）

ランタイム生成物はリポジトリに含めません。

```text
/scripts/
/envs/
/state/
/logs/
/bin/anyvm.exe
/dist/
```

## 6. ビルドと配布

```text
# ビルド
go build -o dist/bin/anyvm.exe ./cmd/anyvm

# 配布物（旧 Copy-AnyVmStructure.ps1 の役割は CI に移管）
dist/
├── bin/anyvm.exe       # マニフェストは go:embed 同梱のため別ファイル不要
└── tools/symexe.exe
```

- 旧版は 16 個の `*_vm_version_cache.json` を同梱していたが、新版は `anyvm update` で生成するため**同梱不要**（初回 `anyvm update` を促す、または `static` フォールバックを同梱）。
- マニフェストは `go:embed` でバイナリに内蔵されるため、配布は実質 `anyvm.exe` + `tools/` のみ。
