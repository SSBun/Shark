# Shark

一个 macOS 虚拟工作区管理器。Shark 用真实目录和符号链接组织多个项目/组件文件夹，让 Codex、Claude Code、终端和其他 Agent 工具都能像打开普通项目一样打开整个工作区。

![Shark Screenshot](resources/screen.png)

**官方网站**: https://ssbun.github.io/Shark

## 功能

### Workspace 管理
- **Virtual Folder Workspaces** - 创建真实目录，并用符号链接挂载多个项目/组件文件夹。
- **多 Workspace 管理** - 在一个侧边栏中管理多个工作区。
- **Pin Workspaces** - 将常用 workspace 固定在顶部。
- **Rename Workspaces** - 重命名 workspace，并同步更新工作区目录和 metadata。
- **Workspace Health Check** - 检查 metadata、缺失文件夹、断开的 symlink 和 Codex hooks 状态，并支持重建 symlinks。

### Folder 管理
- **Add Folders** - 通过拖拽、文件选择器或组件选择器添加多个目录。
- **Component Selector** - 从可配置搜索路径中浏览和选择组件。
- **Copy Path** - 右键复制一个或多个 folder 路径。
- **Visual Folder List** - 查看 workspace 中的 folders，并显示 branch、最新 tag、working tree 和 upstream 状态。
- **Workspace Git Overview** - 在原生表格中集中检查所有 repository 的版本、未提交改动和远端同步状态。
- **Automatic Saving** - folder 变更会自动保存到 `.shark-workspace.json`。

### Codex Sessions
- **Workspace Sessions** - 在当前 workspace 下方展示相关 Codex sessions。
- **Activity Groups** - 按 Last 8 Hours、Last 2 Days、Last Week、Older 分组 active sessions。
- **Archived Sessions** - archived sessions 默认折叠，避免干扰当前工作。
- **Session Actions** - 支持恢复到终端、归档、删除、复制 session ID、复制 jsonl 路径。
- **Running Indicator** - 显示 session 是否正在终端中运行。
- **iTerm Jump** - 安装 Codex hooks 后，可跳转到正在运行的 iTerm2 session。
- **Display Name** - 可为 session 设置 Shark 内部显示名，保存到当前 workspace metadata。
- **Session Preview** - 双击 session 可预览首条用户消息和最近对话，再决定是否恢复或跳转。

### 快捷操作
- **Double-Click to Open** - 双击即可在终端打开虚拟工作区目录。
- **Context Menu** - 右键 workspace 可执行：
  - 打开虚拟工作区目录
  - 在 Finder 中显示
  - 重命名
  - Pin / Unpin
  - Check Health
  - Remove

### Settings
- **Settings Folder** - 配置 Shark workspace 和 app settings 的保存目录。
- **Components Search Paths** - 配置多个组件搜索目录。
- **Terminal App** - 选择默认终端应用。
- **Codex Hooks** - 一键注入 Codex hooks，用于稳定识别正在运行的 terminal session。
- **Venomfiles Support** - 检查带 Venomfiles 的组件依赖状态。

### Venomfiles 管理
- **Check Dependencies** - 扫描并验证 Venomfiles 项目的依赖。
- **Jump to Repository** - 直接打开依赖仓库。
- **Edit Source** - 用系统默认编辑器打开 `.rb` source 文件。
- **Visual Status** - 查看依赖状态并刷新。

## 为什么使用 Shark

### 面向 Agent 工具的工作区
Shark 的 virtual folder 本质上就是一个普通目录。Codex、Claude Code、Cursor、终端和其他工具都可以直接打开它，不需要理解 Shark 的内部数据结构。

### 清晰的 macOS 界面
- 左侧是 workspace 列表。
- 右侧上方是 folders。
- 右侧下方是 Codex sessions。
- 使用原生 macOS 控件、菜单和窗口行为。

### 本地优先
- workspace metadata 保存在 `.shark-workspace.json`。
- session display name 保存在当前 workspace metadata。
- 所有数据都保存在本机。
- 不采集数据，不做云同步。

## 安装

### 一行命令安装
在终端运行：

```bash
curl -sL https://github.com/SSBun/Shark/raw/main/install_latest.sh | bash
```

脚本会：
1. 下载最新 Shark DMG 到 Downloads 文件夹。
2. 自动打开 DMG。

然后：
1. 将 SharkSpace.app 拖到 Applications 文件夹。
2. 如果 macOS 显示 "Shark is damaged"，运行：
   ```bash
   xattr -rd com.apple.quarantine /Applications/SharkSpace.app
   ```

也可以克隆仓库后本地运行：

```bash
git clone https://github.com/SSBun/Shark.git
cd Shark
./install_latest.sh
```

### 手动安装
1. 从 [Releases](https://github.com/SSBun/Shark/releases) 下载最新 `SharkSpace-x.x.x.dmg`。
2. 打开 DMG。
3. 将 Shark 拖到 Applications 文件夹。
4. 如果 macOS 显示 "Shark is damaged"，运行：
   ```bash
   xattr -rd com.apple.quarantine /Applications/SharkSpace.app
   ```

### 系统要求
- macOS 14.0 或更高版本。
- 一个用于打开 virtual workspace 的终端应用。

## 快速开始

1. **启动 Shark** - 从 Applications 文件夹打开应用。
2. **授予权限** - 根据提示授予文件系统访问权限。
3. **创建 Workspace** - 点击 **+** 创建新的 virtual workspace。
4. **添加 Folders** - 选择 workspace 后点击 Add Folder、Select Components，或直接拖拽 folders 到列表区域。
5. **打开 Workspace** - 双击 workspace，或使用右键菜单打开 virtual folder。
6. **可选：安装 Codex Hooks** - 打开 Settings > Terminal，安装 Codex hooks 后可稳定跳转到运行中的 iTerm2 session。

## 使用提示

- 双击 workspace 可快速打开 virtual folder。
- 直接拖拽 folders 到列表即可加入 workspace。
- 右键 workspace 可重命名、pin、显示 Finder、检查健康状态或移除。
- 右键 Codex session 可恢复、归档、删除、设置显示名或复制 session 信息。
- workspace 会在 folders 变化时自动保存。
- 新 workspace 默认创建在 Shark 的 settings folder 中。

## 技术细节

- 使用 **SwiftUI** 和 **Swift 6** 构建。
- 原生 macOS 应用。
- Virtual folder workspace 使用 symlink 组织组件目录。
- Workspace metadata 保存在 `.shark-workspace.json`。
- App preferences 保存在 UserDefaults。
- Codex session 信息来自本机 Codex files 和 sqlite databases。
- 需要文件系统权限来读写 workspace 文件。

## License

This project is open source. See the repository for license details.

## Contributing

欢迎提交 Pull Request。

## Support

如需反馈 bug、提出功能建议或提问，请在 GitHub 创建 issue。

---

**Made for developers who organize projects for agent tools**
