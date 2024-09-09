@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

@REM ���s�f�B���N�g�����C���X�g�[���f�B���N�g���Ƃ���
SET CURRENT_DIR=%~dp0

@REM ####### anyvm��bin�f�B���N�g����PATH�ݒ菈���̊J�n #######
@REM anyvm��bin�f�B���N�g����PATH�́Apowershell/pwsh/cmd�̋N�����ǂݍ��݃X�N���v�g�Őݒ���s��

@REM anyvm��bin�f�B���N�g����PATH
SET ANYVM_WIN_BIN_DIR=%~dp0bin

@REM anyvm��scripts�f�B���N�g����PATH
SET ANYVM_WIN_SCRIPTS_DIR=%~dp0scripts


@REM ####### powershell�̋N�����ǂݍ��݃X�N���v�g�쐬�����̊J�n #######

@REM powershell�̎��s�|���V�[��ύX
@REM Y��������YES�ȊO��powershell�̎��s�|���V�[�̕ύX���X�L�b�v����
SET /P SELECTED="powershell�̎��s�|���V�[��RemoteSigned�ɕύX���܂����H(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :CHANGE_POWERSHELL_POLICY)
IF /i {%SELECTED%}=={yes} (GOTO :CHANGE_POWERSHELL_POLICY)

GOTO END_CHANGE_POWERSHELL_POLICY

:CHANGE_POWERSHELL_POLICY

powershell -Command Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

:END_CHANGE_POWERSHELL_POLICY

@REM powershell�̋N�����ǂݍ��݃X�N���v�g������
FOR /F "usebackq" %%i IN (`powershell -ExecutionPolicy Bypass -command $PROFILE.CurrentUserAllHosts`) DO SET VALUE=%%i

@REM powershell�̋N�����ǂݍ��݃X�N���v�g�̃p�X
SET POWERSHELL_PROFILE_PS1=%VALUE%

@REM Y��������YES�ȊO�͋N�����ǂݍ��݃X�N���v�g�̍쐬���X�L�b�v����
SET /P SELECTED="%POWERSHELL_PROFILE_PS1%���쐬���܂����H(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :CREATE_POWERSHELL_PS1)
IF /i {%SELECTED%}=={yes} (GOTO :CREATE_POWERSHELL_PS1)

GOTO END_POWERSHELL

@REM ####### pwsh�̋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL�����̊J�n#######
:CREATE_POWERSHELL_PS1
@REM powershell�̋N�����ǂݍ��݃X�N���v�g�̃f�B���N�g���̎擾
FOR %%a IN ("%POWERSHELL_PROFILE_PS1%") DO FOR %%b IN ("%%~dpa\.") DO SET "POWERSHELL_PROFILE_DIR=%%~dpa"

@REM powershell�̋N�����ǂݍ��݃X�N���v�g�̃f�B���N�g�����쐬
IF NOT EXIST "%POWERSHELL_PROFILE_DIR%" MKDIR "%POWERSHELL_PROFILE_DIR%"

@REM powershell�̋N�����ǂݍ��݃X�N���v�g���Ȃ��ꍇ�͍쐬�����Ɉړ�
IF NOT EXIST "%POWERSHELL_PROFILE_PS1%" GOTO WRITE_POWERSHELL_PS1

@REM Y��������YES�ȊO�͋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL�������X�L�b�v����
SET /P SELECTED="%POWERSHELL_PROFILE_PS1%�Ƀp�X��ǋL���܂����H(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :WRITE_POWERSHELL_PS1)
IF /i {%SELECTED%}=={yes} (GOTO :WRITE_POWERSHELL_PS1)

GOTO END_POWERSHELL

@REM powershell�̋N�����ǂݍ��݃X�N���v�g�쐬�E�ǋL����
:WRITE_POWERSHELL_PS1

@REM powershell�̋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL����
ECHO $env:Path = "%ANYVM_WIN_BIN_DIR%;" + $env:Path;>>"%POWERSHELL_PROFILE_PS1%"
ECHO . "%ANYVM_WIN_SCRIPTS_DIR%\AnyVmActivate.ps1">>"%POWERSHELL_PROFILE_PS1%"

:END_POWERSHELL
@REM ####### powershell�̋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL�����̏I��#######
@REM ####### powershell�̋N�����ǂݍ��݃X�N���v�g�쐬�����̏I�� #######


@REM ####### cmd�̋N�����ǂݍ��݃X�N���v�g�쐬�����̊J�n #######

@REM cmd�̋N�����ǂݍ��݃X�N���v�g��powershell�̋N���X�N���v�g�Ɠ����f�B���N�g���ɍ쐬����
@REM powershell�̋N�����ǂݍ��݃X�N���v�g������
FOR /F "usebackq" %%i IN (`powershell -ExecutionPolicy Bypass -command $PROFILE.CurrentUserAllHosts`) DO SET VALUE=%%i
@REM powershell�̋N�����ǂݍ��݃X�N���v�g�̃p�X
SET POWERSHELL_PROFILE_PS1=%VALUE%
@REM powershell�̋N�����ǂݍ��݃X�N���v�g�̃f�B���N�g���̎擾
FOR %%a IN ("%POWERSHELL_PROFILE_PS1%") DO FOR %%b IN ("%%~dpa\.") DO SET "POWERSHELL_PROFILE_DIR=%%~dpa"

@REM powershell�̃p�X����cmd�̋N�����ǂݍ��݃X�N���v�g�̃p�X���쐬
SET CMD_PROFILE_BAT=%POWERSHELL_PROFILE_DIR%CmdProfile.bat

@REM cmd�̋N�����ǂݍ��݃X�N���v�g�����W�X�g���ɐݒ肳���Ă��邩�m�F
REG QUERY "HKEY_CURRENT_USER\Software\Microsoft\Command Processor" /v AutoRun 1>NUL 2>&1

@REM cmd�̋N�����ǂݍ��݃X�N���v�g�����W�X�g���ɐݒ肳���Ă��Ȃ��ꍇ�́A���W�X�g���ݒ菈�����s��
IF %ERRORLEVEL%==1 GOTO SETUP_CMD_REG

@REM cmd�̋N�����ǂݍ��݃X�N���v�g�����W�X�g���ɐݒ肳���Ă���ꍇ�́A���W�X�g���ݒ�擾�������s��
IF %ERRORLEVEL%==0 GOTO GET_CMD_REG


@REM ####### cmd�̋N�����ǂݍ��݃X�N���v�g�̃��W�X�g���ݒ菈���̊J�n #######
:SETUP_CMD_REG
ECHO cmd�̋N�����ǂݍ��݃X�N���v�g�̃p�X��%CMD_PROFILE_BAT%�ł��B

@REM Y��������YES�ȊO��cmd�̋N�����ǂݍ��݃X�N���v�g�̃��W�X�g���ݒ菈�����X�L�b�v����
SET /P SELECTED="���W�X�g����cmd�̋N���o�b�`�t�@�C���̃p�X��ǉ����܂����H(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :WRITE_CMD_REG)
IF /i {%SELECTED%}=={yes} (GOTO :WRITE_CMD_REG)

GOTO END_CMD

:WRITE_CMD_REG

@REM cmd�̋N�����ǂݍ��݃X�N���v�g�̃��W�X�g���ݒ菈��
REG ADD "HKEY_CURRENT_USER\Software\Microsoft\Command Processor" /v "AutoRun" /t REG_SZ /d "%CMD_PROFILE_BAT%" /f

@REM cmd�̋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL������
GOTO CREATE_CMD_BAT
@REM ####### cmd�̋N�����ǂݍ��݃X�N���v�g�̃��W�X�g���ݒ菈���̏I�� #######

@REM ####### cmd�̋N�����ǂݍ��݃X�N���v�g�̃��W�X�g���ݒl�擾�����̊J�n #######
:GET_CMD_REG

@REM cmd�̋N�����ǂݍ��݃X�N���v�g�̃��W�X�g���ݒl�擾����
FOR /F "TOKENS=1,2,*" %%I IN ('REG QUERY "HKEY_CURRENT_USER\Software\Microsoft\Command Processor" /v "AutoRun"') DO IF "%%I"=="AutoRun" SET VALUE=%%K

SET CMD_PROFILE_BAT=%VALUE%

@REM cmd�̋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL������
GOTO CREATE_CMD_BAT
@REM ####### cmd�̋N�����ǂݍ��݃X�N���v�g�̃��W�X�g���ݒl�擾�����̏I��#######


@REM ####### cmd�̋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL�����̊J�n#######
:CREATE_CMD_BAT
@REM powershell�̋N�����ǂݍ��݃X�N���v�g�̃f�B���N�g���̎擾
FOR %%a IN ("%CMD_PROFILE_BAT%") DO FOR %%b IN ("%%~dpa\.") DO SET "CMD_PROFILE_DIR=%%~dpa"

@REM cmd�̋N�����ǂݍ��݃X�N���v�g�̃f�B���N�g�����쐬
IF NOT EXIST "%CMD_PROFILE_DIR%" MKDIR "%CMD_PROFILE_DIR%"

@REM cmd�̋N�����ǂݍ��݃X�N���v�g���Ȃ��ꍇ�͍쐬�����Ɉړ�
IF NOT EXIST "%CMD_PROFILE_BAT%" GOTO WRITE_CMD_BAT

@REM Y��������YES�ȊO�͋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL�������X�L�b�v����
SET /P SELECTED="%CMD_PROFILE_BAT%�Ƀp�X��ǋL���܂����H(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :WRITE_CMD_BAT)
IF /i {%SELECTED%}=={yes} (GOTO :WRITE_CMD_BAT)

GOTO END_CMD

@REM cmd�̋N�����ǂݍ��݃X�N���v�g�쐬�E�ǋL����
:WRITE_CMD_BAT

@REM cmd�̋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL����
ECHO @ECHO OFF>>"%CMD_PROFILE_BAT%"
ECHO SET PATH=%ANYVM_WIN_BIN_DIR%;%%PATH%%>>"%CMD_PROFILE_BAT%"
ECHO CALL "%ANYVM_WIN_SCRIPTS_DIR%\AnyVmActivate.bat">>"%CMD_PROFILE_BAT%"

:END_CMD
@REM ####### cmd�̋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL�����̏I��#######
@REM ####### cmd�̋N�����ǂݍ��݃X�N���v�g�쐬�����̏I�� #######


@REM ####### pwsh�̋N�����ǂݍ��݃X�N���v�g�쐬�����̊J�n #######
SET PWSH_PROFILE_PS1=""

@REM pwsh�R�}���h������
FOR /f "usebackq delims=" %%A IN (`where pwsh`) DO SET VALUE=%%A

@REM pwsh�R�}���h���Ȃ��ꍇ�́A�N�����ǂݍ��݃X�N���v�g�̃��W�X�g���ݒ菈�����X�L�b�v����
IF %VALUE%=="" GOTO END_PWSH

@REM pwsh�̋N�����ǂݍ��݃X�N���v�g������
FOR /F "usebackq" %%i IN (`pwsh -ExecutionPolicy Bypass -command $PROFILE.CurrentUserAllHosts`) DO SET VALUE=%%i

@REM pwsh�̋N�����ǂݍ��݃X�N���v�g�̃p�X
SET PWSH_PROFILE_PS1=%VALUE%

@REM Y��������YES�ȊO�͋N�����ǂݍ��݃X�N���v�g�̍쐬���X�L�b�v����
SET /P SELECTED="%PWSH_PROFILE_PS1%���쐬���܂����H(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :CREATE_PWSH_PS1)
IF /i {%SELECTED%}=={yes} (GOTO :CREATE_PWSH_PS1)

GOTO END_PWSH

@REM ####### pwsh�̋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL�����̊J�n#######
:CREATE_PWSH_PS1
@REM powershell�̋N�����ǂݍ��݃X�N���v�g�̃f�B���N�g���̎擾
FOR %%a IN ("%PWSH_PROFILE_PS1%") DO FOR %%b IN ("%%~dpa\.") DO SET "PWSH_PROFILE_DIR=%%~dpa"

@REM pwsh�̋N�����ǂݍ��݃X�N���v�g�̃f�B���N�g�����쐬
IF NOT EXIST "%PWSH_PROFILE_DIR%" MKDIR "%PWSH_PROFILE_DIR%"

@REM pwsh�̋N�����ǂݍ��݃X�N���v�g���Ȃ��ꍇ�͍쐬�����Ɉړ�
IF NOT EXIST "%PWSH_PROFILE_PS1%" GOTO WRITE_PWSH_PS1

@REM Y��������YES�ȊO�͋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL�������X�L�b�v����
SET /P SELECTED="%PWSH_PROFILE_PS1%�Ƀp�X��ǋL���܂����H(Y=YES / N=NO): "
IF /i {%SELECTED%}=={y} (GOTO :WRITE_PWSH_PS1)
IF /i {%SELECTED%}=={yes} (GOTO :WRITE_PWSH_PS1)

GOTO END_PWSH

@REM pwsh�̋N�����ǂݍ��݃X�N���v�g�쐬�E�ǋL����
:WRITE_PWSH_PS1

@REM pwsh�̋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL����
ECHO $env:Path = "%ANYVM_WIN_BIN_DIR%;$;" + $env:Path;>>"%PWSH_PROFILE_PS1%"
ECHO . "%ANYVM_WIN_SCRIPTS_DIR%\AnyVmActivate.ps1">>"%PWSH_PROFILE_PS1%"

:END_PWSH
@REM ####### pwsh�̋N�����ǂݍ��݃X�N���v�g�ւ̃p�X�̒ǋL�����̏I��#######
@REM ####### pwsh�̋N�����ǂݍ��݃X�N���v�g�쐬�����̏I�� #######

:END
