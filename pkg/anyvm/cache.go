package anyvm

import (
	"os"
	"path/filepath"

	"github.com/pelletier/go-toml/v2"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// FileCacheStore は「導入可能バージョン一覧」を state/cache/<tool>.toml に保存する
// （旧 *_vm_version_cache.json の後継。.doc/07 §7, .doc/10）。
type FileCacheStore struct {
	dir string
}

// cacheDoc は cache/<tool>.toml の TOML 構造（[[version]] 配列）。
type cacheDoc struct {
	Version []types.VersionInfo `toml:"version"`
}

// NewFileCacheStore は <root>/state/cache を扱うストアを返す。
func NewFileCacheStore(root string) *FileCacheStore {
	return &FileCacheStore{dir: filepath.Join(root, "state", "cache")}
}

func (c *FileCacheStore) path(tool string) string {
	return filepath.Join(c.dir, tool+".toml")
}

// Load は tool の導入可能バージョン一覧を返す。ファイルが無ければ nil を返す。
func (c *FileCacheStore) Load(tool string) ([]types.VersionInfo, error) {
	data, err := os.ReadFile(c.path(tool))
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var d cacheDoc
	if err := toml.Unmarshal(data, &d); err != nil {
		return nil, err
	}
	return d.Version, nil
}

// Save は tool の導入可能バージョン一覧を保存する。
func (c *FileCacheStore) Save(tool string, vs []types.VersionInfo) error {
	if err := os.MkdirAll(c.dir, 0o755); err != nil {
		return err
	}
	data, err := toml.Marshal(cacheDoc{Version: vs})
	if err != nil {
		return err
	}
	return os.WriteFile(c.path(tool), data, 0o644)
}

// Find は tool の指定バージョンを探す。
func (c *FileCacheStore) Find(tool, version string) (types.VersionInfo, bool) {
	vs, _ := c.Load(tool)
	for _, v := range vs {
		if v.Version == version {
			return v, true
		}
	}
	return types.VersionInfo{}, false
}

// Latest は tool の最新バージョン（一覧は昇順保存のため末尾）を返す。
func (c *FileCacheStore) Latest(tool string) (types.VersionInfo, bool) {
	vs, _ := c.Load(tool)
	if len(vs) == 0 {
		return types.VersionInfo{}, false
	}
	return vs[len(vs)-1], true
}
