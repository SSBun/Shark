# Data Model

## 核心模型

### Workspace

字段：`id`、`name`、`filePath`、`createdAt`、`type`、`isPinned`、`sortOrder`。  
类型：`cursor` 与 `claude`。

### Folder

字段：`id`、`name`、`path`、`displayName`、`bookmarkData`、`hasVenomfiles`。  
计算属性覆盖存在性、Git repo、Git reference、Xcode project、Venomfiles 检测。

### CursorWorkspaceFile

表示 `.code-workspace` JSON。

### ClaudeWorkspaceFile

表示 Claude workspace metadata 和 linked folders，用 symlink 映射真实路径。

### VenomDependency

表示 regular/local Venomfiles 依赖。

## 优化建议

- 为 `WorkspaceManager` 和 workspace file round trip 增加测试。
- 将 `Folder` 中的磁盘/Git 检测逻辑逐步迁到 service，模型保留数据含义。
- 对 `hasVenomfiles` 缓存建立失效策略，避免文件变更后 UI 状态长期不准确。
