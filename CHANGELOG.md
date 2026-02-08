# Changelog

本文件紀錄 `git-sync-multi` 專案的所有顯著變更。
格式基於 [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)，並遵循 Semantic Versioning。

## [Unreleased]

### ✨ Features (新功能)
- **mark_repos_done.ps1**: 新增批次標記專案完成工具，可將主帳號 Repository 的 description 從 `⁉️` 改為 `✅`。
    - 使用獨立設定檔 `ini/repos_to_done.ini`，與其他腳本設定分離避免誤用。
    - 日誌記錄於 `logs/mark_done_log.log`。
- **batch_gh_create.ps1 增強**: 
    - 建立其他帳號 Repository 後，自動更新主帳號 description 加上 `⁉️` 提醒。
    - 更新成功後自動執行專案的 `setup_git_sync.ps1` 並處理 Git 變更（自動 commit 與 pull）。
- **Configuration (設定變更)**:
    - 將 `accounts.txt` 更名為 `accounts.ini` 以符合其格式特性。
    - 將 `projects.txt` 更名為 `projects.ini` 以統一設定檔格式。
    - 將 `repos_to_done.txt` 更名為 `repos_to_done.ini` 以統一設定檔格式。
    - `batch_git_remote.ps1` 導出檔名變更為 `extracted_projects.ini`。

## [1.1.0] - 2026-02-08
### 🚀 Performance (效能優化)
- **Parallel Processing**: 為 `batch_git_pull.ps1` 與 `batch_create_git_sync.ps1` 引入 `ForEach-Object -Parallel`，大幅提升多專案處理速度。
- **Memory Buffer Logging**: 在平行處理中改用管線收集日誌後批次寫入（Batch Write），取代原本的 `System.Threading.Monitor` 鎖定機制，徹底解決檔案佔用 (File Lock) 衝突並減少 I/O。

### ✨ Features (新功能)
- **Smart Filtering**: 所有批次腳本新增智慧過濾功能，自動跳過：
    - Private (私有) 專案
    - Fork (分支) 專案
    - Description 以 `✅` 開頭的已完成專案
- **Auto-Switch Account**: 腳本啟動時自動讀取 `.env` 並切換 `gh` 帳號。
- **Auto-Heal**: `batch_git_status.ps1` 新增自動還原機制，針對 `setup_git_sync.ps1` 與 `.python-version` 的環境雜訊自動執行 `checkout/clean`。

### ♻️ Refactor (重構)
- **Directory Structure**: 規範化目錄結構：
    - `logs/`: 集中存放所有日誌。
    - `ini/`: 存放 `accounts.ini` 與 `projects.ini` 設定檔。
    - `out/`: 存放導出的專案清單 (`extracted_projects.ini`)。
    - `temp/`: 存放 `setup_git_sync.ps1.example` 等中間範本。
- **Documentation**: 建立 `GEMINI.md` 作為 AI Agent 協作指南；統一所有腳本的標頭註解與啟動提示。

## [1.0.0] - Initial Release
- 基礎批次管理功能 (Create, Pull, Status, Remote Check)。
