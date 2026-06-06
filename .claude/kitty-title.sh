#!/usr/bin/env bash

EVENT="$1"
PAYLOAD=$(cat)
LOG_FILE=${CLAUDE_KITTY_TITLE_LOG:-/tmp/claude-kitty-title.log}
{
  printf '%s event=%s ' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$EVENT"
  printf '%s' "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print('cwd=' + d.get('cwd','') + ' tool=' + d.get('tool_name',''))" 2>/dev/null || true
} >> "$LOG_FILE" 2>/dev/null || true

CWD=$(echo "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

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
  MARK=""
else
  REPO=$(basename "$CWD")
  MARK="󰉋"
fi
[ -z "$REPO" ] && REPO="claude"

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
  Stop)
    TITLE="$LABEL·✅"
    ;;
  PermissionRequest)
    TOOL=$(echo "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
    case "$TOOL" in
      AskUserQuestion) TITLE="$LABEL·❔" ;;
      *) TITLE="$LABEL·❓" ;;
    esac
    ;;
  Notification)
    # Passive Claude notifications are usually recaps/timing noise; keep the previous useful tab state.
    exit 0
    ;;
  PreCompact)
    TITLE="$LABEL·🧹"
    ;;
  *)
    TITLE="$LABEL"
    ;;
esac

# Hooks run with captured stdout, so keep title writes quiet.
if command -v kitten >/dev/null 2>&1; then
  kitten @ set-tab-title "$TITLE" >/dev/null 2>&1 \
    || kitten @ --to unix:@kitty set-tab-title "$TITLE" >/dev/null 2>&1 \
    || true
fi

# Fallback for kitty without remote control enabled.
(
  exec 2>/dev/null
  printf "\e]30;%s\a" "$TITLE" > /dev/tty || true
  printf "\e]2;%s\a" "$TITLE" > /dev/tty || true
) || true
