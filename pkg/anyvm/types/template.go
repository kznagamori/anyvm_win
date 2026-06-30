package types

import (
	"strings"
	"text/template"
)

// TemplateFuncs はマニフェストのテンプレート（url/file/path/env/strip_component）で
// 使える補助関数を返す。loader の検証と strategies の展開で同じ関数集合を用いる
// （関数が片方にしか無いと検証は通るのに展開で失敗する、といった不整合を防ぐ）。
func TemplateFuncs() template.FuncMap {
	return template.FuncMap{
		"shortver": ShortVersion,
		"replace":  func(old, new, s string) string { return strings.ReplaceAll(s, old, new) },
	}
}

// ShortVersion は末尾の ".0" を 1 回だけ除去する（gradle 用。.doc/04 §4）。
//
//	8.5.0 -> 8.5 / 8.0.0 -> 8.0 / 7.5.1 -> 7.5.1
//
// 旧 Dart 実装の RegExp(`\.0$`).replaceAll(v, "") と等価。
func ShortVersion(v string) string {
	return strings.TrimSuffix(v, ".0")
}
