# 准备并提交 SharkSpace 1.14.0 源码与版本元数据

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-27 20:09) |
| Artifacts | [Artifacts](../artifacts/prepare-shark-1-14-0/) |
| Kind | Task |
| Parent | release-all-local-changes |

## Scope

当前全部可入库本地改动、已提交的 Fork 修复和 1.14.0 / build 16 版本准备。保留新功能意图，仅修复直接发布阻塞：Project 删除安全、会话初次发布的过滤一致性和新增会话命令的 GUI CLI 查找/失败反馈；不重构无关模块。不运行单元测试，不修改真实 session 数据，不远端发布。

## Plan

1. 核实现有功能和调用边界，修复已确认阻塞，同步文档与版本。
2. Swift 解析、Debug 构建、CLI help/环境探测和敏感信息检查；独立只读 Reviewer 仅能使用 read/grep/find/ls 等工具。
3. 冻结源码、记录各 Target 自检与 R2 分级，执行独立 task-review，处理问题后提交全部可入库改动。
4. npm 登录失效只阻塞后续发布阶段；保留验证限制，不执行会话删除/归档或单元测试。

## Task Summary

**工作区与项目模型**（[Models](../../Shark/Models/)）：将既有 Project 类型及会话摘要字段纳入发布，旧 workspace 的 kind 解码保留兼容默认值。

**项目与设置服务**（[Utilities](../../Shark/Utilities/)）：纳入已有 Project 添加/显示名重命名和子代理筛选设置；补齐 Project 的直接 Git 仓库路径解析，沿用已提交 Fork 原生打开修复。

**工作区与会话界面**（[Views](../../Shark/Views/)）：纳入 Projects 分组、归档切换、可见归档批量清理、会话摘要、右键预览和激活刷新；补齐 Project 删除保护、两阶段筛选一致性、Project 会话重命名禁用及 Codex CLI 环境/错误处理；修正混合多选时的归档目标状态传递。

**发布元数据与文档**（[Xcode 项目](../../Shark.xcodeproj/)；[package.json](../../package.json)；[package-lock.json](../../package-lock.json)；[CHANGELOG](../../CHANGELOG.md)；[README](../../README.md)）：统一 1.14.0 / build 16，记录实际用户可见功能与修复；补充已有 Context 的组件边界和本次验证记录。

**会话静态验证入口**（[scripts](../../scripts/)）：同步会话两阶段过滤、动态 Archive/Unarchive、显式归档目标状态、登录 shell 参数与确认门槛、右键和辅助功能预览断言；仅做脚本语法检查，不执行验证脚本。

## Target
- [x] T1: 现有 Projects 与 Codex 会话改动及 Fork 修复纳入发布，必要的发布阻塞问题已处理且不误删外部项目目录
- [x] T2: package、lockfile、Xcode 版本统一为 1.14.0，build 为 16，更新日志与功能文档符合实际
- [x] T3: 全部可入库的本地改动经过敏感信息检查并提交，构建产物不进入 Git 历史

## Result

- T2: 读取 package.json、lockfile 根和 packages[空键] 均为 1.14.0；Xcode Debug/Release MARKETING_VERSION 均为 1.14.0，CURRENT_PROJECT_VERSION 均为 16。plutil 通过；CHANGELOG 1.14.0 与 README 已按实际功能同步。
- T1: 发布代码区间 40f7db0..27c7d5e。T1 功能与必要边界已经源码/调用方对照；c6c1825 使菜单显式传递目标状态，Store 只选择 isArchived != archived 的条目并执行一个命令，第二轮独立报告确认 TR-1 resolved。27c7d5e 同步旧静态验证断言（过滤 metadata/runtime、动态菜单、shell 参数和删除确认、右键/辅助功能预览），补充目标状态路由保护；bash -n 通过，未运行验证脚本。产品源码保持 c6c1825，更新后的 Debug build/Swift parse 已通过，CLI仅help，见 checks.log。未做真实会话修改、完整GUI或单元测试。
- T3: 初始全部非忽略改动入 3180602，归档补丁和Context/todo入 c6c1825，静态验证脚本同步入27c7d5e；Fork修复6da5a6a在历史中。初次29文件敏感模式扫描无命中；后续源码与脚本/记录人工核对无凭据。App/DMG/node_modules未入库。源码/文档diff check通过，历史原始build.log固有空白按字节保存。生成中的审查与任务记录在准备收尾补交；未推送。
- Review gate: Passed — fresh/read-only 第3轮 run52d99600 无确认发现，TR-1/TR-2均resolved；主Agent实际 check-evidence通过，源码与报告范围一致，非阻断运行时限制保留。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 跨组件 Projects/会话数据操作保持 R2；产品补丁与静态验证同步后必须 fresh 复核。
- Snapshot: snapshot:tasks/artifacts/prepare-shark-1-14-0/evidence/64d9170c8565b262ca636721cbee1f78491834595191655203946c3b37d00abd.json#64d9170c8565b262ca636721cbee1f78491834595191655203946c3b37d00abd
- Evidence: 当前 T1-T3、checks.log 与完整 release-code.diff；产品Debug构建、脚本bash -n、源码对照；测试未运行。
- Task fingerprint: 65107c78fc52930b4ba410927b6b63571f82396f08453e96fc5e54eb0fa7e191
## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/prepare-shark-1-14-0/reviews/round-01.md) | snapshot:tasks/artifacts/prepare-shark-1-14-0/evidence/4e02d8797885896f0d9ab26baaac67ee1bf55063844f862b6dff8d2263cd511a.json#4e02d8797885896f0d9ab26baaac67ee1bf55063844f862b6dff8d2263cd511a | findings | d47f4ec66c56501c1a925aa6d230f3f93093967491d25ca9341e0fe19259b106 |
| 02 | [Round 02](../artifacts/prepare-shark-1-14-0/reviews/round-02.md) | snapshot:tasks/artifacts/prepare-shark-1-14-0/evidence/a8793b6eee2e522a4d7b05deadb39cf49b0b4293648e2ea8984e594eca8784e8.json#a8793b6eee2e522a4d7b05deadb39cf49b0b4293648e2ea8984e594eca8784e8 | findings | 3064647b53d68ad2716a4f89ac9fc1805153cbcc6a943a4f960388cdc8788513 |
| 03 | [Round 03](../artifacts/prepare-shark-1-14-0/reviews/round-03.md) | snapshot:tasks/artifacts/prepare-shark-1-14-0/evidence/64d9170c8565b262ca636721cbee1f78491834595191655203946c3b37d00abd.json#64d9170c8565b262ca636721cbee1f78491834595191655203946c3b37d00abd | no blocking findings | 864c658302f2335c08eec731fae814a5f9db23d75786a2707916298c3b50d592 |

## Verification

- Passed: 审查后再次managed snapshot/report校验通过，Swift parse、bash -n与diff check通过；24文件字节/Git身份及最终独立报告一致，版本1.14.0/build16；无测试或真实会话修改，发布阶段尚未执行。
