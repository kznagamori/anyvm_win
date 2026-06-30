// Package platform は OS 依存処理（リンク生成・スクリプト生成・文字コード・
// プロセス実行）を抽象化し、types.Platform インターフェースを実装する
// （.doc/08-os-abstraction.md）。
//
// 実装は当面 Windows のみを正式サポートするが、lib のクロスビルドと
// テスト容易性のため、非 Windows 向けの暫定実装(Posix)とテスト用の
// Fake も提供する。スクリプト生成など OS 非依存のロジックは
// ビルドタグなしの共有ファイル(scripts.go)に置く。
package platform

import (
	"bytes"
	"context"
	"errors"
	"io"
	"os"
	"os/exec"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// pathExists は path が存在すれば true を返す（OS 非依存）。
func pathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// runProcess は外部プロセスを実行する共有ヘルパー（Windows/Posix 共通）。
//
// プロセスが非ゼロ終了した場合はエラーにせず、RunResult.ExitCode に終了コードを
// 格納して返す（呼び出し側が終了コードで分岐できるようにするため）。
// 実行自体に失敗した場合（実行ファイルが無い等）のみ error を返す。
func runProcess(ctx context.Context, name string, args []string, opt types.RunOpt) (types.RunResult, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	if opt.Dir != "" {
		cmd.Dir = opt.Dir
	}
	if len(opt.Env) > 0 {
		// 既存の環境変数に追加分を上書き結合する。
		env := os.Environ()
		for k, v := range opt.Env {
			env = append(env, k+"="+v)
		}
		cmd.Env = env
	}

	var stdout, stderr bytes.Buffer
	if opt.Stdout != nil {
		cmd.Stdout = io.MultiWriter(opt.Stdout, &stdout)
	} else {
		cmd.Stdout = &stdout
	}
	cmd.Stderr = &stderr

	err := cmd.Run()
	res := types.RunResult{Stdout: stdout.String(), Stderr: stderr.String()}
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			// 非ゼロ終了は結果として表現する。
			res.ExitCode = ee.ExitCode()
			return res, nil
		}
		return res, err
	}
	return res, nil
}
