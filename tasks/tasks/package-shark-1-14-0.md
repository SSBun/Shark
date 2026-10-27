# 构建并核验 SharkSpace 1.14.0 安装包

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-27 20:21) |
| Artifacts | [Artifacts](../artifacts/package-shark-1-14-0/) |
| Kind | Task |
| Parent | release-all-local-changes |

## Scope

使用已审查源码和现有 build-tool 构建 Release/DMG；NO_SIGN=1 保持无证书 CI 模式，但修复其只有链接器签名、bundle 校验失败的问题，改由 Xcode 完整 ad-hoc 签名并在打包前强制验证。不增加 Developer ID、公证或安装步骤。npm 仅 pack/publish dry-run，不正式发布。不运行单元测试。

## Plan

1. 现有依赖已安装，复用 build-tool 与 Shark scheme；修正 NO_SIGN=1 的 Xcode 签名参数，保留无证书边界，强制 codesign 校验后才打包。构建目录置于临时目录，DMG 仍使用忽略的 dist 目录。
2. 核验 DMG 可读性、SHA256、bundle 版本/build/架构以及签名状态，明确没有 Developer ID/公证。
3. 检查 npm dry-run 只含 package.json、README.md、install.js；保存最小证据。因签名与发布脚本修改，执行 R2 fresh/read-only 独立审查后最终校验。

## Task Summary

**打包入口**（[scripts](../../scripts/)）：修复无证书 CI 模式的 Xcode 签名参数，使用完整 ad-hoc 签名并禁用基础调试 entitlement 自动注入；找到 Release app 后严格校验签名，通过后才生成 DMG。沿用原有构建与 DMG 工具链，没有新增发布系统。

**发布说明**（[CHANGELOG](../../CHANGELOG.md)；[README](../../README.md)）：记录 CI 包签名修复，按实际 project/DMG 的最低系统版本将文档更正为 macOS 15.2；同步打包边界 Context。

## Target
- [x] T1: 现有构建入口成功生成 1.14.0 build 16 的 Release app 与有效 DMG，校验和、架构和签名状态明确
- [x] T2: npm 包仅包含允许的安装脚本与元数据，pack/publish dry-run 通过

## Result

- T1: 最终DMG为dist/SharkSpace-1.14.0_20261027T121549Z/SharkSpace-1.14.0.dmg，SHA256=ab77694b49691e0511b7c1d1ba931b55a39f6abf9f957dd48691d7e26d196cbe。现有build-tool成功Release构建，hdiutil verify有效；只读挂载核对App为1.14.0/build16、com.csl.cool.Shark、arm64、最低macOS15.2。codesign严格/深度验证通过，签名ad-hoc且runtime启用；signed entitlement与源文件一致、get-task-allow=false，见artifact-inspection.log。初始仅linker签名失败和中间debug entitlement注入已通过Xcode签名参数修复并重建，历史失败日志保留。非Developer ID、无Apple公证，不声称Gatekeeper信任；未安装或做完整GUI验收。
- T2: npm pack --dry-run --json 与 npm publish --dry-run --access public --json 均退出0；两份JSON确认@ssbun/sharkspace@1.14.0仅3文件README.md、install.js、package.json，不内嵌DMG。修改后的build-tool --help正常解析/加载；未跑单元测试。npm whoami仍401，正式registry发布需要用户登录。
- Review gate: Passed — fresh/read-only reviewer run3478c758 未确认缺陷；主Agent check-evidence已核验20文件及DMG字节，与当前报告/manifest一致，ad-hoc与公证边界明确。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 本阶段实际修改CI/本地打包签名与完整性校验边界，需要独立审查，不能因脚本仅数行而降级。
- Snapshot: snapshot:tasks/artifacts/package-shark-1-14-0/evidence/bfcc5ef893d245481c1feb5391e2dd6c3c4f8ee00504a22991f93edbdd207da6.json#bfcc5ef893d245481c1feb5391e2dd6c3c4f8ee00504a22991f93edbdd207da6
- Evidence: T1/T2、artifact-inspection.log、npm两份dry-run JSON、build-tool-help.log、packaging.diff与最终DMG SHA256。
- Task fingerprint: acc618289ea38e6674d5e7494cd5bcdb56898d5f149b5a3d87d27859e357f107

## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/package-shark-1-14-0/reviews/round-01.md) | snapshot:tasks/artifacts/package-shark-1-14-0/evidence/bfcc5ef893d245481c1feb5391e2dd6c3c4f8ee00504a22991f93edbdd207da6.json#bfcc5ef893d245481c1feb5391e2dd6c3c4f8ee00504a22991f93edbdd207da6 | no blocking findings | abe72489bcb6c64750d58cb8bfb3500f91bbf28fdffd401098d9d459d6c0990f |

## Verification

- Passed: 审查后重新hdiutil verify通过、shasum -c通过，managed snapshot/report校验20文件与最终DMG通过；产物仍1.14.0/build16、signed ent一致且无get-task-allow，npm dry-run清单未变。未安装、无公证或测试。
