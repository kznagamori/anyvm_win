# 11. 移植ロードマップ

段階的に動作する状態を保ちながら移植を進めるためのフェーズ分割です。各フェーズ末に「動くもの」が残る縦切り（vertical slice）を重視します。

## フェーズ 0: 基盤（足場づくり）

| 項目 | 内容 | 参照 |
|------|------|------|
| モジュール初期化 | `go mod init github.com/kznagamori/anyvm_win`、標準レイアウト作成 | [09](09-directory-layout.md) |
| 依存選定 | cobra / BurntSushi/toml or pelletier/go-toml/v2 / x/net/html / bodgit/sevenzip / x/text / x/sync | [01](01-current-architecture.md) |
| ログ基盤 | slog + ConsoleHandler/Fanout/ProgressBar | [06](06-logging.md) |
| Platform 雛形 | インターフェース定義 + Windows スタブ + Fake | [08](08-os-abstraction.md) |
| Go バージョン | 1.22 以上（slog 安定・loopvar） | — |

**完了条件**: `anyvm --version` / `anyvm --help` が動き、slog でログが出る。

## フェーズ 1: ドメイン & マニフェスト

| 項目 | 内容 |
|------|------|
| 型定義 | Manifest / VersionInfo / Env / Version 比較 |
| マニフェストローダ | TOML パース + 検証 + go:embed + 外部上書き |
| Registry | type → ストラテジ解決の骨格 |
| StateStore / CacheStore | active.toml / cache/<tool>.toml の読み書き |

**完了条件**: `anyvm list` が同梱マニフェストからツール一覧を表示。マニフェスト検証の単体テストが通る。

## フェーズ 2: 標準ツールの縦切り（go を最初に）

| 項目 | 内容 |
|------|------|
| discover | `git_tags`（GitHub API/スマート HTTP） |
| install | `archive_extract`（zip + リネーム）+ 進捗 DL/解凍 |
| activate | 標準 Activator + スクリプトテンプレート + ジャンクション |
| CLI | ツールサブコマンドの動的生成、install/set/unset/versions/version/update/uninstall |

**完了条件**: `anyvm go update/install/set/versions` が実機 Windows で通る。go の `set`→`rehash` で `go version` が切り替わる。

## フェーズ 3: 標準ツール横展開

`nodejs, dart, flutter, cmake, kotlin, gradle, jdk, dotnet` をマニフェスト追加で対応。

| 留意点 | 対象 |
|--------|------|
| `github_releases` discover | jdk |
| 多数の env / post_download | dotnet（nuget.exe） |
| strip_component テンプレート | nodejs/cmake/jdk/gradle |
| FuncMap（shortver） | gradle |
| PUB_CACHE | dart/flutter |

**完了条件**: 上記 8 + go の計 9 ツールが全ライフサイクルで動作。

## フェーズ 4: 特殊ストラテジ

| ストラテジ | ツール | 留意点 |
|-----------|--------|--------|
| `single_binary` | bazel, ninja | exe 直配置、symexe ラッパー + .ini |
| `7z 展開`（archive=7z） | mingw, llvm, winlibs | bodgit/sevenzip 検証、複雑バージョン解析（初期は static 併用） |
| `python_msi` | python | WiX/dark + msiexec + ensurepip（subprocess 残置） |
| `rustup` | rust | rustup-init + config.toml、単一インストール型分岐、sccache 条件 env |
| `android_sdk` | androidsdk | HTML 動的取得、多段 PATH、JDK 依存の注意喚起 |

**完了条件**: 17 ツール全てが動作。

## フェーズ 5: 全体コマンド & 移行 & セットアップ

| 項目 | 内容 | 参照 |
|------|------|------|
| 全体コマンド | `init` / `rehash` / `update`(並行) / `unset` / `version`（マニフェスト動的列挙） | [05](05-cli-design.md) |
| `migrate` | 旧 JSON → TOML 変換、VM 名写像、エイリアス | [10](10-data-migration.md) |
| `setup` | 起動プロファイル/レジストリ設定（旧 setup_jp.bat 再実装、SJIS 文字化け解消） | [08](08-os-abstraction.md) |
| シェル補完 | cobra の補完生成（任意） | [05](05-cli-design.md) |

**完了条件**: 旧環境から `migrate`→`setup` で移行でき、`anyvm version` が全ツールを表示。

## フェーズ 6: 品質・配布

| 項目 | 内容 | 参照 |
|------|------|------|
| テスト拡充 | ストラテジ単体・スクリプトゴールデン・マニフェスト検証・統合 | [12](12-testing.md) |
| CI | lint(golangci-lint) / test / windows ビルド / リリース | [09](09-directory-layout.md) |
| ドキュメント | README 刷新、`anyvm help` 整備 | — |
| GUI 連携確認 | Engine API で最小 GUI プロトタイプ（任意・スコープ外だが境界検証） | [07](07-library-api.md) |

**完了条件**: タグ付けリリースで `anyvm.exe` を配布。

## 依存関係（フェーズ順序）

```text
0 基盤
└─1 ドメイン/マニフェスト
   └─2 go 縦切り ── 3 標準横展開 ┐
                                  ├─5 全体/移行/setup ── 6 品質/配布
   └────────────── 4 特殊ストラテジ ┘
```

## リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| GitHub API レート制限 | update 失敗 | semaphore 制限・GITHUB_TOKEN・ETag・スマート HTTP フォールバック（[04](04-tool-migration-catalog.md)） |
| pure-Go 7z が対象を展開不可 | mingw/llvm/winlibs 不動作 | 当該のみ `7z.exe` フォールバック許容（折衷） |
| ジャンクションの権限/実装差 | set 失敗 | リパースポイントで非特権生成、Fake でテスト（[08](08-os-abstraction.md)） |
| WinLibs/MinGW の版解析の複雑さ | 版列挙の不正確 | 初期は `static` 同梱、段階的に自動化 |
| 配布 URL の陳腐化 | install 失敗 | テンプレート URL を CI で定期検証（[12](12-testing.md)） |
