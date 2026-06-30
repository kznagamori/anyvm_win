package strategies

import (
	"context"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// Static はマニフェストに直書きした版一覧をそのまま返す Discoverer（.doc/03 §3）。
// API の無いツールや、更新が稀なツール向け。
type Static struct{}

// Discover は manifest.discover.versions のコピーを返す。
func (Static) Discover(_ context.Context, m *types.Manifest, _ types.Deps) ([]types.VersionInfo, error) {
	out := make([]types.VersionInfo, len(m.Discover.Versions))
	copy(out, m.Discover.Versions)
	return out, nil
}

// NoDiscover は列挙を行わない Discoverer（.doc/03 §3）。
// 外部インストーラが版を管理するツール（Rust）や、update コマンドを持たないツール
// （AndroidSDK）に用いる。update は no-op となる。
type NoDiscover struct{}

// Discover は常に空を返す。
func (NoDiscover) Discover(_ context.Context, _ *types.Manifest, _ types.Deps) ([]types.VersionInfo, error) {
	return nil, nil
}
