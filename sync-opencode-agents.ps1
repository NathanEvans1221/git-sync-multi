# ==============================================================================
# 腳本名稱: sync-opencode-agents.ps1
# 功能描述: 從 AI_AGENT_GUIDELINES 儲存庫拉取最新檔案並覆蓋到指定目錄
# ==============================================================================

param(
    [string]$SourceDir = "",
    [string]$FileName = "",
    [string]$DestFiles = ""
)

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = $PWD }

$envFile = Join-Path $ScriptDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"')
            if (-not [string]::IsNullOrEmpty($value)) {
                Set-Item -Path "env:$key" -Value $value -Force
            }
        }
    }
}

if ([string]::IsNullOrEmpty($SourceDir)) { $SourceDir = $env:SYNC_SOURCE_DIR }
if ([string]::IsNullOrEmpty($FileName)) { $FileName = $env:SYNC_FILE_NAME }
if ([string]::IsNullOrEmpty($DestFiles)) { $DestFiles = $env:SYNC_DEST_FILES }

$DestFileList = $DestFiles -split ';'

$OriginalDir = $PWD

Write-Host ">>> 同步 AI_AGENT_GUIDELINES 檔案" -ForegroundColor Yellow
Write-Host "來源目錄：$SourceDir" -ForegroundColor Gray
foreach ($dest in $DestFileList) {
    Write-Host "目標檔案：$dest" -ForegroundColor Gray
}
Write-Host ""

if (-not (Test-Path $SourceDir)) {
    Write-Host "錯誤：來源目錄不存在 - $SourceDir" -ForegroundColor Red
    exit 1
}

Set-Location $SourceDir
Write-Host "執行 git pull..." -ForegroundColor Cyan
git pull

if ($LASTEXITCODE -ne 0) {
    Write-Host "錯誤：git pull 失敗" -ForegroundColor Red
    exit 1
}

$SourceFile = Join-Path $SourceDir $FileName
if (-not (Test-Path $SourceFile)) {
    Write-Host "錯誤：檔案不存在 - $SourceFile" -ForegroundColor Red
    exit 1
}

Write-Host "複製檔案 $FileName 到目標目錄..." -ForegroundColor Cyan
foreach ($dest in $DestFileList) {
    Copy-Item -Path $SourceFile -Destination $dest -Force
    Write-Host "覆蓋檔案：$dest" -ForegroundColor Yellow
}

Write-Host "完成！" -ForegroundColor Green

Set-Location $OriginalDir
