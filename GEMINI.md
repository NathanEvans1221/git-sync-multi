# Project Context & Guidelines (GEMINI.md)

本文件紀錄 `git-sync-multi` 專案的開發規範、檔案路徑共識與運作邏輯，供 AI 代理人參考。

## 📂 目錄架構規範
所有腳本開發應遵循以下路徑約定：

- **`logs/`**: 所有日誌檔案 (`*.log`)、錯誤紀錄、與過程偵錯資料均應存放在此。
- **`ini/`**: 所有使用者設定檔 (`*.txt`, `*.ini`) 與對應的範本檔 (`*.example`) 均應存放在此。
- **`temp/`**: 存放中間過程所需的範本檔案或暫存資料（如 `setup_git_sync.ps1.example`）。
- **`out/`**: 腳本執行後的最終資料產出物（如導出的專案清單）應存放在此。
- **根目錄**: 僅存放核心腳本 (`*.ps1`) 為原則。

## 🏗️ 系統運作架構
本專案採用以下資料流向與並行處理邏輯：

```mermaid
graph TD
    ENV[.env] -->|1. 載入帳號 GITHUB_ACCOUNT| Script((*.ps1))
    INI[ini/*.txt, *.ini] -->|2. 讀取清單| Script
    Template[temp/*.example] -->|3. 讀取範本| Script
    
    subgraph Core Logic ["Parallel Processing (平行處理)"]
        Script -->|4. 分派任務| Thread1[Thread 1]
        Script -->|4. 分派任務| Thread2[Thread 2]
        Script -->|4. 分派任務| Thread3[Thread 3]
    end
    
    Thread1 -->|Buffer Data| MemoryBuffer
    Thread2 -->|Buffer Data| MemoryBuffer
    Thread3 -->|Buffer Data| MemoryBuffer
    
    MemoryBuffer -->|5. 批次寫入 (Batch Write)| Logs[logs/*.log]
    MemoryBuffer -->|5. 批次寫入 (Batch Write)| Out[out/*.ini]
    MemoryBuffer -->|5. 自愈還原 (Auto-Heal)| GitRepo[Git Repo]
```

## 🔐 運作特徵與習慣
開發或修改腳本時，請確保具備以下邏輯：

### 1. 腳本聲明與啟動說明
- **標頭註解**: 每個腳本最上方必須包含該腳本的功能簡述、主要作者與最後維護規範說明。
- **啟動提示**: 腳本開始執行時，必須先 `Write-Host` 輸出其在 `README.md` 中定義的核心功能描述，確保使用者明確知道即將執行的動作。

### 2. 啟動自我檢查
- **載入環境變數**: 啟動時必須優先執行 `Load-Env` 從 `.env` 取得配置。
- **切換 GitHub 帳號**: 若環境變數定義了 `GITHUB_ACCOUNT`，必須自動執行 `gh auth switch -u $GITHUB_ACCOUNT` 確保權限正確。

### 2. 智慧過濾 (Smart Filtering)
執行批次處理、狀態檢查或同步時，具備以下過濾共識（除非使用者另有要求）：
- **跳過 Private (私有)** 專案。
- **跳過 Fork (分支)** 專案。
- **跳過 已完成專案**: 若 GitHub Description 以 `✅` 開頭，視為已完成並過濾。
- **靜默處理**: 被過濾的項應記錄於 `logs/`，減少終端機干擾。

### 3. 效能優化與資源同步
- **平行處理判斷**: AI 代理人應自行判定任務特性。凡涉及大量網路等待（如 `git pull`、`gh repo view`）或批次磁碟操作，應優先使用 PowerShell 7 的 `ForEach-Object -Parallel` 進行優化。
    - **併發限制 (ThrottleLimit)**: 為避免觸發 GitHub API Rate Limit，預設併發數應設定為 **5** (保守設定)。
- **併發安全與寫入效率**: 執行平行處理時，若需寫入日誌 (Log) 等共用資源：
    - **優先使用 Memory Buffer**: 透過管線收回訊息，在平行區塊結束後再一次性批次寫入檔案。
    - **資源鎖定 (Lock)**: 若情境無法使用 Buffer，必須使用 `[System.Threading.Monitor]` 進行互斥鎖處理，嚴禁在平行執行緒中直接無保護地寫入同一個檔案。

### 4. 自動化自愈
- **自動復原雜訊**: 對於 `.python-version` 或 `setup_git_sync.ps1` 這類環境產生的唯一變動，腳本應具備自動執行 `git checkout` 或 `git clean` 以還原乾淨狀態的能力。
- **自動同步圖示**: 若異動僅包含 Windows 目錄圖示檔案 (`desktop.ini`, `folderico-green.ico`)，應自動執行 commit (訊息：`feat: 更新目錄 icon`) 與 pull。

---
*本文件將隨專案演進持續更新。*
