// Package extract はアーカイブ展開を提供し、types.Extractor を実装する。
// 現フェーズでは zip（標準ライブラリ archive/zip）に対応する。7z は今後のフェーズで
// pure-Go ライブラリにより対応予定（.doc/04 §1, .doc/11）。
package extract

import (
	"archive/zip"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// Client は zip 展開を実装する Extractor。
type Client struct{}

// New は Client を返す。
func New() *Client { return &Client{} }

// Extract は format に応じてアーカイブを destDir へ展開する。
func (Client) Extract(ctx context.Context, archivePath, destDir, format string, progress types.ProgressFunc) error {
	switch strings.ToLower(format) {
	case "zip":
		return extractZip(ctx, archivePath, destDir, progress)
	case "7z":
		// .doc/11 フェーズ4 で pure-Go 7z(bodgit/sevenzip) により対応予定。
		return fmt.Errorf("7z 展開は未実装です（フェーズ4で対応予定）")
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
		if err := extractZipEntry(zf, dest); err != nil {
			return err
		}
		done++
		if progress != nil {
			progress(done, total)
		}
	}
	return nil
}

// extractZipEntry は zip 内の 1 エントリを安全に展開する（zip slip 対策付き）。
func extractZipEntry(zf *zip.File, dest string) error {
	target := filepath.Join(dest, zf.Name)
	// 展開先が dest 配下に収まることを検証する（ディレクトリトラバーサル防止）。
	cleanDest := filepath.Clean(dest)
	if target != cleanDest && !strings.HasPrefix(target, cleanDest+string(os.PathSeparator)) {
		return fmt.Errorf("不正なパス（zip slip）: %s", zf.Name)
	}

	if zf.FileInfo().IsDir() {
		return os.MkdirAll(target, 0o755)
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	rc, err := zf.Open()
	if err != nil {
		return err
	}
	defer rc.Close()
	out, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, zf.Mode())
	if err != nil {
		return err
	}
	defer out.Close()
	// G110: 展開サイズはダウンロード元(公式配布物)を信頼する前提。必要なら上限を設ける。
	_, err = io.Copy(out, rc)
	return err
}
