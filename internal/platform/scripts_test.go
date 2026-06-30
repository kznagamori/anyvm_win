package platform

import (
	"strings"
	"testing"

	"github.com/kznagamori/anyvm_win/pkg/anyvm/types"
)

// TestRenderActivatePs1 は .ps1 のガード変数・PATH・環境変数生成を検証する。
func TestRenderActivatePs1(t *testing.T) {
	act := types.Activation{
		Path: []string{`C:\x\bin`},
		Env:  []types.EnvVar{{Key: "GOROOT", Value: `C:\x`}},
	}
	s := renderActivatePs1("go", act)
	wants := []string{
		"if([string]::IsNullOrEmpty($env:_ANYVM_GO_ACTIVE))",
		`$env:Path = "C:\x\bin;" + $env:Path;`,
		`${env:_OLD_GOROOT} = ${env:GOROOT};`,
		`${env:GOROOT} = "C:\x";`,
	}
	for _, w := range wants {
		if !strings.Contains(s, w) {
			t.Errorf("ps1 に %q が含まれていない:\n%s", w, s)
		}
	}
}

// TestRenderActivateBat は .bat のガード変数・PATH 生成を検証する。
func TestRenderActivateBat(t *testing.T) {
	act := types.Activation{
		Path: []string{`C:\x\bin`},
		Env:  []types.EnvVar{{Key: "GOROOT", Value: `C:\x`}},
	}
	s := renderActivateBat("go", act)
	wants := []string{
		"IF DEFINED _ANYVM_GO_ACTIVE GOTO END_SET_ENV_VAL",
		`SET PATH=C:\x\bin;%PATH%`,
		"SET _OLD_GOROOT=%GOROOT%",
		`SET GOROOT=C:\x`,
	}
	for _, w := range wants {
		if !strings.Contains(s, w) {
			t.Errorf("bat に %q が含まれていない:\n%s", w, s)
		}
	}
}

// TestSpecialEnvNameQuoting は括弧を含むキー（DOTNET_ROOT(x86)）が
// バッチでクォートされることを検証する（.doc/08 §4.4）。
func TestSpecialEnvNameQuoting(t *testing.T) {
	act := types.Activation{Env: []types.EnvVar{{Key: "DOTNET_ROOT(x86)", Value: `C:\d`}}}
	s := renderActivateBat("dotnet", act)
	if !strings.Contains(s, `SET "DOTNET_ROOT(x86)=C:\d"`) {
		t.Errorf("特殊キーがクォートされていない:\n%s", s)
	}
}

// TestRenderAggregate は集約スクリプトに全ツールの呼び出しが含まれることを検証する。
func TestRenderAggregate(t *testing.T) {
	files := renderAggregateFiles([]string{"go", "python"})
	ps1 := files["AnyVmActivate.ps1"]
	if !strings.Contains(ps1, `. $PSScriptRoot\goActivate.ps1`) ||
		!strings.Contains(ps1, `. $PSScriptRoot\pythonActivate.ps1`) {
		t.Errorf("集約 ps1 が想定外:\n%s", ps1)
	}
	bat := files["AnyVmActivate.bat"]
	if !strings.HasPrefix(bat, "@ECHO OFF\n") || !strings.Contains(bat, `CALL %~dp0goActivate.bat`) {
		t.Errorf("集約 bat が想定外:\n%s", bat)
	}
}
