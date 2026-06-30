package logging

import (
	"context"
	"log/slog"
)

// Fanout は複数の slog.Handler へレコードを配るハンドラ（コンソール + ファイル等）。
type Fanout struct {
	handlers []slog.Handler
}

// NewFanout は与えたハンドラ群へ配る Fanout を返す。
func NewFanout(hs ...slog.Handler) *Fanout { return &Fanout{handlers: hs} }

// Enabled はいずれかのハンドラが有効なら true を返す。
func (f *Fanout) Enabled(ctx context.Context, l slog.Level) bool {
	for _, h := range f.handlers {
		if h.Enabled(ctx, l) {
			return true
		}
	}
	return false
}

// Handle は有効な各ハンドラへレコードの複製を渡す。
func (f *Fanout) Handle(ctx context.Context, r slog.Record) error {
	var first error
	for _, h := range f.handlers {
		if h.Enabled(ctx, r.Level) {
			if err := h.Handle(ctx, r.Clone()); err != nil && first == nil {
				first = err
			}
		}
	}
	return first
}

// WithAttrs は各ハンドラへ属性を伝播する。
func (f *Fanout) WithAttrs(a []slog.Attr) slog.Handler {
	nh := make([]slog.Handler, len(f.handlers))
	for i, h := range f.handlers {
		nh[i] = h.WithAttrs(a)
	}
	return &Fanout{handlers: nh}
}

// WithGroup は各ハンドラへグループを伝播する。
func (f *Fanout) WithGroup(name string) slog.Handler {
	nh := make([]slog.Handler, len(f.handlers))
	for i, h := range f.handlers {
		nh[i] = h.WithGroup(name)
	}
	return &Fanout{handlers: nh}
}
