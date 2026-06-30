package cli

import (
	"fmt"
	"log/slog"

	"github.com/spf13/cobra"

	"github.com/kznagamori/anyvm_win/pkg/anyvm"
)

// newInitCmd は init コマンド（scripts/ と集約スクリプトを生成）。
func newInitCmd(eng *anyvm.Engine) *cobra.Command {
	return &cobra.Command{
		Use:   "init",
		Short: "インストール・更新時の初期化（スクリプト生成）",
		RunE: func(c *cobra.Command, _ []string) error {
			return eng.Init(c.Context())
		},
	}
}

// newRehashCmd は rehash コマンド（全ツールのスクリプトを最新化）。
func newRehashCmd(eng *anyvm.Engine) *cobra.Command {
	return &cobra.Command{
		Use:   "rehash",
		Short: "開発ツールのスクリプトを更新（set/unset 後に実行）",
		RunE: func(c *cobra.Command, _ []string) error {
			return eng.RehashAll(c.Context())
		},
	}
}

// newUpdateAllCmd は update コマンド（全ツールの版を再取得）。
func newUpdateAllCmd(eng *anyvm.Engine) *cobra.Command {
	return &cobra.Command{
		Use:   "update",
		Short: "すべてのツールのバージョン検索を実行",
		RunE: func(c *cobra.Command, _ []string) error {
			return eng.UpdateAll(c.Context())
		},
	}
}

// newUnsetAllCmd は unset コマンド（全ツールを無効化）。
func newUnsetAllCmd(eng *anyvm.Engine) *cobra.Command {
	return &cobra.Command{
		Use:   "unset",
		Short: "すべての開発ツールを無効化",
		RunE: func(c *cobra.Command, _ []string) error {
			return eng.UnsetAll(c.Context())
		},
	}
}

// newVersionAllCmd は version コマンド（全ツールのアクティブ版を一覧表示）。
func newVersionAllCmd(eng *anyvm.Engine) *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "すべての開発ツールの有効バージョンを表示",
		RunE: func(c *cobra.Command, _ []string) error {
			active := eng.AllActiveVersions()
			for _, m := range eng.Manifests() {
				v := active[m.Name]
				if v == "" {
					v = "(未設定)"
				}
				slog.Info(fmt.Sprintf("%-14s %s", m.Name, v))
			}
			return nil
		},
	}
}

// newListCmd は list コマンド（管理可能なツール一覧を表示）。
func newListCmd(eng *anyvm.Engine) *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "管理可能なツール（マニフェスト）の一覧を表示",
		RunE: func(c *cobra.Command, _ []string) error {
			for _, m := range eng.Manifests() {
				slog.Info(fmt.Sprintf("%-14s %s", m.Name, m.Description))
			}
			return nil
		},
	}
}
