# 准备并提交 SharkSpace 1.14.0 源码与版本元数据

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-27 19:49) |
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

**工作区与会话界面**（[Views](../../Shark/Views/)）：纳入 Projects 分组、归档切换、可见归档批量清理、会话摘要、右键预览和激活刷新；补齐 Project 删除保护、两阶段筛选一致性、Project 会话重命名禁用及 Codex CLI 环境/错误处理。

**发布元数据与文档**（[Xcode 项目](../../Shark.xcodeproj/)；[package.json](../../package.json)；[package-lock.json](../../package-lock.json)；[CHANGELOG](../../CHANGELOG.md)；[README](../../README.md)）：统一 1.14.0 / build 16，记录实际用户可见功能与修复；补充已有 Context 的组件边界和本次验证记录。

## Target

- [ ] T1: 现有 Projects 与 Codex 会话改动及 Fork 修复纳入发布，必要的发布阻塞问题已处理且不误删外部项目目录
- [ ] T2: package、lockfile、Xcode 版本统一为 1.14.0，build 为 16，更新日志与功能文档符合实际
- [ ] T3: 全部可入库的本地改动经过敏感信息检查并提交，构建产物不进入 Git 历史
