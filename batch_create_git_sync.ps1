# 定義載入 .env 的函式
function Load-Env {
    param($Path = ".env")
    $envPath = Join-Path $PSScriptRoot $Path
    if (Test-Path $envPath) {
        Get-Content $envPath | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
            $parts = $_.Split('=', 2)
            if ($parts.Count -eq 2) {
                $name = $parts[0].Trim()
                $value = $parts[1].Trim().Trim('"').Trim("'")
                [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
            }
        }
    }
}

# 執行載入
Load-Env

# 設定參數
$rootPath = if ($env:ROOT_PATH) { $env:ROOT_PATH } else { "D:\github\chiisen\" }
$templatePath = Join-Path $PSScriptRoot "setup_git_sync.ps1.example"
$targetFileName = "setup_git_sync.ps1"

# 讀取範本內容
if (-not (Test-Path $templatePath)) {
    Write-Error "找不到範本檔案: $templatePath"
    return
}
$templateContent = Get-Content -Path $templatePath -Raw

# 取得根目錄下的所有子目錄
$directories = Get-ChildItem -Path $rootPath -Directory

Write-Host "開始批次建立 $targetFileName..." -ForegroundColor Cyan

foreach ($dir in $directories) {
    $targetPath = Join-Path $dir.FullName $targetFileName
    
    # 如果該目錄已經有檔案，則跳過
    if (Test-Path $targetPath) {
        Write-Host "跳過 (已存在): $($dir.Name)" -ForegroundColor Gray
        continue
    }

    # 以子目錄名稱取代 PROJECT_NAME
    $projectName = $dir.Name
    $newContent = $templateContent.Replace("PROJECT_NAME", $projectName)

    # 寫入新的檔案
    try {
        Set-Content -Path $targetPath -Value $newContent -Encoding utf8
        Write-Host "成功建立: $($dir.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "錯誤 (無法建立於 $($dir.Name)): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n批次處理完成！" -ForegroundColor Cyan
