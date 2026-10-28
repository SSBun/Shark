# Sparkle 2 更新接入

## 当前边界

Shark 通过 SPM 固定使用 Sparkle 2.10.1。应用启动时创建同一个 `SPUStandardUpdaterController`，应用菜单和 Settings > About 的检查按钮共用该实例；检查、下载、验签、安装和重启界面均由 Sparkle 提供。自动检查使用 Sparkle 自己的授权提示、偏好和调度，不另存一套设置。

这不表示当前公开的 1.14.0 已支持 Sparkle：它不包含该框架，不能作为自动更新验收的基线。首次必须手动安装一个包含 Sparkle 的基线版本 A，再从 A 更新到更高 build 的 B。

## 更新源与签名密钥

- Feed 地址：`https://ssbun.github.io/Shark/appcast.xml`。
- 源文件：`docs/appcast.xml`，由既有 GitHub Pages 工作流部署。首次只有合法空 channel，不能放入尚未验证的更新项。
- 公钥保存在 `Shark/Info.plist` 的 `SUPublicEDKey`。
- 私钥由官方 `generate_keys` 创建，存放在当前 Mac 的登录 Keychain，账号为 `com.csl.cool.Shark`。没有导出，也没有上传到 GitHub、CI 或仓库。
- 独立的安全备份尚未确认；正式长期分发前，维护者需完成受控的加密备份。不能把唯一密钥留在可能被清空且无备份的环境中。
- 公钥发布后，不得因为找不到私钥而生成另一对密钥替换它；必须使用 Sparkle 的官方密钥迁移流程。

## Apple 签名条件

Sparkle 框架和其辅助进程需要正确的代码签名。用于本机验收的 Apple Development 签名，不等于生产 Developer ID 签名、Apple 公证或 Gatekeeper 信任。

现有 tag CI 使用 `NO_SIGN=1`。此模式由打包入口从原始 entitlements 生成临时副本，仅增加 `com.apple.security.cs.disable-library-validation=true`，通过 Xcode 完整 ad-hoc 签名，保留 Hardened Runtime 其余保护，并禁用调试 entitlement 自动注入。此应用级例外允许没有 Apple Team 身份的进程加载 Sparkle，同时降低对其他动态库加载的限制；不等于关闭系统 Gatekeeper。

打包入口核实实际产物的 ad-hoc 签名、runtime 标记、Library Validation 例外及不存在启用的 get-task-allow，复制后再次严格验证完整性。不使用 `NO_SIGN=1` 时仍沿用项目身份签名，原始 entitlements 不增加该例外。`--no-build` 也必须显式设置相同模式，不能将其他产物误作已验证的无证书发布包。

本项目选择以 EdDSA 签署最终更新归档，不要求 Developer ID 作为此发布路线的前提；但 EdDSA 不提供 Apple 开发者身份或公证。默认 Gatekeeper 仍可能阻止首次打开，用户必须确认可信来源后自行使用系统提供的单应用“仍要打开”流程，受管理设备可能不允许。不得通过关闭 Gatekeeper 或批量清除隔离属性掩盖该限制。Apple Development 仍仅用于本机开发验证，不能冒充正式 Developer ID 分发。

归档验签和本机启动不能代替公开下载及真实 A→B 升级验收；本次发布不声称已通过 Apple 公证或完整跨机升级验证。

## 准备更新

1. 同步展示版本与严格递增的整数 `CFBundleVersion`，保留相同 bundle identifier、有效公钥和 HTTPS feed。
2. 使用现有 `scripts/build-tool.ts create-dmg` 构建最终签名的归档。打包保留 Sparkle framework 的相对 symlink，并在复制前后校验签名。
3. 按现有流程上传最终 DMG 与 SHA256 到对应 GitHub Release；此时不发布新的 appcast item。
4. 公开下载该 DMG，核对 HTTP 200、SHA256、字节数、版本/build、Apple 签名、架构和最低系统版本。不能拿本机构建的另一份 DMG 替代 CI 的最终字节。
5. 在保存私钥的 Mac 上，用同一版本 Sparkle 的工具准备 feed：

   ```bash
   npx tsx scripts/build-tool.ts appcast VERSION DOWNLOADED_DMG --derived-data DERIVED_DATA
   ```

   `DERIVED_DATA` 中必须已经解析项目锁定的 Sparkle 包。工具会：
   - 只读取专用 Keychain 账号，并确认公钥与应用配置相符；不创建、导出或轮换密钥。
   - 从固定的 GitHub Release HTTPS URL 下载归档并比对 SHA256；未公开或字节不一致立即失败。
   - 在忽略的 `dist` 子目录暂存归档与现有 feed，用官方 `generate_appcast` 生成签名及长度，不生成 delta。
   - 检查展示版本、整数 build 单调递增、URL、长度和签名，再用官方 `sign_update --verify` 验证。
   - 只返回暂存 XML，不覆盖 `docs/appcast.xml`，不执行 Git push 或任何发布。

6. 复核暂存 XML 后，再将其更新到 `docs/appcast.xml` 并部署 Pages。公开 feed 是让旧版客户端看到新更新的真正发布动作，必须在归档验证通过后进行。
7. 从公开 URL 重新核对版本/build、下载 URL、长度、签名、最低系统版本及架构；最后再处理 npm 等二级分发入口。

## 首次验收

所选签名模式的产物验证、公开 feed 和发布/安装授权齐备后：

1. 发布并安装包含 Sparkle 的 A，保持它从可写的 Applications 目录运行。
2. 生成更高 build 的 B，保持签名身份和公钥有效，按上述顺序发布。
3. 在 A 中检查更新，核对标准窗口显示 A 和 B。
4. 在动作时确认后，允许下载、验签、安装和重启；不得用 Finder 或脚本提前覆盖 A。
5. 复核安装后的展示版本/build、签名，以及再次检查不会重复提供 B。

构建、生成 appcast 或签名验证成功，都不能替代这次真实 A → B 验收。

## 官方资料

- [基本接入与安全要求](https://sparkle-project.org/documentation/)
- [SwiftUI 标准更新器](https://sparkle-project.org/documentation/programmatic-setup/)
- [发布更新](https://sparkle-project.org/documentation/publishing/)
