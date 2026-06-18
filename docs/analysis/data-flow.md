# Data Flow

## 数据来源

- UserDefaults：workspace 列表、settings、授权 bookmark、Venomfiles 检测缓存。
- `.code-workspace`：Cursor/Trae workspace folder 列表。
- Claude workspace directory：metadata 文件与 symlink。
- 文件系统：folder 存在性、Git metadata、Xcode project/workspace、Venomfiles。
- GitHub Releases API：更新检查。

## 主要数据流

1. 启动时 `WorkspaceManager` 从 UserDefaults 加载 workspace，否则扫描 settings folder。
2. 选择 workspace 后，`MainWorkspaceView` 解析 Cursor 文件或 Claude metadata，生成 `folders`。
3. `folders` 变化后自动写回当前 workspace。
4. Folder row 出现时检查存在性、权限、Git repo、Git reference、Xcode project。
5. Venomfiles dependency sheet 打开时解析依赖文件并展示。

## 优化建议

- 将“加载失败”和“保存失败”从 `print` 改成用户可见状态。
- 避免 row 级别重复执行成本较高的同步检查，必要时缓存或批量刷新。
- 明确 UserDefaults 中哪些是索引数据，哪些是真实数据源，避免 workspace 文件和 UserDefaults 不一致时难以恢复。
