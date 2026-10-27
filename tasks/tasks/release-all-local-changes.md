# 提交全部本地改动并发布 Shark 新版本

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-27 19:46) |
| Kind | Queue |

## Scope

发布版本按兼容新功能递增为 1.14.0 / build 16；沿用 GitHub tag 工作流与 npm 原生安装器分发。所有原有本地改动属于本次提交范围，不引入新发布系统、不安装到 Applications、不运行单元测试。沿用既有 CI 的 NO_SIGN=1，明确其非 Developer ID、公证状态。远端发布等待独立清单确认。

## Plan

1. `prepare-shark-1-14-0`：准备、检查、独立审查并提交现有代码及版本元数据。
2. `package-shark-1-14-0`：依赖前项源码，构建并核验 Release app、DMG 与 npm dry-run。
3. `publish-shark-1-14-0`：依赖前项产物及发布清单确认，完成 GitHub 与 npm 发布回读。
- Current artifacts: 源码与打包阶段完成；GitHub v1.14.0和DMG已公开发布并核验，应用1.14.0/build16、ad-hoc无公证。npm发布EOTP，latest仍1.13.0。
- Next action: 在发布子任务处理npm一次性验证码，再回读registry并完成最终集成验证。
- Required input: 当前npm OTP或用户自行完成本次npm发布的明确结果。

## Target

- [ ] T1: 当前全部本地改动经过检查并提交，敏感信息与不应发布的构建产物不进入 Git 历史
- [ ] T2: 新版本的应用、包元数据与更新日志一致，构建及安装包检查通过
- [ ] T3: 按项目既有发布渠道发布新版本，并核实远端版本与可下载产物

## Children

1. [准备并提交 SharkSpace 1.14.0 源码与版本元数据](prepare-shark-1-14-0.md)
2. [构建并核验 SharkSpace 1.14.0 安装包](package-shark-1-14-0.md)
3. [发布并回读验证 SharkSpace 1.14.0](publish-shark-1-14-0.md)
