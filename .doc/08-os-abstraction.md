# 08. OS 抽象化層（internal/platform）

決定方針「抽象化し Windows 実装のみ」に基づき、OS 依存処理を `Platform` インターフェースへ局所化します。実装は当面 Windows のみですが、インターフェース化によりテスト時のモック化と将来の他 OS 拡張余地を確保します。

## 1. Platform インターフェース

```go
// internal/platform/platform.go
package platform

import "github.com/kznagamori/anyvm_win/pkg/anyvm/types"

type Platform interface {
	// current → target の実体リンク（Windows: ジャンクション）。
	CreateLink(linkPath, targetPath string) error
	RemoveLink(linkPath string) error
	IsLink(path string) (bool, error)

	// 有効化/無効化スクリプトの生成（.bat/.ps1）。
	WriteActivationScripts(env types.Env, tool string, act types.Activation) error
	WriteAggregateScripts(env types.Env, tools []string) error // AnyVm{Activate,Deactivate}
	ClearActivationScripts(env types.Env, tool string) error

	// コンソール/スクリプトの文字エンコード（Windows-JP: SJIS）。
	EncodeForScript(s string) ([]byte, error)

	// 外部プロセス実行（rustup/msiexec/WiX 等の残置依存）。
	Run(ctx context.Context, name string, args []string, opt RunOpt) (RunResult, error)

	Exists(path string) bool
}
```

`Platform` は `pkg/anyvm` から DI される（[07 Config.Platform](07-library-api.md)）。既定値は `platform.Windows{}`。

## 2. ジャンクション生成（外部 cmd.exe MKLINK の置換）

旧版は `cmd /C MKLINK /J` / `RMDIR` を subprocess 実行していた。新版は **`os`/`syscall` で直接**生成し、`cmd.exe` 依存を排除します。

```go
//go:build windows
// internal/platform/link_windows.go
package platform

import "os"

// Windows のジャンクションは os.Symlink ではなくリパースポイント。
// Go では mkdir 後に DeviceIoControl で reparse point を設定するか、
// golang.org/x/sys/windows を用いる。簡潔には次の選択肢:
//   1) os.Symlink（要 SeCreateSymbolicLinkPrivilege / 開発者モード）
//   2) ディレクトリジャンクション（権限不要・旧仕様と等価）★推奨
func (Windows) CreateLink(link, target string) error {
	return createJunction(link, target) // x/sys/windows でリパースポイント設定
}

func (Windows) RemoveLink(link string) error {
	return os.Remove(link) // ジャンクションは Remove で外れる（実体は消えない）
}
```

> **権限の考慮**: シンボリックリンクは特権が要るが、**ディレクトリジャンクションは非特権で作成可能**。旧版が `MKLINK /J`（ジャンクション）だったのと等価にするため、`createJunction` をリパースポイント（`IO_REPARSE_TAG_MOUNT_POINT`）で実装する。`x/sys/windows` の `DeviceIoControl(FSCTL_SET_REPARSE_POINT, ...)` を用いる。

## 3. 文字エンコード（SJIS）

旧版は `.bat`/`.ps1` を Shift_JIS で書き出していた（日本語 Windows コンソールの既定コードページ CP932 対策）。

```go
//go:build windows
// internal/platform/encoding_windows.go
import "golang.org/x/text/encoding/japanese"

func (Windows) EncodeForScript(s string) ([]byte, error) {
	return japanese.ShiftJIS.NewEncoder().Bytes([]byte(s))
}
```

> 将来 UTF-8 + BOM やコードページ 65001 への移行余地もあるが、互換挙動として SJIS を既定とする。インターフェース化により、テストでは恒等エンコーダに差し替え可能。

## 4. 有効化スクリプトの生成（テンプレート化）

旧版は文字列連結でスクリプトを生成し、`_OLD_<VAR>` の typo（例 dotnet の `$env:OLD_DOTNET_ROOT`）等のバグを抱えていた。新版は **Go テンプレート**で一貫生成します。

### 4.1 生成ロジック

```go
// internal/platform/scripts_windows.go
func (w Windows) WriteActivationScripts(env types.Env, tool string, act types.Activation) error {
	data := scriptData{
		Guard: "_" + tool + "Vm_ENV_VAL",
		Path:  strings.Join(act.Path, ";") + ";",
		Env:   act.Env, // 順序保持のため []KV を推奨
	}
	for _, t := range []scriptTarget{
		{tmpl: activateBatTmpl, file: tool + "Activate.bat"},
		{tmpl: activatePs1Tmpl, file: tool + "Activate.ps1"},
		{tmpl: deactivateBatTmpl, file: tool + "Deactivate.bat"},
		{tmpl: deactivatePs1Tmpl, file: tool + "Deactivate.ps1"},
	} {
		buf := render(t.tmpl, data)
		enc, err := w.EncodeForScript(buf)
		if err != nil { return err }
		if err := os.WriteFile(filepath.Join(env.Scripts, t.file), enc, 0o644); err != nil {
			return err
		}
	}
	return nil
}
```

### 4.2 .bat テンプレート（activate）

```text
@ECHO OFF
IF DEFINED {{.Guard}} GOTO END_SET_ENV_VAL
SET {{.Guard}}="yes"
SET PATH={{.Path}}%PATH%
{{- range .Env}}
SET _OLD_{{.Key}}=%{{.Key}}%
SET {{.Key}}={{.Value}}
{{- end}}
:END_SET_ENV_VAL
```

### 4.3 .ps1 テンプレート（activate）

```text
if([string]::IsNullOrEmpty($env:{{.Guard}})) {
    $env:{{.Guard}} = "yes";
    $env:Path = "{{.Path}}" + $env:Path;
{{- range .Env}}
    ${env:_OLD_{{.Key}}} = ${env:{{.Key}}};
    ${env:{{.Key}}} = "{{.Value}}";
{{- end}}
}
```

### 4.4 deactivate テンプレート（.bat / .ps1）

```text
@ECHO OFF
IF NOT DEFINED {{.Guard}} GOTO END_SET_ENV_VAL
SET {{.Guard}}=
SET PATH=%PATH:{{.Path}}=%
{{- range .Env}}
SET {{.Key}}=%_OLD_{{.Key}}%
SET _OLD_{{.Key}}=
{{- end}}
:END_SET_ENV_VAL
```
```text
if([string]::IsNullOrEmpty($env:{{.Guard}})) {
} else {
    $env:{{.Guard}} = "";
    Set-Item ENV:Path $env:Path.Replace("{{.Path}}", "");
{{- range .Env}}
    ${env:{{.Key}}} = ${env:_OLD_{{.Key}}};
    ${env:_OLD_{{.Key}}} = "";
{{- end}}
}
```

> **`DOTNET_ROOT(x86)` 等の特殊名**: `.ps1` では `${env:DOTNET_ROOT(x86)}` のように波括弧でクォートする。テンプレートで括弧を含むキーを検出し自動クォートする（`.bat` は `SET "NAME(x86)=..."` 形式）。`unset` 時はスクリプトを空（`@ECHO OFF` のみ／空）に上書きする `ClearActivationScripts` を用いる。

## 5. 集約スクリプト（init / rehash）

`init` で全ツールの Activate/Deactivate を呼ぶ集約スクリプトを生成します（旧 `AnyVmActivate.bat/.ps1`）。対象ツールは**マニフェスト由来で動的**に列挙（取りこぼし防止）。

```text
# AnyVmActivate.ps1（生成物）
. $PSScriptRoot\goActivate.ps1
. $PSScriptRoot\pythonActivate.ps1
...
```

## 6. シェル連携（現シェルへの反映）

`set`/`unset`/`rehash` はスクリプトを生成するだけで、**現在のシェルの環境は子プロセスから変えられない**。旧版同様、シェル起動プロファイルに薄い関数を仕込み、`rehash` 実行時に集約スクリプトを dot-source します。

```powershell
# $PROFILE に setup が追記する内容（例）
$env:Path = "<ROOT>\bin;" + $env:Path
. "<ROOT>\scripts\AnyVmActivate.ps1"

function anyvm {
    if ($args[0] -eq "rehash") {
        & "<ROOT>\bin\anyvm.exe" rehash      # スクリプト再生成
        . "<ROOT>\scripts\AnyVmDeactivate.ps1"
        . "<ROOT>\scripts\AnyVmActivate.ps1" # 現シェルへ反映
    } else {
        & "<ROOT>\bin\anyvm.exe" @args
    }
}
```

この `anyvm` 関数の仕込みは `anyvm setup`（[05](05-cli-design.md)）が行い、旧 `setup_jp.bat` の対話（実行ポリシー・$PROFILE・CmdProfile.bat・レジストリ AutoRun）を Go で再実装します（SJIS 文字化けも解消）。

## 7. プロセス実行（残置する外部依存）

```go
type RunOpt struct {
	Env    map[string]string // 例: rustup の CARGO_HOME/RUSTUP_HOME
	Dir    string
	Stdout io.Writer
}
type RunResult struct{ ExitCode int; Stdout, Stderr string }

func (Windows) Run(ctx context.Context, name string, args []string, opt RunOpt) (RunResult, error)
```

`exec.CommandContext` をラップし、ctx キャンセルに対応。利用箇所:

| 残置依存 | 利用ストラテジ |
|----------|----------------|
| `rustup-init.exe` | `rustup` |
| WiX `dark.exe` / `msiexec` | `python_msi` |
| `python.exe -m ensurepip` | `python_msi` |
| `sdkmanager`（要 Java） | `android_sdk` |

## 8. テスト用フェイク

```go
// internal/platform/fake.go（テスト専用）
type Fake struct {
	Links   map[string]string // link → target
	Scripts map[string][]byte // path → content
	Runs    []RunCall
}
func (f *Fake) CreateLink(l, t string) error { f.Links[l] = t; return nil }
// ... 各メソッドを記録/再生
```

これにより `Engine.Set` 等を**実ファイルシステムや Windows API なしで単体テスト**できます（[12](12-testing.md)）。
