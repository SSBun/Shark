# Dependencies

## Swift/macOS

项目没有 Swift Package 依赖，主体使用系统框架：
- SwiftUI
- AppKit
- Foundation
- os/log

## Node/npm

`package.json` 只服务于 DMG 打包和 npm 分发：
- `commander`
- `@clack/prompts`
- `tsx`
- `@types/node`

观察：
- `package.json` 版本是 `1.9.0`，`package-lock.json` 根版本仍为 `1.8.0`。
- `scripts/build-tool.ts` 发布时只写 `package.json`，没有同步 lockfile。

## Ruby/Jekyll

`docs/Gemfile` 用于 GitHub Pages Jekyll 站点。仓库未发现 `docs/Gemfile.lock`，CI 每次会重新解析兼容版本。

## 优化建议

- 用 `npm version` 或同步更新 `package-lock.json`。
- 提交 `docs/Gemfile.lock`，或明确 Pages 构建依赖策略。
- 将 GitHub Action 的 DMG 生成改为调用 `scripts/build-tool.ts`，避免 CI 与本地工具逻辑漂移。
