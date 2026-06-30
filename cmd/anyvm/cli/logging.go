package cli

import (
	"log/slog"
	"os"

	"github.com/kznagamori/anyvm_win/internal/logging"
)

// setupLogging は slog のデフォルトロガーを構築する（.doc/06）。
//
//   - verbose=true で最小レベルを Debug にする（既定は Info）。
//   - format="json" のときは JSON ハンドラ、それ以外は人間向け ConsoleHandler。
//   - Error 以上は file にも追記する。
//
// 戻り値は ConsoleHandler と writer/mutex を共有するプログレスバー（JSON 時は nil）。
func setupLogging(verbose bool, format, file string) *logging.ProgressBar {
	level := slog.LevelInfo
	if verbose {
		level = slog.LevelDebug
	}

	var console slog.Handler
	var pbar *logging.ProgressBar
	if format == "json" {
		console = slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: level})
	} else {
		ch := logging.NewConsoleHandler(os.Stdout, os.Stderr, level)
		// 進捗バーはコンソールと同じ writer/mutex を共有し、ログ行との混線を防ぐ。
		pbar = logging.NewProgressBar(ch.Mutex(), os.Stderr)
		console = ch
	}

	handlers := []slog.Handler{console}
	if fh := logging.NewFileHandler(file, slog.LevelError); fh != nil {
		handlers = append(handlers, fh)
	}
	slog.SetDefault(slog.New(logging.NewFanout(handlers...)))
	return pbar
}
