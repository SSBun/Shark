# 发布并回读验证 SharkSpace 1.14.0

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-27 20:27) |
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
- Next action: 本轮用户已表示登录npm并允许继续，身份核实为ssbun/GitHub SSBun；复核目标版本未占用后执行已展示清单的main/tag与GitHub/npm发布。
- Required input: None。发布中如遇OTP、权限错误或远端状态不确定，再记录具体阻塞。

## Target

- [ ] T1: 用户确认发布清单后，推送发布代码与 v1.14.0，GitHub Release 含可下载且校验正确的 DMG 与 SHA256
- [ ] T2: npm @ssbun/sharkspace@1.14.0 发布成功，registry latest 与目标版本一致
