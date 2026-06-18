# Build And Deploy

## 当前链路

- Xcode scheme：`Shark`
- Xcode product：`SharkSpace.app`
- GitHub Release workflow：tag `v*` 触发，构建 Release，创建 DMG，上传 release asset。
- 本地/npm 工具：`npx tsx scripts/build-tool.ts create-dmg <version>` 和 `publish <version>`。
- 安装脚本：`install_latest.sh` 从 GitHub latest release 下载 DMG 并打开。

## 主要风险

1. CI 查找 `Shark.app`，但实际产品是 `SharkSpace.app`。
2. CI 生成 `Shark-${VERSION}.dmg`，本地/npm 工具生成 `SharkSpace-${version}.dmg`。
3. release build 禁用签名，安装说明依赖 quarantine/Gatekeeper 绕过。
4. `install_latest.sh` 不校验 SHA256，`curl` 没有 `-f`。
5. `workflow_dispatch` 只上传 artifact，不创建 GitHub Release，但文档需要明确。

## 优化建议

- 统一品牌名、`.app` 名、DMG 名、npm 包内文件名。
- GitHub Action 复用 `scripts/build-tool.ts`。
- 建立 Developer ID 签名、公证和 staple 流程。
- 安装脚本使用 `curl -fL`，下载并验证 `.sha256`。
- 移除 `sudo spctl --master-disable` 安装建议。
