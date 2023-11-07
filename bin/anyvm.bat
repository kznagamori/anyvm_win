@ECHO OFF

IF "%~1"=="rehash" (
    %~dp0..\scripts\AnyVmDeativate.bat
    %~dp0..\scripts\AnyVmAativate.bat
    GOTO :EOF
)

%~dp0anyvm_win.exe %*
