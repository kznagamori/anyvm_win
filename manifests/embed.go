// Package manifests は同梱(ビルトイン)のツールマニフェスト(*.toml)を go:embed で
// バイナリへ内蔵する（.doc/02 §4.2, .doc/09）。
//
// pkg/anyvm のローダはまず本 FS のマニフェストを読み、続いて
// <ANYVM_ROOT>/manifests/*.toml（ユーザー定義）を読んで同名を上書きする。
package manifests

import "embed"

// FS は同梱マニフェスト群を保持する埋め込みファイルシステム。
//
//go:embed *.toml
var FS embed.FS
