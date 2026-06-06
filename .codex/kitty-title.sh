#!/usr/bin/env bash

PAYLOAD=$(cat)
EVENT=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hook_event_name',''))" 2>/dev/null)
CWD=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null)
TOOL=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

LOG_FILE=${CODEX_KITTY_TITLE_LOG:-/tmp/codex-kitty-title.log}
{
  printf '%s event=%s cwd=%s tool=%s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$EVENT" "$CWD" "$TOOL"
} >> "$LOG_FILE" 2>/dev/null || true

GIT_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
GIT_COMMON_DIR=$(git -C "$CWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || true)

if [ -n "$GIT_ROOT" ]; then
  if [ -n "$GIT_COMMON_DIR" ]; then
    REPO_DIR=$(dirname "$GIT_COMMON_DIR")
    REPO=$(basename "$REPO_DIR")
  else
    REPO=$(basename "$GIT_ROOT")
  fi
  MARK="◈"
else
  REPO=$(basename "$CWD")
  MARK="◈󰉋"
fi
[ -z "$REPO" ] && REPO="codex"

short_branch() {
  local branch="$1"
  branch="${branch#worktree-}"
  branch="${branch#feature/}"
  branch="${branch#fix/}"
  branch="${branch#bugfix/}"
  branch="${branch#chore/}"

  case "$branch" in
    main|master|trunk|"") printf '' ;;
    pr-[0-9]*|PR-[0-9]*) printf '%s' "$(printf '%s' "$branch" | sed -E 's/^([Pp][Rr]-[0-9]+).*/\1/')" ;;
    [A-Za-z][A-Za-z]-[0-9]*|[A-Za-z][A-Za-z][A-Za-z]-[0-9]*) printf '%s' "$(printf '%s' "$branch" | sed -E 's/^([A-Za-z]+-[0-9]+).*/\1/')" ;;
    *-*) printf '%s' "${branch%%-*}" ;;
    *) printf '%s' "$branch" ;;
  esac
}

BRANCH_SHORT=$(short_branch "$BRANCH")
LABEL="$MARK-$REPO"
[ -n "$BRANCH_SHORT" ] && LABEL="$LABEL/$BRANCH_SHORT"

short_tool() {
  case "$1" in
    apply_patch) printf 'Patch' ;;
    Bash) printf 'Bash' ;;
    mcp__*) printf '%s' "$1" | sed -E 's/^mcp__([^_]+)__?(.+)$/\1:\2/' ;;
    "") printf 'Tool' ;;
    *) printf '%s' "$1" ;;
  esac
}

TOOL_SHORT=$(short_tool "$TOOL")

case "$EVENT" in
  SessionStart)
    TITLE="$LABEL·🌱"
    ;;
  UserPromptSubmit)
    TITLE="$LABEL·💭"
    ;;
  PreToolUse)
    TITLE="$LABEL·⚙️"
    ;;
  PostToolUse)
    TITLE="$LABEL·↩️"
    ;;
  PermissionRequest)
    TITLE="$LABEL·❓"
    ;;
  Stop)
    TITLE="$LABEL·✅"
    ;;
  PreCompact|PostCompact)
    TITLE="$LABEL·🧹"
    ;;
  SubagentStart)
    TITLE="$LABEL·👥"
    ;;
  SubagentStop)
    TITLE="$LABEL·✅"
    ;;
  *)
    TITLE="$LABEL"
    ;;
esac

if command -v kitten >/dev/null 2>&1; then
  kitten @ set-tab-title "$TITLE" >/dev/null 2>&1 \
    || kitten @ --to unix:@kitty set-tab-title "$TITLE" >/dev/null 2>&1 \
    || true
fi

(
  exec 2>/dev/null
  printf "\e]30;%s\a" "$TITLE" > /dev/tty || true
  printf "\e]2;%s\a" "$TITLE" > /dev/tty || true
) || true
