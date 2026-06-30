package types

import "testing"

func TestCompareVersions(t *testing.T) {
	cases := []struct {
		a, b string
		want int
	}{
		{"1.22.0", "1.9.0", 1}, // 数値比較（文字列比較ではない）
		{"1.9.0", "1.22.0", -1},
		{"1.22.0", "1.22.0", 0},
		{"11.0.2_7", "11.0.2", 1}, // JDK のアンダースコア区切り
		{"1.0.0-rc1", "1.0.0", 0}, // サフィックスは基底のみ比較
		{"19", "9", 1},            // AndroidSDK の整数バージョン
		{"1.13.0", "1.13.0", 0},
		{"17.0.9+9", "17.0.1+12", 1}, // JDK の + ビルド: patch が優先
		{"17.0.9+9", "17.0.9+8", 1},  // 同 patch: ビルド番号で比較
		{"17.0.1+12", "17.0.9+9", -1},
	}
	for _, c := range cases {
		if got := CompareVersions(c.a, c.b); got != c.want {
			t.Errorf("CompareVersions(%q, %q) = %d, want %d", c.a, c.b, got, c.want)
		}
	}
}
