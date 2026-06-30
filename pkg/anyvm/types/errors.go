package types

import "errors"

// ライブラリ全体で共有する番兵エラー。
// errors.Is で識別でき、CLI 層で終了コードへ写像する（.doc/05 §6, .doc/07 §9）。
// pkg/anyvm はこれらを変数で再公開する（anyvm.ErrVersionNotFound など）。
var (
	// ErrToolNotFound は指定ツールのマニフェストが見つからない場合。
	ErrToolNotFound = errors.New("tool not found")
	// ErrVersionNotFound は指定バージョンが見つからない場合。
	ErrVersionNotFound = errors.New("version not found")
	// ErrAlreadyInstalled は既に導入済みの場合（冪等成功として扱える）。
	ErrAlreadyInstalled = errors.New("already installed")
	// ErrNotInstalled は未導入の場合。
	ErrNotInstalled = errors.New("not installed")
	// ErrManifestInvalid はマニフェスト検証に失敗した場合。
	ErrManifestInvalid = errors.New("manifest invalid")
	// ErrStrategyNotFound は未登録のストラテジ type が指定された場合。
	ErrStrategyNotFound = errors.New("strategy not registered")
)
