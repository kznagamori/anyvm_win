// Package strategies は、マニフェストの type で選択される discover/install/activate の
// ストラテジ実装を提供する（ハイブリッド方式の「手続き」側。.doc/03, .doc/04, .doc/07）。
//
// 本パッケージはリーフパッケージ pkg/anyvm/types のみに依存し、pkg/anyvm へは依存しない。
// これにより pkg/anyvm 側がビルトインを登録（import strategies）しても import 循環が起きない。
package strategies

import (
	"context"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// httpGetBody は url を GET して本文を返す（html_scrape / android_sdk のページ取得用）。
func httpGetBody(ctx context.Context, deps types.Deps, url string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	resp, err := deps.HTTP.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GET %s: HTTP %d", url, resp.StatusCode)
	}
	return io.ReadAll(resp.Body)
}

// renderTemplate は text/template でテンプレート文字列を展開する。
// 空文字列はそのまま空を返す。未定義フィールド参照は実行時エラーになる。
func renderTemplate(tpl string, data any) (string, error) {
	if tpl == "" {
		return "", nil
	}
	t, err := template.New("t").Funcs(types.TemplateFuncs()).Parse(tpl)
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

// copyFile は src を dst へコピーする（dst の親ディレクトリは作成、実行ビット付与）。
func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o755)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, in)
	return err
}

// findFile は root 配下から basename に一致する最初のファイルのパスを返す（無ければ ""）。
func findFile(root, basename string) (string, error) {
	var found string
	err := filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() && d.Name() == basename {
			found = p
			return fs.SkipAll
		}
		return nil
	})
	return found, err
}

// 各ストラテジがインターフェースを満たすことをコンパイル時に保証する。
var (
	_ types.Discoverer = GitTags{}
	_ types.Discoverer = GithubReleases{}
	_ types.Discoverer = HTMLScrape{}
	_ types.Discoverer = MingwTags{}
	_ types.Discoverer = WinlibsTags{}
	_ types.Discoverer = Static{}
	_ types.Discoverer = NoDiscover{}
	_ types.Installer  = ArchiveExtract{}
	_ types.Installer  = SingleBinary{}
	_ types.Installer  = PythonMsi{}
	_ types.Installer  = Rustup{}
	_ types.Installer  = AndroidSDK{}
	_ types.Activator  = StdActivator{}
)
