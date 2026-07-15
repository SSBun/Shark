#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

xcrun swiftc \
  Shark/Models/GitRepositoryStatus.swift \
  Shark/Views/WorkspaceGitStatusStore.swift \
  scripts/GitRepositoryStatusCheck.swift \
  -o "$tmp_dir/git-repository-status-check"

"$tmp_dir/git-repository-status-check"

if ! rg -Fq 'WorkspaceGitOverviewView' Shark/Views/FolderListView.swift ||
   ! rg -Fq 'GitStatusValueView' Shark/Views/FolderListView.swift ||
   ! rg -Fq 'Fetch & Refresh' Shark/Views/WorkspaceGitOverviewView.swift; then
  echo "Git overview or folder cell status wiring is missing" >&2
  exit 1
fi

echo "git overview verified"
