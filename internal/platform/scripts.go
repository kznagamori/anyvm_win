package platform

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// encoder はスクリプト文字列を OS コンソール向けバイト列へ変換する関数型。
// Windows(日本語環境) では Shift_JIS、その他では UTF-8 恒等を用いる。
type encoder func(string) ([]byte, error)

// guardVar は二重適用防止のためのガード変数名を返す（例: "go" -> "_ANYVM_GO_ACTIVE"）。
// 旧実装の "_<VmName>_ENV_VAL" を、クリーン設計の小文字ツール名向けに刷新したもの。
func guardVar(tool string) string {
	return "_ANYVM_" + strings.ToUpper(tool) + "_ACTIVE"
}

// joinPath は PATH 前置文字列 "d1;d2;" を組み立てる（末尾にも区切り ";" を付ける）。
func joinPath(paths []string) string {
	if len(paths) == 0 {
		return ""
	}
	return strings.Join(paths, ";") + ";"
}

// batNeedsQuote は、括弧や空白を含むキー（例: DOTNET_ROOT(x86)）を
// バッチの SET でクォートすべきかを返す（.doc/08 §4.4）。
func batNeedsQuote(key string) bool {
	return strings.ContainsAny(key, "() ")
}

// renderActivateBat は <tool>Activate.bat の内容を生成する（.doc/08 §4.2）。
//
// ガード変数で二重適用を防ぎ、各環境変数は _OLD_<KEY> に旧値を退避してから設定する。
func renderActivateBat(tool string, act types.Activation) string {
	guard := guardVar(tool)
	var b strings.Builder
	b.WriteString("@ECHO OFF\n")
	fmt.Fprintf(&b, "IF DEFINED %s GOTO END_SET_ENV_VAL\n", guard)
	fmt.Fprintf(&b, "SET %s=\"yes\"\n", guard)
	fmt.Fprintf(&b, "SET PATH=%s%%PATH%%\n", joinPath(act.Path))
	for _, kv := range act.Env {
		if batNeedsQuote(kv.Key) {
			fmt.Fprintf(&b, "SET \"_OLD_%s=%%%s%%\"\n", kv.Key, kv.Key)
			fmt.Fprintf(&b, "SET \"%s=%s\"\n", kv.Key, kv.Value)
		} else {
			fmt.Fprintf(&b, "SET _OLD_%s=%%%s%%\n", kv.Key, kv.Key)
			fmt.Fprintf(&b, "SET %s=%s\n", kv.Key, kv.Value)
		}
	}
	b.WriteString(":END_SET_ENV_VAL\n")
	return b.String()
}

// renderActivatePs1 は <tool>Activate.ps1 の内容を生成する（.doc/08 §4.3）。
// PowerShell では特殊文字を含むキーも扱えるよう ${env:KEY} 記法を用いる。
func renderActivatePs1(tool string, act types.Activation) string {
	guard := guardVar(tool)
	var b strings.Builder
	fmt.Fprintf(&b, "if([string]::IsNullOrEmpty($env:%s)) {\n", guard)
	fmt.Fprintf(&b, "    $env:%s = \"yes\";\n", guard)
	fmt.Fprintf(&b, "    $env:Path = \"%s\" + $env:Path;\n", joinPath(act.Path))
	for _, kv := range act.Env {
		fmt.Fprintf(&b, "    ${env:_OLD_%s} = ${env:%s};\n", kv.Key, kv.Key)
		fmt.Fprintf(&b, "    ${env:%s} = \"%s\";\n", kv.Key, kv.Value)
	}
	b.WriteString("}\n")
	return b.String()
}

// renderDeactivateBat は <tool>Deactivate.bat の内容を生成する（.doc/08 §4.4）。
func renderDeactivateBat(tool string, act types.Activation) string {
	guard := guardVar(tool)
	var b strings.Builder
	b.WriteString("@ECHO OFF\n")
	fmt.Fprintf(&b, "IF NOT DEFINED %s GOTO END_SET_ENV_VAL\n", guard)
	fmt.Fprintf(&b, "SET %s=\n", guard)
	fmt.Fprintf(&b, "SET PATH=%%PATH:%s=%%\n", joinPath(act.Path))
	for _, kv := range act.Env {
		if batNeedsQuote(kv.Key) {
			fmt.Fprintf(&b, "SET \"%s=%%_OLD_%s%%\"\n", kv.Key, kv.Key)
			fmt.Fprintf(&b, "SET \"_OLD_%s=\"\n", kv.Key)
		} else {
			fmt.Fprintf(&b, "SET %s=%%_OLD_%s%%\n", kv.Key, kv.Key)
			fmt.Fprintf(&b, "SET _OLD_%s=\n", kv.Key)
		}
	}
	b.WriteString(":END_SET_ENV_VAL\n")
	return b.String()
}

// renderDeactivatePs1 は <tool>Deactivate.ps1 の内容を生成する（.doc/08 §4.4）。
func renderDeactivatePs1(tool string, act types.Activation) string {
	guard := guardVar(tool)
	var b strings.Builder
	fmt.Fprintf(&b, "if([string]::IsNullOrEmpty($env:%s)) {\n", guard)
	b.WriteString("} else {\n")
	fmt.Fprintf(&b, "    $env:%s = \"\";\n", guard)
	fmt.Fprintf(&b, "    Set-Item ENV:Path $env:Path.Replace(\"%s\", \"\");\n", joinPath(act.Path))
	for _, kv := range act.Env {
		fmt.Fprintf(&b, "    ${env:%s} = ${env:_OLD_%s};\n", kv.Key, kv.Key)
		fmt.Fprintf(&b, "    ${env:_OLD_%s} = \"\";\n", kv.Key)
	}
	b.WriteString("}\n")
	return b.String()
}

// renderActivationFiles は 1 ツール分の 4 スクリプト（名前 -> 内容）を生成する。
func renderActivationFiles(tool string, act types.Activation) map[string]string {
	return map[string]string{
		tool + "Activate.bat":   renderActivateBat(tool, act),
		tool + "Activate.ps1":   renderActivatePs1(tool, act),
		tool + "Deactivate.bat": renderDeactivateBat(tool, act),
		tool + "Deactivate.ps1": renderDeactivatePs1(tool, act),
	}
}

// emptyScripts は無効化時に書き出す空（no-op）スクリプトを返す。
func emptyScripts(tool string) map[string]string {
	return map[string]string{
		tool + "Activate.bat":   "@ECHO OFF\n",
		tool + "Activate.ps1":   "\n",
		tool + "Deactivate.bat": "@ECHO OFF\n",
		tool + "Deactivate.ps1": "\n",
	}
}

// renderAggregateFiles は全ツールを束ねる AnyVm{Activate,Deactivate} を生成する（.doc/08 §5）。
func renderAggregateFiles(tools []string) map[string]string {
	var actBat, actPs1, deactBat, deactPs1 strings.Builder
	actBat.WriteString("@ECHO OFF\n")
	deactBat.WriteString("@ECHO OFF\n")
	for _, t := range tools {
		fmt.Fprintf(&actBat, "CALL %%~dp0%sActivate.bat\n", t)
		fmt.Fprintf(&actPs1, ". $PSScriptRoot\\%sActivate.ps1\n", t)
		fmt.Fprintf(&deactBat, "CALL %%~dp0%sDeactivate.bat\n", t)
		fmt.Fprintf(&deactPs1, ". $PSScriptRoot\\%sDeactivate.ps1\n", t)
	}
	return map[string]string{
		"AnyVmActivate.bat":   actBat.String(),
		"AnyVmActivate.ps1":   actPs1.String(),
		"AnyVmDeactivate.bat": deactBat.String(),
		"AnyVmDeactivate.ps1": deactPs1.String(),
	}
}

// writeFiles は scripts ディレクトリへ、エンコードしたファイル群を書き出す共有ヘルパー。
func writeFiles(dir string, files map[string]string, enc encoder) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("scripts ディレクトリ作成: %w", err)
	}
	for name, content := range files {
		b, err := enc(content)
		if err != nil {
			return fmt.Errorf("エンコード %s: %w", name, err)
		}
		if err := os.WriteFile(filepath.Join(dir, name), b, 0o644); err != nil {
			return fmt.Errorf("書き込み %s: %w", name, err)
		}
	}
	return nil
}

// writeActivationScripts は Activation から 4 スクリプトを生成し、enc でエンコードして書き出す。
func writeActivationScripts(env types.Env, tool string, act types.Activation, enc encoder) error {
	return writeFiles(env.Scripts, renderActivationFiles(tool, act), enc)
}

// writeAggregateScripts は集約スクリプトを生成して書き出す。
func writeAggregateScripts(env types.Env, tools []string, enc encoder) error {
	return writeFiles(env.Scripts, renderAggregateFiles(tools), enc)
}
