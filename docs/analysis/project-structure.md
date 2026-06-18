# Project Structure

## 概览

Shark 是一个 SwiftUI macOS 应用，工程主体在 `Shark/`，发布和网站相关文件分散在根目录、`.github/workflows/`、`scripts/`、`docs/`。

## 主要目录

| 路径 | 作用 |
|---|---|
| `Shark/SharkApp.swift` | App 入口、Settings scene、窗口生命周期管理 |
| `Shark/ContentView.swift` | 根视图，挂载 `MainWorkspaceView` 和 toast |
| `Shark/Models/` | Workspace、Folder、Cursor/Claude workspace file、VenomDependency 数据模型 |
| `Shark/Utilities/` | 权限、设置、workspace CRUD、外部 app 打开器、Git、Venomfiles、更新检查 |
| `Shark/Views/` | 主界面、workspace/folder 列表、组件选择器、依赖弹窗、Git 面板、设置 |
| `scripts/build-tool.ts` | 本地 DMG 和 npm 发布工具 |
| `.github/workflows/` | GitHub Release 构建和 Pages 部署 |
| `docs/` | Jekyll 官网 |

## 结构观察

- `Views` 中多个文件同时包含主 view、row view、sheet view 和业务副作用，例如 `WorkspaceListView.swift`、`FolderListView.swift`、`ComponentGitPanel.swift`。
- 部分通用 UI 组件未接线到主流程，例如 `ComponentSearchFilter.swift` 和 `ComponentValidationView.swift`。
- `Utilities` 承担了很多平台集成逻辑，整体边界清晰，但部分 UI 仍直接执行文件系统和 Git 相关逻辑。

## 优化建议

- 将 `WorkspaceRow`、`FolderRow`、`GitReferenceBadge`、`GitActionButton` 等拆到独立文件。
- 为 workspace/folder 列表引入轻量 view model，把文件系统、权限、保存逻辑从 view body 旁边移走。
- 清理未使用组件，或把主搜索和 Quick Open 正式接线。
