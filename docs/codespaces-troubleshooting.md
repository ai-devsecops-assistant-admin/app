# Codespaces 連線問題故障排除指南
# Codespaces Connection Issues Troubleshooting Guide

## 問題描述 (Problem Description)

如果您遇到以下問題：
- Codespaces 啟動失敗或崩潰
- 無法連線到 GitHub 帳號
- 進入 Codespaces 後無法登入帳戶
- Git 操作失敗，提示認證錯誤

If you encounter the following issues:
- Codespaces fails to start or crashes
- Cannot connect to GitHub account
- Cannot login after entering Codespaces
- Git operations fail with authentication errors

## 解決方案 (Solutions)

### 1. 使用新的 Devcontainer 配置 (Use New Devcontainer Configuration)

本專案現在包含完整的 `.devcontainer` 配置，可自動設定開發環境和處理 GitHub 認證。

This project now includes a complete `.devcontainer` configuration that automatically sets up the development environment and handles GitHub authentication.

**步驟 (Steps):**

1. 確保您在最新的分支上 (Ensure you're on the latest branch)
2. 刪除舊的 Codespace（如果存在）(Delete old Codespace if it exists)
3. 創建新的 Codespace (Create new Codespace)

### 2. GitHub CLI 認證 (GitHub CLI Authentication)

Codespaces 啟動後，您需要進行 GitHub 認證：

After Codespaces starts, you need to authenticate with GitHub:

```bash
gh auth login
```

**選擇以下選項 (Select these options):**
- What account do you want to log into? → **GitHub.com**
- What is your preferred protocol for Git operations? → **HTTPS**
- Authenticate Git with your GitHub credentials? → **Yes**
- How would you like to authenticate? → **Login with a web browser**

複製一次性代碼，然後在瀏覽器中完成認證。

Copy the one-time code and complete authentication in your browser.

### 3. 驗證認證狀態 (Verify Authentication Status)

```bash
gh auth status
```

您應該看到：
You should see:

```
✓ Logged in to github.com as [your-username]
✓ Git operations for github.com configured to use https protocol.
✓ Token: *******************
```

### 4. 配置 Git (Configure Git)

如果 Git 操作仍然失敗，請設定 Git 使用 HTTPS：

If Git operations still fail, configure Git to use HTTPS:

```bash
git config --global url."https://github.com/".insteadOf git@github.com:
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 5. 重建容器 (Rebuild Container)

如果問題持續存在：

If issues persist:

1. 按 `Cmd/Ctrl + Shift + P` 打開命令面板
2. 輸入並選擇：**Codespaces: Rebuild Container**
3. 等待容器重建完成
4. 重新執行 `gh auth login`

---

1. Press `Cmd/Ctrl + Shift + P` to open command palette
2. Type and select: **Codespaces: Rebuild Container**
3. Wait for container rebuild to complete
4. Re-run `gh auth login`

### 6. 手動運行設定腳本 (Manually Run Setup Script)

如果自動設定失敗：

If automatic setup fails:

```bash
bash .devcontainer/post-create.sh
```

## 常見錯誤訊息 (Common Error Messages)

### Error: "fatal: could not read Username for 'https://github.com'"

**解決方案 (Solution):**
```bash
gh auth login
```

### Error: "Permission denied (publickey)"

**解決方案 (Solution):**
```bash
# 改用 HTTPS 而不是 SSH
git config --global url."https://github.com/".insteadOf git@github.com:
gh auth login
```

### Error: "Failed to connect to github.com"

**檢查事項 (Check):**
1. 網路連線是否正常 (Network connection is working)
2. Codespace 是否正在運行 (Codespace is running)
3. 嘗試重新啟動 Codespace (Try restarting Codespace)

### Error: "devcontainer.json: command not found"

**解決方案 (Solution):**

確保您的 Codespace 使用了本專案的 `.devcontainer` 配置。如果沒有，請：

Ensure your Codespace is using this project's `.devcontainer` configuration. If not:

1. 刪除當前的 Codespace
2. 確保最新代碼已推送到 GitHub
3. 創建新的 Codespace

## 預防措施 (Prevention)

### 定期更新 Token (Regularly Update Token)

GitHub token 會過期。定期檢查認證狀態：

GitHub tokens expire. Regularly check authentication status:

```bash
gh auth status
```

如果顯示過期，重新登入：

If expired, login again:

```bash
gh auth refresh
```

### 使用正確的協議 (Use Correct Protocol)

始終使用 HTTPS 進行 Git 操作：

Always use HTTPS for Git operations:

```bash
git config --global url."https://github.com/".insteadOf git@github.com:
```

### 保持 Codespace 更新 (Keep Codespace Updated)

定期重建容器以獲取最新的工具和配置：

Regularly rebuild container to get latest tools and configurations:

**Command Palette** → **Codespaces: Rebuild Container**

## 其他資源 (Additional Resources)

- [GitHub Codespaces 官方文檔](https://docs.github.com/en/codespaces)
- [GitHub CLI 文檔](https://cli.github.com/manual/)
- [Devcontainer 規範](https://containers.dev/)
- [專案 Devcontainer 文檔](.devcontainer/README.md)

## 需要幫助？(Need Help?)

如果以上方法都無法解決問題：

If none of the above solutions work:

1. 查看 [.devcontainer/README.md](./.devcontainer/README.md) 獲取詳細資訊
2. 查看 GitHub Codespaces 日誌以了解錯誤詳情
3. 在專案中創建 Issue，包含：
   - 錯誤訊息的完整內容
   - 您嘗試過的解決步驟
   - Codespaces 建立日誌（如果可用）

---

1. Check [.devcontainer/README.md](./.devcontainer/README.md) for detailed information
2. Review GitHub Codespaces logs for error details
3. Create an Issue in the project including:
   - Full error message
   - Steps you've tried
   - Codespaces creation logs (if available)

## 檢查清單 (Checklist)

使用此清單確保正確設定：

Use this checklist to ensure proper setup:

- [ ] 已創建新的 Codespace（使用最新配置）
- [ ] 已執行 `gh auth login` 並完成認證
- [ ] `gh auth status` 顯示已登入
- [ ] Git 配置正確（`git config --list | grep github`）
- [ ] 可以執行 `make help` 而不出錯
- [ ] 所有必要工具已安裝（運行 `.devcontainer/post-create.sh` 查看）

---

- [ ] Created new Codespace (with latest configuration)
- [ ] Ran `gh auth login` and completed authentication
- [ ] `gh auth status` shows logged in
- [ ] Git configured correctly (`git config --list | grep github`)
- [ ] Can run `make help` without errors
- [ ] All required tools installed (run `.devcontainer/post-create.sh` to check)
