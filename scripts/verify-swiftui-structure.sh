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

echo "swiftui structure verified"
