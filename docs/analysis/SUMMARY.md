# Shark Project Analysis Summary

生成日期：2026-06-17

## Executive Summary

Shark 当前已经是面向 macOS 开发者的多 workspace 管理工具，覆盖 Cursor/Trae、Claude Code、Venomfiles、Git、Fork/SourceTree/Xcode/Terminal 集成。项目功能面较完整，但 UI 可发现性、SwiftUI 可访问性、发布链路一致性是最值得优先优化的区域。

Top findings:

1. **发布链路需要先修**：CI 查找 `Shark.app`，但工程产物是 `SharkSpace.app`；DMG 命名在 CI、本地工具、npm、README 之间不一致。
2. **UI 可访问性有直接修复空间**：多处 icon-only button 缺少文本 label，`NSEvent` monitor 没有移除。
3. **产品体验需要补状态反馈**：未选择 workspace 时操作静默无效，多处失败只 `print`，README/CHANGELOG 与实际功能存在漂移。

## Analysis Index

| Report | 内容 |
|---|---|
| [feature-ui-audit.md](feature-ui-audit.md) | 功能地图、UI 审计、优化建议、优先级 |
| [project-structure.md](project-structure.md) | 目录结构、模块边界、文件组织建议 |
| [dependencies.md](dependencies.md) | Swift/npm/Ruby 依赖与版本一致性 |
| [build-and-deploy.md](build-and-deploy.md) | CI、DMG、npm、安装脚本、签名公证建议 |
| [architecture.md](architecture.md) | 架构模式、service/view 边界、重构建议 |
| [data-flow.md](data-flow.md) | 数据来源、保存/加载流程、缓存建议 |
| [process-analysis.md](process-analysis.md) | 关键用户流程与失败点 |
| [api-surface.md](api-surface.md) | 外部接口、GitHub API、npm bin、系统集成 |
| [data-model.md](data-model.md) | Workspace、Folder、workspace file、dependency 模型 |
| [development-history.md](development-history.md) | 功能演进和工程风险趋势 |

## Recommended Next Steps

1. 统一 `Shark`/`SharkSpace` 品牌和产物命名，修 GitHub Action。
2. 移除不安全安装建议，规划签名、公证和 checksum 校验。
3. 给所有 icon-only button 补可访问 label，修 Cmd+F event monitor 生命周期。
4. 补 UI 状态：未选中 workspace、保存/导入/rename 失败、依赖解析失败。
5. 决定 `NavigationSplitView` 迁移和大视图拆分的范围。
