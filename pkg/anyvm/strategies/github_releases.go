package strategies

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"sort"
	"strings"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// GithubReleases は GitHub Releases のアセットからバージョンを列挙する Discoverer
// （.doc/03 §3, .doc/04 §3。JDK(Adoptium Temurin) 用）。
//
// 複数リポジトリ(sources)の releases を走査し、asset_pattern にマッチするアセット名から
// バージョンを抽出する。version_subst で版文字列を置換し(例 "_"→"+")、ダウンロード URL は
// アセットの browser_download_url を用いる。
type GithubReleases struct{}

// ghRelease / ghAsset は GitHub Releases API のレスポンス（必要な項目のみ）。
type ghRelease struct {
	Assets []ghAsset `json:"assets"`
}

type ghAsset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
}

// Discover は releases を取得・整形して導入可能バージョン一覧を返す。
func (GithubReleases) Discover(ctx context.Context, m *types.Manifest, deps types.Deps) ([]types.VersionInfo, error) {
	if len(m.Discover.Sources) == 0 {
		return nil, fmt.Errorf("github_releases: discover.sources が必要です")
	}
	if m.Discover.AssetPattern == "" {
		return nil, fmt.Errorf("github_releases: asset_pattern が必要です")
	}
	re := regexp.MustCompile(m.Discover.AssetPattern) // ロード時に検証済み

	seen := map[string]bool{}
	var out []types.VersionInfo
	for _, src := range m.Discover.Sources {
		releases, err := fetchReleases(ctx, deps, src)
		if err != nil {
			return nil, err
		}
		for _, rel := range releases {
			for _, a := range rel.Assets {
				sub := re.FindStringSubmatch(a.Name)
				if len(sub) < 2 {
					continue
				}
				ver := sub[1]
				// 版文字列の置換（JDK: "11.0.2_7" -> "11.0.2+7"）。
				for from, to := range m.Discover.VersionSubst {
					ver = strings.ReplaceAll(ver, from, to)
				}
				if m.Discover.MinVersion != "" && types.CompareVersions(ver, m.Discover.MinVersion) < 0 {
					continue
				}
				if seen[ver] {
					continue
				}
				seen[ver] = true
				out = append(out, types.VersionInfo{Version: ver, URL: a.BrowserDownloadURL, File: a.Name})
			}
		}
	}
	sort.Slice(out, func(i, j int) bool {
		return types.CompareVersions(out[i].Version, out[j].Version) < 0
	})
	return out, nil
}

const (
	// releasesPerPage は 1 ページの取得件数。Temurin の各リリースはアセット・メタデータが
	// 大きい(1件あたり ~0.5MB)ため、応答サイズを抑えるべく小さめにする。
	releasesPerPage = 10
	// releasesMaxPages は取得するページ数の上限。全件取得は数百MBに達し非現実的なため、
	// 直近のリリースに限定する（実用上は最新の patch 版が重要。.doc/03 §3 github_releases）。
	releasesMaxPages = 3
	// releasesRetries は大容量応答の途中切断(unexpected EOF)に備えた再試行回数。
	releasesRetries = 3
)

// fetchReleases は owner/repo の releases を「直近 releasesMaxPages ページ」だけ取得する。
func fetchReleases(ctx context.Context, deps types.Deps, ownerRepo string) ([]ghRelease, error) {
	var all []ghRelease
	for page := 1; page <= releasesMaxPages; page++ {
		rels, err := fetchReleasePage(ctx, deps, ownerRepo, page)
		if err != nil {
			return nil, err
		}
		all = append(all, rels...)
		if len(rels) < releasesPerPage {
			break // 最終ページ
		}
	}
	return all, nil
}

// fetchReleasePage は 1 ページを取得する。大容量応答の途中切断等は再試行する。
func fetchReleasePage(ctx context.Context, deps types.Deps, ownerRepo string, page int) ([]ghRelease, error) {
	url := fmt.Sprintf("%s/repos/%s/releases?per_page=%d&page=%d", githubAPIBase, ownerRepo, releasesPerPage, page)
	var lastErr error
	for attempt := 1; attempt <= releasesRetries; attempt++ {
		rels, retryable, err := doFetchReleasePage(ctx, deps, url)
		if err == nil {
			return rels, nil
		}
		if !retryable {
			return nil, err
		}
		lastErr = err
		if deps.Logger != nil {
			deps.Logger.Debug("releases 取得を再試行", "url", url, "attempt", attempt, "err", err)
		}
	}
	return nil, fmt.Errorf("releases 取得失敗(再試行上限) %s: %w", url, lastErr)
}

// doFetchReleasePage は 1 ページを取得して返す。
// retryable=true は一時的な失敗（ネットワーク・途中切断）で、呼び出し側が再試行してよいことを示す。
func doFetchReleasePage(ctx context.Context, deps types.Deps, url string) (rels []ghRelease, retryable bool, err error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, false, err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	if deps.GitHubToken != "" {
		req.Header.Set("Authorization", "Bearer "+deps.GitHubToken)
	}
	resp, err := deps.HTTP.Do(req)
	if err != nil {
		return nil, true, err // ネットワークエラーは再試行可
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, false, fmt.Errorf("GitHub Releases API %s: HTTP %d: %s", url, resp.StatusCode, strings.TrimSpace(string(b)))
	}
	// 一旦全体を読み切ってから unmarshal する（途中切断を ReadAll で検出して再試行できるように）。
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, true, err // unexpected EOF 等は再試行可
	}
	if err := json.Unmarshal(body, &rels); err != nil {
		return nil, true, err // 切断由来の不完全 JSON も再試行可
	}
	return rels, false, nil
}
