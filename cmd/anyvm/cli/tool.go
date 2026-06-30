package cli

import (
	"fmt"
	"log/slog"

	"github.com/spf13/cobra"

	"github.com/kznagamori/anyvm_win/pkg/anyvm"
)

// newToolCmd はマニフェスト 1 件分のサブコマンド木（install/uninstall/set/unset/
// version/versions/update）を生成する（.doc/05 §3）。
func newToolCmd(eng *anyvm.Engine, m anyvm.ManifestMeta) *cobra.Command {
	short := m.Description
	if short == "" {
		short = m.Name + " version manager"
	}
	tc := &cobra.Command{
		Use:     m.Name,
		Short:   short,
		Aliases: m.Aliases,
		RunE:    func(c *cobra.Command, _ []string) error { return c.Help() },
	}
	tc.AddCommand(
		newToolInstall(eng, m.Name, m.NoDiscover),
		newToolUninstall(eng, m.Name, m.SingleInstall),
		newToolSet(eng, m.Name, m.SingleInstall),
		newToolUnset(eng, m.Name),
		newToolVersion(eng, m.Name),
		newToolVersions(eng, m.Name),
		newToolUpdate(eng, m.Name),
	)
	return tc
}

// newToolInstall は install サブコマンド（-l 一覧 / --latest 最新 / -v 指定）。
// discover=none（rust/androidsdk）は版指定なしの `install` で導入する。
func newToolInstall(eng *anyvm.Engine, tool string, noDiscover bool) *cobra.Command {
	var (
		list    bool
		latest  bool
		version string
	)
	c := &cobra.Command{
		Use:   "install",
		Short: "導入（-l 一覧 / --latest 最新 / -v <版> 指定）",
		RunE: func(c *cobra.Command, _ []string) error {
			ctx := c.Context()
			switch {
			case list:
				vs, err := eng.ListInstallable(ctx, tool)
				if err != nil {
					return err
				}
				if len(vs) == 0 {
					slog.Info(fmt.Sprintf("導入可能なバージョンがありません（`anyvm %s update` を実行してください）", tool))
					return nil
				}
				for _, v := range vs {
					slog.Info(v.Version)
				}
				return nil
			case latest:
				return eng.InstallLatest(ctx, tool)
			case version != "":
				return eng.Install(ctx, tool, version)
			case noDiscover:
				// discover=none: 版リストを持たないため、引数なしで導入する。
				return eng.Install(ctx, tool, "")
			default:
				return c.Help()
			}
		},
	}
	f := c.Flags()
	f.BoolVarP(&list, "list", "l", false, "導入可能な版の一覧を表示")
	f.BoolVar(&latest, "latest", false, "最新版を導入")
	f.StringVarP(&version, "version", "v", "", "導入する版")
	return c
}

// newToolUninstall は uninstall サブコマンド（-v 指定。単一インストール型は版不要）。
func newToolUninstall(eng *anyvm.Engine, tool string, singleInstall bool) *cobra.Command {
	var version string
	c := &cobra.Command{
		Use:   "uninstall",
		Short: "指定版を削除（-v <版>）",
		RunE: func(c *cobra.Command, _ []string) error {
			if version == "" && !singleInstall {
				return c.Help()
			}
			return eng.Uninstall(c.Context(), tool, version)
		},
	}
	c.Flags().StringVarP(&version, "version", "v", "", "削除する版")
	return c
}

// newToolSet は set サブコマンド（-v 指定。単一インストール型は版不要）。
func newToolSet(eng *anyvm.Engine, tool string, singleInstall bool) *cobra.Command {
	var version string
	c := &cobra.Command{
		Use:   "set",
		Short: "指定版を有効化（-v <版>）",
		RunE: func(c *cobra.Command, _ []string) error {
			if version == "" && !singleInstall {
				return c.Help()
			}
			return eng.Set(c.Context(), tool, version)
		},
	}
	c.Flags().StringVarP(&version, "version", "v", "", "有効化する版")
	return c
}

// newToolUnset は unset サブコマンド。
func newToolUnset(eng *anyvm.Engine, tool string) *cobra.Command {
	return &cobra.Command{
		Use:   "unset",
		Short: "無効化",
		RunE: func(c *cobra.Command, _ []string) error {
			return eng.Unset(c.Context(), tool)
		},
	}
}

// newToolVersion は version サブコマンド（アクティブ版を表示）。
func newToolVersion(eng *anyvm.Engine, tool string) *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "有効なバージョンを表示",
		RunE: func(c *cobra.Command, _ []string) error {
			v, ok := eng.ActiveVersion(tool)
			if !ok {
				slog.Info("有効なバージョンはありません")
				return nil
			}
			slog.Info(v)
			return nil
		},
	}
}

// newToolVersions は versions サブコマンド（導入済み一覧。アクティブに * を付与）。
func newToolVersions(eng *anyvm.Engine, tool string) *cobra.Command {
	return &cobra.Command{
		Use:   "versions",
		Short: "導入済みバージョン一覧を表示",
		RunE: func(c *cobra.Command, _ []string) error {
			ivs, err := eng.InstalledVersions(tool)
			if err != nil {
				return err
			}
			if len(ivs) == 0 {
				slog.Info("導入済みバージョンはありません")
				return nil
			}
			for _, iv := range ivs {
				mark := " "
				if iv.Active {
					mark = "*"
				}
				slog.Info(mark + iv.Version)
			}
			return nil
		},
	}
}

// newToolUpdate は update サブコマンド（導入可能版の再取得）。
func newToolUpdate(eng *anyvm.Engine, tool string) *cobra.Command {
	return &cobra.Command{
		Use:   "update",
		Short: "導入可能なバージョン一覧を再取得",
		RunE: func(c *cobra.Command, _ []string) error {
			return eng.Update(c.Context(), tool)
		},
	}
}
