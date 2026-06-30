// Package download は進捗付きの HTTP ダウンロードを提供し、types.Downloader を実装する。
package download

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// Client は進捗付き HTTP ダウンローダ（types.Downloader 実装）。
type Client struct {
	// HTTP はリクエスト送信に使うクライアント（テスト時に差し替え可能）。
	HTTP types.HTTPDoer
}

// New は Client を返す。h が nil の場合は http.DefaultClient を用いる。
func New(h types.HTTPDoer) *Client {
	if h == nil {
		h = http.DefaultClient
	}
	return &Client{HTTP: h}
}

// Download は url の内容を dest に保存し、進捗を progress で通知する。
// ctx のキャンセルに対応する。
func (c *Client) Download(ctx context.Context, url, dest string, progress types.ProgressFunc) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("ダウンロード失敗 %s: HTTP %d", url, resp.StatusCode)
	}

	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		return err
	}
	f, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer f.Close()

	total := resp.ContentLength // 不明な場合は -1
	var done int64
	buf := make([]byte, 32*1024)
	for {
		// 各チャンクの前に ctx キャンセルを確認する。
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := f.Write(buf[:n]); werr != nil {
				return werr
			}
			done += int64(n)
			if progress != nil {
				progress(done, total)
			}
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			return rerr
		}
	}
	return nil
}
