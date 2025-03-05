param(
    [Parameter(Mandatory=$true)]
    [string]$SourceDirectory,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationDirectory
)

# 必要なファイルのリストを定義
$filesToCopy = @(
    "bin\anyvm.bat",
    "bin\anyvm.ps1",
    "bin\anyvm_win.exe",
    "bin\bazel_vm_version_cache.json",
    "bin\cmake_vm_version_cache.json",
    "bin\dart_vm_version_cache.json",
    "bin\dotnet_vm_version_cache.json",
    "bin\flutter_vm_version_cache.json",
    "bin\go_vm_version_cache.json",
    "bin\gradle_vm_version_cache.json",
    "bin\jdk_vm_version_cache.json",
    "bin\kotlin_vm_version_cache.json",
    "bin\llvm_vm_version_cache.json",
    "bin\mingw_vm_version_cache.json",
    "bin\ninja_vm_version_cache.json",
    "bin\nodejs_vm_version_cache.json",
    "bin\python_vm_version_cache.json",
    "bin\rust_vm_version_cache.json",
    "bin\winlibs_vm_version_cache.json",    
    "scripts\AnyVmActivate.bat",
    "scripts\AnyVmActivate.ps1",
    "scripts\AnyVmDeactivate.bat",
    "scripts\AnyVmDeactivate.ps1",
    "setup_jp.bat",
    "tools\symexe.exe"
)

# ソースディレクトリとコピー先ディレクトリが存在することを確認
if (-not (Test-Path -Path $SourceDirectory -PathType Container)) {
    Write-Error "指定されたソースディレクトリ '$SourceDirectory' が存在しません。"
    exit 1
}

# コピー先ディレクトリが存在しない場合は作成
if (-not (Test-Path -Path $DestinationDirectory -PathType Container)) {
    try {
        New-Item -Path $DestinationDirectory -ItemType Directory -Force | Out-Null
        Write-Host "コピー先ディレクトリ '$DestinationDirectory' を作成しました。"
    } catch {
        Write-Error "コピー先ディレクトリの作成に失敗しました: $_"
        exit 1
    }
}

# ソースディレクトリ内のanyvm_winフォルダを特定
$anyVmWinDir = Join-Path -Path $SourceDirectory -ChildPath "anyvm_win"
if (-not (Test-Path -Path $anyVmWinDir -PathType Container)) {
    Write-Error "ソースディレクトリ内に 'anyvm_win' フォルダが見つかりません。"
    exit 1
}

# ファイルをコピー
$copyCount = 0
$errorCount = 0

foreach ($file in $filesToCopy) {
    $sourcePath = Join-Path -Path $anyVmWinDir -ChildPath $file
    $destPath = Join-Path -Path $DestinationDirectory -ChildPath $file
    
    # コピー先のディレクトリ構造を作成
    $destDir = Split-Path -Path $destPath -Parent
    if (-not (Test-Path -Path $destDir -PathType Container)) {
        try {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        } catch {
            Write-Error "ディレクトリの作成に失敗しました '$destDir': $_"
            $errorCount++
            continue
        }
    }
    
    # ファイルをコピー
    if (Test-Path -Path $sourcePath -PathType Leaf) {
        try {
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            Write-Host "コピー完了: '$sourcePath' -> '$destPath'"
            $copyCount++
        } catch {
            Write-Error "ファイルのコピーに失敗しました '$file': $_"
            $errorCount++
        }
    } else {
        Write-Warning "ソースファイルが見つかりません: '$sourcePath'"
        $errorCount++
    }
}

# 結果を表示
Write-Host "`n処理完了:"
Write-Host "コピーされたファイル: $copyCount"
if ($errorCount -gt 0) {
    Write-Host "エラーが発生したファイル: $errorCount" -ForegroundColor Red
}