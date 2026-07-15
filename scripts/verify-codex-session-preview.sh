#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

xcrun swiftc \
  Shark/Models/CodexSessionPreview.swift \
  Shark/Utilities/CodexSessionPreviewLoader.swift \
  scripts/CodexSessionPreviewLoaderCheck.swift \
  -o "$tmp_dir/codex-session-preview-check"

"$tmp_dir/codex-session-preview-check"
