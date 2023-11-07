$firstArg = $args[0]

function Perform-Rehash {
    . $PSScriptRoot\..\scripts\AnyVmDeactivate.ps1
    . $PSScriptRoot\..\scripts\AnyVmActivate.ps1
}

function Invoke-AnyVm {
    param($arguments)
    & "$PSScriptRoot\anyvm_win.exe" @arguments
}

if ($firstArg -eq "rehash") {
    Perform-Rehash
} else {
    Invoke-AnyVm -arguments $args
}
