# ==============================================================================
# 腳本名稱: batch_git_remote.ps1
# 功能描述: 批次遠端檢查與導出工具。
#           掃描遠端位址、分類日誌並自動導出標準專案清單。
# ==============================================================================

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

# 切換 GitHub 帳號 (確保權限正確)
if ($env:GITHUB_ACCOUNT) {
    Write-Host "切換 GitHub 帳號至: $env:GITHUB_ACCOUNT" -ForegroundColor Cyan
    gh auth switch -u $env:GITHUB_ACCOUNT 2>$null
}

Write-Host ">>> 批次遠端檢查與導出工具" -ForegroundColor Yellow
Write-Host "功能：掃描遠端位址、智慧導出清單，並依據私有/分支/完成標記進行分類。" -ForegroundColor Gray
Write-Host ""

# 設定搜尋的根目錄
$rootPath = if ($env:ROOT_PATH) { $env:ROOT_PATH } else { "D:\github\chiisen\" }
# 設定 Log 與 輸出路徑
$logDir = Join-Path $PSScriptRoot "logs"
$outDir = Join-Path $PSScriptRoot "out"
$logPath = Join-Path $logDir "git_remote_list.log"
$debugLogPath = Join-Path $logDir "git_remote_debug.log"
$excludedLogPath = Join-Path $logDir "excluded_projects.log"
$projectsExtractPath = Join-Path $outDir "extracted_projects.ini"

# 確保資料夾存在
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

$startTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Host "開始掃描並導出標準專案清單 (Exclude Private/Fork)..." -ForegroundColor Cyan

# 初始 Log 與導出檔 (清空舊資料)
"--- Git Remote Address List: $startTime ---`n" | Out-File -FilePath $logPath -Encoding utf8
"--- Git Remote Multiple Remotes Debug: $startTime ---`n" | Out-File -FilePath $debugLogPath -Encoding utf8
# extracted_projects.ini 與 excluded_projects.log 直接清空
$null | Out-File -FilePath $projectsExtractPath -Encoding utf8
"--- Excluded Projects Reasons: $startTime ---`n" | Out-File -FilePath $excludedLogPath -Encoding utf8

# 取得所有子目錄
$directories = Get-ChildItem -Path $rootPath -Directory


# 取得所有子目錄
$directories = Get-ChildItem -Path $rootPath -Directory

# 平行處理設定
$throttleLimit = 5 # 同時執行的執行緒數量 (保守設定以避免 GitHub API Rate Limit)

Write-Host "偵測到 $($directories.Count) 個目錄，開始平行掃描 (加速模式)..." -ForegroundColor Cyan
$measure = Measure-Command {
    # 平行處理並收集輸出
    $results = $directories | ForEach-Object -Parallel {
        $dir = $_
        $gitDir = Join-Path $dir.FullName ".git"
        
        # 定義回傳物件結構
        $result = @{
            Type = "Skip" # Log, Debug, Exclude, Export
            Content = ""
            DirPath = $dir.FullName
            DirName = $dir.Name
        }

        if (Test-Path $gitDir) {
            # 執行 git remote -v
            $remotes = @(git -C $dir.FullName remote -v 2>$null | Where-Object { $_.Trim() -ne "" })
            
            if ($remotes.Count -eq 2) {
                # 標準兩筆 (Fetch/Push)
                # 解析遠端 URL 以取得 owner/repo (優先看 fetch)
                $fetchLine = $remotes | Where-Object { $_ -match "\(fetch\)" }
                
                if ($fetchLine -match '[:/](?<owner>[^:/]+)/(?<repo>.+)\.git') {
                    $owner = $Matches['owner']
                    $repoName = $Matches['repo']
                    $repoFull = "$owner/$repoName"

                    # 透過 gh 檢查屬性並排除 Private/Fork
                    # 使用 $using:env:GITHUB_ACCOUNT 存取外部環境變數
                    $currentAccount = $using:env:GITHUB_ACCOUNT 

                    $repoData = gh repo view $repoFull --json description,isPrivate,isFork 2>$null | ConvertFrom-Json
                    if ($null -ne $repoData) {
                        $desc = if ($null -ne $repoData.description) { $repoData.description } else { "" }
                        $isPrivate = $repoData.isPrivate
                        $isFork = $repoData.isFork
                        $isDone = $desc.Trim().StartsWith("✅")
                        
                        # 檢查 Owner 是否為當前使用者
                        $isDifferentOwner = $false
                        if (-not [string]::IsNullOrEmpty($currentAccount)) {
                            $isDifferentOwner = ($owner -ne $currentAccount)
                        }

                        if (-not $isPrivate -and -not $isFork -and -not $isDone -and -not $isDifferentOwner) {
                            # 畫面即時顯示成功
                            Write-Host "處理專案: $($dir.Name)" -ForegroundColor Gray
                            Write-Host "  [✅ 已導出 extracted_projects.ini] $($dir.Name)" -ForegroundColor Green
                            
                            # [Export] 成功導出
                            $debugInfo = "    [DEBUG] Private: $isPrivate, Fork: $isFork, Done: $isDone"
                            return @{
                                Type = "Export"
                                Content = "$repoName --public --description `"$desc`""
                                LogContent = "[$($dir.Name)]`n$debugInfo`n$($remotes -join "`n")`n"
                                DirName = $dir.Name
                            }
                        } else {
                            # [Exclude] 排除項目
                            $reason = if($isPrivate){"私有專案 (Private)"}elseif($isFork){"分支專案 (Fork)"}elseif($isDone){"GitHub 描述文字開頭為 ✅ (已完成)"}elseif($isDifferentOwner){"專案擁有者 ($owner) 非當前帳號 ($currentAccount)"}
                            return @{
                                Type = "Exclude"
                                Content = "[$repoName] -- $reason"
                                LogContent = "[$($dir.Name)]`n$($remotes -join "`n")`n"
                            }
                        }
                    } else {
                        return @{ Type = "Exclude"; Content = "[$($dir.Name)] -- 非 GitHub 專案或 API 錯誤" }
                    }
                    # 稍微延遲避免 GitHub API 速率限制
                    Start-Sleep -Milliseconds 50
                } else {
                    return @{ Type = "Exclude"; Content = "[$($dir.Name)] -- 無法解析遠端位址格式" }
                }
            } elseif ($remotes.Count -gt 2) {
                # [Debug] 超過兩筆
                $reason = "偵測到多個遠端位址 ($($remotes.Count) 筆)"
                return @{
                    Type = "Debug"
                    ExcludeContent = "[$($dir.Name)] -- $reason"
                    DebugContent = "[$($dir.Name)] ($($remotes.Count) 筆)`n$($remotes -join "`n")`n"
                }
            } else {
                # [Exclude] 0 筆或 1 筆
                $reason = if ($remotes.Count -eq 0) { "無遠端位址" } else { "單一遠端位址 ($($remotes.Count) 筆)" }
                return @{
                    Type = "Exclude"
                    Content = "[$($dir.Name)] -- $reason"
                    LogContent = "[$($dir.Name)] ($reason)`n$($remotes -join "`n")`n"
                }
            }
        }
        return $null
    } -ThrottleLimit $throttleLimit
}

# 處理並歸類結果 (Batch Write)
$logBuffer = [System.Collections.Generic.List[string]]::new()
$debugBuffer = [System.Collections.Generic.List[string]]::new()
$excludeBuffer = [System.Collections.Generic.List[string]]::new()
$exportBuffer = [System.Collections.Generic.List[string]]::new()
$repoCount = 0

foreach ($res in $results) {
    if ($null -eq $res) { continue }
    $repoCount++

    switch ($res.Type) {
        "Export" {
            $exportBuffer.Add($res.Content)
            $logBuffer.Add($res.LogContent)
        }
        "Exclude" {
            $excludeBuffer.Add($res.Content)
            if ($res.LogContent) { $logBuffer.Add($res.LogContent) }
        }
        "Debug" {
            $excludeBuffer.Add($res.ExcludeContent)
            $debugBuffer.Add($res.DebugContent)
        }
    }
}

# 一次性寫入所有檔案 (Batch Write)
if ($logBuffer.Count -gt 0) { $logBuffer | Out-File -FilePath $logPath -Append -Encoding utf8 }
if ($debugBuffer.Count -gt 0) { $debugBuffer | Out-File -FilePath $debugLogPath -Append -Encoding utf8 }
if ($excludeBuffer.Count -gt 0) { $excludeBuffer | Out-File -FilePath $excludedLogPath -Append -Encoding utf8 }
if ($exportBuffer.Count -gt 0) { $exportBuffer | Out-File -FilePath $projectsExtractPath -Append -Encoding utf8 }

$endTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$summary = "`n--- 掃描完成 ($endTime) ---`n掃描總專案數: $repoCount"

$summary | Out-File -FilePath $logPath -Append -Encoding utf8
$summary | Out-File -FilePath $debugLogPath -Append -Encoding utf8
Write-Host $summary -ForegroundColor Cyan
Write-Host "標準結果: $logPath" -ForegroundColor Yellow
Write-Host "排除結果: $excludedLogPath" -ForegroundColor Gray
Write-Host "導出結果: $projectsExtractPath" -ForegroundColor DarkCyan
Write-Host "異常結果: $debugLogPath" -ForegroundColor Magenta
