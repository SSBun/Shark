# Workspace Context

## Project Core

### Purpose
- Shark 是原生 macOS 虚拟工作区管理器，用真实目录和符号链接组织项目文件夹。（来源：`README.md`「技术细节」）

### Global Vocabulary
- Workspace 指包含项目 symlink 和 `.shark-workspace.json` metadata 的普通目录；Codex sessions 是与 workspace 关联的本地会话。（来源：`README.md`「Workspace 管理」「Codex Sessions」）

### System Map
- `Shark/SharkApp.swift` 的 `SharkApp` 提供主窗口、Settings 和 Codex session 预览窗口；主界面展示 workspace、folders 和 sessions。（来源：`Shark/SharkApp.swift` `body`；`README.md`「清晰的 macOS 界面」）

### Global Invariants
- Workspace metadata 本地存储，应用偏好使用 UserDefaults；workspace 可被终端和 IDE 作为普通目录打开。（来源：`README.md`「技术细节」「面向 Agent 工具的工作区」）

## Workspace
- `WorkspaceGitStatusStore` 按 repository path 保存会话级内存缓存；切回 workspace 时复用已成功加载的状态，只扫描缺失项，显式 local/fetch refresh 会绕过缓存，unavailable 结果不缓存。
- Folder cells 和 Workspace Git Overview 共用 `WorkspaceGitStatusStore`；folder cell 将最新已知 Git tag、working-tree 状态和 upstream 状态单行放在右侧、删除按钮左边。
- Git 状态使用 `git status --porcelain=v2 --branch` 解析 staged、modified、untracked、conflict、ahead/behind/diverged；初次只读本地 tracking refs，用户点击 `Fetch & Refresh` 才更新远端 branches/tags，并标记 Cached、Fetched 或 Fetch Failed。
- Codex session 刷新先用 SQLite thread records + JSONL delta fallback 发布 metadata，再用一次批量 `lsof` 补充 runtime；同 workspace 重刷也通过 load ID 丢弃旧结果。
- 当前 2,500+ 全局 session 数据下，metadata 约 0.16 秒、runtime 约 0.32 秒，完整刷新约 0.48 秒；行为/性能检查为 `scripts/verify-codex-session-refresh.sh`。
- Codex session 刷新性能研究记录在 `docs/research/codex-session-refresh-performance.md`；优化前主瓶颈是逐 PID 串行 `lsof`，其次是打开全部 JSONL 首行。
- Workspace 选择的稳定 ID 改变时会立即清空 Codex session 列表；后台扫描提交前会核对当前 workspace ID，避免旧结果覆盖新选择。
- Shark 是原生 macOS SwiftUI 应用；npm 包装包名为 `@ssbun/sharkspace`。
- Codex session cell 的右键 Preview 和辅助功能动作打开单个可复用的预览窗口；双击不再承担预览入口。来源：`Shark/Views/CodexSessionListView.swift` `CodexSessionRow`。
- Workspace 是真实目录、`.shark-workspace.json` 元数据和项目目录 symlink 组成的 agent/IDE 无关 virtual folder。
- 主界面同时管理 workspace folders 与匹配该 workspace 的本地 Codex sessions；支持运行态识别、恢复和 iTerm2 跳转。
- Workspace health 可检查 metadata、缺失 folder、symlink 与 Codex hooks，并执行有限修复。

## Decisions and Conventions
- GitHub tag release workflow 使用 Node 24，并通过 `npm ci --ignore-scripts` 安装构建依赖，避免 Release asset 创建前触发 npm 包面向最终用户的 DMG 下载 `postinstall`。
- Release DMG 由 `scripts/build-tool.ts` 生成到 `dist/SharkSpace-<version>_<timestamp>/`；本地与 GitHub workflow 共用该入口，release asset 固定命名为 `SharkSpace-<version>.dmg`，供 npm installer 按 package version 下载。
- npm 包只发布 `install.js` 和 README；版本化 DMG 由 GitHub Release 提供，安装脚本按 `package.json.version` 下载。

## CTX-project-ownership — Project 与虚拟工作区的文件所有权
- Scope: 项目引用与虚拟工作区的持久化、删除、重命名和目录读取边界。
- Paths: `Shark/Models/Workspace.swift`, `Shark/Utilities/WorkspaceManager.swift`, `Shark/Views/WorkspaceStore.swift`, `Shark/Views/WorkspaceListView.swift`
- Keywords: Project, WorkspaceKind, 外部目录, 删除, metadata, SourceTree
- Authority: `Shark/Models/Workspace.swift`, `Shark/Utilities/WorkspaceManager.swift`, `Shark/Views/WorkspaceStore.swift`
- Recheck: WorkspaceKind、移除/重命名入口、metadata 读写或 gitRepoPaths 改变时重新检查。

### Purpose and Boundaries
- `Workspace.kind == .project` 仅引用已有目录，不拥有其文件；`WorkspaceStore.removeWorkspace` 不删除 Project 目录，`WorkspaceManager.renameWorkspace` 只更新显示名。
- `.workspace` 使用 `.shark-workspace.json` 与 symlink；旧条目缺少 kind 时解码为 `.workspace`。Project 不读取或写入虚拟工作区 metadata，相关分支由 `WorkspaceStore` 管理。
- `WorkspaceManager.gitRepoPaths(for:)` 对 Project 检查项目目录本身；虚拟工作区则读取 metadata 中的 folders。不能把 Project 当作虚拟工作区解析。

## CTX-codex-session-visibility — 会话筛选与命令边界
- Scope: 会话 metadata/runtime 两阶段可见性、预览入口与会话操作。
- Paths: `Shark/Views/WorkspaceStore.swift`, `Shark/Views/CodexSessionListView.swift`, `Shark/Views/MainWorkspaceView.swift`, `Shark/Utilities/SettingsManager.swift`
- Keywords: subagent, 子代理, metadata, runtime, loadID, 归档, 取消归档, shell
- Authority: `Shark/Views/WorkspaceStore.swift`, `Shark/Views/CodexSessionListView.swift`, `Shark/Views/MainWorkspaceView.swift`, `Shark/Utilities/SettingsManager.swift`
- Recheck: 会话扫描/提交、筛选设置、选择生命周期或 CLI 调用路径改变时重新检查。

### Relationships
- `WorkspaceStore.loadCodexSessions` 在发布 metadata 前应用子代理过滤，再为相同可见集合补充 runtime；两次提交都核对 workspace ID 与 load ID。`MainWorkspaceView` 在应用激活或筛选设置通知时重新加载。
- `CodexSessionListView` 通过右键 Preview 和辅助功能动作触发预览；归档菜单向 `WorkspaceStore.setCodexSessions(_:archived:)` 传递明确目标状态，混合多选只处理状态需要变化的条目。垃圾桶仅处理当前可见列表的已归档项并复用永久删除确认。
- `WorkspaceStore.runCodexSessionCommand` 用登录交互式 zsh 获取用户 CLI 环境，命令参数通过位置参数传递；CLI help/构建只能证明接口与编译兼容，不能证明真实归档/删除副作用正确。
