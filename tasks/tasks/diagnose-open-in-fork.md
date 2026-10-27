# 排查 Open in Fork 菜单无响应原因

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-27 15:07) |
| Kind | Task |

## Scope

仅解释 folder/component 的 Open in Fork 菜单故障，不修改产品代码、不启动或退出 Fork、不更改 Fork session。Workspace 专用菜单走另一条调用链，不将本结论无条件外推。

## Plan

1. 核对菜单调用链、实际运行中的 SharkSpace 环境和 Fork CLI 安装位置。
2. 以同样 PATH 运行最小命令并记录原因与修复方向；不运行单元测试。

## Task Summary

未修改产品代码或组件；仅完成诊断与任务记录，并补齐既有 Context 的 Project Core。

## Target
- [x] T1: 根据菜单调用链与本机可核实证据解释 Open in Fork 无响应的原因和处理方向

## Result

- T1: FolderListView 与 ComponentSelectorView 均调用 ForkOpener.openRepository；该函数经 /usr/bin/env 按 PATH 查找 fork。ps eww 确认运行中 SharkSpace PID 74186 的 PATH 为 /usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin，而 fork CLI 在 /opt/homebrew/bin/fork，指向已安装 Fork.app 的 fork_cli。按该实际 PATH 重放 env fork 仓库路径，退出 127、stderr 为 env: fork: No such file or directory。函数未观察子进程退出状态或向用户报告 stderr，故呈现无响应。建议直接用 NSWorkspace 打开 Fork 并传仓库 URL，处理 completion error。未直接点击 UI、未运行测试；Workspace 专用菜单不适用此结论。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Current
- Reason: 仅排查并解释原因，没有请求交付文件改动；Context 与生命周期记录不计入产品修改。
- Snapshot: nofile:fork-path-diagnosis; ForkOpener.swift sha256=e0206f60a50b152f443abaf3cd26964e020b76b2e93c370fdd3e16c697d3bc0d; GUI PID=74186
- Evidence: T1 的源码调用链、实际 GUI PATH 与匹配 PATH 的退出 127 重放共同支持因果结论。
- Task fingerprint: 2534a793a2c4abd90605d5bda57224021e30ec3d4868e44a1dd95b3fe6b3ac55

## Verification

- Passed: 最终重新读取 GUI 进程 PATH、重放命令仍退出 127，核对 CLI symlink 与 ForkOpener SHA256 未变；无产品代码修改，未执行单元测试。
