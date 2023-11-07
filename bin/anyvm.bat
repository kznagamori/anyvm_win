@ECHO OFF

IF "%~1"=="rehash" (
    %~dp0..\scripts\AnyVmDeactivate.bat
    %~dp0..\scripts\AnyVmActivate.bat
    GOTO :EOF
)
%~dp0anyvm_win.exe %*
