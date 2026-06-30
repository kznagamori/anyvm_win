// Command anyvm は Windows 用の開発ツールバージョン管理 CLI である（.doc/05）。
// 引数解析に cobra、ログ・コンソール出力に log/slog を用い、実処理は pkg/anyvm.Engine へ委譲する。
package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"

	"github.com/kznagamori/anyvm_win/cmd/anyvm/cli"
)

func main() {
	// Ctrl+C で全処理をキャンセルできるようにする。
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	root, err := cli.NewRootCmd()
	if err != nil {
		slog.Error(err.Error())
		os.Exit(cli.ExitCode(err))
	}
	if err := root.ExecuteContext(ctx); err != nil {
		// SilenceErrors=true のため、エラーは自前で slog に集約する（.doc/06）。
		slog.Error(err.Error())
		os.Exit(cli.ExitCode(err))
	}
}
