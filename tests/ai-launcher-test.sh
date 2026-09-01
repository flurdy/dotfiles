#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

workspace="$tmp/workspace"
member="$tmp/member"
home="$tmp/home"
mkdir -p "$workspace" "$member" "$home/.claude/bin" "$home/.pi/bin"

failures=0
status=0
output=""

run() {
  set +e
  output=$("$@" 2>&1)
  status=$?
  set -e
}

run_in_directory() {
  local directory=$1
  shift
  (cd "$directory"; "$@")
}

fail() {
  printf 'not ok - %s\n' "$1"
  failures=$((failures + 1))
}

pass() {
  printf 'ok - %s\n' "$1"
}

assert_status() {
  local name=$1 expected=$2
  if [ "$status" -eq "$expected" ]; then
    pass "$name"
  else
    fail "$name (expected status $expected, got $status; output: $output)"
  fi
}

assert_contains() {
  local name=$1 expected=$2
  if [[ "$output" == *"$expected"* ]]; then
    pass "$name"
  else
    fail "$name (missing: $expected; output: $output)"
  fi
}

assert_not_contains() {
  local name=$1 unexpected=$2
  if [[ "$output" != *"$unexpected"* ]]; then
    pass "$name"
  else
    fail "$name (unexpected: $unexpected; output: $output)"
  fi
}

cat >"$tmp/list-with-handoffs" <<'FIXTURE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '---CURRENT-REPO---' "dir:$FIXTURE_WORKSPACE"
printf '%s\n' '---HANDOFFS-DIR---' "$FIXTURE_HOME/.claude/handoffs"
printf '%s\n' '---HANDOFFS---'
fields=(root.md 2026-08-29 root-handoff "$FIXTURE_WORKSPACE" '?' "dir:$FIXTURE_WORKSPACE" Y '' '' unknown unknown '' '' '' 12:00 '')
(IFS='|'; printf '%s\n' "${fields[*]}")
printf '%s\n' '---WORKSPACE-MEMBER-HANDOFFS---'
fields=(member.md 2026-08-29 member-handoff "$FIXTURE_MEMBER" main member-remote Y '' '' unknown unknown '' '' '' 13:00 '' "$FIXTURE_MEMBER")
(IFS='|'; printf '%s\n' "${fields[*]}")
FIXTURE
chmod +x "$tmp/list-with-handoffs"

cat >"$tmp/list-empty" <<'FIXTURE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '---CURRENT-REPO---' "dir:$FIXTURE_WORKSPACE"
printf '%s\n' '---HANDOFFS---' '---WORKSPACE-MEMBER-HANDOFFS---'
FIXTURE
chmod +x "$tmp/list-empty"

run run_in_directory "$workspace" env \
  AI_HANDOFF_LIST="$tmp/list-with-handoffs" \
  FIXTURE_WORKSPACE="$workspace" \
  FIXTURE_MEMBER="$member" \
  FIXTURE_HOME="$home" \
  "$repo/.claude/bin/cl-gather" --list
assert_status 'gather succeeds outside Git when handoffs exist' 0
assert_contains 'gather includes current-directory handoff' 'handoff: root-handoff'
assert_contains 'gather omits an unknown handoff branch' $'\thandoff\t'"$workspace"$'\t\thandoff\t'
assert_contains 'gather includes workspace-member handoff' 'handoff: member-handoff'
assert_contains 'gather includes a local fresh-session choice' '+ new session here'
assert_not_contains 'gather excludes worktree choices outside Git' '+ new worktree'
assert_contains 'member descriptor carries owning repository root' "$member"

cat >"$tmp/fzf" <<'FIXTURE'
#!/usr/bin/env bash
[ -z "${FZF_LOG:-}" ] || printf '%s\n' "$*" >"$FZF_LOG"
printf 'enter\n'
sed -n '2p'
FIXTURE
chmod +x "$tmp/fzf"
run run_in_directory "$workspace" env \
  PATH="$tmp:/usr/bin:/bin" \
  AI_HANDOFF_LIST="$tmp/list-with-handoffs" \
  FIXTURE_WORKSPACE="$workspace" \
  FIXTURE_MEMBER="$member" \
  FIXTURE_HOME="$home" \
  "$repo/.claude/bin/cl-gather"
assert_status 'gather selects a handoff outside Git' 0
assert_contains 'selected descriptor preserves an empty branch field' $'handoff\t'"$workspace"$'\t\thandoff\t'
assert_contains 'selected descriptor preserves the handoff note' "$home/.claude/handoffs/root.md"

run run_in_directory "$workspace" env \
  AI_HANDOFF_LIST="$tmp/list-empty" \
  FIXTURE_WORKSPACE="$workspace" \
  "$repo/.claude/bin/cl-gather" --list
assert_status 'gather declines a plain directory without handoffs' 1

git_repo="$tmp/git-repo"
git init -q "$git_repo"
run run_in_directory "$git_repo" env \
  PATH=/usr/bin:/bin \
  AI_HANDOFF_LIST="$tmp/list-empty" \
  FIXTURE_WORKSPACE="$git_repo" \
  "$repo/.claude/bin/cl-gather" --list
assert_status 'gather still builds contexts inside Git' 0
assert_contains 'gather keeps the main checkout choice' $'main\tmain\t'
assert_contains 'gather keeps the new-worktree choice' '+ new worktree'

mode_file="$tmp/pi-launch-mode"
printf 'implement\n' >"$mode_file"
run "$repo/.pi/bin/pl-gather" --toggle-mode-file="$mode_file"
assert_status 'pl mode toggle selects plan' 0
assert_contains 'pl mode toggle renders plan in the header' 'mode=plan'
printf 'plan\n' >"$mode_file"
run "$repo/.pi/bin/pl-gather" --toggle-mode-file="$mode_file"
assert_status 'pl mode toggle returns to implement' 0
assert_contains 'pl mode toggle renders implement in the header' 'mode=implement'

run run_in_directory "$git_repo" env \
  PATH="$tmp:/usr/bin:/bin" \
  FZF_LOG="$tmp/pl-fzf.args" \
  AI_HANDOFF_LIST="$tmp/list-empty" \
  FIXTURE_WORKSPACE="$git_repo" \
  "$repo/.pi/bin/pl-gather"
assert_status 'pl gather opens the mode-aware picker' 0
run grep -F -- '--header=mode=implement' "$tmp/pl-fzf.args"
assert_status 'pl picker shows the initial mode' 0
run grep -F -- 'ctrl-p:transform-header' "$tmp/pl-fzf.args"
assert_status 'pl picker binds the mode toggle' 0

cat >"$home/.claude/bin/cl-gather" <<FIXTURE
#!/usr/bin/env bash
printf 'handoff\\t%s\\t\\thandoff\\t%s\\t%s\\n' '$member' '$home/.claude/handoffs/member.md' '$member'
FIXTURE
chmod +x "$home/.claude/bin/cl-gather"

cat >"$home/.pi/bin/pl-gather" <<FIXTURE
#!/usr/bin/env bash
printf 'handoff\\t%s\\t\\thandoff\\t%s\\t%s\\timplement\\n' '$member' '$home/.claude/handoffs/member.md' '$member'
FIXTURE
chmod +x "$home/.pi/bin/pl-gather"

run env HOME="$home" fish -c "cd '$workspace'; source '$repo/.config/fish/functions/cl.fish'; cl --dry-run"
assert_status 'cl accepts a handoff from a non-Git workspace root' 0
assert_contains 'cl switches to the handoff owner' "cd $member"
assert_contains 'cl seeds the selected handoff' "claude  <load $home/.claude/handoffs/member.md>"
assert_not_contains 'cl does not bypass the picker outside Git' 'not a git repo'

run env HOME="$home" fish -c "cd '$workspace'; source '$repo/.config/fish/functions/pl.fish'; pl --dry-run"
assert_status 'pl accepts a handoff from a non-Git workspace root' 0
assert_contains 'pl switches to the handoff owner' "cd $member"
assert_contains 'pl seeds the selected handoff' "pi --implement <load $home/.claude/handoffs/member.md>"
assert_not_contains 'pl does not bypass the picker outside Git' 'not a git repo'

mkdir -p "$home/.dotfiles/.pi/bin"
cp -f "$home/.pi/bin/pl-gather" "$home/.dotfiles/.pi/bin/pl-gather"
rm -f "$home/.pi/bin/pl-gather"
run env HOME="$home" fish -c "cd '$workspace'; source '$repo/.config/fish/functions/pl.fish'; pl --dry-run"
assert_status 'pl can use the helper tracked by dotfiles' 0
assert_contains 'pl finds the tracked helper without an installed link' "cd $member"

cat >"$home/.claude/bin/cl-gather" <<'FIXTURE'
#!/usr/bin/env bash
exit 1
FIXTURE
chmod +x "$home/.claude/bin/cl-gather"
cat >"$home/.pi/bin/pl-gather" <<'FIXTURE'
#!/usr/bin/env bash
exit 1
FIXTURE
chmod +x "$home/.pi/bin/pl-gather"

plain="$tmp/plain"
mkdir -p "$plain"
run env HOME="$home" fish -c "cd '$plain'; source '$repo/.config/fish/functions/cl.fish'; cl --dry-run"
assert_status 'cl preserves direct launch in a plain directory' 0
assert_contains 'cl direct fallback stays in the plain directory' "claude    # from $plain"
run env HOME="$home" fish -c "cd '$plain'; source '$repo/.config/fish/functions/pl.fish'; pl --dry-run"
assert_status 'pl preserves direct launch in a plain directory' 0
assert_contains 'pl direct fallback stays in the plain directory' "# from $plain"

if [ "$failures" -gt 0 ]; then
  printf '%s test assertion(s) failed\n' "$failures" >&2
  exit 1
fi
