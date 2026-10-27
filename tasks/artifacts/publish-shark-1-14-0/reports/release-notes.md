# SharkSpace 1.14.0

- 新增 Projects 分组，直接添加已有目录并查看 Codex 会话；移除只删除列表引用，重命名只改变显示名。
- 默认隐藏子代理会话，可在设置中切换；会话列表展示消息摘要，应用激活时刷新。
- 支持取消归档与确认后的可见归档会话批量清理；混合多选按菜单目标状态执行，不反转其他会话。
- 会话预览调整为右键 Preview，保留辅助功能入口。
- 修复 Open in Fork 在 GUI 环境中找不到 CLI 的问题，并显示打开错误。
- Codex 会话命令通过登录 shell 查找 CLI，失败时显示错误。
- 修复 CI 安装包签名不完整，打包前验证签名完整性。

## 安装与兼容性

- 应用版本：1.14.0，build 16；最低 macOS 15.2。
- 安装包采用无证书 ad-hoc 签名，**不是 Developer ID 签名，未经过 Apple 公证**。签名完整性通过不代表 Gatekeeper 信任。
- npm 安装器从同版本 GitHub Release 下载 DMG，npm 包不内嵌安装包。

## 验证范围

Debug/Release 构建、Swift 与脚本语法检查、DMG 完整性、bundle 签名与权限项核验，以及 npm 打包/发布 dry-run 已完成。未执行单元测试、完整 GUI 或覆盖安装验收。
