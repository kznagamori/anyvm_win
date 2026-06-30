package anyvm

import "github.com/kznagamori/anyvm_win/pkg/anyvm/types"

// Compare は 2 つのバージョン文字列を数値比較する（types.CompareVersions のラッパー）。
//
//	a < b => -1 / a == b => 0 / a > b => +1
func Compare(a, b string) int { return types.CompareVersions(a, b) }
