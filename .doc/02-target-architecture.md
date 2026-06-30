# 02. 目標アーキテクチャ

## 1. 設計原則

1. **lib ファースト** — すべての処理ロジックは `pkg/anyvm`（公開ライブラリ）に置き、CLI は薄いアダプタとする。GUI も同じ lib を利用する。
2. **データと手続きの分離（ハイブリッド）** — ツール差異のうちデータ化できる部分は TOML マニフェストへ、手続きが複雑な部分は Go ストラテジへ。
3. **OS 依存の局所化** — リンク生成・スクリプト生成・文字コード・プロセス起動は `internal/platform` に閉じ込め、インターフェース越しに使う。
4. **副作用の注入** — ファイルシステム・HTTP・時刻・プロセス実行は interface で受け取り、テスト時に差し替え可能にする。
5. **コンテキスト透過** — 長時間処理（DL・解凍・サブプロセス）は `context.Context` を受け取り、キャンセル・タイムアウトに対応（GUI からの中断に必須）。

## 2. レイヤ構造

```text
┌──────────────────────────────────────────────────────────────┐
│ プレゼンテーション層                                          │
│  cmd/anyvm        : cobra コマンド木、フラグ束縛、slog 初期化   │
│  （将来）GUI       : 同じ pkg/anyvm.Engine を呼ぶ              │
└───────────────────────────┬──────────────────────────────────┘
                            │  Engine API（[07]）
┌───────────────────────────▼──────────────────────────────────┐
│ アプリケーション層  pkg/anyvm                                  │
│  Engine            : ユースケース（Install/Set/Update/...）    │
│  Registry          : マニフェスト集合・ストラテジ解決          │
│  StateStore        : active.toml の読み書き                    │
│  CacheStore        : cache/<tool>.toml の読み書き              │
└───────────┬───────────────┬───────────────┬──────────────────┘
            │               │               │
┌───────────▼────┐ ┌────────▼───────┐ ┌─────▼───────────────────┐
│ ドメイン層      │ │ ストラテジ層    │ │ ドメイン層               │
│ Manifest/Version│ │ Discoverer      │ │ Activation（env/PATH 計算）│
│ 値オブジェクト  │ │ Installer       │ │                          │
│                 │ │ Activator       │ │                          │
└─────────────────┘ └────────┬───────┘ └──────────────────────────┘
                            │  低レベル副作用
┌───────────────────────────▼──────────────────────────────────┐
│ インフラ層  internal/                                          │
│  platform : CreateLink / WriteScript / Encode / Exec（windows）│
│  download : 進捗付き HTTP                                       │
│  extract  : zip / 7z（pure-Go）                                │
│  httpapi  : GitHub API / HTML スクレイプ                        │
└──────────────────────────────────────────────────────────────┘
```

## 3. パッケージ構成（概要）

詳細は [09. ディレクトリ構成](09-directory-layout.md)。ここでは責務の対応のみ示します。

```text
github.com/kznagamori/anyvm_win
├── cmd/anyvm/             # CLI 本体（main, cobra コマンド）
├── pkg/anyvm/             # 公開 lib（GUI からも import 可能）
│   ├── engine.go          # Engine: ユースケースの入口
│   ├── manifest.go        # Manifest 型・ローダ
│   ├── version.go         # Version 型・比較
│   ├── state.go           # StateStore（active.toml）
│   ├── cache.go           # CacheStore（cache/<tool>.toml）
│   ├── discover.go        # Discoverer インターフェースとレジストリ
│   ├── install.go         # Installer インターフェースとレジストリ
│   ├── activate.go        # Activator インターフェースとレジストリ
│   └── strategies/        # 各 type の実装（git_tags, archive_extract, rustup, ...）
├── internal/
│   ├── platform/          # OS 抽象化（windows 実装）
│   ├── download/          # 進捗付きダウンロード
│   ├── extract/           # zip / 7z 展開
│   └── scrape/            # HTML スクレイプ・GitHub API クライアント
├── manifests/             # 同梱 TOML（go:embed 対象）
└── .doc/
```

## 4. ハイブリッドプラグイン機構

### 4.1 マニフェスト（データ）+ ストラテジ（手続き）

1 ツール = 1 TOML マニフェスト。マニフェストは「どのストラテジを、どのパラメータで使うか」を宣言します。Engine はマニフェストの `type` を見てレジストリからストラテジ実装を解決し、パラメータを渡して実行します。

```text
manifest (go.toml)                  registry                strategy 実装
─────────────────────               ──────────              ───────────────────
[discover] type="git_tags" ───────► discover["git_tags"] ─► GitTagsDiscoverer
[install]  type="archive_extract" ► install["archive_..."] ► ArchiveExtractInstaller
[activate] (env/path テンプレート) ► （共通 Activator が解釈）
```

- **標準ツール**（Go, Kotlin, CMake など）は既存ストラテジ type の組み合わせ + データだけで表現でき、コード追加は不要。
- **特殊ツール**（Python, Rust, AndroidSDK, Ninja）は専用ストラテジ type を 1 つ実装し、マニフェストからパラメータで駆動。
- **ユーザープラグイン**は、同梱ストラテジ type を使う限り **TOML を 1 枚置くだけ**で新ツールを追加できる。既存ストラテジで表現できない全く新しい手続きが必要な場合のみ、Go 実装の追加（フォーク/ビルド）が必要。

### 4.2 マニフェストの読み込み順（同梱 + 上書き）

```text
1. go:embed の manifests/*.toml を読む（ビルトイン）
2. <ANYVM_ROOT>/manifests/*.toml を読む（ユーザー追加・上書き）
   - 同名 name があれば後勝ちで上書き（ユーザー優先）
3. 検証（必須フィールド・type の存在・テンプレート構文）→ Registry へ
```

これにより「組み込みコードを設定ファイル化する」要求を満たしつつ、無設定でもすぐ動く（ビルトイン同梱）状態を実現します。

## 5. 主要ユースケースのデータフロー

### 5.1 `anyvm <tool> update`（バージョン検出）

```text
CLI → Engine.Update(ctx, tool)
        → Registry.Manifest(tool)
        → discoverer := discoverRegistry[m.Discover.Type]
        → versions := discoverer.Discover(ctx, m)   # API/HTML/git→APIへ削減
        → CacheStore.Save(tool, versions)           # cache/<tool>.toml
        → slog: 「N 件のバージョンを取得」
```

### 5.2 `anyvm <tool> install -v X`（インストール）

```text
CLI → Engine.Install(ctx, tool, X, progress)
        → m := Registry.Manifest(tool)
        → v := CacheStore.Find(tool, X)
        → if envs/<tool>/X 既存 → 「導入済み」で終了
        → installer := installRegistry[m.Install.Type]
        → installer.Install(ctx, m, v, env, progress)
              # download（進捗）→ extract（zip/7z）→ リネーム/配置
        → slog: 「導入完了」
```

### 5.3 `anyvm <tool> set -v X`（有効化）

```text
CLI → Engine.Set(ctx, tool, X)
        → Engine.unset(tool)（既存 current の後始末）
        → platform.CreateLink(envs/<tool>/current, envs/<tool>/X)  # ジャンクション = os/syscall
        → act := Activation.Build(m, X, env)   # env/PATH をテンプレートから計算
        → platform.WriteScript(scripts/<tool>Activate.bat/.ps1, act.Bat/.Ps1)
        → StateStore.SetActive(tool, X)        # active.toml
        → slog: 「X を有効化。anyvm rehash で反映」
```

### 5.4 `anyvm rehash` / `update` / `unset` / `version`（全体コマンド）

旧版はラッパーがツールを列挙していたが、新版は **Registry が保持する全マニフェストを動的に走査**する。取りこぼし（旧 update の AndroidSDK/Rust 欠落）を構造的に防ぐ。

## 6. 並行性・キャンセル

- ダウンロード・解凍・サブプロセスは `context.Context` を受け取り、CLI は `signal.NotifyContext`（Ctrl+C）で、GUI は明示的 cancel でキャンセルできる。
- `update`（全ツール）は `errgroup` で並行化し、`golang.org/x/sync/semaphore` で同時実行数を制限する（GitHub API レートに配慮。[04](04-tool-migration-catalog.md)）。

## 7. エラーハンドリング方針

- ドメインエラーは `errors.Is/As` で識別可能な番兵エラー／型付きエラーにする（例: `ErrVersionNotFound`, `ErrAlreadyInstalled`）。
- ストラテジ実装は `fmt.Errorf("... : %w", err)` でラップし、文脈を積む。
- CLI 層でエラーを slog（Error）に記録し、終了コードへ写像する（[05](05-cli-design.md), [06](06-logging.md)）。

## 8. 次に読む

- マニフェストの厳密なスキーマ → [03. プラグイン／マニフェスト仕様](03-plugin-manifest-spec.md)
- 19 ツールの具体的な落とし込み → [04. ツール移植カタログ](04-tool-migration-catalog.md)
- lib の公開 API → [07. ライブラリ API](07-library-api.md)
