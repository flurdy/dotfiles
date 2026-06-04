#!/usr/bin/env bash
# Bobthefish-inspired status line for Claude Code
# Line 1: [Model] hostname │ k8s │ path │ git branch + status
# Line 2: 5h usage bar │ 7d usage bar │ $cost │ effort │ mode │ ⏱ duration

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -z "$cwd" ] && cwd="$PWD"

# --- Parse JSON fields ---
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
model_id=$(echo "$input" | jq -r '.model.id // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
rate_5h_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0')
rate_7d_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0')
git_worktree=$(echo "$input" | jq -r '.workspace.git_worktree // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

host=$(hostname -s)

# --- Caching helper for expensive git operations ---
cache_git_status() {
  local cache_file="/tmp/statusline-git-cache-$session_id"
  local cache_max_age=5  # seconds

  # Check if cache exists and is fresh
  if [ -f "$cache_file" ]; then
    local cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0) ))
    if [ "$cache_age" -lt "$cache_max_age" ]; then
      cat "$cache_file"
      return 0
    fi
  fi

  # Cache miss or stale: refresh git status
  local branch dirty untracked staged is_worktree repo
  if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir &>/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" describe --tags --exact-match 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

    dirty="0"
    if ! git -C "$cwd" diff --quiet 2>/dev/null; then dirty="1"; fi

    untracked="0"
    if [ -n "$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | head -1)" ]; then untracked="1"; fi

    staged="0"
    if ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then staged="1"; fi

    # Detect a linked worktree by comparing the per-worktree git dir against
    # the shared common dir. Both must be resolved to absolute form first:
    # from a subdir of a normal repo, --git-dir is absolute but
    # --git-common-dir is relative (../.git), which would otherwise false-flag.
    local gitdir commondir
    gitdir=$(git -C "$cwd" rev-parse --path-format=absolute --git-dir 2>/dev/null)
    commondir=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    is_worktree="0"
    [ -n "$gitdir" ] && [ "$gitdir" != "$commondir" ] && is_worktree="1"

    # In a worktree the path often hides the real repo (e.g.
    # ~/Code/blc/claude-blc-2/worktrees/foo). Derive it from the shared
    # git dir: basename of the dir that holds the common .git → repo name.
    repo=""
    if [ "$is_worktree" = "1" ]; then
      repo=$(basename "$(dirname "$commondir")" 2>/dev/null)
      [ "$repo" = "." ] || [ "$repo" = "/" ] && repo=""
    fi
  else
    branch="" dirty="0" untracked="0" staged="0" is_worktree="0" repo=""
  fi

  # Write cache
  echo "$branch|$dirty|$untracked|$staged|$is_worktree|$repo" > "$cache_file" 2>/dev/null
  cat "$cache_file"
}

# --- Non-blocking PR lookup (cached) ---
# Prints the last-known PR for $branch as "number|state|isDraft" (or nothing).
# Never blocks: it echoes whatever is cached this instant and, only when that
# cache is stale, kicks off a fully-detached background `gh` refresh for next
# time. Empty results are cached too, so branches without a PR aren't re-queried
# every TTL. Disable entirely with CLAUDE_STATUSLINE_PR=0.
cache_pr() {
  local branch="$1"
  [ -z "$branch" ] && return
  [ "${CLAUDE_STATUSLINE_PR:-1}" = "0" ] && return
  command -v gh >/dev/null 2>&1 || return

  local ttl="${CLAUDE_STATUSLINE_PR_TTL:-120}" lock_ttl=30 now age key cache lock
  key=$(printf '%s' "$cwd|$branch" | cksum | tr -cd '0-9' | cut -c1-12)
  cache="/tmp/statusline-pr-$key"
  lock="$cache.lock"
  now=$(date +%s)

  # Emit the last-known value immediately (possibly stale) — this is the only
  # output, so the caller never waits on the network.
  [ -f "$cache" ] && cat "$cache"

  age=$ttl
  [ -f "$cache" ] && age=$(( now - $(stat -c %Y "$cache" 2>/dev/null || echo 0) ))
  if [ "$age" -ge "$ttl" ]; then
    local lage=$lock_ttl
    [ -f "$lock" ] && lage=$(( now - $(stat -c %Y "$lock" 2>/dev/null || echo 0) ))
    if [ "$lage" -ge "$lock_ttl" ]; then
      : > "$lock"
      # Detached: own fds redirected away from the caller's command-substitution
      # pipe, so $(cache_pr ...) returns without waiting for gh. `mv` runs
      # unconditionally (gh exits non-zero when a branch has no PR) so the empty
      # "no PR" result is cached too and isn't re-queried until the TTL lapses.
      # `timeout` bounds a hung gh so background refreshes can't pile up.
      ( cd "$cwd" 2>/dev/null
        timeout 8 gh pr view "$branch" --json number,state,isDraft \
           --jq '"\(.number)|\(.state)|\(.isDraft)"' 2>/dev/null > "$cache.tmp"
        mv -f "$cache.tmp" "$cache" 2>/dev/null
      ) </dev/null >/dev/null 2>&1 &
      disown 2>/dev/null
    fi
  fi
}

# --- Colors ---
RST='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

C_HOST='\033[38;2;37;94;135m'
C_K8S='\033[38;2;95;135;175m'
C_PATH='\033[38;2;153;153;153m'
C_DIR='\033[1;37m'
C_GIT='\033[38;2;24;147;3m'
C_GIT_DIRTY='\033[38;2;204;153;0m'
C_SEP='\033[38;2;100;100;100m'
C_MODEL='\033[38;2;0;200;170m'
C_COST='\033[38;2;120;200;80m'
C_TIME='\033[38;2;180;180;180m'
C_EFFORT='\033[38;2;160;140;200m'
C_MODE='\033[38;2;200;160;60m'
C_BAR_FILL='\033[38;2;80;200;80m'
C_BAR_EMPTY='\033[38;2;60;60;60m'
C_BAR_WARN='\033[38;2;220;180;40m'
C_BAR_CRIT='\033[38;2;220;60;60m'
C_LABEL='\033[38;2;120;120;120m'
C_REPO='\033[1;38;2;120;200;120m'  # worktree's real repo name (pairs with 🌳)
C_PR_OPEN='\033[38;2;87;171;90m'     # open PR
C_PR_DRAFT='\033[38;2;140;140;140m'  # draft PR
C_PR_MERGED='\033[38;2;163;113;247m' # merged PR

SEP="${C_SEP} │ ${RST}"

# --- Helper: short model name ---
short_model() {
  case "$1" in
    *opus*4*6*|*opus-4-6*)   echo "Opus 4.6" ;;
    *opus*4*5*|*opus-4-5*)   echo "Opus 4.5" ;;
    *sonnet*4*6*|*sonnet-4-6*) echo "Sonnet 4.6" ;;
    *sonnet*4*5*|*sonnet-4-5*) echo "Sonnet 4.5" ;;
    *haiku*4*5*|*haiku-4-5*) echo "Haiku 4.5" ;;
    *opus*)   echo "Opus" ;;
    *sonnet*) echo "Sonnet" ;;
    *haiku*)  echo "Haiku" ;;
    *)        echo "$1" ;;
  esac
}

# --- Helper: banded fill count ---
# Splits the bar into 3 zones aligned with the green/warn/crit colors so
# that bar count tracks color tier (e.g. width=3 → 1 green, 2 yellow, 3 red).
# Within each zone fill scales linearly. Width % 3 remainder goes to the
# crit band first, then warn, so the danger zone is never the smallest.
banded_fill() {
  local pct=$1 width=$2 warn=$3 crit=$4
  local band=$(( width / 3 ))
  local rem=$(( width - band * 3 ))
  local g_size=$band w_size=$band c_size=$band
  (( rem >= 1 )) && c_size=$(( c_size + 1 ))
  (( rem >= 2 )) && w_size=$(( w_size + 1 ))
  local g_max=$g_size
  local w_max=$(( g_max + w_size ))

  local result=0
  if (( pct <= 0 )); then
    result=0
  elif (( pct >= crit )); then
    local span=$(( 100 - crit ))
    if (( span <= 0 || c_size <= 0 )); then
      result=$width
    else
      local extra=$(( ((pct - crit) * c_size + span - 1) / span ))
      (( extra < 1 )) && extra=1
      result=$(( w_max + extra ))
    fi
  elif (( pct >= warn )); then
    local span=$(( crit - warn ))
    if (( span <= 0 || w_size <= 0 )); then
      result=$w_max
    else
      local extra=$(( ((pct - warn) * w_size + span - 1) / span ))
      (( extra < 1 )) && extra=1
      result=$(( g_max + extra ))
    fi
  else
    if (( warn <= 0 || g_size <= 0 )); then
      result=0
    else
      local extra=$(( (pct * g_size + warn - 1) / warn ))
      (( extra < 1 )) && extra=1
      result=$extra
    fi
  fi

  (( result > width )) && result=$width
  (( result < 0 )) && result=0
  echo $result
}

# --- Helper: progress bar ---
# Usage: progress_bar <percentage> <width> [warn_pct] [crit_pct]
progress_bar() {
  local pct=${1%.*}  # truncate to int
  local width=${2:-10}
  local warn_pct=${3:-60}
  local crit_pct=${4:-80}
  local filled=$(banded_fill "$pct" "$width" "$warn_pct" "$crit_pct")
  local empty=$(( width - filled ))

  # Color based on severity
  local fill_color="$C_BAR_FILL"
  if [ "$pct" -ge "$crit_pct" ]; then
    fill_color="$C_BAR_CRIT"
  elif [ "$pct" -ge "$warn_pct" ]; then
    fill_color="$C_BAR_WARN"
  fi

  local bar=""
  for ((i=0; i<filled; i++)); do bar+="▮"; done
  local empty_bar=""
  for ((i=0; i<empty; i++)); do empty_bar+="▯"; done

  printf "%b%s%b%s%b" "$fill_color" "$bar" "$C_BAR_EMPTY" "$empty_bar" "$RST"
}

# --- Helper: format duration ---
fmt_duration() {
  local ms=$1
  local total_sec=$(( ms / 1000 ))
  local hrs=$(( total_sec / 3600 ))
  local mins=$(( (total_sec % 3600) / 60 ))
  local secs=$(( total_sec % 60 ))
  if [ $hrs -gt 0 ]; then
    printf "%dh %dm" $hrs $mins
  elif [ $mins -gt 0 ]; then
    printf "%dm %ds" $mins $secs
  else
    printf "%ds" $secs
  fi
}

# ===== LINE 1: Environment segments =====

# Model tag
model_short=$(short_model "$model_id")
segment_model="${C_MODEL}${BOLD}${model_short}${RST}"

# Hostname (using nerd font icon - screen/monitor F108)
segment_host="${C_HOST}${BOLD}$(printf '\xef\x84\x88') ${host}${RST}"

# K8s context
segment_k8s=""
if [ "${theme_display_k8s_context}" = "yes" ] || [ "${theme_display_k8s_context}" = "true" ]; then
  if command -v kubectl &>/dev/null; then
    k8s_ctx=$(kubectl config current-context 2>/dev/null)
    if [ -n "$k8s_ctx" ]; then
      segment_k8s="${C_K8S}☸ ${k8s_ctx}${RST}"
    fi
  fi
fi

# Abbreviated path (bobthefish style)
abbrev_path() {
  local p="$1"
  p="${p/#$HOME/\~}"
  IFS='/' read -ra parts <<< "$p"
  local len=${#parts[@]}
  local result=""
  for ((i=0; i<len; i++)); do
    if [ $i -eq 0 ]; then
      result="${parts[$i]}"
    elif [ $i -eq $((len-1)) ]; then
      result="${result}/${C_DIR}${parts[$i]}${RST}${C_PATH}"
    else
      result="${result}/${parts[$i]:0:3}"
    fi
  done
  echo "$result"
}
segment_path="${C_PATH}$(printf '\xef\x81\xbc') $(abbrev_path "$cwd")${RST}"

# Git branch + status (cached)
# segment_git  = branch + status icons (branch is truncatable in compact mode)
# segment_repo = worktree's real repo as its own cell (replaces the path)
# git_icon, branch, status_icons are left as globals so render_compact can
# rebuild a truncated branch cell on demand.
segment_git=""
segment_repo=""
status_icons=""
git_icon=$(printf '\xef\x90\x98')
IFS='|' read -r branch dirty untracked staged is_worktree repo <<< "$(cache_git_status)"
if [ -n "$branch" ]; then
  # Convert numeric flags back to visual icons
  dirty_icon=""
  [ "$dirty" = "1" ] && dirty_icon="●"
  untracked_icon=""
  [ "$untracked" = "1" ] && untracked_icon="…"
  staged_icon=""
  [ "$staged" = "1" ] && staged_icon="✚"
  status_icons="${dirty_icon}${untracked_icon}${staged_icon}"

  if [ -n "$status_icons" ]; then
    segment_git="${C_GIT_DIRTY}${git_icon} ${branch} ${status_icons}${RST}"
  else
    segment_git="${C_GIT}${git_icon} ${branch}${RST}"
  fi

  # Worktree: surface the real repo (the path's leaf is just the worktree dir,
  # redundant with the branch) as its own cell.
  if [ "$is_worktree" = "1" ]; then
    if [ -n "$repo" ]; then
      segment_repo="${C_REPO}🌳 ${repo}${RST}"
    else
      segment_repo="${C_REPO}🌳${RST}"
    fi
  fi
fi

# Pull request for the current branch (cached, non-blocking) → its own cell.
segment_pr=""
if [ -n "$branch" ]; then
  IFS='|' read -r pr_num pr_state pr_draft <<< "$(cache_pr "$branch")"
  if [ -n "$pr_num" ]; then
    pr_icon=$(printf '\xef\x90\x87')   # nf-oct-git_pull_request
    case "$pr_state" in
      OPEN)   [ "$pr_draft" = "true" ] \
                && segment_pr="${C_PR_DRAFT}${pr_icon} #${pr_num}${RST}" \
                || segment_pr="${C_PR_OPEN}${pr_icon} #${pr_num}${RST}" ;;
      MERGED) segment_pr="${C_PR_MERGED}${pr_icon} #${pr_num}${RST}" ;;
      *)      segment_pr="" ;;   # CLOSED → hide
    esac
  fi
fi

# Effort level (read from settings.json)
segment_effort=""
effort_val=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)
if [ -n "$effort_val" ]; then
  segment_effort="${C_EFFORT}⚡${effort_val}${RST}"
fi

# ===== LINE 2: Usage segments =====

# 5-hour rate limit bar
pct_5h=${rate_5h_pct%.*}
bar_5h=$(progress_bar "$pct_5h" 8)
segment_5h="${bar_5h} ${C_LABEL}5h${RST}"

# 7-day rate limit bar
pct_7d=${rate_7d_pct%.*}
bar_7d=$(progress_bar "$pct_7d" 6)
segment_7d="${bar_7d} ${C_LABEL}7d${RST}"

# Context window — tighter thresholds: bloat starts ~20%, painful ~50% on 1M models
pct_ctx=${ctx_pct%.*}
bar_ctx=$(progress_bar "$pct_ctx" 6 20 50)
segment_ctx="${bar_ctx} ${C_LABEL}ctx${RST}"

# Session cost
cost_fmt=$(printf "%.2f" "$cost_usd")
segment_cost="${C_COST}\$${cost_fmt}${RST}"

# Session duration
duration_fmt=$(fmt_duration "$duration_ms")
segment_time="${C_TIME}${duration_fmt}${RST}"

# Last updated timestamp
segment_clock="${C_LABEL}$(date '+%H:%M')${RST}"

# ===== SHARED HELPERS =====

C_BORDER='\033[38;2;70;70;70m'

visible_len() {
  printf '%b' "$1" | sed $'s/\x1b\\[[0-9;]*m//g' | wc -L
}

# ===== COMPACT (1 line) =====

render_compact() {
  # Shorter model name
  local m1
  case "$model_id" in
    *opus*)   m1="Opus" ;;
    *sonnet*) m1="Sonnet" ;;
    *haiku*)  m1="Haiku" ;;
    *)        m1="$model_id" ;;
  esac

  local seg_e=""
  if [ -n "$effort_val" ]; then
    local ev
    case "$effort_val" in
      low) ev="Lo" ;; medium) ev="Md" ;; high) ev="Hi" ;; xhigh) ev="Xh" ;; max) ev="Mx" ;; *) ev="${effort_val:0:2}" ;;
    esac
    seg_e="${C_EFFORT}⚡${ev}${RST}"
  fi

  # Mini bars (3 wide, no labels)
  mini_bar() {
    local pct=${1%.*} width=3
    local warn_pct=${2:-60} crit_pct=${3:-80}
    local filled=$(banded_fill "$pct" "$width" "$warn_pct" "$crit_pct")
    local empty=$(( width - filled ))
    local fill_color="$C_BAR_FILL"
    (( pct >= crit_pct )) && fill_color="$C_BAR_CRIT"
    (( pct >= warn_pct && pct < crit_pct )) && fill_color="$C_BAR_WARN"
    local bar="" ebar=""
    for ((i=0; i<filled; i++)); do bar+="▮"; done
    for ((i=0; i<empty; i++)); do ebar+="▯"; done
    printf "%b%s%b%s%b" "$fill_color" "$bar" "$C_BAR_EMPTY" "$ebar" "$RST"
  }
  local seg_bars
  seg_bars="$(mini_bar "$pct_ctx" 20 50) $(mini_bar "$pct_5h") $(mini_bar "$pct_7d")"

  # Memoised display width — visible_len forks (sed|wc); cells repeat across
  # truncate/drop passes, so cache by content and return via a global.
  declare -A _vl
  local _VLEN _LW
  vlen() {
    local k="$1"
    if [ -n "${_vl[$k]+_}" ]; then _VLEN=${_vl[$k]}; return; fi
    _VLEN=$(visible_len "$k"); _vl[$k]=$_VLEN
  }

  # Branch cell, rebuilt at a max length (truncates the branch name only,
  # keeping the icon and status markers).
  branch_cell() {
    local max=$1 b="$branch"
    [ -z "$b" ] && return
    if [ -n "$max" ] && [ "$max" -gt 1 ] && [ "${#b}" -gt "$max" ]; then b="${b:0:max-1}…"; fi
    if [ -n "$status_icons" ]; then
      printf '%b%s %s %s%b' "$C_GIT_DIRTY" "$git_icon" "$b" "$status_icons" "$RST"
    else
      printf '%b%s %s%b' "$C_GIT" "$git_icon" "$b" "$RST"
    fi
  }

  # Cell visibility (most-droppable first when narrow). The path is droppable
  # (shown when wide for on-disk context); the worktree repo is kept until the
  # very last resort.
  local show_k8s=1 show_path=1 show_repo=1 show_dur=1 show_effort=1 show_clock=1 show_pr=1
  [ -z "$segment_k8s" ] && show_k8s=0
  local bmax=""   # branch max length ("" = full)

  local cells=()
  assemble() {
    cells=()
    [ "$show_clock" = 1 ] && cells+=("$segment_clock")
    if [ "$show_effort" = 1 ] && [ -n "$seg_e" ]; then
      cells+=("${C_MODEL}${BOLD}${m1}${RST} ${seg_e}")
    else
      cells+=("${C_MODEL}${BOLD}${m1}${RST}")
    fi
    cells+=("$seg_bars")
    [ "$show_dur" = 1 ] && cells+=("$segment_time")
    [ "$show_k8s" = 1 ] && [ -n "$segment_k8s" ] && cells+=("$segment_k8s")
    [ "$show_path" = 1 ] && [ -n "$segment_path" ] && cells+=("$segment_path")
    [ "$show_repo" = 1 ] && [ -n "$segment_repo" ] && cells+=("$segment_repo")
    local bc; bc="$(branch_cell "$bmax")"
    [ -n "$bc" ] && cells+=("$bc")
    [ "$show_pr" = 1 ] && [ -n "$segment_pr" ] && cells+=("$segment_pr")
  }
  line_width() {
    local total=0 n=${#cells[@]} c
    for c in "${cells[@]}"; do vlen "$c"; total=$(( total + _VLEN + 2 )); done
    (( n > 1 )) && total=$(( total + n - 1 ))
    _LW=$total
  }

  local W=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
  case "$W" in ''|*[!0-9]*) W=80 ;; esac
  # Leave a small safety gap (clip-last-column terminals, $COLUMNS resize lag).
  W=$(( W - ${CLAUDE_STATUSLINE_FIT_MARGIN:-2} ))
  (( W < 20 )) && W=20

  assemble; line_width

  # Fit to width by shedding the least-important things first, so the branch
  # (worktree name), repo and PR stay intact as long as possible. The path is
  # bonus context shown only when there's room:
  #   k8s → path → duration → effort → clock → PR → truncate branch → drop repo.
  local f
  for f in show_k8s show_path show_dur show_effort show_clock show_pr; do
    [ "$_LW" -le "$W" ] && break
    printf -v "$f" '%s' 0; assemble; line_width
  done

  # Still over: truncate the branch gradually toward a hard minimum.
  while [ "$_LW" -gt "$W" ] && [ "${#branch}" -gt 6 ] && { [ -z "$bmax" ] || [ "$bmax" -gt 6 ]; }; do
    if [ -z "$bmax" ]; then bmax=$(( ${#branch} - 2 )); else bmax=$(( bmax - 2 )); fi
    (( bmax < 6 )) && bmax=6
    assemble; line_width
  done

  # Absolute last resort: drop the repo cell.
  if [ "$_LW" -gt "$W" ] && [ "$show_repo" = 1 ] && [ -n "$segment_repo" ]; then
    show_repo=0; assemble; line_width
  fi

  # Render row: cell │ cell │ ...
  local widths=() c
  for c in "${cells[@]}"; do vlen "$c"; widths+=($(( _VLEN + 2 ))); done
  local row="" i
  for ((i=0; i<${#cells[@]}; i++)); do
    local content=" ${cells[$i]} "
    vlen "$content"
    local pad=$(( widths[i] - _VLEN )); (( pad < 0 )) && pad=0
    printf -v padstr '%*s' "$pad" ""
    (( i > 0 )) && row+=$(printf '%b│%b' "$C_BORDER" "$RST")
    row+=$(printf '%b%s' "$RST" "$content${padstr}")
  done
  printf '%b' "$row"
}

# ===== TABLE (5 lines) =====

render_table() {
  pad_right() {
    local content="$1" target="$2"
    local vlen pad
    vlen=$(visible_len "$content")
    pad=$(( target - vlen ))
    (( pad < 0 )) && pad=0
    printf '%b' "$content"
    printf '%*s' "$pad" ""
  }

  build_border_line() {
    local total=$1 fill=$2
    shift 2
    declare -A jmap
    while (( $# >= 2 )); do jmap[$1]="$2"; shift 2; done
    local line=""
    for ((i=0; i<total; i++)); do
      [[ "${jmap[$i]+_}" ]] && line+="${jmap[$i]}" || line+="$fill"
    done
    printf '%b%s%b' "$C_BORDER" "$line" "$RST"
  }

  local PAD=1

  # Width budget (shared by the path-guard and the fall-back-to-compact check).
  # The margin guards against terminals that clip the final column and against
  # $COLUMNS lagging a resize.
  local tcols=${COLUMNS:-$(tput cols 2>/dev/null || echo 200)}
  case "$tcols" in ''|*[!0-9]*) tcols=200 ;; esac
  local budget=$(( tcols - ${CLAUDE_STATUSLINE_FIT_MARGIN:-2} ))

  # Row 1: environment. Non-worktree shows the path. A worktree keeps the repo
  # cell and adds the on-disk path too — but only when row 1 still fits within
  # the budget (the table itself doesn't reflow), else just repo + branch.
  local r1_segs=("$segment_host")
  [ -n "$segment_k8s" ] && r1_segs+=("$segment_k8s")
  if [ -n "$segment_repo" ]; then
    local probe=("$segment_host")
    [ -n "$segment_k8s" ] && probe+=("$segment_k8s")
    probe+=("$segment_path" "$segment_repo")
    [ -n "$segment_git" ] && probe+=("$segment_git")
    [ -n "$segment_pr" ] && probe+=("$segment_pr")
    local psum=2 s
    for s in "${probe[@]}"; do psum=$(( psum + $(visible_len "$s") + 2*PAD + 1 )); done
    [ "$psum" -le "$budget" ] && r1_segs+=("$segment_path")
    r1_segs+=("$segment_repo")
  else
    r1_segs+=("$segment_path")
  fi
  [ -n "$segment_git" ] && r1_segs+=("$segment_git")
  [ -n "$segment_pr" ] && r1_segs+=("$segment_pr")

  # Row 2: Claude session info
  local r2_segs=("$segment_model")
  [ -n "$segment_effort" ] && r2_segs+=("$segment_effort")
  r2_segs+=("$segment_ctx" "$segment_5h" "$segment_7d" "$segment_cost" "$segment_time" "$segment_clock")

  # Compute widths
  local r1_widths=() r2_widths=()
  for s in "${r1_segs[@]}"; do r1_widths+=($(( $(visible_len "$s") + 2*PAD ))); done
  for s in "${r2_segs[@]}"; do r2_widths+=($(( $(visible_len "$s") + 2*PAD ))); done

  # Total inner width
  local r1_inner=0 r2_inner=0
  for w in "${r1_widths[@]}"; do r1_inner=$(( r1_inner + w + 1 )); done
  r1_inner=$(( r1_inner - 1 ))
  for w in "${r2_widths[@]}"; do r2_inner=$(( r2_inner + w + 1 )); done
  r2_inner=$(( r2_inner - 1 ))

  # Expand shorter row
  local total_inner
  if (( r1_inner > r2_inner )); then
    r2_widths[-1]=$(( r2_widths[-1] + r1_inner - r2_inner )); total_inner=$r1_inner
  elif (( r2_inner > r1_inner )); then
    r1_widths[-1]=$(( r1_widths[-1] + r2_inner - r1_inner )); total_inner=$r2_inner
  else
    total_inner=$r1_inner
  fi

  local total_width=$(( 1 + total_inner + 1 ))
  local pR=$(( total_width - 1 ))

  # The table has an irreducible width (row 2's usage cells). If it won't fit
  # within the budget even after dropping the path, fall back to the fully
  # responsive compact line so we never overflow.
  if [ "$total_width" -gt "$budget" ]; then render_compact; return; fi

  # Divider positions
  local r1_divs=() r2_divs=() pos
  pos=1; for ((i=0; i<${#r1_widths[@]}-1; i++)); do pos=$(( pos + r1_widths[i] )); r1_divs+=($pos); pos=$(( pos + 1 )); done
  pos=1; for ((i=0; i<${#r2_widths[@]}-1; i++)); do pos=$(( pos + r2_widths[i] )); r2_divs+=($pos); pos=$(( pos + 1 )); done

  # Top border
  local top_args=("$total_width" "─" 0 "┌")
  for p in "${r1_divs[@]}"; do top_args+=($p "┬"); done
  top_args+=($pR "┐")

  # Middle border
  declare -A mid_jmap
  mid_jmap[0]="├"; mid_jmap[$pR]="┤"
  for p in "${r1_divs[@]}"; do mid_jmap[$p]="┴"; done
  for p in "${r2_divs[@]}"; do
    [[ "${mid_jmap[$p]}" == "┴" ]] && mid_jmap[$p]="┼" || mid_jmap[$p]="┬"
  done
  local mid_args=("$total_width" "─")
  for p in "${!mid_jmap[@]}"; do mid_args+=($p "${mid_jmap[$p]}"); done

  # Bottom border
  local bot_args=("$total_width" "─" 0 "└")
  for p in "${r2_divs[@]}"; do bot_args+=($p "┴"); done
  bot_args+=($pR "┘")

  # Render row helper
  render_row() {
    local -n _segs=$1 _widths=$2
    printf '%b│%b' "$C_BORDER" "$RST"
    for ((i=0; i<${#_segs[@]}; i++)); do
      pad_right " ${_segs[$i]} " ${_widths[$i]}
      printf '%b│%b' "$C_BORDER" "$RST"
    done
  }

  printf '%b\n' "$(build_border_line "${top_args[@]}")"
  printf '%b\n' "$(render_row r1_segs r1_widths)"
  printf '%b\n' "$(build_border_line "${mid_args[@]}")"
  printf '%b\n' "$(render_row r2_segs r2_widths)"
  printf '%b'   "$(build_border_line "${bot_args[@]}")"
}

# ===== Output: choose mode =====
# Mode selection, in priority order:
#   CLAUDE_STATUSLINE=table   → always the 5-line bordered table
#   CLAUDE_STATUSLINE=compact → always the 1-line view
#   CLAUDE_STATUSLINE=auto    → table when the terminal is tall enough (default)
#
# In auto mode the height comes from $LINES, which Claude Code sets before
# running this command (requires Claude Code >= 2.1.153). Falls back to
# `tput lines`, then to 24 rows when neither is available. The table needs
# 5 rows; CLAUDE_STATUSLINE_MIN_ROWS (default 50) sets the switch-over height.

term_rows="${LINES:-}"
[ -z "$term_rows" ] && term_rows="$(tput lines 2>/dev/null)"
case "$term_rows" in ''|*[!0-9]*) term_rows=24 ;; esac
min_rows="${CLAUDE_STATUSLINE_MIN_ROWS:-50}"

case "${CLAUDE_STATUSLINE:-auto}" in
  table)   render_table ;;
  compact) render_compact ;;
  *)       # auto: table only when the window has room for it
    if [ "$term_rows" -ge "$min_rows" ]; then
      render_table
    else
      render_compact
    fi
    ;;
esac
