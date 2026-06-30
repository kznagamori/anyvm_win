package anyvm

import "github.com/kznagamori/anyvm_win/pkg/anyvm/types"

// 番兵エラーの再公開（実体は types）。CLI は errors.Is で識別して終了コードへ写像する。
var (
	ErrToolNotFound     = types.ErrToolNotFound
	ErrVersionNotFound  = types.ErrVersionNotFound
	ErrAlreadyInstalled = types.ErrAlreadyInstalled
	ErrNotInstalled     = types.ErrNotInstalled
	ErrManifestInvalid  = types.ErrManifestInvalid
	ErrStrategyNotFound = types.ErrStrategyNotFound
)
