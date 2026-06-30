package strategies

import (
	"bytes"
	"context"
	"fmt"
	"regexp"
	"sort"
	"strings"

	"golang.org/x/net/html"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// HTMLScrape は HTML ページの <a> を解析してバージョンを列挙する Discoverer
// （.doc/03 §3。Python）。anchor_text でアンカーを絞り、href_regex の group(1) を版とする。
//
// 注: Dart 原典の href_regex は後方参照(\1)を使うが、Go の RE2 は後方参照非対応のため、
// マニフェスト側は後方参照なしの等価パターンを用いる（version は group(1) で抽出）。
type HTMLScrape struct{}

// Discover はページを取得し、条件に合うアンカーから版一覧を組み立てる。
func (HTMLScrape) Discover(ctx context.Context, m *types.Manifest, deps types.Deps) ([]types.VersionInfo, error) {
	if m.Discover.URL == "" {
		return nil, fmt.Errorf("html_scrape: discover.url が必要です")
	}
	if m.Discover.HrefRegex == "" {
		return nil, fmt.Errorf("html_scrape: discover.href_regex が必要です")
	}
	body, err := httpGetBody(ctx, deps, m.Discover.URL)
	if err != nil {
		return nil, err
	}
	anchors, err := parseAnchors(body)
	if err != nil {
		return nil, err
	}
	re := regexp.MustCompile(m.Discover.HrefRegex) // ロード時に検証済み

	seen := map[string]bool{}
	var out []types.VersionInfo
	for _, a := range anchors {
		if m.Discover.AnchorText != "" && strings.TrimSpace(a.text) != m.Discover.AnchorText {
			continue
		}
		mm := re.FindStringSubmatch(a.href)
		if len(mm) < 2 {
			continue
		}
		ver := mm[1]
		if m.Discover.MinVersion != "" && types.CompareVersions(ver, m.Discover.MinVersion) < 0 {
			continue
		}
		if seen[ver] {
			continue
		}
		// URL/File は [artifact] テンプレートで生成（無ければ href を直接使用）。
		vi, err := artifactOrHref(m, ver, a.href)
		if err != nil {
			return nil, err
		}
		seen[ver] = true
		out = append(out, vi)
	}
	sort.Slice(out, func(i, j int) bool {
		return types.CompareVersions(out[i].Version, out[j].Version) < 0
	})
	return out, nil
}

// artifactOrHref は版から VersionInfo を作る。[artifact] があればそのテンプレート、
// 無ければ href をそのまま URL/File に使う。
func artifactOrHref(m *types.Manifest, version, href string) (types.VersionInfo, error) {
	td := struct{ Version string }{Version: version}
	if m.Artifact.URL != "" {
		url, err := renderTemplate(m.Artifact.URL, td)
		if err != nil {
			return types.VersionInfo{}, err
		}
		file, err := renderTemplate(m.Artifact.File, td)
		if err != nil {
			return types.VersionInfo{}, err
		}
		return types.VersionInfo{Version: version, URL: url, File: file}, nil
	}
	return types.VersionInfo{Version: version, URL: href, File: href[strings.LastIndexByte(href, '/')+1:]}, nil
}

// anchor は <a> のテキストと href。
type anchor struct {
	text string
	href string
}

// parseAnchors は HTML から全 <a>（テキストと href）を抽出する。
func parseAnchors(body []byte) ([]anchor, error) {
	doc, err := html.Parse(bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	var anchors []anchor
	var walk func(*html.Node)
	walk = func(n *html.Node) {
		if n.Type == html.ElementNode && n.Data == "a" {
			href := ""
			for _, attr := range n.Attr {
				if attr.Key == "href" {
					href = attr.Val
					break
				}
			}
			anchors = append(anchors, anchor{text: nodeText(n), href: href})
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(doc)
	return anchors, nil
}

// nodeText は要素配下の全テキストを連結して返す。
func nodeText(n *html.Node) string {
	var sb strings.Builder
	var f func(*html.Node)
	f = func(n *html.Node) {
		if n.Type == html.TextNode {
			sb.WriteString(n.Data)
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			f(c)
		}
	}
	f(n)
	return sb.String()
}
