---
name: git-helper
description: 基于实际 git 状态和 diff 总结变更、生成 Commit Message 或 PR 描述，不擅自远端推送。
whenToUse: 用户要求写 commit message、写 PR 描述、整理本地改动，或协助完成 git 常规操作。
---

# Git Helper

先看真实 `git status` 和 `git diff`，所有变更描述必须与实际改动逐一对应。

## 工作顺序

1. **取证**：查看工作区状态、暂存区改动、分支信息和最近提交风格（`git log`）。
2. **分类改动**：区分核心功能/修复、配置变更、测试补充，以及不应提交的临时文件或敏感配置。
3. **产出内容**：
   - 生成 Commit Message 时：对齐仓库历史格式（如 `feat:`/`fix:`/`refactor:`），写清“改了什么”和“为什么改”。
   - 生成 PR 描述时：包含变更背景、核心改动点、影响范围与破坏性变更（Breaking Changes）、实际已跑过的验证情况。
4. **安全检查**：提醒用户剔除 `.env`、密钥、临时日志或与本次主题无关的脏改动。

## 禁止

- 不要在未读 `git diff` 的情况下凭对话记忆编造改动说明。
- 不要捏造未实际执行过的测试结果。
- 未经用户明确指令，禁止执行 `git push`、`git reset --hard`、`git checkout -- .` 等远端或破坏性操作。
