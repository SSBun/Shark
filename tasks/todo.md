# Virtual Folder Workspace 重构

## 假设
- 目标：移除 Cursor workspace 类型，只保留单一 virtual folder workspace 模型。
- virtual folder 是真实目录，目录内包含项目/组件目录的符号链接和元数据文件。
- 这个模型应保持 agent/IDE 无关，因为普通工具只需要打开这个目录即可。
- 不迁移旧 `.code-workspace` 文件；旧类型从模型、UI、扫描、打开逻辑中移除。

## 计划
- [x] 梳理 Cursor/Claude workspace 类型影响面。
- [x] 明确旧 `.code-workspace` 行为：不再扫描、创建、导入或打开。
- [x] 提出并确认设计：使用单一 virtual folder 模型。
- [x] 写入设计规格文档。
- [x] 写入实施计划和验证步骤。
- [x] 添加最小回归检查脚本。
- [x] 删除 Cursor workspace 类型和 `.code-workspace` 相关逻辑。
- [x] 将 Claude-specific workspace 文件泛化为 `VirtualWorkspaceFile`。
- [x] 更新 UI：移除类型选择、导入、类型分组、duplicate conversion 和 IDE 默认设置。
- [x] 更新 README / CHANGELOG 的相关行为说明。
- [x] 运行静态清理脚本。
- [x] 运行 macOS Debug 构建。

## 执行记录
- 新增 `VirtualWorkspaceFile`，元数据文件为 `.shark-workspace.json`。
- `Workspace` 不再持有 `WorkspaceType`，`filePath` 统一表示虚拟工作区目录。
- `WorkspaceManager` 只扫描包含 `.shark-workspace.json` 的目录，只创建 virtual workspace。
- `MainWorkspaceView` 只读写 virtual workspace 元数据和符号链接。
- `WorkspaceListView` 移除了 workspace 类型入口、导入入口和类型分组。
- `WorkspaceOpener` 改为打开虚拟工作区目录。
- 旧 virtual workspace 的 `.claude-workspace.json` 仍可被扫描和读取；后续保存会写入新的 `.shark-workspace.json`。
- `SettingsView` 移除了默认 IDE 配置。

## 验证
- `bash scripts/verify-virtual-workspace.sh` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 已完成实现和验证。
- 构建中仍有既有 warning：`SettingsView.swift` 的 `allowedFileTypes` 已废弃、`AlertManager.swift` 有未使用变量；这两个不属于本次 virtual folder 重构范围。

# SwiftUI 结构优化

## 计划
- [x] 提交 virtual folder 重构现有改动。
- [x] 添加最小结构检查脚本。
- [x] 引入 `@MainActor @Observable` 的 `WorkspaceStore`。
- [x] 简化 `MainWorkspaceView`，让它只负责布局和 presentation。
- [x] 让 `WorkspaceListView` 通过 store 执行动作，移除 workspace manager glue。
- [x] 运行结构检查、virtual workspace 检查和 Debug 构建。

## 验证
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `bash scripts/verify-virtual-workspace.sh` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

# Codex Sessions 面板

## README / CHANGELOG 更新

### 假设
- README 需要反映当前 virtual folder、Codex sessions、workspace health 功能。
- CHANGELOG 的 1.10.0 之后改动放在 Unreleased。
- 文档必须使用中文。

### 计划
- [x] 更新 README，移除旧导入说明并补充新功能。
- [x] 更新 CHANGELOG 的 Unreleased。
- [x] 运行文档相关检查。

### 验证
- `bash scripts/verify-virtual-workspace.sh` 通过。
- `git diff --check` 通过。
- README 已移除旧 import / `.code-workspace` / UserDefaults metadata 描述。

### Review
- README 已更新为当前 virtual folder、Codex sessions、Codex hooks 和 workspace health 功能说明。
- CHANGELOG 的 Unreleased 已记录 session 时间分组、workspace health 和 README 更新。

## Workspace Health 菜单入口

### 假设
- 入口放在 workspace 右键菜单。
- 本次先实现检查结果 sheet，不做自动修复。
- 菜单项需要带图标，符合现有 context menu 样式。

### 计划
- [x] 在 workspace context menu 增加 `Check Health...` 图标菜单项。
- [x] 增加当前 workspace 的最小 health report。
- [x] 运行 SwiftUI 结构检查和 Debug 构建。

### 验证
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

### Review
- Workspace 右键菜单新增带 `stethoscope` 图标的 `Check Health...`。
- Sheet 显示 workspace directory、metadata、linked folders、symlinks、unexpected symlinks、Codex hooks 状态。
- 暂不做修复动作，先只读检查。

### 后续计划
- [x] 增加 `Recreate Symlinks` 修复动作。
- [x] 增加 `Remove Missing Links` 修复动作，并在写 metadata 前确认。
- [x] 修复后刷新 health report。

### 后续验证
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Codex Session 时间分组

### 假设
- “active date” 使用 session 的 `updatedAt`。
- 只分组 active sessions；archived sessions 保持原来的折叠分组。
- 分组为 8 小时内、2 天内、1 周内、更早。

### 计划
- [x] 在 `CodexSessionListView` 内按 `updatedAt` 分组 active sessions。
- [x] 保持多选、右键菜单和 archived 折叠行为不变。
- [x] 更新 Codex sessions UI 检查并运行验证。

### 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

### Review
- Active Codex sessions 现在按 `updatedAt` 分为 Last 8 Hours、Last 2 Days、Last Week、Older。
- Archived sessions 继续保持原来的折叠分组。

## Codex Session 显示名

### 假设
- 只修改 Shark 内展示名，不写 Codex 私有 sqlite。
- 显示名保存到 workspace 的 `.shark-workspace.json`。
- 空显示名表示回退到 Codex 原始标题。

### 计划
- [x] 在 virtual workspace 元数据中增加 Codex session display name 字段。
- [x] 加载 Codex sessions 时优先使用 workspace 保存的 display name。
- [x] 在 session context menu 增加 Rename Display Name。
- [x] 更新最小验证脚本并运行验证。

### 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

### Review
- Codex session display name 现在保存到 workspace 的 `.shark-workspace.json`。
- 列表标题优先使用 Shark display name，空值回退到 Codex 原始标题。
- 只支持单个 session 改名；批量改名没有明确语义，先不做。

## 假设
- 目标：在选中的 workspace 详情区域中增加 Codex sessions 列表。
- UI 采用已确认的方案 1：右侧区域上下分割，上方 folders，下方 Codex Sessions。
- Codex session 来源为本机 `~/.codex/sessions` 和 `~/.codex/archived_sessions` 的 `.jsonl` 文件。
- session 是否属于当前 workspace：匹配 session metadata 的 `cwd` 是否位于 workspace 目录或当前 workspace folders 路径下。
- 先实现只读列表和基础动作，不实现搜索、筛选、恢复会话等扩展功能。

## 计划
- [x] 检查 Codex session 文件格式和索引文件。
- [x] 添加最小回归检查脚本。
- [x] 新增 `CodexSession` 模型。
- [x] 新增 `CodexSessionManager`，读取 session metadata 和 `session_index.jsonl`。
- [x] 新增 `CodexSessionListView`。
- [x] 在 `WorkspaceStore` 中维护 sessions 状态并随 workspace/folders 刷新。
- [x] 将 `MainWorkspaceView` 右侧改为 `VSplitView`：folders + sessions。
- [x] 提供 Open、Show in Finder、Copy Path 基础动作。
- [x] 运行 Codex sessions UI 检查。
- [x] 运行 SwiftUI 结构检查。
- [x] 运行 macOS Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 已实现右侧下方面板展示 Codex sessions。
- 当前只读取 session metadata 的第一行和 `session_index.jsonl`，避免全文扫描 session 内容。
- 刻意未加入搜索、过滤、恢复会话能力；等列表数量和使用方式明确后再加。

# Codex Sessions 信息补全

## 假设
- Codex App 的列表标题优先来自最新的 `~/.codex/state_5.sqlite` 或 `~/.codex/sqlite/state_5.sqlite` 的 `threads.title`，为空时回退到 `first_user_message` / `preview`。
- archived 状态优先来自 `threads.archived`，缺失时根据文件是否位于 `archived_sessions` 判断。
- 只补全列表所需信息：标题、archived 状态、source/model；不读取完整对话内容。

## 计划
- [x] 扩展 `CodexSession` 模型保存 archived/source/model。
- [x] 让 `CodexSessionManager` 优先读取 Codex sqlite threads。
- [x] 在 session 行显示 archived 状态和 source/model。
- [x] 更新最小验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 列表标题现在优先使用最新 Codex App sqlite 的 `threads.title`，空标题时回退到 `first_user_message` / `preview` / `session_index.jsonl` 的 `thread_name`，最后才显示 id。
- archived 状态优先使用 sqlite `threads.archived`，缺失时按 `archived_sessions` 路径判断。
- 未加入全文摘要或恢复会话能力，避免扫描完整 jsonl。

# Codex Sessions Loading 卡住修复

## 假设
- loading 一直显示，是因为 sqlite 子进程 stdout pipe 写满后，`waitUntilExit()` 永远等不到退出。
- `isLoadingCodexSessions` 应使用 `defer` 重置，避免正常失败路径留下 loading 状态。

## 计划
- [x] 调整 sqlite 读取顺序：先读取 stdout 到 EOF，再 `waitUntilExit()`。
- [x] 给 `loadCodexSessions()` 添加 `defer` 重置 loading。
- [x] 运行 Codex sessions 检查、SwiftUI 结构检查和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 根因：sqlite 子进程输出很大，先 `waitUntilExit()` 会让 stdout pipe 写满后互相等待。
- 修复：先 `readDataToEndOfFile()` drain stdout，再 `waitUntilExit()`；loading 状态用 `defer` 清理。

# Codex Sessions Archived 折叠分组

## 假设
- Active sessions 保持直接展示。
- Archived sessions 默认收起到一个可展开分组。
- 不新增搜索、筛选或持久化展开状态。

## 计划
- [x] 在 `CodexSessionListView` 内部分离 active/archived sessions。
- [x] 用默认折叠的 `DisclosureGroup` 展示 archived sessions。
- [x] 更新最小验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- Active sessions 仍直接显示。
- Archived sessions 现在放在默认折叠的 `Archived Sessions (count)` 分组里。
- 未持久化展开状态，避免增加不必要设置。

# Codex Sessions Resume 菜单

## 假设
- 不再显示 session 行右侧跳转图标。
- Resume 使用当前设置的 terminal 执行 `codex resume <session_id>`。
- Context menu 需要新增 `Resume in Terminal` 和 `Copy Session ID`。

## 计划
- [x] 给 `TerminalOpener` 增加最小命令执行入口。
- [x] 在 `WorkspaceStore` 增加 resume 和 copy session id 动作。
- [x] 更新 `CodexSessionListView`：移除右侧跳转按钮，新增 context menu。
- [x] 更新验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 移除了 session 行右侧跳转按钮。
- Context menu 新增 `Resume in Terminal`，使用当前设置的 terminal 执行 `codex resume <session_id>`。
- Context menu 新增 `Copy Session ID`。

# Codex Sessions 多选操作

## 假设
- 移除 context menu 里的 `Open`。
- 支持多选 session。
- 右键菜单对当前选中项批量执行 `Resume in Terminal`、`Archive`、`Delete`。
- `Delete` 是永久删除，需要确认。

## 计划
- [x] 在 `CodexSessionListView` 增加 `List(selection:)` 多选状态。
- [x] Context menu 使用选中项作为批量目标。
- [x] 在 `WorkspaceStore` 增加批量 resume/archive/delete。
- [x] 更新验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `codex archive --help` 和 `codex delete --help` 确认 CLI 支持对应命令。
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- Codex session context menu 已移除 `Open`。
- Session 列表支持多选；右键已选中项时，`Resume in Terminal`、`Archive`、`Delete` 会对全部选中项生效。
- `Delete` 先弹出 App 级确认，再执行 `codex delete --force <session_id>`，避免后台 CLI 卡在二次确认。

# Codex Session 终端运行态

## 假设
- 只需要识别 Codex CLI session 是否正在 Terminal 里运行。
- 运行态来自本机进程打开的 session jsonl 文件和 tty。
- 双击 cell 优先跳转到当前设置终端里对应 tty 的窗口/标签；暂不做跨所有终端的复杂窗口枚举。

## 计划
- [x] 新增运行态模型和检测工具。
- [x] 加载 sessions 时合并运行态。
- [x] 列表 cell 增加状态点并支持双击跳转。
- [x] 更新验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- Session 运行态通过 `ps` + `lsof` 读取正在打开的 Codex rollout jsonl 文件并映射到 tty。
- Cell 左侧绿色状态点表示正在 terminal 中运行，灰点表示未运行。
- 双击正在运行的 session 会按 tty 尝试激活 Terminal/iTerm2 对应 tab；其他 terminal 先只激活应用。

# Codex Session 跳转图标

## 假设
- 单击行应保持 List 原生选择行为。
- 只有正在 terminal 运行的 session 需要显示跳转图标。
- 图标点击执行已有 terminal tab 激活动作。

## 计划
- [x] 移除 row 双击手势。
- [x] 为 active runtime session 增加跳转图标按钮。
- [x] 更新验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 移除了 session row 的双击手势，避免影响 `List(selection:)` 的单击选择。
- 只有正在 terminal 运行的 session 显示跳转图标。
- 点击跳转图标会调用已有 tty 激活逻辑跳到活跃 terminal tab。

# Codex Session 跳转日志

## 假设
- 点击跳转无反馈，需要日志覆盖 UI 点击、store 分发、终端激活、AppleScript 返回值和错误。
- 日志使用现有 `Log`，会进入 `/Users/caishilin/.venom/logs/Shark.log`。
- 顺手兼容 tty 的 `/dev/ttys013` 与 `ttys013` 两种 AppleScript 表达。

## 计划
- [x] 在跳转按钮 action 添加点击日志。
- [x] 在 `WorkspaceStore.activateCodexSessionTerminal` 添加 session/tty 日志。
- [x] 在 `TerminalOpener.activateTerminalTab` 和 AppleScript 执行结果添加日志。
- [x] 在 runtime detector 添加识别结果日志。
- [x] 更新 lesson 和验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 跳转链路现在会输出 `[TerminalJump]` 日志：按钮点击、session id、tty、目标 terminal app、AppleScript result/error、fallback。
- 运行态扫描会输出 `[CodexRuntime]` 日志：扫描进程数、识别到的 session/pid/tty、最终状态数量。
- AppleScript tty 匹配同时尝试 `/dev/ttysxxx` 和 `ttysxxx`，避免不同终端返回格式不一致。

# Codex Session 终端跳转权限修复

## 假设
- 日志中的 `-1743 Not authorized to send Apple events to iTerm` 是跳转无效的直接原因。
- 需要给生成的 Info.plist 增加 `NSAppleEventsUsageDescription`。
- Hardened Runtime 下需要 Apple Events entitlement。

## 计划
- [x] 增加 Apple Events usage description。
- [x] 增加 Apple Events automation entitlement。
- [x] 运行验证和 Debug 构建。
- [x] 说明已有拒绝权限时的系统设置处理方式。

## 验证
- 从 `/Users/caishilin/.venom/logs/Shark.log` 确认跳转失败原因为 `NSAppleScriptErrorNumber = "-1743"`，即 Apple Events 未授权。
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 已为生成的 Info.plist 增加 `NSAppleEventsUsageDescription`，用于系统弹出自动化权限提示。
- 已为 hardened runtime 增加 `com.apple.security.automation.apple-events` entitlement。
- 如果本机已拒绝过权限，需要在系统设置中允许 Shark 控制 iTerm/Terminal，或重置 Apple Events 权限后重试。

# Codex Session 移除危险跳转

## 假设
- AppleScript/Automation 跳转 terminal tab 会触发系统级输入法/光标异常，必须先移除入口。
- 保留运行状态点即可，用户仍可看到 session 是否运行中。
- 不再申请 Apple Events 权限，避免触发 TCC/Automation 路径。

## 计划
- [x] 移除 Codex session row 跳转按钮。
- [x] 移除 Codex session terminal activation 回调链路。
- [x] 移除本次为跳转添加的 Apple Events Info.plist 和 entitlement。
- [x] 更新验证脚本，禁止 Codex jump/TerminalJump 路径。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 已移除 Codex session 的危险 terminal tab 跳转按钮。
- 已移除 Codex session 专用 `TerminalJump` 回调链路和 Apple Events 权限配置。
- 保留运行状态点，只展示 session 是否在 terminal 中运行。

# Codex Session iTerm 标题跳转

## 假设
- 只支持 iTerm2，避免重新引入多终端 AppleScript 分支。
- Shark 启动的 Codex session 会设置唯一 tab title。
- 跳转只按 tab title 查找，不再按 tty/session id 枚举。
- 既有未通过 Shark 启动的 tab 可能没有标题，暂不处理。

## 计划
- [x] `resume` 时设置 iTerm tab title。
- [x] 增加按 title 跳转 iTerm tab 的最小方法。
- [x] 恢复运行中 session 的跳转按钮，但仅对 iTerm2 可用。
- [x] 补回 Apple Events 权限配置。
- [x] 更新验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- `Resume in Terminal` 现在会先设置 tab title：`Codex <session-id-prefix>`。
- 跳转按钮使用 iTerm2 AppleScript 按 tab title 精确选择，不再按 tty 或 session id 枚举。
- 既有不是通过 Shark 启动的 Codex tab 不一定有该 title，可能无法跳转。

# Codex Session iTerm TTY 跳转

## 假设
- 不能用 tab title 匹配 session；同一个 tab 可能连续运行多个 Codex session。
- CodeIsland 的关键做法是保存终端稳定标识，如 iTerm session id 或 tty。
- Shark 目前没有 hook 采集 `ITERM_SESSION_ID`，但运行态检测已经能从进程拿到 tty。
- 最小正确实现：删除 title-based 路径，按运行中 session 的 tty 选择 iTerm2 tab。

## 计划
- [x] 参考 CodeIsland 的 iTerm tty fallback 逻辑。
- [x] 移除 `Resume in Terminal` 设置 tab title。
- [x] 将跳转改为 `tty of session` 匹配。
- [x] 更新验证脚本，禁止 title-based 匹配。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 已删除 tab title 作为 Codex session 身份的实现。
- `Resume in Terminal` 现在只执行 `codex resume <session_id>`，不再写 terminal title。
- 运行中 session 的 jump 按钮现在使用进程运行态里的 tty，通过 iTerm2 `tty of session` 选择对应 tab/session。
- 未引入 CodeIsland 的 hook/IPC 架构；等需要跨终端或 iTerm session id 级别精确匹配时再加。

# Codex Hooks 设置注入

## 假设
- 目标是在 Settings 页面提供一个按钮，让用户把 Shark 的 Codex hook 注入 Codex 配置。
- 使用官方支持的 `~/.codex/hooks.json`，不修改 `config.toml`。
- 最小事件集：`SessionStart` 记录终端标识，`Stop` 标记 inactive，`PreToolUse` / `PostToolUse` 刷新 lastSeen。
- helper 写本地快照到 Shark App Support，Shark session runtime 优先读取快照，再用现有 `lsof` 扫描兜底。
- 不实现卸载、hook trust UI 或 socket server；用户仍需在 Codex `/hooks` 中信任新 hook。

## 计划
- [x] 新增 Codex hook installer：生成 helper 脚本并合并 `~/.codex/hooks.json`。
- [x] 新增 runtime snapshot 读取，支持 iTerm session id 和 tty。
- [x] Settings Terminal tab 增加 Codex Hooks 安装入口和状态文案。
- [x] iTerm 跳转优先用 `unique ID of session`，再用 tty。
- [x] 更新验证脚本并运行构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- Settings 的 Terminal tab 新增 Codex Hooks 安装入口。
- 安装会生成 `~/Library/Application Support/Shark/codex-session-hook`，并把 `SessionStart`、`Stop`、`PreToolUse`、`PostToolUse` 注入 `~/.codex/hooks.json`。
- helper 将 session runtime 快照写入 `~/Library/Application Support/Shark/CodexSessionRuntime`。
- Session 跳转现在优先用 hook 捕获的 iTerm session id，再回退到 tty 和现有 `lsof` 检测。
- 未实现卸载、socket server 和 hook trust 管理；Codex 要求时仍需用户在 `/hooks` 中信任。
