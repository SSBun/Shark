# 构建并核验 SharkSpace 1.14.0 安装包

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-27 20:09) |
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

- [ ] T1: 现有构建入口成功生成 1.14.0 build 16 的 Release app 与有效 DMG，校验和、架构和签名状态明确
- [ ] T2: npm 包仅包含允许的安装脚本与元数据，pack/publish dry-run 通过
