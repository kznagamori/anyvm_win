$firstArg = $args[0]

function Invoke-AnyVm {
    param($arguments)
    & "$PSScriptRoot\anyvm_win.exe" @arguments
}

function Perform-Rehash {
    . $PSScriptRoot\..\scripts\AnyVmDeactivate.ps1
    . $PSScriptRoot\..\scripts\AnyVmActivate.ps1
}

function Perform-Update {
    & "$PSScriptRoot\anyvm_win.exe"  BazelVm update
    & "$PSScriptRoot\anyvm_win.exe"  CMakeVm update
    & "$PSScriptRoot\anyvm_win.exe"  DartVm update
    & "$PSScriptRoot\anyvm_win.exe"  FlutterVm update
    & "$PSScriptRoot\anyvm_win.exe"  GoVm update
    & "$PSScriptRoot\anyvm_win.exe"  GradleVm update
    & "$PSScriptRoot\anyvm_win.exe"  JDKVm update
    & "$PSScriptRoot\anyvm_win.exe"  KotlinVm update
    & "$PSScriptRoot\anyvm_win.exe"  LLVMVm update
    & "$PSScriptRoot\anyvm_win.exe"  MinGWVm update
    & "$PSScriptRoot\anyvm_win.exe"  NinjaVm update
    & "$PSScriptRoot\anyvm_win.exe"  NodejsVm update
    & "$PSScriptRoot\anyvm_win.exe"  PythonVm update
    & "$PSScriptRoot\anyvm_win.exe"  dotnetVm update
}

function Perform-Unset {
    & "$PSScriptRoot\anyvm_win.exe"  AndroidSDKVm unset
    & "$PSScriptRoot\anyvm_win.exe"  BazelVm unset
    & "$PSScriptRoot\anyvm_win.exe"  CMakeVm unset
    & "$PSScriptRoot\anyvm_win.exe"  DartVm unset
    & "$PSScriptRoot\anyvm_win.exe"  FlutterVm unset
    & "$PSScriptRoot\anyvm_win.exe"  GoVm unset
    & "$PSScriptRoot\anyvm_win.exe"  GradleVm unset
    & "$PSScriptRoot\anyvm_win.exe"  JDKVm unset
    & "$PSScriptRoot\anyvm_win.exe"  KotlinVm unset
    & "$PSScriptRoot\anyvm_win.exe"  LLVMVm unset
    & "$PSScriptRoot\anyvm_win.exe"  MinGWVm unset
    & "$PSScriptRoot\anyvm_win.exe"  NinjaVm unset
    & "$PSScriptRoot\anyvm_win.exe"  NodejsVm unset
    & "$PSScriptRoot\anyvm_win.exe"  PythonVm unset
    & "$PSScriptRoot\anyvm_win.exe"  RustVm unset
    & "$PSScriptRoot\anyvm_win.exe"  dotnetVm unset
}

function Perform-Version {
    Write-Output "AndroidSDKVm"; & "$PSScriptRoot\anyvm_win.exe"  AndroidSDKVm version
    Write-Output "BazelVm"; & "$PSScriptRoot\anyvm_win.exe"  BazelVm version
    Write-Output "CMakeVm"; & "$PSScriptRoot\anyvm_win.exe"  CMakeVm version
    Write-Output "DartVm"; & "$PSScriptRoot\anyvm_win.exe"  DartVm version
    Write-Output "FlutterVm"; & "$PSScriptRoot\anyvm_win.exe"  FlutterVm version
    Write-Output "GoVm"; & "$PSScriptRoot\anyvm_win.exe"  GoVm version
    Write-Output "GradleVm"; & "$PSScriptRoot\anyvm_win.exe"  GradleVm version
    Write-Output "JDKVm"; & "$PSScriptRoot\anyvm_win.exe"  JDKVm version
    Write-Output "KotlinVm"; & "$PSScriptRoot\anyvm_win.exe"  KotlinVm version
    Write-Output "LLVMVm"; & "$PSScriptRoot\anyvm_win.exe"  LLVMVm version
    Write-Output "MinGWVm"; & "$PSScriptRoot\anyvm_win.exe"  MinGWVm version
    Write-Output "NinjaVm"; & "$PSScriptRoot\anyvm_win.exe"  NinjaVm version
    Write-Output "NodejsVm"; & "$PSScriptRoot\anyvm_win.exe"  NodejsVm version
    Write-Output "PythonVm"; & "$PSScriptRoot\anyvm_win.exe"  PythonVm version
    Write-Output "RustVm"; & "$PSScriptRoot\anyvm_win.exe"  RustVm version
    Write-Output "dotnetVm"; & "$PSScriptRoot\anyvm_win.exe"  dotnetVm version
}

if ($firstArg -eq "rehash") {
    Perform-Rehash
} elseif  ($firstArg -eq "update") {
    Perform-Update
} elseif  ($firstArg -eq "unset") {
    Perform-Unset
} elseif  ($firstArg -eq "version") {
    Perform-Version
} else {
    Invoke-AnyVm -arguments $args
}
