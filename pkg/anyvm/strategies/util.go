// Package strategies は、マニフェストの type で選択される discover/install/activate の
// ストラテジ実装を提供する（ハイブリッド方式の「手続き」側。.doc/03, .doc/04, .doc/07）。
//
// 本パッケージはリーフパッケージ pkg/anyvm/types のみに依存し、pkg/anyvm へは依存しない。
// これにより pkg/anyvm 側がビルトインを登録（import strategies）しても import 循環が起きない。
package strategies

import (
	"os"
	"strings"
	"text/template"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// renderTemplate は text/template でテンプレート文字列を展開する。
// 空文字列はそのまま空を返す。未定義フィールド参照は実行時エラーになる。
func renderTemplate(tpl string, data any) (string, error) {
	if tpl == "" {
		return "", nil
	}
	t, err := template.New("t").Parse(tpl)
	if err != nil {
		return "", err
	}
	var b strings.Builder
	if err := t.Execute(&b, data); err != nil {
		return "", err
	}
	return b.String(), nil
}

// fileExists は path が存在すれば true を返す。
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// 各ストラテジがインターフェースを満たすことをコンパイル時に保証する。
var (
	_ types.Discoverer = GitTags{}
	_ types.Discoverer = Static{}
	_ types.Discoverer = NoDiscover{}
	_ types.Installer  = ArchiveExtract{}
	_ types.Activator  = StdActivator{}
)
