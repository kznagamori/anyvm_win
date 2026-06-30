package anyvm

import (
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"path"
	"regexp"
	"strings"
	"text/template"

	"github.com/pelletier/go-toml/v2"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// LoadManifests は埋め込み FS とユーザーディレクトリ群から TOML マニフェストを読み込み、
// 検証して Registry に登録する（.doc/02 §4.2, .doc/03 §8）。
//
// 読み込み順は「埋め込み(ビルトイン) → 外部(ユーザー定義)」で、同名は後勝ち（ユーザー優先）。
// 検証に失敗したマニフェストは警告ログを出してスキップし、他ツールの動作は継続する。
//
// なお registerBuiltins によるストラテジ登録が完了した Registry を渡すこと
// （検証で type の存在を確認するため）。
func LoadManifests(reg *Registry, embedded fs.FS, extraDirs []string, logger *slog.Logger) error {
	if embedded != nil {
		if err := loadFromFS(reg, embedded, logger); err != nil {
			return fmt.Errorf("埋め込みマニフェストの読み込み: %w", err)
		}
	}
	for _, dir := range extraDirs {
		if dir == "" {
			continue
		}
		// 外部ディレクトリは存在しなくてもよい。
		if _, err := os.Stat(dir); err != nil {
			continue
		}
		if err := loadFromFS(reg, os.DirFS(dir), logger); err != nil {
			warn(logger, "外部マニフェストの読み込みに失敗", "dir", dir, "err", err)
		}
	}
	return nil
}

// loadFromFS は fsys 直下の *.toml をすべて読み込んで登録する。
func loadFromFS(reg *Registry, fsys fs.FS, logger *slog.Logger) error {
	entries, err := fs.ReadDir(fsys, ".")
	if err != nil {
		return err
	}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".toml") {
			continue
		}
		data, err := fs.ReadFile(fsys, path.Join(".", e.Name()))
		if err != nil {
			warn(logger, "マニフェスト読込失敗", "file", e.Name(), "err", err)
			continue
		}
		var m types.Manifest
		if err := toml.Unmarshal(data, &m); err != nil {
			warn(logger, "マニフェスト解析失敗", "file", e.Name(), "err", err)
			continue
		}
		if err := validateManifest(reg, &m); err != nil {
			warn(logger, "マニフェスト検証失敗", "file", e.Name(), "err", err)
			continue
		}
		reg.AddManifest(&m)
	}
	return nil
}

// validateManifest は必須項目・type の存在・正規表現/テンプレート構文を検証する（.doc/03 §9）。
func validateManifest(reg *Registry, m *types.Manifest) error {
	if m.Name == "" {
		return fmt.Errorf("%w: name が空です", ErrManifestInvalid)
	}
	if m.Discover.Type == "" {
		return fmt.Errorf("%w: discover.type が空です", ErrManifestInvalid)
	}
	if m.Install.Type == "" {
		return fmt.Errorf("%w: install.type が空です", ErrManifestInvalid)
	}
	// 登録済みストラテジか確認する（未実装 type のマニフェストはスキップさせる）。
	if _, ok := reg.discoverers[m.Discover.Type]; !ok {
		return fmt.Errorf("%w: 未登録の discover type=%q", ErrManifestInvalid, m.Discover.Type)
	}
	if _, ok := reg.installers[m.Install.Type]; !ok {
		return fmt.Errorf("%w: 未登録の install type=%q", ErrManifestInvalid, m.Install.Type)
	}
	// 正規表現の構文検証。
	for _, re := range []string{m.Discover.Include, m.Discover.Exclude, m.Discover.AssetPattern, m.Discover.HrefRegex, m.Layout.VersionPattern} {
		if re == "" {
			continue
		}
		if _, err := regexp.Compile(re); err != nil {
			return fmt.Errorf("%w: 正規表現 %q: %v", ErrManifestInvalid, re, err)
		}
	}
	// テンプレートの構文検証。
	tpls := append([]string{m.Artifact.URL, m.Artifact.File, m.Install.StripComponent}, m.Activate.Path...)
	for _, tpl := range tpls {
		if tpl == "" {
			continue
		}
		if _, err := template.New("x").Parse(tpl); err != nil {
			return fmt.Errorf("%w: テンプレート %q: %v", ErrManifestInvalid, tpl, err)
		}
	}
	return nil
}

// warn は logger があれば Warn ログを出す簡易ヘルパー。
func warn(logger *slog.Logger, msg string, args ...any) {
	if logger != nil {
		logger.Warn(msg, args...)
	}
}
