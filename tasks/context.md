# Workspace Context

## Workspace
- `WorkspaceGitStatusStore` 按 repository path 保存会话级内存缓存；切回 workspace 时复用已成功加载的状态，只扫描缺失项，显式 local/fetch refresh 会绕过缓存，unavailable 结果不缓存。
- Folder cells 和 Workspace Git Overview 共用 `WorkspaceGitStatusStore`；folder cell 将最新已知 Git tag、working-tree 状态和 upstream 状态单行放在右侧、删除按钮左边。
- Git 状态使用 `git status --porcelain=v2 --branch` 解析 staged、modified、untracked、conflict、ahead/behind/diverged；初次只读本地 tracking refs，用户点击 `Fetch & Refresh` 才更新远端 branches/tags，并标记 Cached、Fetched 或 Fetch Failed。
- Codex session 刷新先用 SQLite thread records + JSONL delta fallback 发布 metadata，再用一次批量 `lsof` 补充 runtime；同 workspace 重刷也通过 load ID 丢弃旧结果。
- 当前 2,500+ 全局 session 数据下，metadata 约 0.16 秒、runtime 约 0.32 秒，完整刷新约 0.48 秒；行为/性能检查为 `scripts/verify-codex-session-refresh.sh`。
- Codex session 刷新性能研究记录在 `docs/research/codex-session-refresh-performance.md`；优化前主瓶颈是逐 PID 串行 `lsof`，其次是打开全部 JSONL 首行。
- Workspace 选择的稳定 ID 改变时会立即清空 Codex session 列表；后台扫描提交前会核对当前 workspace ID，避免旧结果覆盖新选择。
- Shark 是原生 macOS SwiftUI 应用；npm 包装包名为 `@ssbun/sharkspace`。
- 双击 Codex session cell 会打开单个可复用的预览窗口，展示首条用户消息和最近 8 条 user/assistant 消息；单击与 Command 多选保持不变。
- Workspace 是真实目录、`.shark-workspace.json` 元数据和项目目录 symlink 组成的 agent/IDE 无关 virtual folder。
- 主界面同时管理 workspace folders 与匹配该 workspace 的本地 Codex sessions；支持运行态识别、恢复和 iTerm2 跳转。
- Workspace health 可检查 metadata、缺失 folder、symlink 与 Codex hooks，并执行有限修复。

## Decisions and Conventions
- npm 包只发布 `install.js` 和 README；版本化 DMG 由 GitHub Release 提供，安装脚本按 `package.json.version` 下载。
