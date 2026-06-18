# Virtual Folder Workspace 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 删除 Cursor workspace 类型，只保留 virtual folder workspace。

**架构：** 复用现有 Claude workspace 的目录+metadata+symlink 机制，改成中性命名。删除 `.code-workspace` 读写分支和 Cursor/Claude 类型选择 UI。

**技术栈：** SwiftUI、Foundation、AppKit、xcodebuild。

---

### Task 1: 数据模型和存储

**文件：**
- 修改：`Shark/Models/Workspace.swift`
- 修改：`Shark/Models/ClaudeWorkspaceFile.swift`
- 删除：`Shark/Models/CursorWorkspaceFile.swift`
- 修改：`Shark/Utilities/WorkspaceManager.swift`
- 修改：`Shark/Utilities/SettingsManager.swift`

- [ ] 把 `Workspace` 改成无类型目录模型。
- [ ] 把 `ClaudeWorkspaceFile` 泛化为 `VirtualWorkspaceFile`。
- [ ] 只扫描 `.shark-workspace.json` 目录，忽略 `.code-workspace`。
- [ ] 删除 duplicate Cursor/Claude 转换。

### Task 2: UI 和打开行为

**文件：**
- 修改：`Shark/Utilities/WorkspaceOpener.swift`
- 修改：`Shark/Views/MainWorkspaceView.swift`
- 修改：`Shark/Views/WorkspaceListView.swift`
- 修改：`Shark/Views/SettingsView.swift`
- 修改：`Shark/Utilities/FileDialogHelper.swift`

- [ ] `+` 直接创建 virtual workspace。
- [ ] 删除 workspace type picker、type icon、duplicate-as 菜单。
- [ ] 打开 workspace 时打开目录。
- [ ] 移除不再使用的默认 IDE 设置和 workspace import UI。

### Task 3: 文档和验证

**文件：**
- 修改：`README.md`
- 修改：`CHANGELOG.md`
- 修改：`tasks/todo.md`

- [ ] 文档改成中文并描述 virtual folder 模型。
- [ ] 确认没有 `.cursor`、`WorkspaceType`、`CursorWorkspaceFile` 编译引用。
- [ ] 运行 `xcodebuild` 构建。
