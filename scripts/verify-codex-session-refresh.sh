#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

swiftc -O -parse-as-library \
  Shark/Models/CodexSession.swift \
  Shark/Models/CodexSessionRuntimeState.swift \
  Shark/Utilities/Log.swift \
  Shark/Utilities/CodexHookInstaller.swift \
  Shark/Utilities/CodexSessionRuntimeDetector.swift \
  Shark/Utilities/CodexSessionManager.swift \
  scripts/CodexSessionRefreshCheck.swift \
  -o "$tmp_dir/codex-session-refresh-check"

"$tmp_dir/codex-session-refresh-check"
