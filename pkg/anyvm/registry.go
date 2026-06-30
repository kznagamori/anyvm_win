package anyvm

import (
	"fmt"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// Registry はマニフェスト集合とストラテジ実装を保持し、type から実装を解決する
// （.doc/02 §4.1, .doc/07 §4）。
type Registry struct {
	manifests   map[string]*types.Manifest // name -> manifest
	aliases     map[string]string          // alias -> name
	order       []string                   // 登録順（安定列挙用）
	discoverers map[string]types.Discoverer
	installers  map[string]types.Installer
	activator   types.Activator
}

// NewRegistry は空の Registry を返す。
func NewRegistry() *Registry {
	return &Registry{
		manifests:   map[string]*types.Manifest{},
		aliases:     map[string]string{},
		discoverers: map[string]types.Discoverer{},
		installers:  map[string]types.Installer{},
	}
}

// AddManifest はマニフェストを登録する。同名は後勝ちで上書きする（ユーザー定義優先）。
func (r *Registry) AddManifest(m *types.Manifest) {
	if _, exists := r.manifests[m.Name]; !exists {
		r.order = append(r.order, m.Name)
	}
	r.manifests[m.Name] = m
	for _, a := range m.Aliases {
		r.aliases[a] = m.Name
	}
}

// RegisterDiscoverer は discover type と実装を登録する。
func (r *Registry) RegisterDiscoverer(typ string, d types.Discoverer) { r.discoverers[typ] = d }

// RegisterInstaller は install type と実装を登録する。
func (r *Registry) RegisterInstaller(typ string, i types.Installer) { r.installers[typ] = i }

// SetActivator は標準 Activator を登録する。
func (r *Registry) SetActivator(a types.Activator) { r.activator = a }

// Manifest は name または alias からマニフェストを解決する。
func (r *Registry) Manifest(name string) (*types.Manifest, bool) {
	if m, ok := r.manifests[name]; ok {
		return m, true
	}
	if canon, ok := r.aliases[name]; ok {
		return r.manifests[canon], true
	}
	return nil, false
}

// Names は登録順のツール名一覧を返す。
func (r *Registry) Names() []string {
	out := make([]string, len(r.order))
	copy(out, r.order)
	return out
}

// Metas は CLI 用の軽量メタ情報一覧を登録順で返す。
func (r *Registry) Metas() []types.ManifestMeta {
	out := make([]types.ManifestMeta, 0, len(r.order))
	for _, n := range r.order {
		out = append(out, r.manifests[n].Meta())
	}
	return out
}

// discoverer は discover type に対応する実装を返す（未登録はエラー）。
func (r *Registry) discoverer(typ string) (types.Discoverer, error) {
	d, ok := r.discoverers[typ]
	if !ok {
		return nil, fmt.Errorf("%w: discover type=%q", ErrStrategyNotFound, typ)
	}
	return d, nil
}

// installer は install type に対応する実装を返す（未登録はエラー）。
func (r *Registry) installer(typ string) (types.Installer, error) {
	i, ok := r.installers[typ]
	if !ok {
		return nil, fmt.Errorf("%w: install type=%q", ErrStrategyNotFound, typ)
	}
	return i, nil
}
