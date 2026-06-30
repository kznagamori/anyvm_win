# anyvm_win Go 移植ドキュメント

Dart で実装された Windows 用開発ツールバージョン管理システム **anyvm_win** を Go 言語へ移植するための設計ドキュメント群です。

## 移植の基本方針（決定事項）

本ドキュメントは以下の確定方針に基づいて記述されています。

| # | 論点 | 決定 | 詳細 |
|---|------|------|------|
| 1 | 各開発環境の外部化方式 | **ハイブリッド**（宣言的 TOML マニフェスト + Go 側ストラテジ実装） | [03](03-plugin-manifest-spec.md) |
| 2 | OS 対応範囲 | **抽象化し Windows 実装のみ**（platform 層をインターフェース化） | [08](08-os-abstraction.md) |
| 3 | 後方互換性 | **互換よりクリーン設計を優先**（形式・コマンド名を刷新、旧版移行手順を別途提供） | [10](10-data-migration.md) |
| 4 | 設定ファイル形式 | **TOML** | [03](03-plugin-manifest-spec.md) |
| 5 | ログ／コンソール出力 | **slog に集約**（ユーザー向け出力もカスタム `slog.Handler` 経由） | [06](06-logging.md) |
| 6 | リポジトリ／モジュール構成 | **標準レイアウト**（`cmd/` + `pkg/` + `internal/` + `go:embed`） | [09](09-directory-layout.md) |
| 7 | ドキュメント粒度 | **包括的マルチファイル**（実装スケッチ含む） | 本ドキュメント群 |
| 8 | 外部ツール依存 | **可能な限り削減**（git→API、MKLINK→os/syscall、zip→archive/zip、7z→pure-Go 等） | [04](04-tool-migration-catalog.md) |

## ドキュメント一覧

| ファイル | 内容 | 主な読者 |
|----------|------|----------|
| [00-overview.md](00-overview.md) | 移植の目的・スコープ・全体像・決定事項の根拠 | 全員 |
| [01-current-architecture.md](01-current-architecture.md) | 現状（Dart 版）アーキテクチャの分析。19 ツールの組み込みコードのカタログ | 全員 |
| [02-target-architecture.md](02-target-architecture.md) | 目標アーキテクチャ。lib / CLI / GUI の 3 層構造とハイブリッドプラグイン機構 | 設計者 |
| [03-plugin-manifest-spec.md](03-plugin-manifest-spec.md) | プラグイン／TOML マニフェストの完全仕様。ストラテジ type と go:embed 上書き | 実装者・プラグイン作者 |
| [04-tool-migration-catalog.md](04-tool-migration-catalog.md) | 19 ツールをマニフェスト + ストラテジへマッピングした移植カタログ | 実装者 |
| [05-cli-design.md](05-cli-design.md) | cobra による CLI 設計。コマンド木・フラグ・動的サブコマンド生成 | 実装者 |
| [06-logging.md](06-logging.md) | slog によるログ設計。カスタム Handler・レベル・ファイル出力・進捗表示 | 実装者 |
| [07-library-api.md](07-library-api.md) | `pkg/anyvm` 公開 API 設計。インターフェース・型・コアフロー | 実装者・GUI 開発者 |
| [08-os-abstraction.md](08-os-abstraction.md) | OS 抽象化層。リンク生成・スクリプト生成・文字エンコーディング | 実装者 |
| [09-directory-layout.md](09-directory-layout.md) | リポジトリ構成と実行時ランタイム構成、設定／データ配置 | 実装者 |
| [10-data-migration.md](10-data-migration.md) | 旧 Dart 版 → 新 Go 版のデータ移行ガイドと互換性方針 | 運用者・実装者 |
| [11-roadmap.md](11-roadmap.md) | 移植ロードマップ。フェーズ分割とマイルストーン | プロジェクト管理者 |
| [12-testing.md](12-testing.md) | テスト戦略。ユニット／統合／モック／マニフェスト検証 | 実装者 |

## 読む順序

- **全体像をつかみたい** → 00 → 01 → 02
- **プラグイン機構を実装する** → 03 → 04 → 07
- **CLI を実装する** → 05 → 06 → 09
- **既存環境から移行する** → 10

## 用語

| 用語 | 意味 |
|------|------|
| VM | "Version Manager" の略。本ツールが管理する各開発ツール単位（例: GoVm, PythonVm）。移植後は「ツール (tool)」と呼称 |
| マニフェスト (Manifest) | 1 ツールの宣言的定義を記述した TOML ファイル |
| ストラテジ (Strategy) | バージョン検出・インストール・有効化の振る舞いを表す Go 実装。マニフェストの `type` で選択 |
| アクティベート (Activate) | あるバージョンを有効化し、PATH・環境変数を設定するシェルスクリプトを生成すること |
| ジャンクション (Junction) | Windows のディレクトリ実体リンク。`current` → `<version>` に使用 |
