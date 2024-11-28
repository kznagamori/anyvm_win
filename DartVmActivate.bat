@ECHO OFF
IF DEFINED _DartVm_ENV_VAL GOTO END_SET_ENV_VAL
SET _DartVm_ENV_VAL="yes"
SET PATH=%~dp0envs\dart\3.5.4\bin;%~dp0envs\dart\.pub-cache\bin;%PATH%
SET _OLD_PUB_CACHE=%PUB_CACHE%
SET PUB_CACHE=%~dp0envs\dart\.pub-cache
:END_SET_ENV_VAL
