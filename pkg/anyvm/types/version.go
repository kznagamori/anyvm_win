package types

import (
	"strconv"
	"strings"
)

// CompareVersions は 2 つのバージョン文字列を数値的に比較する。
//
//	a <  b => -1
//	a == b =>  0
//	a >  b => +1
//
// サフィックス（"-rc1" 等）は基底のみで比較し、区切りは '.' と '_' の両方を許容する。
// これにより "1.22.0"・"11.0.2_7"（JDK）・"19"（AndroidSDK 整数）などを一貫して扱える
// （.doc/07 §8）。数値に解釈できない要素は 0 とみなす。
func CompareVersions(a, b string) int {
	na, nb := splitVersion(a), splitVersion(b)
	for i := 0; i < len(na) || i < len(nb); i++ {
		var x, y int
		if i < len(na) {
			x = na[i]
		}
		if i < len(nb) {
			y = nb[i]
		}
		if x < y {
			return -1
		}
		if x > y {
			return 1
		}
	}
	return 0
}

// splitVersion は基底部分を数値要素のスライスへ分解する。
func splitVersion(v string) []int {
	// "-" 以降（プレリリースサフィックス）を落とす。
	v = strings.SplitN(v, "-", 2)[0]
	// 区切りは '.'・'_'（JDK の 11.0.2_7）・'+'（JDK の 11.0.2+7 ビルド番号）を許容する。
	parts := strings.FieldsFunc(v, func(r rune) bool { return r == '.' || r == '_' || r == '+' })
	nums := make([]int, 0, len(parts))
	for _, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil {
			n = 0
		}
		nums = append(nums, n)
	}
	return nums
}
