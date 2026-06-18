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
