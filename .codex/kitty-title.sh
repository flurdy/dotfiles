#!/usr/bin/env bash

PAYLOAD=$(cat)
EVENT=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hook_event_name',''))" 2>/dev/null)
CWD=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null)
TOOL=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
SESSION_ID=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null)
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

display_repo() {
  printf '%s' "${KITTY_TITLE_REPO_ALIAS:-$1}"
}

display_bead() {
  local bead="$1" marker=""
  if [[ "$bead" == ✓* ]]; then
    marker="✓"
    bead="${bead#✓}"
  fi
  bead="${bead#"$REPO"-}"
  printf '%s%s' "$marker" "$bead"
}

role_for_prompt() {
  case "$1" in
    /watch-release|/watch-release\ *|\$watch-release|\$watch-release\ *)
      printf '🚢-releases'
      ;;
    /watch-prs|/watch-prs\ *|\$watch-prs|\$watch-prs\ *)
      printf '👀-PRs'
      ;;
  esac
}

session_role() {
  [ -n "$SESSION_ID" ] || return

  local session_key role_file prompt role
  session_key=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9._-')
  [ -n "$session_key" ] || return
  role_file="/tmp/kitty-role-codex-$session_key"

  if [ "$EVENT" = "UserPromptSubmit" ]; then
    prompt=$(printf '%s' "$PAYLOAD" | jq -r '.prompt // empty' 2>/dev/null)
    role=$(role_for_prompt "$prompt")
    [ -n "$role" ] && printf '%s' "$role" > "$role_file"
  fi

  [ -r "$role_file" ] && sed -E 's/[[:space:]]+/-/g' "$role_file"
}

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

session_bead() {
  case "$BRANCH" in
    main|master|trunk|"") ;;
    *) return ;;
  esac

  local beads_root="$CWD"
  while [ "$beads_root" != "/" ] && [ ! -d "$beads_root/.beads" ]; do
    beads_root=$(dirname "$beads_root")
  done
  [ -d "$beads_root/.beads" ] || return

  local issues_file="$beads_root/.beads/issues.jsonl"
  [ -r "$issues_file" ] || return
  local interactions_file="$beads_root/.beads/interactions.jsonl"
  if [ -r "$interactions_file" ]; then
    local issues_mtime interactions_mtime
    issues_mtime=$(stat -c %Y "$issues_file" 2>/dev/null || echo 0)
    interactions_mtime=$(stat -c %Y "$interactions_file" 2>/dev/null || echo 0)
    [ $((interactions_mtime - issues_mtime)) -gt 10 ] && return
  fi

  local session_key state_file evidence candidates candidate count status
  session_key=${SESSION_ID:-$(printf '%s' "$CWD|$PPID" | cksum | cut -d' ' -f1)}
  session_key=$(printf '%s' "$session_key" | tr -cd 'A-Za-z0-9._-')
  state_file="/tmp/kitty-bead-session-$session_key"

  evidence=$(printf '%s' "$PAYLOAD" | jq -r '
    [
      .prompt?,
      .tool_input.command?,
      .tool_input.args?,
      .tool_input.issue_id?,
      .tool_input.id?
    ] | map(select(type == "string")) | join("\n")
  ' 2>/dev/null)

  candidates=$(printf '%s' "$evidence" \
    | grep -Eo '[A-Za-z][A-Za-z0-9_-]*-[A-Za-z0-9]+([.][0-9]+)?' \
    | awk '!seen[$0]++' || true)
  candidate=""
  count=0
  while IFS= read -r bead; do
    [ -z "$bead" ] && continue
    if jq -e --arg id "$bead" 'select(.id == $id)' "$issues_file" >/dev/null 2>&1; then
      candidate="$bead"
      count=$((count + 1))
    fi
  done <<< "$candidates"

  if [ "$count" -eq 1 ]; then
    printf '%s' "$candidate" > "$state_file"
  elif [ -s "$state_file" ]; then
    candidate=$(cat "$state_file")
  else
    candidates=$(jq -r 'select(.status == "in_progress") | .id' "$issues_file" 2>/dev/null)
    count=$(printf '%s\n' "$candidates" | sed '/^$/d' | wc -l)
    if [ "$count" -eq 1 ]; then
      candidate=$(printf '%s\n' "$candidates" | sed -n '1p')
      printf '%s' "$candidate" > "$state_file"
    elif [ "$count" -eq 0 ]; then
      candidate=$(jq -rs '
        map(select(.status == "closed"))
        | sort_by(.closed_at // .updated_at // "")
        | last.id // empty
      ' "$issues_file" 2>/dev/null)
      [ -n "$candidate" ] && printf '%s' "$candidate" > "$state_file"
    else
      candidate=""
    fi
  fi

  [ -z "$candidate" ] && return
  status=$(jq -r --arg id "$candidate" 'select(.id == $id) | .status' "$issues_file" 2>/dev/null)
  [ "$status" = "closed" ] && candidate="✓$candidate"
  printf '%s' "$candidate"
}

BRANCH_SHORT=$(short_branch "$BRANCH")
REPO_DISPLAY=$(display_repo "$REPO")
LABEL="$MARK-$REPO_DISPLAY"
if [ -n "$SSH_TTY" ]; then
  REMOTE_PREFIX="🌐"
  [ -n "$KITTY_TITLE_HOST_ALIAS" ] && REMOTE_PREFIX="$REMOTE_PREFIX$KITTY_TITLE_HOST_ALIAS/"
  LABEL="$REMOTE_PREFIX·$LABEL"
fi
if [ -n "$BRANCH_SHORT" ]; then
  LABEL="$LABEL/$BRANCH_SHORT"
else
  BEAD=$(session_bead)
  [ -n "$BEAD" ] && LABEL="$LABEL/$(display_bead "$BEAD")"
fi
ROLE=$(session_role)
[ -n "$ROLE" ] && LABEL="$LABEL·$ROLE"

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
    TITLE="$LABEL·💭"
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

set_kitty_tab_title() {
  if [ -n "$SSH_TTY" ]; then
    local command
    command=$(jq -cn --arg title "$TITLE" \
      '{cmd:"set-tab-title",version:[0,26,0],no_response:true,payload:{title:$title}}')
    printf '\eP@kitty-cmd%s\e\\' "$command" > "$SSH_TTY"
  elif command -v kitten >/dev/null 2>&1; then
    kitten @ set-tab-title "$TITLE" >/dev/null 2>&1 \
      || kitten @ --to unix:@kitty set-tab-title "$TITLE" >/dev/null 2>&1
  fi
}

set_kitty_tab_title 2>/dev/null || true

(
  exec 2>/dev/null
  TITLE_TTY=${SSH_TTY:-/dev/tty}
  printf "\e]30;%s\a" "$TITLE" > "$TITLE_TTY" || true
  printf "\e]2;%s\a" "$TITLE" > "$TITLE_TTY" || true
) || true
