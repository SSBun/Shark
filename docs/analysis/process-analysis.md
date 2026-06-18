# Process Analysis

## 关键用户流程

### 创建 workspace

1. 用户点击左侧加号。
2. 选择 Cursor Workspace 或 Claude Code Workspace。
3. App 请求文件系统权限。
4. 创建文件或目录。
5. 加入 workspace 列表并选中。

优化点：创建失败目前只 `print`，需要 toast/alert。

### 添加 folder

1. 用户选择 workspace。
2. 通过 Add、拖拽或 Select Components 选择 folder。
3. App 创建 bookmark 并检测 Venomfiles。
4. 更新 `folders`。
5. 自动保存到 workspace。

优化点：未选择 workspace 时按钮应禁用或显示空状态，不应静默无效。

### 查看依赖

1. Folder 检测到 Venomfiles。
2. 右键选择 Check Dependencies。
3. 解析 regular/local dependency。
4. 可打开 repo、编辑源文件或查看 local branch。

优化点：依赖解析失败需要错误态，不只是空列表。

### 发布安装

1. 本地或 CI 构建 app。
2. 创建 DMG。
3. GitHub Release 或 npm 分发。
4. 用户安装并处理 Gatekeeper。

优化点：签名、公证、checksum 验证应优先做。
