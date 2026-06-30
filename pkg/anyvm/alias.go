// Package anyvm は開発ツールのバージョン管理を行う公開ライブラリである。
// CLI(cmd/anyvm) も将来の GUI も本パッケージの Engine を介して同一のユースケースを利用する
// （.doc/02, .doc/07）。
//
// 副作用（HTTP・ファイル・プロセス・OS API）は注入可能なインターフェースとして受け取り、
// すべてのユースケースは context.Context を透過してキャンセルに対応する。
package anyvm

import "github.com/kznagamori/anyvm_win/pkg/anyvm/types"

// 公開 API 用の型エイリアス。実体は import 循環回避のためリーフパッケージ types にある。
// 利用者は anyvm.Env / anyvm.VersionInfo などとして参照できる（.doc/07 §1）。
type (
	Manifest         = types.Manifest
	VersionInfo      = types.VersionInfo
	InstalledVersion = types.InstalledVersion
	ManifestMeta     = types.ManifestMeta
	Env              = types.Env
	EnvVar           = types.EnvVar
	Activation       = types.Activation
	ProgressFunc     = types.ProgressFunc
	Platform         = types.Platform
	Deps             = types.Deps
	Discoverer       = types.Discoverer
	Installer        = types.Installer
	Activator        = types.Activator
)
