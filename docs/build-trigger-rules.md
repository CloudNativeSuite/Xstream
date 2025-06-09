# ✅ 构建触发规则说明（Build Trigger Rules）

本项目构建流程由 GitHub Actions 自动控制，触发规则如下：

---

## ✅ 自动触发条件

| 场景 | 条件 | 是否触发构建 | 用途 |
|------|------|----------------|------|
| 1️⃣ 推送 Tag | Tag 以 `v*` 开头，例如 `v0.1.4` | ✅ 是 | 发布构建（如上传 Release 包） |
| 2️⃣ 手动触发 | GitHub Actions 页面中点击 `Run workflow` | ✅ 是 | 调试 / 手动验证 / Release 前重构 |
| 3️⃣ Pull Request 触发 | PR 合并目标为 `main`，且包含关键路径变更：<br/>`lib/**`, `macos/**`, `linux/**`, `windows/**`, `assets/**`, `pubspec.*` | ✅ 是 | 代码变更构建验证（CI 检查） |

---

## ❌ 不触发构建的情况

| 场景 | 是否触发 | 说明 |
|------|------------|------|
| 直接 `push` 到 `main` 分支 | ❌ 否 | `main` 为受保护分支，不接受直接推送 |
| PR 仅修改非关键路径（如 `README.md`、`docs/`） | ❌ 否 | 避免无效构建资源浪费 |

---

## 🛠 对应配置片段（`.github/workflows/build-and-release.yml`）

```yaml
on:
  push:
    tags:
      - 'v*'

  pull_request:
    branches:
      - main
    paths:
      - 'lib/**'
      - 'assets/**'
      - 'pubspec.*'
      - 'macos/**'
      - 'linux/**'
      - 'windows/**'
      - '.github/workflows/build-and-release.yml'

  workflow_dispatch:
