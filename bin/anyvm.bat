@ECHO OFF

IF "%~1"=="rehash" (
    %~dp0..\scripts\AnyVmDeactivate.bat
    %~dp0..\scripts\AnyVmActivate.bat
    GOTO :EOF
)
IF "%~1"=="update" (
    %~dp0anyvm_win.exe  BazelVm update
    %~dp0anyvm_win.exe  CMakeVm update
    %~dp0anyvm_win.exe  DartVm update
    %~dp0anyvm_win.exe  FlutterVm update
    %~dp0anyvm_win.exe  GoVm update
    %~dp0anyvm_win.exe  GradleVm update
    %~dp0anyvm_win.exe  JDKVm update
    %~dp0anyvm_win.exe  KotlinVm update
    %~dp0anyvm_win.exe  LLVMVm update
    %~dp0anyvm_win.exe  MinGWVm update
    %~dp0anyvm_win.exe  NinjaVm update
    %~dp0anyvm_win.exe  NodejsVm update
    %~dp0anyvm_win.exe  PythonVm update
    %~dp0anyvm_win.exe  WinLibsVm update
    %~dp0anyvm_win.exe  dotnetVm update
    GOTO :EOF
)
IF "%~1"=="unset" (
    %~dp0anyvm_win.exe  AndroidSDKVm unset
    %~dp0anyvm_win.exe  BazelVm unset
    %~dp0anyvm_win.exe  CMakeVm unset
    %~dp0anyvm_win.exe  DartVm unset
    %~dp0anyvm_win.exe  FlutterVm unset
    %~dp0anyvm_win.exe  GoVm unset
    %~dp0anyvm_win.exe  GradleVm unset
    %~dp0anyvm_win.exe  JDKVm unset
    %~dp0anyvm_win.exe  KotlinVm unset
    %~dp0anyvm_win.exe  LLVMVm unset
    %~dp0anyvm_win.exe  MinGWVm unset
    %~dp0anyvm_win.exe  NinjaVm unset
    %~dp0anyvm_win.exe  NodejsVm unset
    %~dp0anyvm_win.exe  PythonVm unset
    %~dp0anyvm_win.exe  RustVm unset
    %~dp0anyvm_win.exe  WinLibsVm unset
    %~dp0anyvm_win.exe  dotnetVm unset
    GOTO :EOF
)
IF "%~1"=="version" (
    ECHO AndroidSDKVm && %~dp0anyvm_win.exe  AndroidSDKVm version
    ECHO BazelVm && %~dp0anyvm_win.exe  BazelVm version
    ECHO CMakeVm && %~dp0anyvm_win.exe  CMakeVm version
    ECHO DartVm && %~dp0anyvm_win.exe  DartVm version
    ECHO FlutterVm && %~dp0anyvm_win.exe  FlutterVm version
    ECHO GoVm && %~dp0anyvm_win.exe  GoVm version
    ECHO GradleVm && %~dp0anyvm_win.exe  GradleVm version
    ECHO JDKVm && %~dp0anyvm_win.exe  JDKVm version
    ECHO KotlinVm && %~dp0anyvm_win.exe  KotlinVm version
    ECHO LLVMVm && %~dp0anyvm_win.exe  LLVMVm version
    ECHO MinGWVm && %~dp0anyvm_win.exe  MinGWVm version
    ECHO NinjaVm && %~dp0anyvm_win.exe  NinjaVm version
    ECHO NodejsVm && %~dp0anyvm_win.exe  NodejsVm version
    ECHO PythonVm && %~dp0anyvm_win.exe  PythonVm version
    ECHO RustVm && %~dp0anyvm_win.exe  RustVm version
    ECHO WinLibsVm && %~dp0anyvm_win.exe  WinLibsVm version
    ECHO dotnetVm && %~dp0anyvm_win.exe  dotnetVm version
    GOTO :EOF
)

%~dp0anyvm_win.exe %*
