//go:build windows

package platform

import (
	"context"
	"os"

	"golang.org/x/text/encoding/japanese"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// New は Windows 向けの Platform 実装を返す。
func New() types.Platform { return Windows{} }

// Windows は Windows 用の Platform 実装。
type Windows struct{}

// encode はスクリプトを日本語 Windows コンソールの既定コードページ(CP932)向けに
// Shift_JIS でエンコードする（旧実装の挙動を踏襲。.doc/08 §3）。
func (Windows) encode(s string) ([]byte, error) {
	return japanese.ShiftJIS.NewEncoder().Bytes([]byte(s))
}

// CreateLink は link を target を指すディレクトリジャンクションとして作成する。
func (Windows) CreateLink(link, target string) error { return createJunction(link, target) }

// RemoveLink はジャンクションを外す（リンク先の実体は削除されない）。
func (Windows) RemoveLink(link string) error { return os.Remove(link) }

// IsLink は path が reparse point(ジャンクション/シンボリックリンク)かを返す。
func (Windows) IsLink(path string) (bool, error) {
	fi, err := os.Lstat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}
	return fi.Mode()&os.ModeSymlink != 0, nil
}

// WriteActivationScripts は <tool>Activate/Deactivate の .bat/.ps1 を SJIS で生成する。
func (w Windows) WriteActivationScripts(env types.Env, tool string, act types.Activation) error {
	return writeActivationScripts(env, tool, act, w.encode)
}

// ClearActivationScripts は無効化時にスクリプトを空に上書きする。
func (w Windows) ClearActivationScripts(env types.Env, tool string) error {
	return writeFiles(env.Scripts, emptyScripts(tool), w.encode)
}

// WriteAggregateScripts は集約スクリプト AnyVm{Activate,Deactivate} を生成する。
func (w Windows) WriteAggregateScripts(env types.Env, tools []string) error {
	return writeAggregateScripts(env, tools, w.encode)
}

// Run は外部プロセスを実行する。
func (Windows) Run(ctx context.Context, name string, args []string, opt types.RunOpt) (types.RunResult, error) {
	return runProcess(ctx, name, args, opt)
}

// Exists は path の存在を返す。
func (Windows) Exists(path string) bool { return pathExists(path) }
