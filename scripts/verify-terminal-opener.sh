#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! rg -Fq '["-b", "com.googlecode.iterm2", path]' Shark/Utilities/TerminalOpener.swift; then
  echo "iTerm2 folder open must use the bundle id, not the app name" >&2
  exit 1
fi

if rg -Fq '["-a", "iTerm2", path]' Shark/Utilities/TerminalOpener.swift; then
  echo "open -a iTerm2 fails on systems where the app name is iTerm" >&2
  exit 1
fi

echo "terminal opener verified"
