package strategies

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// githubAPIBase は GitHub REST API のベース URL（テストで差し替え可能）。
var githubAPIBase = "https://api.github.com"

// GitTags は Git タグからバージョンを列挙する Discoverer（.doc/03 §3, .doc/04 §1）。
//
// 外部 git コマンドには依存せず、GitHub の REST API(/repos/{owner}/{repo}/tags) で
// タグを取得する。strip_prefix の除去・include/exclude 正規表現・min_version で絞り込み、
// artifact テンプレートからダウンロード URL/ファイル名を生成する。
type GitTags struct{}

// ghTag は GitHub Tags API のレスポンス要素（必要な name のみ）。
type ghTag struct {
	Name string `json:"name"`
}

// Discover はタグを取得・整形して導入可能バージョン一覧を返す。
func (GitTags) Discover(ctx context.Context, m *types.Manifest, deps types.Deps) ([]types.VersionInfo, error) {
	if m.Discover.Source == "" {
		return nil, fmt.Errorf("git_tags: discover.source が必要です")
	}
	owner, repo, err := parseGitHubRepo(m.Discover.Source)
	if err != nil {
		return nil, err
	}
	tags, err := fetchTags(ctx, deps, m.Discover.Source, owner, repo)
	if err != nil {
		return nil, err
	}

	// 検証済み正規表現（マニフェストロード時に検証）を用いる。
	var include, exclude *regexp.Regexp
	if m.Discover.Include != "" {
		include = regexp.MustCompile(m.Discover.Include)
	}
	if m.Discover.Exclude != "" {
		exclude = regexp.MustCompile(m.Discover.Exclude)
	}

	seen := map[string]bool{}
	var versions []string
	for _, tag := range tags {
		// タグ接頭辞を除去（例: "go1.22.0" -> "1.22.0", "v20.11.0" -> "20.11.0"）。
		v := strings.TrimPrefix(tag, m.Discover.StripPrefix)
		// 版文字列の置換（JDK の "_" -> "+" など）。
		for from, to := range m.Discover.VersionSubst {
			v = strings.ReplaceAll(v, from, to)
		}
		if include != nil && !include.MatchString(v) {
			continue
		}
		if exclude != nil && exclude.MatchString(v) {
			continue
		}
		if m.Discover.MinVersion != "" && types.CompareVersions(v, m.Discover.MinVersion) < 0 {
			continue
		}
		if seen[v] {
			continue
		}
		seen[v] = true
		versions = append(versions, v)
	}
	// 昇順に並べる（一覧表示・最新版選択の安定化）。
	sort.Slice(versions, func(i, j int) bool {
		return types.CompareVersions(versions[i], versions[j]) < 0
	})

	out := make([]types.VersionInfo, 0, len(versions))
	for _, v := range versions {
		// artifact テンプレートは版のみを参照する想定（Env パスは install 時に用いる）。
		td := types.TemplateData{Version: v, Tool: m.Name}
		url, err := renderTemplate(m.Artifact.URL, td)
		if err != nil {
			return nil, fmt.Errorf("artifact.url テンプレート: %w", err)
		}
		file, err := renderTemplate(m.Artifact.File, td)
		if err != nil {
			return nil, fmt.Errorf("artifact.file テンプレート: %w", err)
		}
		out = append(out, types.VersionInfo{Version: v, URL: url, File: file})
	}
	return out, nil
}

// parseGitHubRepo は "https://github.com/<owner>/<repo>" から owner と repo を取り出す。
func parseGitHubRepo(src string) (owner, repo string, err error) {
	s := strings.TrimSuffix(src, "/")
	s = strings.TrimSuffix(s, ".git")
	idx := strings.Index(s, "github.com/")
	if idx < 0 {
		return "", "", fmt.Errorf("git_tags: GitHub リポジトリ URL ではありません: %s", src)
	}
	rest := s[idx+len("github.com/"):]
	parts := strings.Split(rest, "/")
	if len(parts) < 2 || parts[0] == "" || parts[1] == "" {
		return "", "", fmt.Errorf("git_tags: owner/repo を取得できません: %s", src)
	}
	return parts[0], parts[1], nil
}

// errRateLimited は GitHub REST API のレート制限（403/429）を示す番兵エラー。
var errRateLimited = errors.New("github api rate limited")

// fetchTags はタグ名を取得する。まず GitHub REST API を試し、レート制限(403/429)に
// 当たった場合は、レート対象外のスマート HTTP(info/refs) へフォールバックする
// （.doc/03 §3, .doc/04 §1）。
func fetchTags(ctx context.Context, deps types.Deps, source, owner, repo string) ([]string, error) {
	tags, err := fetchTagsREST(ctx, deps, owner, repo)
	if err == nil {
		return tags, nil
	}
	if errors.Is(err, errRateLimited) && source != "" {
		if deps.Logger != nil {
			deps.Logger.Debug("REST がレート制限。スマート HTTP にフォールバックします", "source", source)
		}
		return fetchTagsSmartHTTP(ctx, deps, source)
	}
	return nil, err
}

// fetchTagsREST は Tags API をページングしながら全タグ名を取得する。
// 安全のためページ数に上限を設ける。GitHubToken があれば認証ヘッダを付与する。
func fetchTagsREST(ctx context.Context, deps types.Deps, owner, repo string) ([]string, error) {
	const maxPages = 30
	var all []string
	for page := 1; page <= maxPages; page++ {
		url := fmt.Sprintf("%s/repos/%s/%s/tags?per_page=100&page=%d", githubAPIBase, owner, repo, page)
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("Accept", "application/vnd.github+json")
		if deps.GitHubToken != "" {
			req.Header.Set("Authorization", "Bearer "+deps.GitHubToken)
		}
		resp, err := deps.HTTP.Do(req)
		if err != nil {
			return nil, err
		}
		// 403/429 はレート制限としてフォールバック可能なエラーにする。
		if resp.StatusCode == http.StatusForbidden || resp.StatusCode == http.StatusTooManyRequests {
			resp.Body.Close()
			return nil, fmt.Errorf("GitHub API %s: HTTP %d: %w", url, resp.StatusCode, errRateLimited)
		}
		if resp.StatusCode != http.StatusOK {
			b, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
			resp.Body.Close()
			return nil, fmt.Errorf("GitHub API %s: HTTP %d: %s", url, resp.StatusCode, strings.TrimSpace(string(b)))
		}
		var tags []ghTag
		if err := json.NewDecoder(resp.Body).Decode(&tags); err != nil {
			resp.Body.Close()
			return nil, err
		}
		resp.Body.Close()
		for _, t := range tags {
			all = append(all, t.Name)
		}
		// 100 件未満なら最終ページ。
		if len(tags) < 100 {
			break
		}
	}
	return all, nil
}

// fetchTagsSmartHTTP は git の スマート HTTP プロトコル(info/refs?service=git-upload-pack)
// で参照広告を取得し、refs/tags のタグ名を抽出する。レート制限の対象外で、未認証でも使える。
func fetchTagsSmartHTTP(ctx context.Context, deps types.Deps, source string) ([]string, error) {
	url := strings.TrimSuffix(source, "/") + "/info/refs?service=git-upload-pack"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	resp, err := deps.HTTP.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("smart HTTP %s: HTTP %d", url, resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	return parsePktLineTags(body), nil
}

// parsePktLineTags は git の pkt-line 形式の参照広告から refs/tags のタグ名を抽出する。
// peeled タグ(^{}) は基底名へ畳み、重複は除去する。
func parsePktLineTags(body []byte) []string {
	const tagPrefix = "refs/tags/"
	seen := map[string]bool{}
	var tags []string
	for i := 0; i+4 <= len(body); {
		// 先頭 4 桁の 16 進数がパケット長（自身の 4 バイトを含む）。
		n, err := strconv.ParseInt(string(body[i:i+4]), 16, 32)
		if err != nil {
			break
		}
		if n == 0 { // flush パケット
			i += 4
			continue
		}
		if int(n) < 4 || i+int(n) > len(body) {
			break
		}
		line := string(body[i+4 : i+int(n)])
		i += int(n)

		idx := strings.Index(line, tagPrefix)
		if idx < 0 {
			continue
		}
		name := line[idx+len(tagPrefix):]
		// 改行・NUL（capabilities 区切り）・空白以降を落とす。
		if p := strings.IndexAny(name, "\n\x00 "); p >= 0 {
			name = name[:p]
		}
		name = strings.TrimSuffix(name, "^{}") // peeled タグを基底名へ
		if name == "" || seen[name] {
			continue
		}
		seen[name] = true
		tags = append(tags, name)
	}
	return tags
}
