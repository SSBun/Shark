# API Surface

## 对外接口

项目没有网络服务 API。主要外部接口是：

- GitHub Releases API：`UpdateManager.checkForUpdates()`。
- macOS 文件系统和 security-scoped bookmark。
- AppleScript/`open`/CLI 与 Terminal、Fork、SourceTree、Xcode、IDE 集成。
- npm package bin：`shark` 指向 `install.js`。
- GitHub Pages 官网。

## 风险和建议

- GitHub API 只做更新发现，没有下载校验。
- npm bin 和 `postinstall` 都运行 `install.js`，使用 `npx @ssbun/sharkspace shark` 时可能打开两次 DMG。
- AppleScript/CLI 集成失败时多数只记录 log，应给用户可见反馈。
