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
    & "$PSScriptRoot\anyvm_win.exe"  LLVMVm unset      
    & "$PSScriptRoot\anyvm_win.exe"  MinGWVm unset     
    & "$PSScriptRoot\anyvm_win.exe"  NinjaVm unset     
    & "$PSScriptRoot\anyvm_win.exe"  NodejsVm unset    
    & "$PSScriptRoot\anyvm_win.exe"  PythonVm unset    
    & "$PSScriptRoot\anyvm_win.exe"  RustVm unset      
    & "$PSScriptRoot\anyvm_win.exe"  dotnetVm unset    
}


if ($firstArg -eq "rehash") {
    Perform-Rehash
} elseif  ($firstArg -eq "update") {
    Perform-Update
} elseif  ($firstArg -eq "unset") {
    Perform-Unset
} else {
    Invoke-AnyVm -arguments $args
}
