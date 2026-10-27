# Review round 01

- Schema: task-review-report/v1
- Task: prepare-shark-1-14-0
- Round: 01
- Snapshot: snapshot:tasks/artifacts/prepare-shark-1-14-0/evidence/4e02d8797885896f0d9ab26baaac67ee1bf55063844f862b6dff8d2263cd511a.json#4e02d8797885896f0d9ab26baaac67ee1bf55063844f862b6dff8d2263cd511a
- Task fingerprint: 0a370f631edfb2499849ee45d7f7133624776356fc26ad63ea85dc9516153602
- Outcome: findings
- Mode: independent subagent
- Run: e2b0ba3a-5690-43d5-851c-a8885a61334c

## Reviewer feedback

Review mode: independent subagent

## Reviewed scope/snapshot

审查第一阶段源码、版本元数据及提供的 `40f7db0 → 3180602` 差异，绑定 snapshot `4e02d8797885896f0d9ab26baaac67ee1bf55063844f862b6dff8d2263cd511a`。不包含后续 DMG、GitHub/npm 发布。

## Review

- **Correct**：Project 删除入口检查 `.workspace`，重命名仅更新显示名；永久删除会话复用确认对话框；metadata/runtime 使用同一过滤集合。package、lockfile、Xcode 均为 `1.14.0`，build 为 `16`。

### Findings

**TR-1**
- **Severity**：P1 / Concern
- **Location**：
  - ["/Users/caishilin/Desktop/personal/Shark/Shark/Views/CodexSessionListView.swift"](file:///Users/caishilin/Desktop/personal/Shark/Shark/Views/CodexSessionListView.swift)：127、133–136、244–246。
  - ["/Users/caishilin/Desktop/personal/Shark/Shark/Views/WorkspaceStore.swift"](file:///Users/caishilin/Desktop/personal/Shark/Shark/Views/WorkspaceStore.swift)：322–332。
- **Issue**：混合选择 active/archived 会话时，菜单显示单一的 `Archive` 或 `Unarchive`，实际却逐项反转状态，执行与菜单相反的操作。
- **Evidence**：列表允许跨分组多选；`targetSessions` 返回所有选中会话，菜单标题只取右键行状态。新增实现将集合拆分，同时执行 archive 和 unarchive。例如选中 active A 与 archived B，在 A 上点击 `Archive`，B 反而被取消归档。此结论来自调用链静态检查，未操作真实会话。
- **Impact**：批量归档/恢复会意外改变另一类会话状态；被意外归档的会话还会进入后续归档清理集合。
- **Suggested next step**：从菜单传入明确目标状态；Archive 仅处理 active，Unarchive 仅处理 archived。用混合选择场景验证命令路由，无需操作真实会话。

- **Merge verdict**：BLOCK，建议修复 TR-1 后重新审查；不是完成授权。

## Unverified risks

- **T1，非独立阻断项**：未验证完整 GUI、真实 CLI 副作用。SQLite 索引缺失时 fallback 的 `source` 为 nil，过滤器会保留这些会话；其对子代理实际数据的影响尚未验证。
- **T3／snapshot 绑定，证据限制**：两次 `watchdog_diff` 均仅显示范围外任务状态变化，没有被审查已跟踪文件的工作树变化。但该工具不检查已提交区间，也不证明未跟踪 artifact 的字节不变；未独立重算 SHA256 或核验提交历史。需主 Agent 在采纳审查前核验绑定，不应将本报告当作完整 hash 证明。

## Checks performed

实际执行：读取 Target/Scope、完整提供差异、相关源码和调用方、snapshot manifest、版本配置、安装器及 CI/构建入口；两次检查工作树变化。未编辑、构建、运行测试、执行真实会话命令或发布。

## Author evidence examined

读取任务 T1–T3 Result、R2 assessment，以及 ["/Users/caishilin/Desktop/personal/Shark/tasks/artifacts/prepare-shark-1-14-0/evidence/checks.log"](file:///Users/caishilin/Desktop/personal/Shark/tasks/artifacts/prepare-shark-1-14-0/evidence/checks.log)。其中 Debug 构建成功、Swift parse、plutil 与 CLI help 通过属于作者证据，未独立重跑。

## Coverage limits

源码静态审查不能证明 GUI 实际交互、Fork 内部状态或真实会话变更结果；未来发布未完成及 npm 登录问题未列为本阶段缺陷。