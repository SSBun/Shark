#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if rg -n 'WorkspaceType|CursorWorkspaceFile|\.cursor|code-workspace|createNewWorkspace|duplicateAsCursor|duplicateAsClaude|createClaudeWorkspace|ClaudeWorkspaceFile' Shark README.md CHANGELOG.md; then
  echo "virtual workspace cleanup is incomplete" >&2
  exit 1
fi

if ! rg -q 'legacyMetadataFileName = "\.claude-workspace\.json"' Shark/Models/VirtualWorkspaceFile.swift; then
  echo "missing legacy virtual workspace metadata compatibility" >&2
  exit 1
fi

if awk '/func refreshWorkspaces/,/MARK: - Pin/ { print }' Shark/Utilities/WorkspaceManager.swift | rg -n 'workspaces = \[\]'; then
  echo "refresh must not clear saved workspace state before scanning" >&2
  exit 1
fi

echo "virtual workspace cleanup verified"
