package strategies

import (
	"context"
	"sort"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// StdActivator は全ツール共通の標準 Activator（.doc/07 §5）。
// マニフェストの activate 定義からテンプレートを展開し、current ジャンクションの張り替えと
// 有効化/無効化スクリプトの生成を行う。
type StdActivator struct{}

// Activate は version を有効化する。
func (StdActivator) Activate(_ context.Context, m *types.Manifest, version string, env types.Env, deps types.Deps) error {
	// link=junction のツールは current を版ディレクトリへ張り替える。
	if m.Layout.Link == "junction" {
		if deps.Platform.Exists(env.Current) {
			if err := deps.Platform.RemoveLink(env.Current); err != nil {
				return err
			}
		}
		if err := deps.Platform.CreateLink(env.Current, env.VersionDir(version)); err != nil {
			return err
		}
	}
	// PATH・環境変数を計算してスクリプトを生成する。
	act := BuildActivation(m, version, env)
	return deps.Platform.WriteActivationScripts(env, m.Name, act)
}

// Deactivate は無効化する（current を外し、スクリプトを空にする）。
func (StdActivator) Deactivate(_ context.Context, m *types.Manifest, env types.Env, deps types.Deps) error {
	if m.Layout.Link == "junction" && deps.Platform.Exists(env.Current) {
		if err := deps.Platform.RemoveLink(env.Current); err != nil {
			return err
		}
	}
	return deps.Platform.ClearActivationScripts(env, m.Name)
}

// BuildActivation はマニフェストの activate 定義から、テンプレート展開済みの
// PATH と環境変数（Activation）を組み立てる（.doc/03 §7, .doc/07 §5）。
//
// 環境変数はキー名でソートして決定的順序にする（生成スクリプトを安定させ、
// ゴールデンテストを可能にするため。.doc/12）。
func BuildActivation(m *types.Manifest, version string, env types.Env) types.Activation {
	td := env.TemplateData(version)

	// PATH（順序保持）。
	paths := make([]string, 0, len(m.Activate.Path))
	for _, p := range m.Activate.Path {
		if s, err := renderTemplate(p, td); err == nil {
			paths = append(paths, s)
		}
	}

	// 環境変数（マップで合成 → ソートしてスライス化）。
	envmap := make(map[string]string, len(m.Activate.Env))
	for k, v := range m.Activate.Env {
		s, _ := renderTemplate(v, td)
		envmap[k] = s
	}
	// 条件付き環境変数（exists が示すパスが存在する場合のみ適用）。
	for _, ei := range m.Activate.EnvIf {
		cond, _ := renderTemplate(ei.Exists, td)
		if cond != "" && fileExists(cond) {
			for k, v := range ei.Env {
				s, _ := renderTemplate(v, td)
				envmap[k] = s
			}
		}
	}

	keys := make([]string, 0, len(envmap))
	for k := range envmap {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	envvars := make([]types.EnvVar, 0, len(keys))
	for _, k := range keys {
		envvars = append(envvars, types.EnvVar{Key: k, Value: envmap[k]})
	}

	return types.Activation{Path: paths, Env: envvars}
}
