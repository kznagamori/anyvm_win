package strategies

import (
	"context"
	"fmt"
	"regexp"
	"sort"
	"strings"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// MingwTags は niXman/mingw-builds-binaries のタグからバージョンを列挙する Discoverer
// （.doc/04 §5）。タグ(longVersion)を "-" で分割し、先頭が semver のものを採用、
// 残りを versionInfo として 7z アセット URL を組み立てる（git_tags の単純な include では
// 表現できないため専用実装）。version には longVersion（タグ全体）を保存する。
type MingwTags struct{}

var mingwSemver = regexp.MustCompile(`^\d+\.\d+\.\d+$`)

// Discover はタグを取得し、mingw の 7z アセット一覧を返す。
func (MingwTags) Discover(ctx context.Context, m *types.Manifest, deps types.Deps) ([]types.VersionInfo, error) {
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
		long := strings.TrimPrefix(tag, m.Discover.StripPrefix)
		parts := strings.Split(long, "-")
		if len(parts) < 2 {
			continue
		}
		version := parts[0]
		if !mingwSemver.MatchString(version) {
			continue
		}
		if seen[long] {
			continue
		}
		seen[long] = true
		versionInfo := strings.Join(parts[1:], "-")
		file := fmt.Sprintf("x86_64-%s-release-posix-seh-ucrt-%s.7z", version, versionInfo)
		url := fmt.Sprintf("https://github.com/%s/%s/releases/download/%s/%s", owner, repo, long, file)
		out = append(out, types.VersionInfo{Version: long, URL: url, File: file})
	}
	sort.Slice(out, func(i, j int) bool {
		return types.CompareVersions(out[i].Version, out[j].Version) < 0
	})
	return out, nil
}
