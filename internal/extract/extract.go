// Package extract はアーカイブ展開を提供し、types.Extractor を実装する。
// zip（標準ライブラリ archive/zip）と 7z（pure-Go github.com/bodgit/sevenzip）に対応する
// （.doc/04 §1 の「外部 7z.exe を使わず pure-Go で展開」決定）。
package extract

import (
	"archive/zip"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/bodgit/sevenzip"
	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// Client は zip / 7z 展開を実装する Extractor。
type Client struct{}

// New は Client を返す。
func New() *Client { return &Client{} }

// Extract は format に応じてアーカイブを destDir へ展開する。
func (Client) Extract(ctx context.Context, archivePath, destDir, format string, progress types.ProgressFunc) error {
	switch strings.ToLower(format) {
	case "zip":
		return extractZip(ctx, archivePath, destDir, progress)
	case "7z":
		return extractSevenZip(ctx, archivePath, destDir, progress)
	default:
		return fmt.Errorf("未知のアーカイブ形式: %q", format)
	}
}

// extractZip は zip を展開する。展開件数ベースで進捗を通知する。
func extractZip(ctx context.Context, src, dest string, progress types.ProgressFunc) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer r.Close()

	total := int64(len(r.File))
	var done int64
	for _, zf := range r.File {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
		fi := zf.FileInfo()
		if err := extractEntry(dest, zf.Name, fi.IsDir(), fi.Mode(), zf.Open); err != nil {
			return err
		}
		done++
		if progress != nil {
			progress(done, total)
		}
	}
	return nil
}

// extractSevenZip は 7z を展開する（pure-Go bodgit/sevenzip）。展開件数ベースで進捗通知。
func extractSevenZip(ctx context.Context, src, dest string, progress types.ProgressFunc) error {
	r, err := sevenzip.OpenReader(src)
	if err != nil {
		return fmt.Errorf("7z を開けません（%s）: %w", filepath.Base(src), err)
	}
	defer r.Close()

	total := int64(len(r.File))
	var done int64
	for _, f := range r.File {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
		fi := f.FileInfo()
		if err := extractEntry(dest, f.Name, fi.IsDir(), fi.Mode(), f.Open); err != nil {
			return err
		}
		done++
		if progress != nil {
			progress(done, total)
		}
	}
	return nil
}

// extractEntry は zip/7z 共通の 1 エントリ展開（ディレクトリトラバーサル対策付き）。
// open はエントリ内容を読み出すためのオープナ（zip.File.Open / sevenzip.File.Open）。
func extractEntry(dest, name string, isDir bool, mode os.FileMode, open func() (io.ReadCloser, error)) error {
	target := filepath.Join(dest, name)
	// 展開先が dest 配下に収まることを検証する（zip slip / path traversal 防止）。
	cleanDest := filepath.Clean(dest)
	if target != cleanDest && !strings.HasPrefix(target, cleanDest+string(os.PathSeparator)) {
		return fmt.Errorf("不正なパス（path traversal）: %s", name)
	}

	if isDir {
		return os.MkdirAll(target, 0o755)
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	rc, err := open()
	if err != nil {
		return err
	}
	defer rc.Close()

	if mode == 0 {
		mode = 0o644
	}
	out, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
	if err != nil {
		return err
	}
	defer out.Close()
	// G110: 展開サイズはダウンロード元(公式配布物)を信頼する前提。
	_, err = io.Copy(out, rc)
	return err
}
