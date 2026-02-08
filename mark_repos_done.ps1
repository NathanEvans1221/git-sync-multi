# ==============================================================================
# 腳本名稱: mark_repos_done.ps1
# 功能描述: 將主帳號 Repository 的 description 從 ⁉️ 改為 ✅，標記專案為已完成。
# ==============================================================================

Write-Host ">>> 標記 Repository 為已完成" -ForegroundColor Yellow
Write-Host "功能：將主帳號 Repository description 開頭的 ⁉️ 改為 ✅" -ForegroundColor Gray
Write-Host ""

# --- 載入環境變數 ---
function Load-Env {
    param([string]$EnvFile = ".env")
    if (Test-Path $EnvFile) {
        Get-Content $EnvFile | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+?)\s*=\s*(.+?)\s*$') {
                $name = $Matches[1]
                $value = $Matches[2] -replace '^["'']|["'']$', ''
                [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
            }
        }
    } else {
        Write-Host "警告: 找不到 .env 檔案，將使用預設值。" -ForegroundColor Yellow
    }
}

Load-Env

# --- 取得設定 ---
$rootPath = $env:ROOT_PATH
$mainAccount = $env:GITHUB_ACCOUNT

if (-not $rootPath) {
    Write-Host "錯誤: 未設定 ROOT_PATH 環境變數。" -ForegroundColor Red
    exit 1
}

if (-not $mainAccount) {
    Write-Host "錯誤: 未設定 GITHUB_ACCOUNT 環境變數。" -ForegroundColor Red
    exit 1
}

Write-Host "主帳號: $mainAccount" -ForegroundColor Cyan
Write-Host "根目錄: $rootPath" -ForegroundColor Cyan

# --- 切換到主帳號 ---
Write-Host "`n切換 GitHub 帳號至: $mainAccount" -ForegroundColor Cyan
gh auth switch --user $mainAccount 2>$null
Start-Sleep -Seconds 2

# --- 讀取專案清單 ---
$projectsFile = Join-Path $PSScriptRoot "ini\repos_to_done.ini"

if (-not (Test-Path $projectsFile)) {
    Write-Host "錯誤: 找不到 $projectsFile" -ForegroundColor Red
    exit 1
}

$projects = Get-Content -Path $projectsFile | Where-Object { $_ -match '^[^#\s]' }

# --- 日誌設定 ---
$logDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logPath = Join-Path $logDir "mark_done_log.log"

Write-Host "`n開始處理專案..." -ForegroundColor Cyan

$updatedCount = 0
$skippedCount = 0

foreach ($line in $projects) {
    $trimmedLine = $line.Trim()
    
    # 解析專案名稱（取第一個空白前的內容）
    if ($trimmedLine -match '^(?<name>[^\s]+)') {
        $repoName = $Matches['name']
        $repoFull = "$mainAccount/$repoName"
        
        Write-Host "`n------------------------------------------" -ForegroundColor Gray
        Write-Host "檢查: $repoFull" -ForegroundColor Cyan
        
        # 取得 Repository 現有 Description
        $repoInfoJson = gh repo view $repoFull --json description 2>$null | ConvertFrom-Json
        
        if ($null -eq $repoInfoJson) {
            Write-Host "  ⚠️ 無法取得 Repository 資訊，跳過" -ForegroundColor Yellow
            $skippedCount++
            continue
        }
        
        $currentDesc = if ($repoInfoJson.description) { $repoInfoJson.description } else { "" }
        
        Write-Host "  目前 Description: $currentDesc" -ForegroundColor Gray
        
        # 檢查是否開頭為 ⁉️
        if ($currentDesc.StartsWith("⁉️ ")) {
            # 移除 ⁉️ 並加上 ✅
            $newDesc = "✅" + $currentDesc.Substring(2)
            
            Write-Host "  更新為: $newDesc" -ForegroundColor Yellow
            
            gh repo edit $repoFull --description "$newDesc" 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ 更新成功" -ForegroundColor Green
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [DONE] ${repoFull}: $currentDesc -> $newDesc" | Out-File -FilePath $logPath -Append
                $updatedCount++
            } else {
                Write-Host "  ❌ 更新失敗" -ForegroundColor Red
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] ${repoFull}: Failed to update" | Out-File -FilePath $logPath -Append
            }
        } elseif ($currentDesc.StartsWith("✅")) {
            Write-Host "  已標記為完成，跳過" -ForegroundColor Gray
            $skippedCount++
        } else {
            Write-Host "  開頭不是 ⁉️，跳過" -ForegroundColor Gray
            $skippedCount++
        }
    }
}

Write-Host "`n==========================================" -ForegroundColor Magenta
Write-Host "處理完成！" -ForegroundColor Cyan
Write-Host "  已更新: $updatedCount 個專案" -ForegroundColor Green
Write-Host "  已跳過: $skippedCount 個專案" -ForegroundColor Gray
Write-Host "  日誌: $logPath" -ForegroundColor Gray
