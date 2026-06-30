//go:build !windows

package platform

import (
	"context"
	"os"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// New は非 Windows 環境向けの暫定 Platform 実装を返す。
//
// 本ツールは Windows 専用だが、lib のクロスビルドおよびテストを可能にするため、
// リンクは os.Symlink、文字コードは UTF-8 恒等で代替する（.doc/08 の抽象化方針）。
func New() types.Platform { return Posix{} }

// Posix は非 Windows 向けの暫定実装。
type Posix struct{}

// EncodeForScript は UTF-8 恒等エンコード（非 Windows では SJIS 変換を行わない）。
func (Posix) EncodeForScript(s string) ([]byte, error) { return []byte(s), nil }

// CreateLink は symlink で代替する（ジャンクション相当）。
func (Posix) CreateLink(link, target string) error { return os.Symlink(target, link) }

// RemoveLink はリンクを外す。
func (Posix) RemoveLink(link string) error { return os.Remove(link) }

// IsLink は path がシンボリックリンクかを返す。
func (Posix) IsLink(path string) (bool, error) {
	fi, err := os.Lstat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}
	return fi.Mode()&os.ModeSymlink != 0, nil
}

// WriteActivationScripts は .bat/.ps1 を UTF-8 で生成する。
func (p Posix) WriteActivationScripts(env types.Env, tool string, act types.Activation) error {
	return writeActivationScripts(env, tool, act, p.EncodeForScript)
}

// ClearActivationScripts は無効化時にスクリプトを空に上書きする。
func (p Posix) ClearActivationScripts(env types.Env, tool string) error {
	return writeFiles(env.Scripts, emptyScripts(tool), p.EncodeForScript)
}

// WriteAggregateScripts は集約スクリプトを生成する。
func (p Posix) WriteAggregateScripts(env types.Env, tools []string) error {
	return writeAggregateScripts(env, tools, p.EncodeForScript)
}

// Run は外部プロセスを実行する。
func (Posix) Run(ctx context.Context, name string, args []string, opt types.RunOpt) (types.RunResult, error) {
	return runProcess(ctx, name, args, opt)
}

// Exists は path の存在を返す。
func (Posix) Exists(path string) bool { return pathExists(path) }
