# 发布并回读验证 SharkSpace 1.14.0

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-27 20:23) |
| Artifacts | [Artifacts](../artifacts/publish-shark-1-14-0/) |
| Kind | Task |
| Parent | release-all-local-changes |

## Scope

仅对既有 SSBun/Shark main 与新 tag v1.14.0、GitHub Release 资产及 @ssbun/sharkspace@1.14.0 的 public/latest 发布；不覆盖已有tag/版本，不安装本地App，不运行单元测试。发布前等待用户独立清单确认；npm身份须有效且与包权限匹配。

## Plan

1. 补交生成中的任务/审查记录，保持全部本地改动已提交；核对GitHub身份与远端tag未占用。
2. 用户确认发布清单后推送main和新tag，让既有工作流生成Release；回读workflow、asset、下载校验和、DMG版本/签名。
3. GitHub同版本DMG可访问后核对npm登录身份/版本未占用，发布public/latest并回读registry和包内容；保持发布记录及最终集成验证。
- Current artifacts: 本地已验收DMG为 `dist/SharkSpace-1.14.0_20261027T121549Z/SharkSpace-1.14.0.dmg`；[发布说明](../artifacts/publish-shark-1-14-0/reports/release-notes.md)。
- Next action: 用户确认GitHub与npm对外发布清单后，重新核对身份与tag/version再执行远端步骤。
- Required input: 用户执行npm login恢复身份，并明确确认本次远端发布清单。当前尚未执行push/tag/npm正式发布。

## Block

- Reason: npm whoami 持续返回 E401 Unauthorized；当前无有效npm身份。正式GitHub/npm发布清单也尚待用户确认，未执行任何远端写入。
- Unblock when: 用户完成npm login，Agent重新核实有效身份与包权限，并取得本次发布清单的明确确认。

## Target

- [ ] T1: 用户确认发布清单后，推送发布代码与 v1.14.0，GitHub Release 含可下载且校验正确的 DMG 与 SHA256
- [ ] T2: npm @ssbun/sharkspace@1.14.0 发布成功，registry latest 与目标版本一致
