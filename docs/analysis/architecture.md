# Architecture

## 当前架构

Shark 采用 SwiftUI view + singleton service 的简单架构：

- `WorkspaceManager.shared` 管理 workspace 列表、扫描、创建、rename、duplicate、pin/reorder。
- `SettingsManager.shared` 管理 UserDefaults 设置、授权目录和默认外部 app。
- `AuthorizationManager.shared` 管理权限请求 sheet。
- `AlertManager.shared` 提供 toast/alert 反馈。
- 外部工具集成按 opener 拆分：`WorkspaceOpener`、`TerminalOpener`、`ForkOpener`、`SourceTreeOpener`、`XcodeOpener`。

## 优点

- 功能定位直接，文件名基本能表达职责。
- Cursor 与 Claude workspace 的数据模型有明确区分。
- 外部 app 打开器分离较好。

## 风险

- 多个 SwiftUI view 直接执行文件系统、权限、Git、解析和保存逻辑，测试困难。
- `WorkspaceListView`、`FolderListView`、`ComponentGitPanel` 体积偏大且多类型混放。
- `MainWorkspaceView` 通过 `onChange(of: folders)` 自动保存，副作用触发边界需要谨慎维护。

## 优化建议

- 引入 `WorkspaceListViewModel` 和 `FolderListViewModel`，先迁移错误反馈和异步加载，不做大规模重构。
- 把 Git/Venomfiles 扫描结果缓存策略集中到 service，避免 row appear 时重复同步磁盘读取。
- 把主窗口从 `HSplitView` 迁移到 `NavigationSplitView`，让 sidebar/detail 结构成为架构边界。
