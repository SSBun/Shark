# Development History

## 近期演进

从 changelog 和 git log 看，项目从 2025-11 的 Cursor workspace 管理逐步扩展：

- 2026-01：组件搜索路径、Xcode project、权限处理。
- 2026-03：多 IDE、Venomfiles、SourceTree、更新检查、安装脚本。
- 2026-04：developing dependencies 和本地分支展示。
- 2026-05：Claude Code workspace、symlink 修复、duplicate、Fork workspace。
- 2026-06：workspace grouping、pin/reorder、TypeScript build-tool。

## 观察

- 功能增长很快，主视图和列表视图承载了过多行为。
- 文档和发布链路没有完全跟上产品重命名与功能扩展。
- 目前没有测试 target，回归主要依赖手动验证。

## 优化建议

- 下一阶段优先做“产品一致性修复”和“发布链路可靠性”，再做新增功能。
- 建立最小测试 target，先覆盖 workspace 文件读写、duplicate、symlink、Venomfiles parser。
