# 发布并回读验证 SharkSpace 1.14.0

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-27 20:38) |
| Artifacts | [Artifacts](../artifacts/publish-shark-1-14-0/) |
| Kind | Task |
| Parent | release-all-local-changes |

## Scope

仅对既有 SSBun/Shark main 与新 tag v1.14.0、GitHub Release 资产及 @ssbun/sharkspace@1.14.0 的 public/latest 发布；不覆盖已有tag/版本，不安装本地App，不运行单元测试。发布前等待用户独立清单确认；npm身份须有效且与包权限匹配。

## Plan

1. 补交生成中的任务/审查记录，保持全部本地改动已提交；核对GitHub身份与远端tag未占用。
2. 用户确认发布清单后推送main和新tag，让既有工作流生成Release；回读workflow、asset、下载校验和、DMG版本/签名。
3. GitHub同版本DMG可访问后核对npm登录身份/版本未占用，发布public/latest并回读registry和包内容；保持发布记录及最终集成验证。
- Current artifacts: GitHub [v1.14.0](https://github.com/SSBun/Shark/releases/tag/v1.14.0) 已发布；[工作流](https://github.com/SSBun/Shark/actions/runs/40504052031) 成功；公开DMG下载、SHA256、版本/build与签名已核验。npm正式发布返回EOTP，registry latest仍1.13.0。
- Next action: 取得当前npm一次性验证码后，先核实1.14.0未占用，再用同一发布命令附OTP重试一次；或用户在本机完成发布后回读registry。
- Required input: 当前npm OTP，或用户自行完成npm publish的明确结果。不要将验证码写入仓库或任务记录。

## Block

- Reason: npm登录已有效（ssbun），但正式publish返回EOTP，要求authenticator一次性验证码；没有发布1.14.0，registry latest仍1.13.0。GitHub Release已成功且验证通过。
- Unblock when: 用户提供当前有效npm OTP或自行完成本次npm发布；重新检查目标版本真实状态后继续，禁止盲目重复发布。

## Target
- [x] T1: 用户确认发布清单后，推送发布代码与 v1.14.0，GitHub Release 含可下载且校验正确的 DMG 与 SHA256
- [ ] T2: npm @ssbun/sharkspace@1.14.0 发布成功，registry latest 与目标版本一致

## Result

- T1: 用户恢复npm登录并允许继续后核实身份ssbun/GitHub SSBun、版本/tag未占用；原子推送main与v1.14.0，tag解析为323191bbe737b2df1cdd721bea3cf9030a5c1161。工作流40504052031成功；Release公开且非prerelease，含DMG与SHA256并已填充发布说明。无认证curl下载后shasum-c、hdiutil verify与codesign严格验证通过，App1.14.0/build16、arm64、min15.2、ent与源一致、无get-task-allow。公开DMG SHA256=5d8fa5a47db2fa1bccb367a158027546edfa46ca4a95df1e1b9301662c5a5782，与GitHub asset digest一致。见github-run.json、github-release.json、download-verification.log；ad-hoc不代表Developer ID或公证。

## Verification

- Failed: npm publish --access public --tag latest --json返回EOTP；回读registry最新及latest仍1.13.0，未声称npm发布完成。需要当前OTP或用户自行发布后核实。
