if([string]::IsNullOrEmpty($env:_DartVm_ENV_VAL)) {
    $env:_DartVm_ENV_VAL = "yes";
    $env:Path = $PSScriptRoot + "\envs\dart\3.4.4\bin;" + $PSScriptRoot + "\envs\dart\.pub-cache\bin;" + $env:Path;
    $env:_OLD_PUB_CACHE = $env:PUB_CACHE;
    $env:PUB_CACHE = $PSScriptRoot + "\envs\dart\.pub-cache";
} else {
}
