package cli

import (
	"context"
	"errors"

	"github.com/kznagamori/anyvm_win/pkg/anyvm"
)

// ExitCode はエラー種別をプロセス終了コードへ写像する（.doc/05 §6）。
func ExitCode(err error) int {
	switch {
	case err == nil:
		return 0
	case errors.Is(err, anyvm.ErrAlreadyInstalled):
		// 既に導入済みは冪等成功として扱う。
		return 0
	case errors.Is(err, anyvm.ErrVersionNotFound), errors.Is(err, anyvm.ErrToolNotFound):
		return 2
	case errors.Is(err, context.Canceled):
		return 130 // Ctrl+C
	default:
		return 1
	}
}
