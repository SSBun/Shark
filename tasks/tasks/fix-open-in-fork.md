# 修复 Open in Fork 菜单无响应

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-27 15:15) |
| Artifacts | [Artifacts](../artifacts/fix-open-in-fork/) |
| Kind | Task |

## Scope

仅修复 folder/component 共用的仓库打开动作及错误提示；不改变 Fork workspace session 管理，不安装替换当前 SharkSpace，不覆盖既有未提交产品改动，不运行单元测试。

## Plan

1. 根据已复现的 PATH 查找失败替换共享打开边界，沿用原生 Launch Services 与既有提示服务。
2. 执行 Swift 解析与 Shark scheme 的 Debug 构建；受限 PATH 下检查原生打开请求，并核对保留逻辑。
3. 按实际结果记录验证范围及局限，完成风险分级和最终检查。

## Task Summary

**Fork 仓库打开工具**（[工具组件](../../Shark/Utilities/)）：不再启动依赖 shell PATH 的 Fork CLI，改为通过 Launch Services 定位 Fork 并传入仓库目录 URL。无效目录、应用不可用和异步打开错误使用现有 AlertManager 提示；提示更新限定在 MainActor。Fork workspace 管理代码保持不变。

## Target
- [x] T1: 文件夹和组件的 Open in Fork 在 GUI 环境中不依赖 shell PATH 即可打开所选仓库
- [x] T2: Fork 不可用或打开失败时显示明确错误，不再静默失败
- [x] T3: 不改变 Open In Fork Workspace 的现有行为

## Result

- T1: FolderListView 与 ComponentSelectorView 仍共用 ForkOpener，改用 NSWorkspace 按 bundle identifier 定位 Fork 并交付目录 URL，没有 shell/CLI 调用。Swift parse 与 Shark scheme Debug 构建通过；与 GUI 相同 PATH 下实际原生打开返回 com.DanPristupov.Fork，见 evidence/debug-build.log 与 evidence/native-open.log。未自动验收 Fork 内部标签页。
- T2: 源码逐分支检查：无效目录、找不到 Fork、异步 open error 均向 AlertManager.error 提交明确消息；同步入口 MainActor 隔离，异步错误回到 MainActor。Debug 构建验证调用与隔离兼容。未卸载 Fork 或人为制造系统打开错误，未做提示视觉验收，未运行单元测试。
- T3: 修改前 git HEAD 与当前 ForkOpener 的仓库打开分组之前内容逐字节对比一致；ForkWorkspaceManager、会话读写与 workspace 专用菜单未修改。原有其他产品文件脏改动保留。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 改动限于一个共享仓库启动函数，修复已证实的 PATH 故障；没有 session 数据修改、权限调整或发布行为。
- Snapshot: snapshot:tasks/artifacts/fix-open-in-fork/evidence/d03a59fc225cb8e78b848a5ccf2ede02ad36e842529a54b2b8aa75e25709099a.json#d03a59fc225cb8e78b848a5ccf2ede02ad36e842529a54b2b8aa75e25709099a
- Evidence: T1-T3；Swift parse、Debug build、受限 PATH 原生打开完成记录以及 ForkWorkspaceManager 字节比较。
- Result clarity: 目标明确：移除 GUI 对 shell PATH 的依赖，保留两个菜单的选中路径语义并提示错误。
- Bounded impact: 仅 ForkOpener.openRepository 的两个直接菜单调用方；调用点和多选循环不变，失败在 helper 内结束，不改变 workspace manager。
- Low risk: 只向已解析的 Fork 应用交付既有目录 URL，失败为可重试提示；不修改仓库、Fork session、权限或系统设置。
- Sufficient verification: 真实 Debug 构建覆盖两个调用方；原生 API 在同一受限 PATH 成功完成，守卫和错误回调经代码对照与编译验证；保留逻辑逐字节比较一致。UI 视觉与强制系统错误未验收。
- Task fingerprint: 5dcd98db9c0deac6c42b295e9d09775b90dc72ad9d6bc3ba4a47151bbfcd03de

## Verification

- Passed: 最终 managed snapshot 文件身份校验通过；重新 parse 与 scoped diff check 通过，日志确认 BUILD SUCCEEDED 及 Native open completed；再次确认无 CLI 调用且 workspace manager 字节一致。未运行单元测试，未安装替换现有 App。
