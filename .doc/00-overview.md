# 00. 概要 — 移植の目的・スコープ・全体像

## 1. 背景

`anyvm_win` は Linux の **anyenv** に着想を得た、Windows 用の開発ツールバージョン管理システムです。Python・Node.js・Go・Rust・Java など 17 種類の開発ツールを、レジストリやシステム全体のインストールを汚さずにインストール・切り替え・アンインストールできます。

現行版は **Dart** で実装され、単一の実行ファイル `anyvm_win.exe`（`dart compile exe` で生成）として配布されています。本プロジェクトは、この実装を **Go 言語** へ移植します。

## 2. 移植の目的（要求仕様）

| 要求 | 内容 | 対応ドキュメント |
|------|------|------------------|
| 言語移行 | Dart → Go | 全体 |
| ライブラリ化 | 処理ロジックを再利用可能な lib として切り出す（将来 GUI から利用） | [02](02-target-architecture.md), [07](07-library-api.md) |
| プラグイン／設定ファイル化 | 各開発環境・言語が「組み込みコード」になっているのを、プラグインまたは設定ファイルに外部化 | [03](03-plugin-manifest-spec.md), [04](04-tool-migration-catalog.md) |
| 引数解析 | **cobra** を使用 | [05](05-cli-design.md) |
| ログ機能 | コンソール出力に **log/slog** を使用し、ログ機能を追加 | [06](06-logging.md) |

## 3. スコープ

### 3.1 対象に含む

- 17 ツール（PythonVm, NodejsVm, GoVm, RustVm, DartVm, FlutterVm, JDKVm, dotnetVm, CMakeVm, BazelVm, GradleVm, MinGWVm, LLVMVm, NinjaVm, KotlinVm, AndroidSDKVm, WinLibsVm）の全機能
- `init` / `rehash` / `update` / `unset` / `version` の全体コマンド
- バージョン検出（update）・インストール・有効化（set/activate）・無効化（unset）・アンインストールの全ライフサイクル
- 再利用可能な lib（`pkg/anyvm`）と、それを利用する CLI（`cmd/anyvm`）
- 各ツールを宣言的に記述する TOML マニフェスト機構と、ユーザーによる追加・上書き（プラグイン）

### 3.2 対象に含まない（本移植では）

- GUI 本体の実装（lib が GUI から利用可能であることのみ保証。[07](07-library-api.md) で API 境界を設計）
- Windows 以外の OS 向けの**実装**（ただし lib の OS 依存部はインターフェースで抽象化し、将来の拡張余地は残す。[08](08-os-abstraction.md)）
- 旧 Dart 版とのデータ／コマンド**完全互換**（クリーン設計を優先。移行は [10](10-data-migration.md) の手順で対応）

## 4. 設計上の重要決定とその根拠

### 4.1 外部化方式 = ハイブリッド

17 ツールはほぼ同型のテンプレート（install/update/versions/version/set/unset/uninstall の 7 サブコマンド）で実装されており、違いは概ね次の 3 点に集約されます。

1. **バージョン検出方法**（HTML スクレイピング／`git ls-remote`／GitHub API／なし）
2. **インストール方法**（zip 展開＋リネーム／単一 exe 配置／7z 展開／専用インストーラ）
3. **設定する環境変数**（PATH 追加先と固有の環境変数）

これらのうち「データで表現できる部分（URL・正規表現・環境変数・バージョン取得方式の種別）」は **TOML マニフェスト**へ、「手続きが複雑な部分（Python の WiX/msiexec、Rust の rustup、AndroidSDK の動的取得など）」は **Go 側のストラテジ実装**へ分離します。マニフェストの `type` フィールドがストラテジを選択します。

> 完全宣言（すべてを TOML 化）では Python/Rust 等の特殊手続きを表現しきれず、完全プラグイン（外部プロセス）では実装量・配布が増大します。ハイブリッドが保守性と表現力の最良バランスです。詳細は [03](03-plugin-manifest-spec.md)。

### 4.2 OS 対応 = 抽象化して Windows 実装のみ

本ツールはジャンクション・`.bat`/`.ps1` 生成・`cmd.exe`・`MKLINK`・SJIS エンコード・レジストリ等、Windows 固有の機構に強く依存します。一方で「lib 化して GUI から再利用」「テスト容易性」を満たすため、OS 依存部分を `Platform` インターフェースに切り出します。実装は当面 Windows のみ提供しますが、リンク生成やスクリプト生成をモック可能にすることで単体テストを容易にします。詳細は [08](08-os-abstraction.md)。

### 4.3 後方互換性 = クリーン設計を優先

旧版は実行ファイルの位置から相対的にディレクトリを決め、`anyvm_win.json` と `*_vm_version_cache.json`（JSON）でデータを保持し、`PythonVm` のような PascalCase（一部 `dotnetVm` と不統一）のコマンド名を採用していました。新版では次のように刷新します。

- データ形式を **TOML** に統一（`active.toml` / `cache/<tool>.toml`）
- コマンド名を CLI 慣例の小文字へ（`anyvm python install ...`）
- ルートディレクトリを環境変数 `ANYVM_ROOT` で明示可能に（exe 位置依存を排除）

旧環境からの移行は `anyvm migrate` サブコマンドおよび手順書（[10](10-data-migration.md)）で支援します。

### 4.4 設定形式 = TOML / ログ = slog 集約 / 構成 = 標準レイアウト / 外部依存 = 削減

- **TOML**: マニフェスト・状態・キャッシュすべてに採用。コメント可・Go 親和性が高い。
- **slog 集約**: ユーザー向け出力（versions 一覧・進捗・確認）も含めカスタム `slog.Handler` で整形。GUI ではハンドラを差し替えてレコードを取得。詳細は [06](06-logging.md)。
- **標準レイアウト**: `cmd/anyvm`（CLI）・`pkg/anyvm`（公開 lib）・`internal/`（共有実装詳細）。マニフェストは `go:embed` で同梱しつつ外部ファイルで上書き可能。
- **外部依存削減**: `git ls-remote` → GitHub/HTTP API、`MKLINK` → `os`/`syscall`、zip → `archive/zip`、7z → pure-Go ライブラリ。本質的に必要なもの（rustup-init、WiX/msiexec、Python 独自インストーラ）のみ subprocess として残す。

## 5. 全体像（ターゲット構成の俯瞰）

```text
                ┌─────────────────────────────────────────────┐
                │            利用者インターフェース             │
                │   cmd/anyvm (CLI, cobra)   │  将来: GUI       │
                └───────────────┬─────────────┴────────┬───────┘
                                │                       │
                                ▼                       ▼
                ┌─────────────────────────────────────────────┐
                │              pkg/anyvm (公開 lib)             │
                │  Engine: Discover / Install / Activate ...    │
                │  Manifest ローダ（go:embed + 外部 TOML 上書き）│
                │  ストラテジ・レジストリ（type → 実装）         │
                └───────┬───────────────┬───────────────┬──────┘
                        │               │               │
              ┌─────────▼──────┐ ┌──────▼───────┐ ┌─────▼────────┐
              │ Discoverer      │ │ Installer    │ │ Activator     │
              │ git_tags/api/.. │ │ archive/7z/. │ │ env+PATH 生成 │
              └────────┬────────┘ └──────┬───────┘ └─────┬────────┘
                       │                 │               │
                       ▼                 ▼               ▼
                ┌─────────────────────────────────────────────┐
                │      internal/platform (OS 抽象化層)          │
                │  CreateLink / Script 生成 / Encoding / Exec   │
                │            └─ windows 実装                     │
                └─────────────────────────────────────────────┘
```

## 6. 次に読む

- 現状の作りを正確に把握する → [01. 現状アーキテクチャ分析](01-current-architecture.md)
- 目標の作りを把握する → [02. 目標アーキテクチャ](02-target-architecture.md)
