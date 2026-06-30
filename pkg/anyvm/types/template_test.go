package types

import "testing"

func TestShortVersion(t *testing.T) {
	cases := map[string]string{
		"8.5.0": "8.5",   // 末尾 .0 を除去（gradle）
		"8.0.0": "8.0",   // 1 回だけ除去
		"7.5.1": "7.5.1", // .0 で終わらなければ変化なし
		"8.0":   "8",
		"8.5":   "8.5",
	}
	for in, want := range cases {
		if got := ShortVersion(in); got != want {
			t.Errorf("ShortVersion(%q) = %q, want %q", in, got, want)
		}
	}
}
