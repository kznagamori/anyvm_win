package logging

import (
	"fmt"
	"io"
	"strings"
	"sync"
)

// ProgressBar は \r で同一行を更新するプログレスバー（.doc/06 §6）。
//
// ConsoleHandler と writer・mutex を共有することで、ログ行と進捗表示の混線を防ぐ。
// 数値進捗は types.ProgressFunc 経由で別系統に流し、メッセージのみ slog に集約する。
type ProgressBar struct {
	mu     *sync.Mutex
	w      io.Writer
	width  int
	active bool
}

// NewProgressBar は ConsoleHandler と共有する mutex と出力先 w でバーを生成する。
func NewProgressBar(mu *sync.Mutex, w io.Writer) *ProgressBar {
	return &ProgressBar{mu: mu, w: w, width: 40}
}

// Update は進捗を描画する。total<=0（総量不明）の場合はダウンロード済み量のみ表示する。
// types.ProgressFunc としてそのまま渡せるシグネチャ。
func (p *ProgressBar) Update(done, total int64) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.active = true
	if total <= 0 {
		fmt.Fprintf(p.w, "\rDownloaded: %.2f MB", float64(done)/1024/1024)
		return
	}
	ratio := float64(done) / float64(total)
	if ratio > 1 {
		ratio = 1
	}
	n := int(ratio * float64(p.width))
	bar := strings.Repeat("=", n) + strings.Repeat(" ", p.width-n)
	fmt.Fprintf(p.w, "\r[%s] %.2f%%", bar, ratio*100)
}

// Done は進捗表示を確定し改行する。
func (p *ProgressBar) Done() {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.active {
		fmt.Fprintln(p.w)
		p.active = false
	}
}
