@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

@REM 実行ディレクトリをインストールディレクトリとする
SET CURRENT_DIR=%~dp0

@REM ####### anyvmのbinディレクトリのPATH設定処理の開始 #######
@REM anyvmのbinディレクトリのPATHは、powershell/pwsh/cmdの起動時読み込みスクリプトで設定を行う

@REM anyvmのbinディレクトリのPATH
SET ANYVM_WIN_BIN_DIR=%~dp0bin

@REM anyvmのscriptsディレクトリのPATH
SET ANYVM_WIN_SCRIPTS_DIR=%~dp0scripts


@REM ####### powershellの起動時読み込みスクリプト作成処理の開始 #######

@REM powershellの実行ポリシーを変更
@REM YもしくがYES以外はpowershellの実行ポリシーの変更をスキップする
SET /P SELECTED="powershellの実行ポリシーをRemoteSignedに変更しますか？(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :CHANGE_POWERSHELL_POLICY)
IF /i {%SELECTED%}=={yes} (GOTO :CHANGE_POWERSHELL_POLICY)

GOTO END_CHANGE_POWERSHELL_POLICY

:CHANGE_POWERSHELL_POLICY

powershell -Command Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

:END_CHANGE_POWERSHELL_POLICY

@REM powershellの起動時読み込みスクリプトを検索
FOR /F "usebackq" %%i IN (`powershell -ExecutionPolicy Bypass -command $PROFILE.CurrentUserAllHosts`) DO SET VALUE=%%i

@REM powershellの起動時読み込みスクリプトのパス
SET POWERSHELL_PROFILE_PS1=%VALUE%

@REM YもしくがYES以外は起動時読み込みスクリプトの作成をスキップする
SET /P SELECTED="%POWERSHELL_PROFILE_PS1%を作成しますか？(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :CREATE_POWERSHELL_PS1)
IF /i {%SELECTED%}=={yes} (GOTO :CREATE_POWERSHELL_PS1)

GOTO END_POWERSHELL

@REM ####### pwshの起動時読み込みスクリプトへのパスの追記処理の開始#######
:CREATE_POWERSHELL_PS1
@REM powershellの起動時読み込みスクリプトのディレクトリの取得
FOR %%a IN ("%POWERSHELL_PROFILE_PS1%") DO FOR %%b IN ("%%~dpa\.") DO SET "POWERSHELL_PROFILE_DIR=%%~dpa"

@REM powershellの起動時読み込みスクリプトのディレクトリを作成
IF NOT EXIST "%POWERSHELL_PROFILE_DIR%" MKDIR "%POWERSHELL_PROFILE_DIR%"

@REM powershellの起動時読み込みスクリプトがない場合は作成処理に移動
IF NOT EXIST "%POWERSHELL_PROFILE_PS1%" GOTO WRITE_POWERSHELL_PS1

@REM YもしくがYES以外は起動時読み込みスクリプトへのパスの追記処理をスキップする
SET /P SELECTED="%POWERSHELL_PROFILE_PS1%にパスを追記しますか？(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :WRITE_POWERSHELL_PS1)
IF /i {%SELECTED%}=={yes} (GOTO :WRITE_POWERSHELL_PS1)

GOTO END_POWERSHELL

@REM powershellの起動時読み込みスクリプト作成・追記処理
:WRITE_POWERSHELL_PS1

@REM powershellの起動時読み込みスクリプトへのパスの追記処理
ECHO $env:Path = "%ANYVM_WIN_BIN_DIR%;" + $env:Path;>>"%POWERSHELL_PROFILE_PS1%"
ECHO . "%ANYVM_WIN_SCRIPTS_DIR%\AnyVmActivate.ps1">>"%POWERSHELL_PROFILE_PS1%"

:END_POWERSHELL
@REM ####### powershellの起動時読み込みスクリプトへのパスの追記処理の終了#######
@REM ####### powershellの起動時読み込みスクリプト作成処理の終了 #######


@REM ####### cmdの起動時読み込みスクリプト作成処理の開始 #######

@REM cmdの起動時読み込みスクリプトはpowershellの起動スクリプトと同じディレクトリに作成する
@REM powershellの起動時読み込みスクリプトを検索
FOR /F "usebackq" %%i IN (`powershell -ExecutionPolicy Bypass -command $PROFILE.CurrentUserAllHosts`) DO SET VALUE=%%i
@REM powershellの起動時読み込みスクリプトのパス
SET POWERSHELL_PROFILE_PS1=%VALUE%
@REM powershellの起動時読み込みスクリプトのディレクトリの取得
FOR %%a IN ("%POWERSHELL_PROFILE_PS1%") DO FOR %%b IN ("%%~dpa\.") DO SET "POWERSHELL_PROFILE_DIR=%%~dpa"

@REM powershellのパスからcmdの起動時読み込みスクリプトのパスを作成
SET CMD_PROFILE_BAT=%POWERSHELL_PROFILE_DIR%CmdProfile.bat

@REM cmdの起動時読み込みスクリプトがレジストリに設定されれているか確認
REG QUERY "HKEY_CURRENT_USER\Software\Microsoft\Command Processor" /v AutoRun 1>NUL 2>&1

@REM cmdの起動時読み込みスクリプトがレジストリに設定されれていない場合は、レジストリ設定処理を行う
IF %ERRORLEVEL%==1 GOTO SETUP_CMD_REG

@REM cmdの起動時読み込みスクリプトがレジストリに設定されれている場合は、レジストリ設定取得処理を行う
IF %ERRORLEVEL%==0 GOTO GET_CMD_REG


@REM ####### cmdの起動時読み込みスクリプトのレジストリ設定処理の開始 #######
:SETUP_CMD_REG
ECHO cmdの起動時読み込みスクリプトのパスは%CMD_PROFILE_BAT%です。

@REM YもしくがYES以外はcmdの起動時読み込みスクリプトのレジストリ設定処理をスキップする
SET /P SELECTED="レジストリにcmdの起動バッチファイルのパスを追加しますか？(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :WRITE_CMD_REG)
IF /i {%SELECTED%}=={yes} (GOTO :WRITE_CMD_REG)

GOTO END_CMD

:WRITE_CMD_REG

@REM cmdの起動時読み込みスクリプトのレジストリ設定処理
REG ADD "HKEY_CURRENT_USER\Software\Microsoft\Command Processor" /v "AutoRun" /t REG_SZ /d "%CMD_PROFILE_BAT%" /f

@REM cmdの起動時読み込みスクリプトへのパスの追記処理へ
GOTO CREATE_CMD_BAT
@REM ####### cmdの起動時読み込みスクリプトのレジストリ設定処理の終了 #######

@REM ####### cmdの起動時読み込みスクリプトのレジストリ設値取得処理の開始 #######
:GET_CMD_REG

@REM cmdの起動時読み込みスクリプトのレジストリ設値取得処理
FOR /F "TOKENS=1,2,*" %%I IN ('REG QUERY "HKEY_CURRENT_USER\Software\Microsoft\Command Processor" /v "AutoRun"') DO IF "%%I"=="AutoRun" SET VALUE=%%K

SET CMD_PROFILE_BAT=%VALUE%

@REM cmdの起動時読み込みスクリプトへのパスの追記処理へ
GOTO CREATE_CMD_BAT
@REM ####### cmdの起動時読み込みスクリプトのレジストリ設値取得処理の終了#######


@REM ####### cmdの起動時読み込みスクリプトへのパスの追記処理の開始#######
:CREATE_CMD_BAT
@REM powershellの起動時読み込みスクリプトのディレクトリの取得
FOR %%a IN ("%CMD_PROFILE_BAT%") DO FOR %%b IN ("%%~dpa\.") DO SET "CMD_PROFILE_DIR=%%~dpa"

@REM cmdの起動時読み込みスクリプトのディレクトリを作成
IF NOT EXIST "%CMD_PROFILE_DIR%" MKDIR "%CMD_PROFILE_DIR%"

@REM cmdの起動時読み込みスクリプトがない場合は作成処理に移動
IF NOT EXIST "%CMD_PROFILE_BAT%" GOTO WRITE_CMD_BAT

@REM YもしくがYES以外は起動時読み込みスクリプトへのパスの追記処理をスキップする
SET /P SELECTED="%CMD_PROFILE_BAT%にパスを追記しますか？(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :WRITE_CMD_BAT)
IF /i {%SELECTED%}=={yes} (GOTO :WRITE_CMD_BAT)

GOTO END_CMD

@REM cmdの起動時読み込みスクリプト作成・追記処理
:WRITE_CMD_BAT

@REM cmdの起動時読み込みスクリプトへのパスの追記処理
ECHO @ECHO OFF>>"%CMD_PROFILE_BAT%"
ECHO SET PATH=%ANYVM_WIN_BIN_DIR%;%%PATH%%>>"%CMD_PROFILE_BAT%"
ECHO CALL "%ANYVM_WIN_SCRIPTS_DIR%\AnyVmActivate.bat">>"%CMD_PROFILE_BAT%"

:END_CMD
@REM ####### cmdの起動時読み込みスクリプトへのパスの追記処理の終了#######
@REM ####### cmdの起動時読み込みスクリプト作成処理の終了 #######


@REM ####### pwshの起動時読み込みスクリプト作成処理の開始 #######
SET PWSH_PROFILE_PS1=""

@REM pwshコマンドを検索
FOR /f "usebackq delims=" %%A IN (`where pwsh`) DO SET VALUE=%%A

@REM pwshコマンドがない場合は、起動時読み込みスクリプトのレジストリ設定処理をスキップする
IF %VALUE%=="" GOTO END_PWSH

@REM pwshの起動時読み込みスクリプトを検索
FOR /F "usebackq" %%i IN (`pwsh -ExecutionPolicy Bypass -command $PROFILE.CurrentUserAllHosts`) DO SET VALUE=%%i

@REM pwshの起動時読み込みスクリプトのパス
SET PWSH_PROFILE_PS1=%VALUE%

@REM YもしくがYES以外は起動時読み込みスクリプトの作成をスキップする
SET /P SELECTED="%PWSH_PROFILE_PS1%を作成しますか？(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :CREATE_PWSH_PS1)
IF /i {%SELECTED%}=={yes} (GOTO :CREATE_PWSH_PS1)

GOTO END_PWSH

@REM ####### pwshの起動時読み込みスクリプトへのパスの追記処理の開始#######
:CREATE_PWSH_PS1
@REM powershellの起動時読み込みスクリプトのディレクトリの取得
FOR %%a IN ("%PWSH_PROFILE_PS1%") DO FOR %%b IN ("%%~dpa\.") DO SET "PWSH_PROFILE_DIR=%%~dpa"

@REM pwshの起動時読み込みスクリプトのディレクトリを作成
IF NOT EXIST "%PWSH_PROFILE_DIR%" MKDIR "%PWSH_PROFILE_DIR%"

@REM pwshの起動時読み込みスクリプトがない場合は作成処理に移動
IF NOT EXIST "%PWSH_PROFILE_PS1%" GOTO WRITE_PWSH_PS1

@REM YもしくがYES以外は起動時読み込みスクリプトへのパスの追記処理をスキップする
SET /P SELECTED="%PWSH_PROFILE_PS1%にパスを追記しますか？(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :WRITE_PWSH_PS1)
IF /i {%SELECTED%}=={yes} (GOTO :WRITE_PWSH_PS1)

GOTO END_PWSH

@REM pwshの起動時読み込みスクリプト作成・追記処理
:WRITE_PWSH_PS1

@REM pwshの起動時読み込みスクリプトへのパスの追記処理
ECHO $env:Path = "%ANYVM_WIN_BIN_DIR%;$;" + $env:Path;>>"%PWSH_PROFILE_PS1%"
ECHO . "%ANYVM_WIN_SCRIPTS_DIR%\AnyVmActivate.ps1">>"%PWSH_PROFILE_PS1%"

:END_PWSH
@REM ####### pwshの起動時読み込みスクリプトへのパスの追記処理の終了#######
@REM ####### pwshの起動時読み込みスクリプト作成処理の終了 #######

:END
