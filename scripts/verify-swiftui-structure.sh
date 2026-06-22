#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! rg -q '@MainActor' Shark/Views/WorkspaceStore.swift ||
   ! rg -q '@Observable' Shark/Views/WorkspaceStore.swift ||
   ! rg -q 'final class WorkspaceStore' Shark/Views/WorkspaceStore.swift; then
  echo "missing modern WorkspaceStore" >&2
  exit 1
fi

if rg -n -e '@StateObject private var workspaceManager' -e 'Binding\(' Shark/Views/MainWorkspaceView.swift; then
  echo "MainWorkspaceView still owns legacy manager/binding glue" >&2
  exit 1
fi

if ! rg -Fq 'Check Health...' Shark/Views/WorkspaceListView.swift || ! rg -Fq 'stethoscope' Shark/Views/WorkspaceListView.swift; then
  echo "Workspace context menu must expose health check with an icon" >&2
  exit 1
fi

if ! rg -Fq 'Recreate Symlinks' Shark/Views/WorkspaceListView.swift || ! rg -Fq 'Remove Missing Links' Shark/Views/WorkspaceListView.swift; then
  echo "Workspace health sheet must expose repair actions" >&2
  exit 1
fi

echo "swiftui structure verified"
