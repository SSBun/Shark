# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Codex sessions 现在按 Last 8 Hours、Last 2 Days、Last Week、Older 分组显示 active sessions。
- Workspace 右键菜单新增 `Check Health...`，可检查 workspace directory、metadata、linked folders、symlinks、unexpected symlinks 和 Codex hooks 状态。
- Workspace Health 面板新增 `Recreate Symlinks` 和 `Remove Missing Links` 修复动作。

### Changed
- 更新 README，使其匹配当前 virtual folder、Codex sessions、Codex hooks 和 workspace health 功能。

## [1.10.0] - 2026-06-18

### Added
- 新增 Codex Sessions 面板，按当前 workspace 展示相关 Codex 会话。
- 支持 Codex session 多选、归档、删除、复制 ID、复制路径和在终端恢复。
- 支持检测 Codex CLI session 是否正在终端运行，并跳转到对应 iTerm2 session。
- 新增 Codex hooks 安装入口，用于捕获稳定的终端 session 标识。
- 支持为 Codex session 设置 Shark 内部显示名，并保存到 workspace 的 `.shark-workspace.json`。

### Changed
- 移除 Cursor workspace 类型和旧 workspace 文件管理流程。
- 只保留 virtual folder workspace：真实目录 + metadata + symlink。
- Workspace 打开行为改为打开虚拟工作区目录。

## [1.9.0] - 2026-06-04

### Added
- Workspace grouping: same-name cursor + claude workspaces shown under shared section header
- TypeScript build-tool (`scripts/build-tool.ts`) replacing shell script for DMG creation and npm publishing
- `build-tool publish <version>` command — bumps version, creates DMG, publishes to npm
- `build-tool create-dmg [version]` command — build + DMG packaging with spinner UI

### Changed
- `scripts/create-dmg.sh` replaced by `scripts/build-tool.ts` (uses commander + @clack/prompts)
- Workspace list groups workspaces by name instead of flat list under "Pinned"/"Workspaces" sections
- Build output is now silent, only showing errors on failure

### Added
- Pin workspaces to top of list with context menu toggle
- Drag-and-drop reordering within pinned and unpinned sections
- Orange pin indicator icon on pinned workspace rows
- Sort order persists across app restarts

## [1.7.0] - 2026-05-16

### Added
- "Open In Fork Workspace" context menu for workspace cells — finds or creates a named Fork workspace with all git repos as tabs
- Shared `gitRepoPaths(for:)` helper on WorkspaceManager for both Cursor and Claude workspace types

### Changed
- Disabled App Sandbox for full filesystem and AppleScript access
- Simplified ForkOpener to resolve `fork` CLI via PATH

## [1.6.0] - 2026-05-14

### Added
- Duplicate workspace via context menu: Cursor → Claude or Claude → Cursor

## [1.5.1] - 2026-05-11

### Fixed
- Symlink removal failure when symlink points to a directory (caused "file already exists" error when saving Claude Code workspaces)
- Added debug logging to SymlinkManager and workspace save flow

## [1.5.0] - 2026-05-11

### Added
- Support for multiple components search paths with add/remove UI
- Legacy single-path auto-migration to array format

### Fixed
- DMG creation failure from duplicate Applications symlink
- Stale rw.* temp files not cleaned up after DMG creation

## [1.4.0] - 2026-05-10

### Added
- Claude Code workspace support with symlink-based folders

## [1.3.2] - 2026-04-07

### Added
- Developing Dependencies section with git branch display

## [1.3.1] - 2026-04-07

### Added
- Developing Dependencies section

## [1.3.0] - 2026-04-01

### Added
- Venomfiles dependency checker for project components
- Multi-IDE support for opening workspaces and jumping to dependency repositories
- Edit button to open dependency source file in default editor

### Changed
- Removed Zed from IDE selector due to lack of legacy workspace-file support

## [1.2.1] - 2026-03-26

### Changed
- Internal version bump

## [1.2.0] - 2026-03-12

### Added
- Drag-and-drop support for folders
- Updated app icon
- Jekyll website for Shark

### Fixed
- Robust DMG URL extraction with GitHub API, redirect, and HTML scraping fallbacks

## [1.1.4] - 2026-03-06

### Added
- One-command installation script (`install_latest.sh`)
- Renamed Advanced tab to About

### Fixed
- `hdiutil` detach handling for volume names with spaces
- Cache refresh and correct detach on DMG install
- Use `github.com` raw URL instead of `raw.githubusercontent.com`

### Changed
- Download DMG to Downloads folder and open it instead of auto-installing

## [1.1.3] - 2026-03-06

### Added
- Update checker with GitHub Releases API

## [1.1.2] - 2026-03-06

### Added
- Multi-select support and context menus for folders
- Open in SourceTree option in context menus
- SourceTree app icon for SourceTree menu items
- INSTALL.md included in DMG with `xattr` instructions

### Changed
- Reorganized folder and workspace context menu sections

## [1.1.1] - 2026-03-04

### Added
- Git branch/tag badges for folder rows

### Changed
- Refactored Log utility to use static methods with `LogCategory`

## [1.1.0] - 2026-01-29

### Added
- Xcode project support
- Improved sandbox permission handling

## [1.0.3] - 2026-01-29

### Added
- Components search path and component selector
- Click component list cell to toggle selection

### Fixed
- Sync workspace file name with list name on rename
- Handle security-scoped bookmarks for custom storage path
- Refresh workspace list after changing storage path

## [1.0.2] - 2025-11-12

### Added
- Git repository detection
- Fork integration

## [1.0.1] - 2025-11-12

### Fixed
- Window management bugs
- File dialog issues

## [1.0.0] - 2025-11-12

### Added
- Inline rename functionality for workspaces
- Gatekeeper bypass instructions
- Open button for workspace rows
- README with screenshots
