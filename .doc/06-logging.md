# 06. ログ設計（log/slog 集約）

要求仕様「CLI のコンソール出力は log/slog を使用」「ログ機能を追加」を満たし、決定方針「slog に集約」（ユーザー向け出力もカスタム `slog.Handler` 経由）で設計します。

## 1. 方針

- 旧 Dart 版は `logger.i/d/w/e` で**ユーザー向け出力と診断ログを混在**させていた。新版もすべて slog 経由に集約するが、**レベルで役割を規約化**して整理する。
- **Info = ユーザー向けチャネル**（versions 一覧・「導入完了」等）。コンソールには整形なしのメッセージのみを stdout に出す。
- **Debug = 診断チャネル**（パス・コマンド引数・内部状態）。`--verbose` 時のみ、属性・ソース付きで stderr に出す。
- **Warn/Error = 警告・異常**。接頭辞付きで stderr。Error 以上はログファイルにも追記。
- GUI は **`slog.Handler` を差し替える**だけで、全メッセージをレコードとして取得できる。

> 進捗バーのような「行指向でない UI」は slog のレコード整形には乗らないため、**数値進捗は `ProgressFunc` コールバックで別系統**にし、メッセージ（開始・完了）のみ slog に流す（§6 で詳述）。これが「slog 集約」と「実用的な進捗表示」の両立解。

## 2. レベル規約

| slog レベル | 役割 | 既定の出力先 | 整形 | 表示条件 |
|-------------|------|--------------|------|----------|
| `Debug` | 診断（旧 `logger.d`） | stderr | `DEBUG msg key=val source=...` | `--verbose` 時のみ |
| `Info` | ユーザー向け出力（旧 `logger.i`） | stdout | `msg`（接頭辞なし） | 常時 |
| `Warn` | 警告（旧 `logger.w`） | stderr | `warning: msg` | 常時 |
| `Error` | 異常（旧 `logger.e`） | stderr ＋ ファイル | `error: msg key=val` | 常時 |

「ユーザー向けの素の出力」は `slog.Info` に**属性を付けず**メッセージだけを渡す運用とする。診断のための詳細は `slog.Debug` に属性付きで渡す。

```go
// 例: versions 一覧（ユーザー向け）
logger.Info(" 1.21.5")
logger.Info("*1.22.0") // アクティブ版
// 例: 診断
logger.Debug("create junction", "link", link, "target", target)
// 例: 異常
logger.Error("ジャンクション作成に失敗", "err", err, "link", link)
```

## 3. カスタム ConsoleHandler

```go
// internal/logging/console.go
package logging

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"sync"
)

// ConsoleHandler はレベルに応じて stdout/stderr に人間向け整形で出力する。
type ConsoleHandler struct {
	mu      *sync.Mutex // 進捗バーと出力先を共有しロックで直列化（§6）
	out     io.Writer   // stdout（Info）
	err     io.Writer   // stderr（Debug/Warn/Error）
	level   slog.Leveler
	attrs   []slog.Attr
}

func (h *ConsoleHandler) Enabled(_ context.Context, l slog.Level) bool {
	return l >= h.level.Level()
}

func (h *ConsoleHandler) Handle(_ context.Context, r slog.Record) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	switch {
	case r.Level == slog.LevelInfo:
		// ユーザー向け: メッセージのみ
		fmt.Fprintln(h.out, r.Message)
	case r.Level == slog.LevelWarn:
		fmt.Fprintln(h.err, "warning: "+r.Message)
	case r.Level >= slog.LevelError:
		fmt.Fprint(h.err, "error: "+r.Message)
		h.writeAttrs(h.err, r) // err= などを併記
		fmt.Fprintln(h.err)
	default: // Debug
		fmt.Fprint(h.err, "DEBUG "+r.Message)
		h.writeAttrs(h.err, r)
		fmt.Fprintln(h.err)
	}
	return nil
}

func (h *ConsoleHandler) WithAttrs(a []slog.Attr) slog.Handler {
	nh := *h
	nh.attrs = append(append([]slog.Attr{}, h.attrs...), a...)
	return &nh
}
func (h *ConsoleHandler) WithGroup(string) slog.Handler { return h } // 簡略

func (h *ConsoleHandler) writeAttrs(w io.Writer, r slog.Record) {
	for _, a := range h.attrs {
		fmt.Fprintf(w, " %s=%v", a.Key, a.Value)
	}
	r.Attrs(func(a slog.Attr) bool { fmt.Fprintf(w, " %s=%v", a.Key, a.Value); return true })
}
```

## 4. ファイル出力と JSON

- `Error` 以上は常にログファイル（既定 `<ROOT>/logs/anyvm.log`、`--log-file` で変更）へ追記。
- `--log-format json` 指定時はコンソールも `slog.JSONHandler` に切替（自動化・解析向け）。

```go
// internal/logging/fanout.go
// 複数ハンドラへ配る（コンソール + ファイル）。
type FanoutHandler struct{ hs []slog.Handler }

func (f *FanoutHandler) Enabled(ctx context.Context, l slog.Level) bool {
	for _, h := range f.hs { if h.Enabled(ctx, l) { return true } }
	return false
}
func (f *FanoutHandler) Handle(ctx context.Context, r slog.Record) error {
	var first error
	for _, h := range f.hs {
		if h.Enabled(ctx, r.Level) {
			if err := h.Handle(ctx, r.Clone()); err != nil && first == nil { first = err }
		}
	}
	return first
}
func (f *FanoutHandler) WithAttrs(a []slog.Attr) slog.Handler { /* 各 h に伝播 */ return f }
func (f *FanoutHandler) WithGroup(string) slog.Handler        { return f }
```

## 5. CLI からの初期化

```go
// cmd/anyvm/cli/logging.go
func setupLogging(verbose bool, format, file string) {
	level := slog.LevelInfo
	if verbose {
		level = slog.LevelDebug
	}
	var console slog.Handler
	if format == "json" {
		console = slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: level})
	} else {
		console = logging.NewConsoleHandler(os.Stdout, os.Stderr, level)
	}
	handlers := []slog.Handler{console}
	if fileH := logging.NewFileHandler(file, slog.LevelError); fileH != nil {
		handlers = append(handlers, fileH) // Error 以上をファイルへ
	}
	slog.SetDefault(slog.New(logging.NewFanout(handlers...)))
}
```

`slog.SetDefault` により lib 側は `slog.Default()`／パッケージ関数 `slog.Info(...)` を使うだけでよく、lib は出力先を知らない（疎結合）。

## 6. 進捗表示の扱い（slog 集約との両立）

進捗バーは `\r` で同一行を更新するため、行指向の slog レコードには不向きです。次のように分離します。

- **数値進捗**: Engine は `ProgressFunc func(done, total int64)` を受け取り、ダウンロード・解凍で呼ぶ（[07](07-library-api.md)）。
- **CLI**: `ProgressFunc` を ConsoleHandler と**同じ writer・同じ mutex**を使う `ProgressBar` に接続し、ログ行と進捗バーが混線しないようにする。
- **メッセージ**: 「Download ...」「Extraction complete.」等は `slog.Info` で流す（集約を維持）。
- **GUI**: `ProgressFunc` を進捗ウィジェットに接続。メッセージは差し替えた `slog.Handler` で受信。

```go
// internal/logging/progress.go
type ProgressBar struct {
	mu    *sync.Mutex // ConsoleHandler と共有
	w     io.Writer   // stderr
	width int
}
func (p *ProgressBar) Update(done, total int64) {
	p.mu.Lock(); defer p.mu.Unlock()
	// [=====     ] 50.00% を \r で更新
}
func (p *ProgressBar) Done() { /* 改行して確定 */ }
```

> mutex を共有することで、進捗バー更新中にログ行が割り込んで表示が崩れる問題を防ぐ。`--log-format json` や非 TTY 環境では進捗バーを無効化し、節目を `slog.Info` のみで報告する。

## 7. GUI でのハンドラ差し替え

```go
// 将来の GUI 側
type uiHandler struct{ ch chan<- LogEvent }
func (h *uiHandler) Handle(_ context.Context, r slog.Record) error {
	h.ch <- LogEvent{Level: r.Level, Msg: r.Message, Time: r.Time}
	return nil
}
// ...
slog.SetDefault(slog.New(&uiHandler{ch: events}))
// Engine.Install(ctx, tool, ver) のメッセージはすべて events に届く。
// 進捗は engine.SetProgress(func(d, t int64){ widget.Set(d, t) }) で受ける。
```

これにより「slog に集約」しつつ、CLI／GUI それぞれに最適な表示を実現できます。

## 8. ロギング規約（実装ガイド）

| 場面 | 使うレベル | 例 |
|------|-----------|-----|
| 一覧・状態の表示 | `Info`（属性なし） | `slog.Info(" 1.22.0")` |
| 完了・節目の通知 | `Info` | `slog.Info("導入完了")` |
| パス・引数・分岐 | `Debug`（属性あり） | `slog.Debug("run", "exe", exe, "args", args)` |
| 想定内の警告 | `Warn` | `slog.Warn("version does not exist")` |
| 失敗・例外 | `Error`（`err` 属性） | `slog.Error("download 失敗", "err", err, "url", url)` |

- lib 内では `panic` せず error を返す。ログ出力は原則 CLI/Engine 境界で行い、二重ログを避ける（深い階層では `return fmt.Errorf("...: %w", err)`）。
