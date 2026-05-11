# Changelog

All notable changes to this project will be documented in this file.

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
- Removed Zed from IDE selector due to lack of `.code-workspace` support

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
