# 12. テスト戦略

副作用を注入する設計（[02](02-target-architecture.md), [07](07-library-api.md), [08](08-os-abstraction.md)）を活かし、**実 Windows・実ネットワークなしで大半をテスト**できるようにします。

## 1. テストの層

```text
┌─ E2E（手動 / 限定 CI）  実機 Windows で go の install→set→version
├─ 統合テスト            Engine + Fake Platform + ローカル HTTP サーバ
├─ 単体テスト            ストラテジ / ローダ / 比較 / スクリプト生成
└─ 静的検査              golangci-lint, go vet, マニフェスト検証
```

## 2. マニフェスト検証テスト（最重要）

同梱マニフェスト（[03](03-plugin-manifest-spec.md), [04](04-tool-migration-catalog.md)）が常に正しいことを保証します。

```go
func TestEmbeddedManifestsValid(t *testing.T) {
	ms, err := anyvm.LoadEmbedded()
	if err != nil { t.Fatal(err) }
	for _, m := range ms {
		// 必須フィールド / type 存在 / 正規表現コンパイル / テンプレート構文
		if err := m.Validate(knownStrategies); err != nil {
			t.Errorf("%s: %v", m.Name, err)
		}
	}
	// 17 ツールが揃っているか
	want := []string{"go","python","nodejs","rust","dart","flutter","jdk",
		"dotnet","cmake","bazel","gradle","mingw","llvm","ninja","kotlin",
		"androidsdk","winlibs"}
	assertAllPresent(t, ms, want)
}
```

## 3. テンプレート展開テスト

URL/file/path/env のテンプレートが期待文字列を生成するか（[03 §2](03-plugin-manifest-spec.md)）。

```go
func TestArtifactURL(t *testing.T) {
	m := loadManifest(t, "go")
	got := renderArtifactURL(m, "1.22.0")
	want := "https://go.dev/dl/go1.22.0.windows-amd64.zip"
	if got != want { t.Errorf("got %q want %q", got, want) }
}

func TestStripComponentTemplate(t *testing.T) {
	// node-v{{.Version}}-win-x64 → node-v20.11.0-win-x64
	// gradle: shortver(8.5.0) → gradle-8.5
}
```

## 4. バージョン比較テスト

```go
func TestCompare(t *testing.T) {
	cases := []struct{ a, b string; want int }{
		{"1.22.0", "1.9.0", 1},        // 数値比較（文字列比較ではない）
		{"11.0.2_7", "11.0.2", 1},     // JDK アンダースコア
		{"1.0.0-rc1", "1.0.0", 0},     // サフィックスは基底比較
		{"19", "9", 1},                // AndroidSDK 整数
	}
	for _, c := range cases { /* ... */ }
}
```

## 5. スクリプト生成のゴールデンテスト

`.bat`/`.ps1` 生成（[08 §4](08-os-abstraction.md)）を golden ファイルで固定。旧版のバグ（`_OLD_` typo・特殊変数名のクォート）が再発しないことを保証。

```go
func TestActivateScriptGolden(t *testing.T) {
	env := testEnv()
	act := buildActivation(loadManifest(t, "go"), "1.22.0", env)
	got := renderTemplate(activateBatTmpl, scriptDataFrom(act, "go"))
	golden.Assert(t, got, "go_activate.bat.golden") // -update で再生成
}

func TestDotnetSpecialEnvNameQuoting(t *testing.T) {
	// DOTNET_ROOT(x86) が .ps1 で ${env:DOTNET_ROOT(x86)} に、
	// .bat で SET "DOTNET_ROOT(x86)=..." になること
}
```

## 6. ストラテジ単体テスト（Fake 注入）

### discover（ローカル fixture）
```go
func TestGitTagsDiscover(t *testing.T) {
	srv := httptest.NewServer(serveFile("testdata/golang_tags.json"))
	defer srv.Close()
	d := strategies.GitTags{}
	vs, err := d.Discover(ctx, manifestWithSource(srv.URL), depsWithHTTP(srv.Client()))
	// strip_prefix=go, min_version=1.13.0, include 正規表現の適用を検証
}
```
`testdata/` に GitHub API のタグ JSON・python.org の HTML・adoptium releases JSON を保存して再生。

### install（Fake Platform + Fake Extractor）
```go
func TestArchiveExtractInstall(t *testing.T) {
	fp := &platform.Fake{Links: map[string]string{}}
	ex := &extract.Fake{Files: zipFixture("go/...")}
	err := strategies.ArchiveExtract{}.Install(ctx, m, ver, env, deps(fp, ex))
	// strip_component の rename、install-cache の後始末を検証
}
```

### activate（Fake Platform）
```go
func TestActivateCreatesJunctionAndScripts(t *testing.T) {
	fp := &platform.Fake{Links: map[string]string{}, Scripts: map[string][]byte{}}
	_ = strategies.StdActivator{}.Activate(ctx, m, "1.22.0", env, deps(fp))
	assertEqual(t, fp.Links[env.Current], filepath.Join(env.EnvDir, "1.22.0"))
	assertContains(t, fp.Scripts[scriptPath(env,"goActivate.bat")], "SET GOROOT=")
}
```

## 7. 統合テスト（Engine 全体）

```go
func TestEngineInstallSetFlow(t *testing.T) {
	srv := fakeArtifactServer(t)            // 版一覧 + zip を配信
	eng := newTestEngine(t, srv, &platform.Fake{...})
	must(eng.Update(ctx, "go"))
	must(eng.Install(ctx, "go", "1.22.0"))
	must(eng.Set(ctx, "go", "1.22.0"))
	v, ok := eng.ActiveVersion("go")
	assert(ok && v == "1.22.0")
}
```

`tmp` ディレクトリを ROOT にし、HTTP はローカル httptest、Platform は Fake で、実ネットワーク・実 Windows API なしに全フローを検証します。

## 8. ロギングのテスト

```go
func TestConsoleHandlerLevels(t *testing.T) {
	var out, errb bytes.Buffer
	h := logging.NewConsoleHandler(&out, &errb, slog.LevelDebug, true)
	l := slog.New(h)
	l.Info(" 1.22.0")                   // out に "1.22.0\n"
	l.Warn("missing")                   // errb に "warning: missing"
	l.Error("boom", "err", errSample)   // errb に "error: boom err=..."
	// 出力先・整形を検証
}
```

## 9. E2E（実機 / 限定 CI）

GitHub Actions の `windows-latest` で、ネットワークに出られる最小ケースを smoke test。

```text
anyvm go update
anyvm go install --latest
anyvm go set -v <latest>
anyvm rehash  # 別シェルで go version を確認
```

レート制限・外部 URL 変動に影響されるため、**必須ではなく日次/手動**トリガとし、失敗してもユニット/統合の緑は別管理。

## 10. URL 健全性チェック（定期）

`update` が生成する URL テンプレートが実在 URL を指すか、CI（日次）で各ツール最新版に対し HTTP `HEAD` を投げて 200 を確認。陳腐化（配布レイアウト変更）を早期検知（[11 リスク](11-roadmap.md)）。

## 11. カバレッジ目標（目安）

| 対象 | 目標 |
|------|------|
| `pkg/anyvm`（ローダ・比較・Engine 分岐） | 80%+ |
| `pkg/anyvm/strategies` | 70%+（外部実行部除く） |
| `internal/platform`（純ロジック・テンプレート） | 80%+（OS API 直叩き除く） |
| マニフェスト検証 | 100%（全同梱マニフェスト） |

## 12. CI パイプライン（概要）

```yaml
# .github/workflows/ci.yml（抜粋）
jobs:
  test:
    strategy:
      matrix: { os: [windows-latest, ubuntu-latest] }
    steps:
      - uses: actions/setup-go@v5
        with: { go-version: '1.22' }
      - run: go vet ./...
      - run: go test ./...           # Fake/httptest 主体で OS 非依存
      - run: golangci-lint run
```

> Windows 固有実装（`*_windows.go`）は `ubuntu` ではビルド対象外（build tag）。ロジックは Fake で OS 非依存にテストするため、Linux CI でも大半が回る。
