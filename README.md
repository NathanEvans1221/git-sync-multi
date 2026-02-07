# git-sync-multi
批次管理多個 Git 專案的同步與備份工具。

## 🛠️ 工具清單

### 1. batch_git_pull.ps1 (批次更新)
自動掃描指定目錄下的所有子資料夾，若發現為 Git 倉庫，則自動執行 `git pull` 以同步遠端更新。

#### 使用方法
- 在 PowerShell 中執行：
  ```powershell
  ./batch_git_pull.ps1
  ```
- **錯誤記錄**：若執行過程中發生錯誤，將會記錄在 `git_pull_errors.log` 中。

---

### 2. batch_create_git_sync.ps1 (批次初始化)
批次為每個子目錄建立 `setup_git_sync.ps1` 同步設定腳本。

#### 功能說明
- 掃描 `ROOT_PATH` 下的所有子目錄。
- 若目錄中尚未存在 `setup_git_sync.ps1`，則會根據 `setup_git_sync.ps1.example` 範本產生檔案。
- 自動將範本中的 `PROJECT_NAME` 替換為實際的資料夾名稱。

#### 使用方法
- 在 PowerShell 中執行：
  ```powershell
  ./batch_create_git_sync.ps1
  ```

---

## ⚙️ 環境配置 (.env)
請複製 `.env.example` 並更名為 `.env`，設定以下變數：

| 變數名稱 | 說明 | 範例 |
| :--- | :--- | :--- |
| `ROOT_PATH` | 所有 Git 專案的父目錄路徑 | `D:\github\chiisen\` |

---

## 📄 檔案結構
- `batch_git_pull.ps1`: 批次執行 `git pull` 的主腳本。
- `batch_create_git_sync.ps1`: 批次建立同步設定的輔助腳本。
- `setup_git_sync.ps1.example`: `setup_git_sync.ps1` 的內容範本。
- `.env`: 環境變數設定檔。

