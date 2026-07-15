#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

for file in Shark/Models/CodexSession.swift Shark/Models/CodexSessionRuntimeState.swift Shark/Models/CodexSessionPreview.swift Shark/Utilities/CodexSessionManager.swift Shark/Utilities/CodexSessionRuntimeDetector.swift Shark/Utilities/CodexSessionPreviewLoader.swift Shark/Utilities/CodexHookInstaller.swift Shark/Views/CodexSessionListView.swift Shark/Views/CodexSessionPreviewView.swift; do
  if [[ ! -f "$file" ]]; then
    echo "missing $file" >&2
    exit 1
  fi
done

if ! rg -q 'VSplitView' Shark/Views/MainWorkspaceView.swift; then
  echo "MainWorkspaceView must place folders and Codex sessions in a VSplitView" >&2
  exit 1
fi

if ! rg -q 'loadCodexSessions' Shark/Views/WorkspaceStore.swift; then
  echo "WorkspaceStore must load Codex sessions for selected workspace" >&2
  exit 1
fi

workspace_selection_body=$(sed -n '/var selectedWorkspace:/,/var folders:/p' Shark/Views/WorkspaceStore.swift)
if ! printf '%s\n' "$workspace_selection_body" | rg -Fq 'didSet' ||
   ! printf '%s\n' "$workspace_selection_body" | rg -Fq 'codexSessions = []' ||
   ! printf '%s\n' "$workspace_selection_body" | rg -Fq 'isLoadingCodexSessions = false'; then
  echo "WorkspaceStore must clear stale Codex sessions and loading state when workspace selection changes" >&2
  exit 1
fi

session_load_body=$(sed -n '/func loadCodexSessions()/,/func openCodexSession/p' Shark/Views/WorkspaceStore.swift)
if ! printf '%s\n' "$session_load_body" | rg -Fq 'selectedWorkspace?.id == workspace.id'; then
  echo "WorkspaceStore must discard Codex session results from a previously selected workspace" >&2
  exit 1
fi

if ! printf '%s\n' "$session_load_body" | rg -Fq 'codexSessionLoadID == loadID' ||
   ! printf '%s\n' "$session_load_body" | rg -q '^[[:space:]]*codexSessions = sessions$' ||
   ! printf '%s\n' "$session_load_body" | rg -q '^[[:space:]]*codexSessions = sessionsWithRuntimeState$'; then
  echo "WorkspaceStore must publish metadata before runtime state and discard superseded refreshes" >&2
  exit 1
fi

if ! rg -q 'state_5.sqlite' Shark/Utilities/CodexSessionManager.swift; then
  echo "CodexSessionManager must read Codex app thread metadata" >&2
  exit 1
fi

if ! rg -q 'isArchived' Shark/Models/CodexSession.swift Shark/Views/CodexSessionListView.swift; then
  echo "Codex sessions must expose archived state in the UI" >&2
  exit 1
fi

if ! rg -q 'DisclosureGroup' Shark/Views/CodexSessionListView.swift; then
  echo "Archived Codex sessions must be in a collapsed group" >&2
  exit 1
fi

if ! rg -Fq 'Last 8 Hours' Shark/Views/CodexSessionListView.swift || ! rg -Fq 'Last 2 Days' Shark/Views/CodexSessionListView.swift || ! rg -Fq 'Last Week' Shark/Views/CodexSessionListView.swift || ! rg -Fq 'Older' Shark/Views/CodexSessionListView.swift; then
  echo "Active Codex sessions must be grouped by recent activity" >&2
  exit 1
fi

if ! rg -q 'Resume in Terminal' Shark/Views/CodexSessionListView.swift; then
  echo "Codex session rows must support resuming in terminal" >&2
  exit 1
fi

if ! rg -q 'Copy Session ID' Shark/Views/CodexSessionListView.swift; then
  echo "Codex session rows must support copying session ids" >&2
  exit 1
fi

if ! rg -q 'Rename Display Name' Shark/Views/CodexSessionListView.swift; then
  echo "Codex session rows must support Shark-only display renaming" >&2
  exit 1
fi

if ! rg -q 'codexSessionDisplayNames' Shark/Models/VirtualWorkspaceFile.swift Shark/Views/WorkspaceStore.swift; then
  echo "Codex session display names must be stored in workspace metadata" >&2
  exit 1
fi

if ! rg -Fq 'arguments: ["resume", session.id]' Shark/Views/WorkspaceStore.swift; then
  echo "WorkspaceStore must resume Codex sessions with codex resume <session_id>" >&2
  exit 1
fi

if ! rg -Fq 'TerminalOpener.runCommands' Shark/Views/WorkspaceStore.swift || ! rg -Fq 'iTermSplitResume' Shark/Utilities/TerminalOpener.swift; then
  echo "Codex session multi-resume must use one iTerm2 tab with split sessions when available" >&2
  exit 1
fi

if ! rg -Fq 'codexResumeInITermSplits' Shark/Utilities/SettingsManager.swift Shark/Views/SettingsView.swift Shark/Utilities/TerminalOpener.swift; then
  echo "Codex session split resume must be configurable from Settings" >&2
  exit 1
fi

if ! rg -Fq 'CodexResumeSplitLayout' Shark/Utilities/TerminalOpener.swift Shark/Utilities/SettingsManager.swift Shark/Views/SettingsView.swift; then
  echo "Codex session split resume must expose a configurable split layout" >&2
  exit 1
fi

if ! rg -Fq 'rightBottomSession' Shark/Utilities/TerminalOpener.swift || ! rg -Fq 'leftBottomSession' Shark/Utilities/TerminalOpener.swift; then
  echo "Automatic Codex split layout must support three-pane and four-pane layouts" >&2
  exit 1
fi

if rg -Fq 'Label("Open"' Shark/Views/CodexSessionListView.swift; then
  echo "Codex session context menu must not include Open" >&2
  exit 1
fi

if ! rg -Fq 'List(selection:' Shark/Views/CodexSessionListView.swift; then
  echo "Codex session list must support selection" >&2
  exit 1
fi

if ! rg -Fq 'Label("Archive"' Shark/Views/CodexSessionListView.swift; then
  echo "Codex session rows must support archive" >&2
  exit 1
fi

if ! rg -Fq 'Label("Delete"' Shark/Views/CodexSessionListView.swift; then
  echo "Codex session rows must support delete" >&2
  exit 1
fi

if ! rg -Fq '["codex", command, "--force", id]' Shark/Views/WorkspaceStore.swift; then
  echo "WorkspaceStore must delete Codex sessions with codex delete --force <session_id> after app confirmation" >&2
  exit 1
fi

if ! rg -q 'runtimeState' Shark/Models/CodexSession.swift Shark/Utilities/CodexSessionManager.swift Shark/Views/CodexSessionListView.swift; then
  echo "Codex sessions must expose terminal runtime state" >&2
  exit 1
fi

if ! rg -q 'lsof' Shark/Utilities/CodexSessionRuntimeDetector.swift; then
  echo "Codex runtime detector must map running CLI sessions from open rollout files" >&2
  exit 1
fi

if ! rg -Fq 'processIDList' Shark/Utilities/CodexSessionRuntimeDetector.swift ||
   ! rg -Fq 'allowNonzeroExit: true' Shark/Utilities/CodexSessionRuntimeDetector.swift; then
  echo "Codex runtime detector must batch lsof PIDs and preserve partial output" >&2
  exit 1
fi

if ! rg -Fq 'threadsByPath' Shark/Utilities/CodexSessionManager.swift ||
   rg -Fq 'CodexSessionRuntimeDetector.terminalStates()' Shark/Utilities/CodexSessionManager.swift; then
  echo "Codex session metadata must use the SQLite path index without blocking on runtime detection" >&2
  exit 1
fi

if ! rg -Fq 'CodexHookInstaller.runtimeDirectory' Shark/Utilities/CodexSessionRuntimeDetector.swift; then
  echo "Codex runtime detector must read hook snapshots before lsof fallback" >&2
  exit 1
fi

if rg -Fq 'onTapGesture(count: 2)' Shark/Views/CodexSessionListView.swift; then
  echo "Codex session rows must not replace List selection with an onTapGesture double-click" >&2
  exit 1
fi

if ! rg -Fq 'simultaneousGesture(' Shark/Views/CodexSessionListView.swift || ! rg -Fq 'TapGesture(count: 2)' Shark/Views/CodexSessionListView.swift; then
  echo "Codex session rows must preserve List selection while supporting double-click preview" >&2
  exit 1
fi

if ! rg -Fq 'event_msg' Shark/Utilities/CodexSessionPreviewLoader.swift || ! rg -Fq 'recentMessageLimit = 8' Shark/Utilities/CodexSessionPreviewLoader.swift; then
  echo "Codex session preview must load the initial prompt and eight recent user-visible messages" >&2
  exit 1
fi

if ! rg -Fq 'arrow.up.forward.square' Shark/Views/CodexSessionListView.swift; then
  echo "Running Codex session rows must show the iTerm jump icon" >&2
  exit 1
fi

if rg -Fq '[TerminalJump]' Shark/Views/CodexSessionListView.swift Shark/Views/WorkspaceStore.swift Shark/Utilities/TerminalOpener.swift; then
  echo "Old Codex terminal jump path must be removed" >&2
  exit 1
fi

if rg -Fq 'codexSessionTitle' Shark/Utilities/TerminalOpener.swift Shark/Views/WorkspaceStore.swift; then
  echo "Codex iTerm jump must not use tab titles as session identity" >&2
  exit 1
fi

if ! rg -Fq 'jumpToITermTab' Shark/Utilities/TerminalOpener.swift Shark/Views/WorkspaceStore.swift; then
  echo "Codex iTerm jump must have a dedicated tab selector" >&2
  exit 1
fi

if ! rg -Fq 'tty of terminalSession' Shark/Utilities/TerminalOpener.swift; then
  echo "Codex iTerm jump must select sessions by tty" >&2
  exit 1
fi

if ! rg -Fq 'unique ID of terminalSession' Shark/Utilities/TerminalOpener.swift; then
  echo "Codex iTerm jump must prefer hook-captured iTerm session id" >&2
  exit 1
fi

if ! rg -Fq 'iTermTTYJump' Shark/Utilities/TerminalOpener.swift; then
  echo "Codex iTerm jump must log tty-based activation results" >&2
  exit 1
fi

if rg -Fq 'iTermTitleJump' Shark/Utilities/TerminalOpener.swift; then
  echo "Codex iTerm jump must not use title-based activation" >&2
  exit 1
fi

if ! rg -Fq 'NSAppleEventsUsageDescription' Shark.xcodeproj/project.pbxproj; then
  echo "iTerm jump must include Apple Events usage description" >&2
  exit 1
fi

if ! rg -Fq '[CodexRuntime]' Shark/Utilities/CodexSessionRuntimeDetector.swift; then
  echo "Codex runtime detector must log scan results" >&2
  exit 1
fi

if ! rg -Fq 'Install Codex Hooks' Shark/Views/SettingsView.swift; then
  echo "Settings must expose Codex hook installation" >&2
  exit 1
fi

if ! rg -Fq 'hooks.json' Shark/Utilities/CodexHookInstaller.swift; then
  echo "Codex hooks must be installed into hooks.json" >&2
  exit 1
fi

if ! rg -Fq '"SessionStart"' Shark/Utilities/CodexHookInstaller.swift || ! rg -Fq '"Stop"' Shark/Utilities/CodexHookInstaller.swift; then
  echo "Codex hooks must capture start and stop events" >&2
  exit 1
fi

echo "codex sessions UI verified"
