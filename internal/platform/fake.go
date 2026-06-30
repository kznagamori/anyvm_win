package platform

import (
	"context"
	"path/filepath"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// Fake はテスト用の Platform 実装。
// 副作用を実ファイルシステム/OS API なしにメモリへ記録し、テストで検証できるようにする
// （.doc/08 §8, .doc/12）。
type Fake struct {
	Links   map[string]string // link -> target
	Scripts map[string][]byte // ファイルパス -> 内容（UTF-8）
	Cleared []string          // ClearActivationScripts で空にされたツール
	Runs    []FakeRun         // Run の呼び出し履歴
	Files   map[string]bool   // Exists が true を返すパス
}

// FakeRun は Run 1 回分の記録。
type FakeRun struct {
	Name string
	Args []string
	Opt  types.RunOpt
}

// NewFake は初期化済みの Fake を返す。
func NewFake() *Fake {
	return &Fake{
		Links:   map[string]string{},
		Scripts: map[string][]byte{},
		Files:   map[string]bool{},
	}
}

// CreateLink は link->target を記録する。
// 実 Platform と同様、作成後はそのリンクパスが Exists で true になるようにする。
func (f *Fake) CreateLink(link, target string) error {
	f.Links[link] = target
	f.Files[link] = true
	return nil
}

// RemoveLink は記録したリンクを削除する（Exists も false に戻す）。
func (f *Fake) RemoveLink(link string) error {
	delete(f.Links, link)
	delete(f.Files, link)
	return nil
}

// IsLink は記録済みリンクかどうかを返す。
func (f *Fake) IsLink(path string) (bool, error) {
	_, ok := f.Links[path]
	return ok, nil
}

// WriteActivationScripts は生成内容をメモリに記録する。
func (f *Fake) WriteActivationScripts(env types.Env, tool string, act types.Activation) error {
	for name, content := range renderActivationFiles(tool, act) {
		f.Scripts[filepath.Join(env.Scripts, name)] = []byte(content)
	}
	return nil
}

// ClearActivationScripts は空スクリプトを記録し、対象ツールを Cleared に積む。
func (f *Fake) ClearActivationScripts(env types.Env, tool string) error {
	for name, content := range emptyScripts(tool) {
		f.Scripts[filepath.Join(env.Scripts, name)] = []byte(content)
	}
	f.Cleared = append(f.Cleared, tool)
	return nil
}

// WriteAggregateScripts は集約スクリプトをメモリに記録する。
func (f *Fake) WriteAggregateScripts(env types.Env, tools []string) error {
	for name, content := range renderAggregateFiles(tools) {
		f.Scripts[filepath.Join(env.Scripts, name)] = []byte(content)
	}
	return nil
}

// Run は呼び出しを記録し、成功(終了コード 0)を返す。
func (f *Fake) Run(ctx context.Context, name string, args []string, opt types.RunOpt) (types.RunResult, error) {
	f.Runs = append(f.Runs, FakeRun{Name: name, Args: args, Opt: opt})
	return types.RunResult{ExitCode: 0}, nil
}

// EncodeForScript は UTF-8 恒等エンコード（テスト用）。
func (f *Fake) EncodeForScript(s string) ([]byte, error) { return []byte(s), nil }

// Exists は Files マップに登録されたパスのみ true を返す。
func (f *Fake) Exists(path string) bool { return f.Files[path] }
