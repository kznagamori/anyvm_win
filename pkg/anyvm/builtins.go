package anyvm

import "github.com/kznagamori/anyvm_win/pkg/anyvm/strategies"

// registerBuiltins は同梱のストラテジ実装を Registry に登録する。
//
// pkg/anyvm が pkg/anyvm/strategies を import するが、strategies 側は types のみに依存し
// pkg/anyvm を import しないため、import 循環は発生しない（.doc/02 §4.1 の実装上の解決）。
//
// フェーズ2〜4 で全 discover/install ストラテジを登録する。
// discover: git_tags / github_releases / html_scrape / mingw_tags / winlibs_tags / static / none
// install : archive_extract(zip/7z) / single_binary / python_msi / rustup / android_sdk
func registerBuiltins(reg *Registry) {
	reg.RegisterDiscoverer("git_tags", strategies.GitTags{})
	reg.RegisterDiscoverer("github_releases", strategies.GithubReleases{})
	reg.RegisterDiscoverer("html_scrape", strategies.HTMLScrape{})
	reg.RegisterDiscoverer("mingw_tags", strategies.MingwTags{})
	reg.RegisterDiscoverer("winlibs_tags", strategies.WinlibsTags{})
	reg.RegisterDiscoverer("static", strategies.Static{})
	reg.RegisterDiscoverer("none", strategies.NoDiscover{})

	reg.RegisterInstaller("archive_extract", strategies.ArchiveExtract{})
	reg.RegisterInstaller("single_binary", strategies.SingleBinary{})
	reg.RegisterInstaller("python_msi", strategies.PythonMsi{})
	reg.RegisterInstaller("rustup", strategies.Rustup{})
	reg.RegisterInstaller("android_sdk", strategies.AndroidSDK{})

	reg.SetActivator(strategies.StdActivator{})
}
