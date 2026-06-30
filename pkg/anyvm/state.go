package anyvm

import (
	"os"
	"path/filepath"

	"github.com/pelletier/go-toml/v2"
)

// FileStateStore は「現在アクティブなバージョン」を state/active.toml に保存する
// （旧 anyvm_win.json の後継。.doc/07 §7, .doc/10）。形式は単純な map: `go = "1.22.0"`。
type FileStateStore struct {
	path string
}

// NewFileStateStore は <root>/state/active.toml を扱うストアを返す。
func NewFileStateStore(root string) *FileStateStore {
	return &FileStateStore{path: filepath.Join(root, "state", "active.toml")}
}

// load は active.toml を読み込む。ファイルが無い場合は空マップを返す。
func (s *FileStateStore) load() (map[string]string, error) {
	data, err := os.ReadFile(s.path)
	if err != nil {
		if os.IsNotExist(err) {
			return map[string]string{}, nil
		}
		return nil, err
	}
	m := map[string]string{}
	if err := toml.Unmarshal(data, &m); err != nil {
		return nil, err
	}
	return m, nil
}

// save は active.toml を書き出す。
func (s *FileStateStore) save(m map[string]string) error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o755); err != nil {
		return err
	}
	data, err := toml.Marshal(m)
	if err != nil {
		return err
	}
	return os.WriteFile(s.path, data, 0o644)
}

// Active は tool のアクティブバージョンと、設定されているかを返す。
func (s *FileStateStore) Active(tool string) (string, bool) {
	m, err := s.load()
	if err != nil {
		return "", false
	}
	v, ok := m[tool]
	return v, ok
}

// All はアクティブバージョンのマップ（tool -> version）を返す。
func (s *FileStateStore) All() map[string]string {
	m, _ := s.load()
	return m
}

// SetActive は tool のアクティブバージョンを設定する。
func (s *FileStateStore) SetActive(tool, version string) error {
	m, err := s.load()
	if err != nil {
		return err
	}
	m[tool] = version
	return s.save(m)
}

// ClearActive は tool のアクティブ設定を削除する。
func (s *FileStateStore) ClearActive(tool string) error {
	m, err := s.load()
	if err != nil {
		return err
	}
	delete(m, tool)
	return s.save(m)
}
