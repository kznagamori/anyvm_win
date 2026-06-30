package logging

import (
	"log/slog"
	"os"
	"path/filepath"
)

// NewFileHandler は指定パスへ level 以上のログを追記する slog.Handler を返す。
// path が空、またはファイルを開けない場合は nil を返す（呼び出し側でスキップ）。
//
// 注: ファイルハンドルは CLI プロセスの寿命に合わせて開きっぱなしにする
// （短命プロセスのため明示クローズは省略）。
func NewFileHandler(path string, level slog.Level) slog.Handler {
	if path == "" {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return nil
	}
	return slog.NewTextHandler(f, &slog.HandlerOptions{Level: level})
}
