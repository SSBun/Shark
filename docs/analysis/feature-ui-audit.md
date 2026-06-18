# Shark 功能与 UI 设计审计报告

审计日期：2026-06-17  
项目路径：`/Users/caishilin/Desktop/personal/Shark`  
审计范围：产品功能、信息架构、SwiftUI/macOS UI 设计、可访问性、发布链路与文档一致性。  
方法：只读静态审计；未运行应用、未执行构建、未修改产品源码。

## 结论摘要

Shark 已经不是一个简单的 Cursor workspace 管理器。当前产品实际覆盖 Cursor/Trae `.code-workspace` 打开、Claude Code workspace 目录与 symlink 管理、组件选择器、Venomfiles 依赖查看、Git 分支状态、Fork/SourceTree/Xcode/Terminal 快捷打开、更新检查和发布安装链路。

最大优化空间不在“缺功能”，而在三个方向：

1. **功能可发现性不足**：大量关键能力藏在图标按钮或右键菜单里，主界面对新用户不够自解释。
2. **SwiftUI/macOS 原生性不足**：主窗口仍是手写 `HSplitView`，多个 icon-only button 缺少可访问标签，空状态/搜索/弹窗样式重复实现。
3. **发布与文档一致性风险高**：产品名、DMG 名、README、CI、本地 npm 发布工具之间存在 `Shark` 和 `SharkSpace` 分裂，CI 可能找不到实际 `.app` 产物。

## 当前功能地图

### Workspace 管理

- 创建 Cursor/Trae 可打开的 `.code-workspace` 文件：`WorkspaceListView.createNewWorkspace()`，见 `Shark/Views/WorkspaceListView.swift:294`。
- 创建 Claude Code workspace 目录，并用 symlink 组织组件文件夹：`WorkspaceManager.createClaudeWorkspace()`，见 `Shark/Utilities/WorkspaceManager.swift:136`。
- 导入已有 `.code-workspace`：`WorkspaceListView.importWorkspace()`，见 `Shark/Views/WorkspaceListView.swift:339`。
- 同名 Cursor 与 Claude workspace 分组展示：`WorkspaceGroup.groups(from:)`，见 `Shark/Models/Workspace.swift:49`。
- 搜索 workspace 名称和路径：`WorkspaceListView.filteredWorkspaces`，见 `Shark/Views/WorkspaceListView.swift:26`。
- 双击 workspace 打开：见 `Shark/Views/WorkspaceListView.swift:207`。
- 右键菜单支持 pin、Finder、rename、duplicate、Fork workspace、SourceTree 等动作：见 `Shark/Views/WorkspaceListView.swift:583`。

### Folder 管理

- 添加文件夹：文件选择器、多选、拖拽、组件选择器四条路径，见 `Shark/Views/FolderListView.swift:37`、`Shark/Views/FolderListView.swift:132`、`Shark/Views/ComponentSelectorView.swift:169`。
- 自动保存到当前 workspace 文件或 Claude metadata：见 `Shark/Views/MainWorkspaceView.swift:234`。
- 行内显示 folder 名称、路径、存在状态、权限锁、Git 分支/tag badge：见 `Shark/Views/FolderListView.swift:217`。
- 支持多选后批量打开 Terminal/Fork/SourceTree：见 `Shark/Views/FolderListView.swift:340`。
- 自动检测 Xcode project/workspace 并提供 “Open with Xcode”：见 `Shark/Models/Folder.swift:252` 与 `Shark/Views/FolderListView.swift:356`。

### 组件选择与 Venomfiles

- 组件选择器从多个 search paths 扫描一级子目录：见 `Shark/Views/ComponentSelectorView.swift:185`。
- 支持搜索、勾选、多选添加、复制路径、打开 Fork/SourceTree/Terminal：见 `Shark/Views/ComponentSelectorView.swift:109`。
- Venomfiles 检测深度为 3 层：见 `Shark/Models/Folder.swift:313`。
- 依赖弹窗区分 regular dependencies 与 developing dependencies，支持搜索、打开 repo、编辑源文件、显示本地依赖分支：见 `Shark/Views/DependencyListView.swift:102`。

### Git 与外部工具

- Git 面板提供 status、ahead/behind、modified/staged/untracked、Pull/Push/Fetch/Commit/Stash/Branch：见 `Shark/Views/ComponentGitPanel.swift:115`。
- Workspace 级 “Open In Fork Workspace” 会收集 workspace 内所有 Git repo：见 `Shark/Views/WorkspaceListView.swift:440`。
- 支持默认 IDE 和默认 terminal 配置：见 `Shark/Views/SettingsView.swift:191`、`Shark/Views/SettingsView.swift:271`。

### 设置、权限与更新

- Settings 包含 General/Folders/Terminal/About：见 `Shark/Views/SettingsView.swift:13`。
- 可配置 settings folder、components search paths、授权目录、默认 IDE、默认 terminal：见 `Shark/Views/SettingsView.swift:100`。
- 授权 sheet 覆盖文件系统、Full Disk、Network 三类文案：见 `Shark/Views/AuthorizationPanel.swift:101`。
- 更新检查调用 GitHub Releases latest API 后打开 release page：见 `Shark/Utilities/UpdateManager.swift:67`、`Shark/Utilities/UpdateManager.swift:129`。

## 高优先级优化建议

### 1. 修复发布产物命名和 CI 查找逻辑

证据：
- Xcode 产物名是 `SharkSpace.app`：`Shark.xcodeproj/project.pbxproj:296`。
- GitHub Action 查找 `Shark.app`：`.github/workflows/build-and-release.yml:57`。
- CI 生成 `Shark-${VERSION}.dmg`：`.github/workflows/build-and-release.yml:69`。
- 本地/npm build-tool 生成 `SharkSpace-${version}.dmg`：`scripts/build-tool.ts:132`。
- npm 包只包含 `SharkSpace.dmg`：`package.json:11`。

影响：GitHub Release、npm 安装、README 手动安装路径互相漂移，CI 很可能在 “Create DMG” 步骤找不到 app。

建议：
- 选定一个对外品牌名，建议统一为 `SharkSpace` 或统一回 `Shark`，不要混用。
- GitHub Action 直接调用 `npx tsx scripts/build-tool.ts create-dmg "$VERSION"`，让 DMG 创建逻辑只有一个来源。
- 如果继续保留 Action 内联 shell，至少把 `find build -name "Shark.app"` 改为查找 `*.app` 或 `SharkSpace.app`，并统一 release asset 名称。

### 2. 不再建议用户绕过 Gatekeeper，改为签名与公证

证据：
- `install.js` 建议 `sudo spctl --master-disable`：`install.js:24`。
- README/install script 建议移除 quarantine：`README.md:82`、`install_latest.sh:48`。
- CI release build 明确禁用签名：`.github/workflows/build-and-release.yml:50`。

影响：用户安全体验差，安装说明会降低信任感，也不符合 macOS 分发预期。

建议：
- 建立 Developer ID Application 签名、公证、staple 的 release 流程。
- 安装脚本下载 `.sha256` 并校验 DMG。
- README 改成“如遇到 Gatekeeper 阻止，请下载已签名公证版本或查看 release 校验值”，不要建议关闭全局安全策略。

### 3. 补上 icon-only 按钮的可访问标签

证据：
- Workspace header 图标按钮：`Shark/Views/WorkspaceListView.swift:51`、`:68`、`:78`、`:88`。
- Folder header 图标按钮：`Shark/Views/FolderListView.swift:38`、`:48`。
- Settings 和弹窗内图标按钮：`Shark/Views/SettingsView.swift:129`、`Shark/Views/ComponentGitPanel.swift:37`、`Shark/Views/DependencyListView.swift:265`。

影响：`.help()` 不是 VoiceOver 标签，Voice Control 和屏幕阅读器难以理解动作。

建议：
- 使用 `Button("Refresh Venomfiles", systemImage: "arrow.clockwise", action: refresh)`，再加 `.labelStyle(.iconOnly)` 保持视觉不变。
- 删除、关闭、打开外部应用等按钮都给明确文本 label。

### 4. 修复 `NSEvent.addLocalMonitorForEvents` 生命周期

证据：`WorkspaceListView.setupKeyboardShortcuts()` 在 `onAppear` 添加本地 event monitor，但没有保存 token 或移除，见 `Shark/Views/WorkspaceListView.swift:282`。

影响：视图重复出现后会累积监听器，导致 Cmd+F 重复响应和潜在泄漏。

建议：
- 优先改成 `.searchable`、`.commands` 或 `.keyboardShortcut`。
- 如果必须继续用 `NSEvent`，保存 monitor token，并在 `onDisappear` 中 `NSEvent.removeMonitor(_:)`。

### 5. 让“未选择 workspace”状态可见

证据：
- `addFolder()` 和 `addSelectedFolders()` 在无选中 workspace 时静默 return：`Shark/Views/MainWorkspaceView.swift:130`、`:188`。
- Folder header 的 Add/Select Components 只根据 callback 是否存在禁用，不根据 workspace 是否已选中：`Shark/Views/FolderListView.swift:48`。

影响：用户未选择 workspace 时点击按钮没有反馈，看起来像功能失效。

建议：
- 右侧 detail 在未选中 workspace 时显示 `ContentUnavailableView("Select a Workspace", ...)`。
- Add Folder / Select Components 按钮根据 `selectedWorkspace != nil` 禁用，并用 tooltip 解释。

## 中优先级优化建议

### 6. 主窗口迁移到 `NavigationSplitView`

当前主窗口使用 `HSplitView`：`Shark/Views/MainWorkspaceView.swift:29`。

建议使用 macOS 更原生的结构：
- sidebar：workspace list。
- detail：folder list 与 workspace detail。
- toolbar：search、refresh、add/import actions。

价值：
- 更好地接入系统 sidebar 行为。
- 搜索、toolbar、selection 状态更自然。
- 减少两个列表视图各自手写 header 的重复。

### 7. 统一空状态和搜索无结果状态

证据：
- Workspace 搜索无结果自定义 VStack：`Shark/Views/WorkspaceListView.swift:175`。
- Folder 空状态自定义 VStack：`Shark/Views/FolderListView.swift:66`。
- Component selector 和 Dependency list 自定义空状态：`Shark/Views/ComponentSelectorView.swift:63`、`Shark/Views/DependencyListView.swift:81`。

建议：
- macOS 14+ 可使用 `ContentUnavailableView`。
- 搜索场景使用 `ContentUnavailableView.search`。
- 将 `ComponentValidationView.EmptyStateView` 如果不再使用则删除，或替换为系统空状态。

### 8. 减少固定字号和固定弹窗尺寸

证据：
- 大量 `.font(.system(size:))` 出现在 list row、settings、dependency、git panel。
- 弹窗固定尺寸：`SettingsView.swift:64`、`ComponentSelectorView.swift:179`、`DependencyListView.swift:199`、`AuthorizationPanel.swift:85`。

影响：大字号辅助设置、长路径、未来本地化时容易截断。

建议：
- 优先用 `.headline`、`.body`、`.caption` 等语义字体。
- 弹窗使用 `minWidth/idealWidth/minHeight`，内容区保留 `ScrollView`。
- 长路径使用 middle truncation，并在可复制区域启用 text selection。

### 9. 清理或接线未使用的 UI 基础组件

证据：
- `SearchBar`、`SearchableListView`、`QuickOpenView` 等基本未接入主界面：`Shark/Views/ComponentSearchFilter.swift:10`、`:85`、`:228`。
- `ValidationField`、`ValidationButton`、`ErrorBanner`、`EmptyStateView`、`LoadingOverlay` 基本是孤立组件：`Shark/Views/ComponentValidationView.swift:10`。

建议：
- 如果近期不会做 Quick Open，就删除未接线组件，降低维护噪音。
- 如果要保留，优先把 Cmd+F 和搜索框统一到 `SearchBar`，再把 `QuickOpenView` 接到 Cmd+P 或 Cmd+O。

### 10. 面向用户显示错误，而不是只 `print`

证据：
- 创建 workspace 失败只 `print`：`WorkspaceListView.swift:315`。
- 导入 workspace 失败只 `print`：`WorkspaceListView.swift:365`。
- rename/save 失败只 `print`：`WorkspaceListView.swift:383`、`MainWorkspaceView.swift:251`。

建议：
- 复用 `AlertManager` 给用户显示失败原因。
- 对文件权限、文件已存在、解析失败分别给可执行建议。

## 功能一致性问题

| 问题 | 证据 | 建议 |
|---|---|---|
| README 说 folder 右键可 Copy Path，但 FolderRow 没有该入口 | `README.md:21`，`FolderListView.swift:304`，`ComponentSelectorView.swift:113` | 给 FolderRow context menu 加 Copy Path，或更新 README |
| CHANGELOG 说 workspace 支持 drag-and-drop reorder，但 view 中没有 `onMove`/drag/drop | `CHANGELOG.md:20`，`WorkspaceManager.swift:372` | 补 UI 接线，或修正文档 |
| README 写 macOS 14.0+，工程 target 是 15.2 | `README.md:104`，`project.pbxproj:238` | 统一系统要求 |
| README 写 Swift 6，工程配置 `SWIFT_VERSION = 5.0` | `README.md:129`，`project.pbxproj:298` | 统一 Swift 版本声明 |
| AuthorizationPanel 的 network 文案提到 sync/remote resources，但 README 说无云同步 | `AuthorizationPanel.swift:118`，`README.md:62` | 删除 network 授权文案或改成更新检查用途 |
| Import dialog 允许 JSON，但逻辑只接受 `.code-workspace` | `FileDialogHelper.swift:13`，`WorkspaceListView.swift:350` | 自定义 UTType 或允许所有文件但校验扩展并报错 |
| 自定义 terminal 选择写入 UserDefaults，但 `TerminalOpener` 不读取 | `SettingsView.swift:466`，`TerminalOpener.swift:83` | 接线自定义 terminal，或移除入口 |

## 建议实施顺序

1. **发布链路修正**：统一 Shark/SharkSpace 命名，修 CI 查找 app，统一 DMG 生成工具。
2. **安装安全修正**：移除 `spctl --master-disable` 建议，规划签名/公证/checksum 校验。
3. **可访问性快速修复**：所有 icon-only button 加文本 label 和 `.labelStyle(.iconOnly)`。
4. **键盘监听修复**：替换或正确移除 `NSEvent` monitor。
5. **核心 UX 修复**：未选中 workspace 状态、Copy Path 一致性、拖拽排序文档或功能一致性。
6. **UI 原生化**：迁移 `NavigationSplitView`、统一 toolbar/search/empty state。
7. **结构清理**：拆分大视图文件，删除或接线未使用 UI 组件。

## 验证建议

后续实现优化时建议补最小验证集：
- `WorkspaceManager`：创建、导入、rename、duplicate、pin/sort order。
- `ClaudeWorkspaceFile` 与 `SymlinkManager`：symlink name 冲突、删除重建、metadata round trip。
- `VenomfileParser`：regular/local dependency 解析。
- UI smoke：未选中 workspace、空列表、搜索无结果、权限失败、长路径。
- Release smoke：GitHub Action 和本地 `build-tool` 产物名称一致，checksum 可验证。
