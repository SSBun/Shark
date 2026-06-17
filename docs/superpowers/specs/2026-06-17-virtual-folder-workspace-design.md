# Virtual Folder Workspace Design

## Goal

Remove the Cursor workspace type and keep one workspace model: a virtual folder workspace.

A virtual folder workspace is a real directory that contains symlinks to project/component folders plus metadata. Agent tools and IDEs can open it as a normal project folder.

## Scope

In scope:
- Remove `.code-workspace` creation, import, save, open, and duplicate-to-Cursor flows.
- Remove `WorkspaceType.cursor`.
- Replace the type picker with a single create action.
- Rename Claude-specific core concepts to virtual-folder terminology where they represent the generic model.
- Keep existing virtual-folder behavior: metadata file, linked folder list, symlink creation, rename, delete, folder add/drop/component select, Git/Fork/SourceTree/Xcode/Terminal actions.

Out of scope:
- Migration/import of existing `.code-workspace` files.
- Deleting user `.code-workspace` files from disk.
- New agent-specific launchers.
- Redesigning the whole app shell.

## Product Behavior

The app manages only virtual folder workspaces.

Creating a workspace creates a directory under the configured settings folder. The directory contains metadata and symlinks to selected folders. The workspace list shows these directories only.

Opening a workspace opens the workspace directory. It no longer opens a `.code-workspace` file. Existing folder-level actions remain available from folder rows.

If old `.code-workspace` files exist in the settings folder, Shark ignores them. It does not delete them.

## Data Model

`Workspace` no longer needs a type. Its path is always a directory path.

Current `ClaudeWorkspaceFile` should become a neutral virtual workspace metadata type. Minimum rename:
- `ClaudeWorkspaceFile` -> `VirtualWorkspaceFile`
- `.claude-workspace.json` -> keep or rename to `.shark-workspace.json`

Recommendation: rename the metadata file to `.shark-workspace.json`. Old `.claude-workspace.json` compatibility is out of scope for this A-path cleanup.

## UI Changes

Workspace list:
- `+` directly creates a virtual folder workspace.
- Remove the Cursor/Claude picker popover.
- Remove duplicate-as-Cursor / duplicate-as-Claude menu item.
- Remove workspace type icons/colors.
- Update row help text to mention opening the workspace folder.

Settings:
- Keep default IDE setting only if it is still used elsewhere. If workspace open no longer uses IDE selection, remove that setting now rather than keeping dead UI.
- Keep terminal setting because folder/workspace opening can still use it.

Docs:
- Update README and changelog language from Cursor/Claude workspace types to virtual folder workspaces.

## Code Impact

Likely files:
- `Shark/Models/Workspace.swift`
- `Shark/Models/ClaudeWorkspaceFile.swift`
- `Shark/Utilities/WorkspaceManager.swift`
- `Shark/Utilities/WorkspaceOpener.swift`
- `Shark/Views/MainWorkspaceView.swift`
- `Shark/Views/WorkspaceListView.swift`
- `Shark/Views/SettingsView.swift`
- `README.md`
- `CHANGELOG.md`

Files likely removable if no longer referenced:
- `Shark/Models/CursorWorkspaceFile.swift`
- Cursor-only helpers in `FileDialogHelper` and `SettingsManager`

## Verification

Smallest useful checks:
- Build succeeds with no `.cursor` or `CursorWorkspaceFile` references.
- Creating a workspace creates a directory with metadata.
- Adding/removing folders updates metadata and symlinks.
- Opening a workspace opens the directory.
- Existing `.code-workspace` files are ignored, not deleted.

## Deliberate Simplifications

- No migration path for `.code-workspace`.
- No backward compatibility for old Cursor workspace records in UserDefaults.
- No agent-specific opening logic yet; a virtual folder is the shared contract.
