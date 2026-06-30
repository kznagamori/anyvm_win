package strategies

import (
	"context"
	"fmt"
	"regexp"
	"sort"
	"strings"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// WinlibsTags は brechtsanders/winlibs_mingw のタグからバージョンを列挙する Discoverer
// （.doc/04 §5）。posix ビルド & ucrt のみ採用し、版を "gcc-llvm-mingw-revision" 形式へ
// 正規化する。LLVM 無しビルドは llvm を 0.0.0 として扱う。3 パターンの正規表現で解析する
// （Dart 原典の複雑な版解析を忠実移植）。
type WinlibsTags struct{}

var (
	// pattern1（旧, LLVM あり）: gcc-llvm-mingw-(ucrt|msvcrt)-rN
	winlibsP1 = regexp.MustCompile(`^(\d+\.\d+\.\d+)-(\d+\.\d+\.\d+)-(\d+\.\d+\.\d+)-(ucrt|msvcrt)-r(\d+)$`)
	// pattern2（新, LLVM あり）: gcc(threading)-llvm-mingw-(ucrt|msvcrt)-rN
	winlibsP2 = regexp.MustCompile(`^(\d+\.\d+\.\d+)(posix|win32|mcf)-(\d+\.\d+\.\d+)-(\d+\.\d+\.\d+)-(ucrt|msvcrt)-r(\d+)$`)
	// pattern3（新, LLVM なし）: gcc(threading)-mingw-(ucrt|msvcrt)-rN
	winlibsP3 = regexp.MustCompile(`^(\d+\.\d+\.\d+)(posix|win32|mcf)-(\d+\.\d+\.\d+)-(ucrt|msvcrt)-r(\d+)$`)
)

// Discover はタグを取得し、winlibs の 7z アセット一覧を返す。
func (WinlibsTags) Discover(ctx context.Context, m *types.Manifest, deps types.Deps) ([]types.VersionInfo, error) {
	owner, repo, err := parseGitHubRepo(m.Discover.Source)
	if err != nil {
		return nil, err
	}
	tags, err := fetchTags(ctx, deps, m.Discover.Source, owner, repo)
	if err != nil {
		return nil, err
	}

	seen := map[string]bool{}
	var out []types.VersionInfo
	for _, tag := range tags {
		t := strings.TrimPrefix(tag, m.Discover.StripPrefix)
		gcc, llvm, mingw, rev, ok := parseWinlibsTag(t)
		if !ok {
			continue
		}
		version := fmt.Sprintf("%s-%s-%s-%s", gcc, llvm, mingw, rev) // 正規化版
		if seen[version] {
			continue
		}
		seen[version] = true

		var dir, file string
		if llvm == "0.0.0" {
			dir = fmt.Sprintf("%sposix-%s-ucrt-r%s", gcc, mingw, rev)
			file = fmt.Sprintf("winlibs-x86_64-posix-seh-gcc-%s-mingw-w64ucrt-%s-r%s.7z", gcc, mingw, rev)
		} else {
			dir = fmt.Sprintf("%sposix-%s-%s-ucrt-r%s", gcc, llvm, mingw, rev)
			file = fmt.Sprintf("winlibs-x86_64-posix-seh-gcc-%s-llvm-%s-mingw-w64ucrt-%s-r%s.7z", gcc, llvm, mingw, rev)
		}
		url := fmt.Sprintf("https://github.com/%s/%s/releases/download/%s/%s", owner, repo, dir, file)
		out = append(out, types.VersionInfo{Version: version, URL: url, File: file})
	}
	sort.Slice(out, func(i, j int) bool {
		return winlibsCompare(out[i].Version, out[j].Version) < 0
	})
	return out, nil
}

// parseWinlibsTag は 3 パターンで posix&ucrt のみ採用し、(gcc, llvm, mingw, revision) を返す。
// LLVM 無しビルドは llvm="0.0.0"。採用外は ok=false。
func parseWinlibsTag(t string) (gcc, llvm, mingw, rev string, ok bool) {
	// pattern1: 旧形式（threading 指定なし＝posix 既定, LLVM あり）。ucrt のみ。
	if mm := winlibsP1.FindStringSubmatch(t); mm != nil {
		if mm[4] != "ucrt" {
			return "", "", "", "", false
		}
		return mm[1], mm[2], mm[3], mm[5], true
	}
	// pattern2: 新形式（threading 指定, LLVM あり）。posix & ucrt のみ。
	if mm := winlibsP2.FindStringSubmatch(t); mm != nil {
		if mm[2] != "posix" || mm[5] != "ucrt" {
			return "", "", "", "", false
		}
		return mm[1], mm[3], mm[4], mm[6], true
	}
	// pattern3: 新形式（threading 指定, LLVM なし）。posix & ucrt のみ。LLVM=0.0.0。
	if mm := winlibsP3.FindStringSubmatch(t); mm != nil {
		if mm[2] != "posix" || mm[4] != "ucrt" {
			return "", "", "", "", false
		}
		return mm[1], "0.0.0", mm[3], mm[5], true
	}
	return "", "", "", "", false
}

// winlibsCompare は "gcc-llvm-mingw-revision" を各フィールド数値比較で順序づける
// （共有の CompareVersions は "-" 以降を落とすため、winlibs 専用に全フィールドを見る）。
func winlibsCompare(a, b string) int {
	pa := strings.Split(a, "-")
	pb := strings.Split(b, "-")
	n := len(pa)
	if len(pb) < n {
		n = len(pb)
	}
	for i := 0; i < n; i++ {
		if c := types.CompareVersions(pa[i], pb[i]); c != 0 {
			return c
		}
	}
	return len(pa) - len(pb)
}
