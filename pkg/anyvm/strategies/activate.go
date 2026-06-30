package strategies

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// StdActivator は全ツール共通の標準 Activator（.doc/07 §5）。
// マニフェストの activate 定義からテンプレートを展開し、current ジャンクションの張り替えと
// 有効化/無効化スクリプトの生成を行う。
type StdActivator struct{}

// Activate は version を有効化する。
func (StdActivator) Activate(_ context.Context, m *types.Manifest, version string, env types.Env, deps types.Deps) error {
	switch {
	case m.Layout.Link == "junction":
		// link=junction のツールは current を版ディレクトリへ張り替える。
		if err := removeCurrentLink(env, deps); err != nil {
			return err
		}
		if err := deps.Platform.CreateLink(env.Current, env.VersionDir(version)); err != nil {
			return err
		}
	case m.Install.Wrapper == "symexe":
		// ninja 型（link=none）: current を実ディレクトリにし symexe ラッパー + .ini を配置。
		if err := setupSymexeWrapper(m, version, env, deps); err != nil {
			return err
		}
	}
	// PATH・環境変数を計算してスクリプトを生成する。
	act := BuildActivation(m, version, env)
	return deps.Platform.WriteActivationScripts(env, m.Name, act)
}

// Deactivate は無効化する（current を外し、スクリプトを空にする）。
func (StdActivator) Deactivate(_ context.Context, m *types.Manifest, env types.Env, deps types.Deps) error {
	switch {
	case m.Layout.Link == "junction":
		if err := removeCurrentLink(env, deps); err != nil {
			return err
		}
	case m.Install.Wrapper == "symexe":
		// symexe の current は junction でなく実ディレクトリなので通常削除する。
		_ = os.RemoveAll(env.Current)
	}
	return deps.Platform.ClearActivationScripts(env, m.Name)
}

// setupSymexeWrapper は ninja 型（link=none + wrapper=symexe）の current を組み立てる。
// current を実ディレクトリとして作り、tools/symexe.exe を current/<binary> にコピーし、
// <binary 拡張子抜き>.ini に実体（<version>）へのパスを書く（.doc/04 §6、Dart 原典の ninja.ini）。
func setupSymexeWrapper(m *types.Manifest, version string, env types.Env, deps types.Deps) error {
	binary := m.Install.Binary
	if binary == "" {
		return fmt.Errorf("symexe: install.binary が必要です")
	}
	_ = os.RemoveAll(env.Current)
	if err := os.MkdirAll(env.Current, 0o755); err != nil {
		return err
	}
	symexe := filepath.Join(env.Tools, "symexe.exe")
	if err := copyFile(symexe, filepath.Join(env.Current, binary)); err != nil {
		return fmt.Errorf("symexe.exe の配置に失敗（%s が必要）: %w", symexe, err)
	}
	verDir := env.VersionDir(version)
	iniName := strings.TrimSuffix(binary, filepath.Ext(binary)) + ".ini"
	ini := fmt.Sprintf("[CONFIG]\nOPTS=\nCODEPAGE=65001\n[OPT]\nPATH=%s\n[EXE]\nPATH=%s\n",
		verDir, filepath.Join(verDir, binary))
	enc, err := deps.Platform.EncodeForScript(ini)
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(env.Current, iniName), enc, 0o644)
}

// removeCurrentLink は current が存在する場合に、それがリンクであることを確認してから外す。
// リンクでない実体ディレクトリだった場合は、誤って実体を消さないようエラーにする（堅牢化）。
func removeCurrentLink(env types.Env, deps types.Deps) error {
	if !deps.Platform.Exists(env.Current) {
		return nil
	}
	isLink, err := deps.Platform.IsLink(env.Current)
	if err != nil {
		return err
	}
	if !isLink {
		return fmt.Errorf("%s がリンクではありません（実体ディレクトリ）。手動で確認してください", env.Current)
	}
	return deps.Platform.RemoveLink(env.Current)
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
