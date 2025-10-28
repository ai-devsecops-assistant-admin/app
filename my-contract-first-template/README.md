# 📜 Contract-First Fullstack Template

> 契約驅動 · 克隆即跑 · Mock/Real 雙模式 · 可治理 Flow 引擎

## ✅ 特性
- 🔗 OpenAPI + JSON/YAML 契約為唯一真相
- 🎮 Flow 編排引擎（Go 實作）
- 🧪 內建 CRUD Mock API（GET/POST/:id）
- 🔄 前端支援切換 `mock` / `real` 模式
- 🐳 Docker Compose + Makefile
- 🛡️ CI/CD：校驗契約一致性 + 輕量 E2E 測試

## 🚀 快速啟動
```sh
make dev.up
```

| 服務 | URL |
|------|-----|
| Frontend | http://localhost:4200 |
| Mock API | http://localhost:8787/mock/v1/users |
| Artifact Repo | http://localhost:8787/repo/api/index.json |

## 🛠️ 開發命令
```sh
make gen.openapi     # 生成 OpenAPI 與 TS 型別
make validate.artifact # 校驗 flows/datasets 是否存在
make test.e2e        # 執行輕量 E2E 測試
make dev.down        # 關閉服務
```

## 🌱 使用 degit 初始化新專案
```sh
npx degit your-org/my-contract-first-template my-new-project
cd my-new-project && make init
```
