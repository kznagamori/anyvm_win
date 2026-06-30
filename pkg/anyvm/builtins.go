package anyvm

import "github.com/kznagamori/anyvm_win/pkg/anyvm/strategies"

// registerBuiltins は同梱のストラテジ実装を Registry に登録する。
//
// pkg/anyvm が pkg/anyvm/strategies を import するが、strategies 側は types のみに依存し
// pkg/anyvm を import しないため、import 循環は発生しない（.doc/02 §4.1 の実装上の解決）。
//
// 現フェーズ(基盤 + go 縦切り)では git_tags / static / none と archive_extract、
// 標準 Activator を登録する。残りのストラテジ（github_releases / html_scrape /
// single_binary / python_msi / rustup / android_sdk / 7z）は以降のフェーズで追加する。
func registerBuiltins(reg *Registry) {
	reg.RegisterDiscoverer("git_tags", strategies.GitTags{})
	reg.RegisterDiscoverer("static", strategies.Static{})
	reg.RegisterDiscoverer("none", strategies.NoDiscover{})

	reg.RegisterInstaller("archive_extract", strategies.ArchiveExtract{})

	reg.SetActivator(strategies.StdActivator{})
}
