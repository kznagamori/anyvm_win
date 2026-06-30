// Package logging は log/slog を中心とした CLI のログ・進捗表示を提供する
// （.doc/06-logging.md）。Info をユーザー向けチャネル、Debug を診断チャネルとし、
// レベルで役割を規約化する。
package logging

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"sync"
)

// ConsoleHandler はレベルに応じて stdout/stderr へ人間向け整形で出力する slog.Handler。
//
//   - Info  : ユーザー向け出力。メッセージのみを stdout に出す（接頭辞なし）。
//   - Warn  : "warning: " を付けて stderr に出す。
//   - Error : "error: " を付け、属性を併記して stderr に出す。
//   - Debug : "DEBUG " を付け、属性を併記して stderr に出す（--verbose 時のみ有効）。
type ConsoleHandler struct {
	mu    *sync.Mutex // 進捗バーと出力先を共有しロックで直列化（.doc/06 §6）
	out   io.Writer   // Info の出力先（stdout）
	err   io.Writer   // Debug/Warn/Error の出力先（stderr）
	level slog.Leveler
	attrs []slog.Attr
}

// NewConsoleHandler は ConsoleHandler を生成する。
func NewConsoleHandler(out, err io.Writer, level slog.Leveler) *ConsoleHandler {
	return &ConsoleHandler{mu: &sync.Mutex{}, out: out, err: err, level: level}
}

// Mutex は進捗バーと共有するためのロックを返す（.doc/06 §6）。
func (h *ConsoleHandler) Mutex() *sync.Mutex { return h.mu }

// Enabled は指定レベルが出力対象かを返す。
func (h *ConsoleHandler) Enabled(_ context.Context, l slog.Level) bool {
	return l >= h.level.Level()
}

// Handle はレコードをレベル別に整形して出力する。
func (h *ConsoleHandler) Handle(_ context.Context, r slog.Record) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	switch {
	case r.Level == slog.LevelInfo:
		// ユーザー向け: メッセージのみ。
		fmt.Fprintln(h.out, r.Message)
	case r.Level == slog.LevelWarn:
		fmt.Fprintln(h.err, "warning: "+r.Message)
	case r.Level >= slog.LevelError:
		fmt.Fprint(h.err, "error: "+r.Message)
		h.writeAttrs(h.err, r)
		fmt.Fprintln(h.err)
	default: // Debug
		fmt.Fprint(h.err, "DEBUG "+r.Message)
		h.writeAttrs(h.err, r)
		fmt.Fprintln(h.err)
	}
	return nil
}

// WithAttrs は属性を引き継いだ新しいハンドラを返す（mutex は共有する）。
func (h *ConsoleHandler) WithAttrs(a []slog.Attr) slog.Handler {
	nh := *h
	nh.attrs = append(append([]slog.Attr{}, h.attrs...), a...)
	return &nh
}

// WithGroup は本ハンドラでは簡略化のため何もしない。
func (h *ConsoleHandler) WithGroup(string) slog.Handler { return h }

// writeAttrs は保持属性とレコード属性を " key=value" 形式で書き出す。
func (h *ConsoleHandler) writeAttrs(w io.Writer, r slog.Record) {
	for _, a := range h.attrs {
		fmt.Fprintf(w, " %s=%v", a.Key, a.Value)
	}
	r.Attrs(func(a slog.Attr) bool {
		fmt.Fprintf(w, " %s=%v", a.Key, a.Value)
		return true
	})
}
