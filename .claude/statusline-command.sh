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
  local branch dirty untracked staged is_worktree
  if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir &>/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" describe --tags --exact-match 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

    dirty="0"
    if ! git -C "$cwd" diff --quiet 2>/dev/null; then dirty="1"; fi

    untracked="0"
    if [ -n "$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | head -1)" ]; then untracked="1"; fi

    staged="0"
    if ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then staged="1"; fi

    is_worktree="0"
    if [ -f "$cwd/.git" ] || [ "$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)" != "$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)" ]; then
      is_worktree="1"
    fi
  else
    branch="" dirty="0" untracked="0" staged="0" is_worktree="0"
  fi

  # Write cache
  echo "$branch|$dirty|$untracked|$staged|$is_worktree" > "$cache_file" 2>/dev/null
  cat "$cache_file"
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
segment_git=""
IFS='|' read -r branch dirty untracked staged is_worktree <<< "$(cache_git_status)"
if [ -n "$branch" ]; then
  # Convert numeric flags back to visual icons
  dirty_icon=""
  [ "$dirty" = "1" ] && dirty_icon="●"
  untracked_icon=""
  [ "$untracked" = "1" ] && untracked_icon="…"
  staged_icon=""
  [ "$staged" = "1" ] && staged_icon="✚"

  status_icons="${dirty_icon}${untracked_icon}${staged_icon}"
  wt_icon=""
  [ "$is_worktree" = "1" ] && wt_icon=" 🌳"

  if [ -n "$status_icons" ]; then
    segment_git="${C_GIT_DIRTY}$(printf '\xef\x90\x98') ${branch} ${status_icons}${wt_icon}${RST}"
  else
    segment_git="${C_GIT}$(printf '\xef\x90\x98') ${branch}${wt_icon}${RST}"
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
  local seg_m="${C_MODEL}${BOLD}${m1}${RST}"

  local seg_e=""
  if [ -n "$effort_val" ]; then
    local ev
    case "$effort_val" in
      low) ev="Lo" ;; medium) ev="Md" ;; high) ev="Hi" ;; xhigh) ev="Xh" ;; max) ev="Mx" ;; *) ev="${effort_val:0:2}" ;;
    esac
    seg_e=" ${C_EFFORT}⚡${ev}${RST}"
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

  # Build bordered cells: clock | model+effort | bars | time
  local cells=()
  cells+=("$segment_clock")
  cells+=("${seg_m}${seg_e}")
  cells+=("$(mini_bar "$pct_ctx" 20 50) $(mini_bar "$pct_5h") $(mini_bar "$pct_7d")")
  cells+=("$segment_time")

  local widths=()
  for c in "${cells[@]}"; do widths+=($(( $(visible_len "$c") + 2 ))); done  # +2 for padding

  # Compute divider positions and total width
  local total_inner=0
  for w in "${widths[@]}"; do total_inner=$(( total_inner + w + 1 )); done
  total_inner=$(( total_inner - 1 ))
  local total_width=$(( 1 + total_inner + 1 ))
  local pR=$(( total_width - 1 ))

  local divs=() pos=1
  for ((i=0; i<${#widths[@]}-1; i++)); do
    pos=$(( pos + widths[i] ))
    divs+=($pos)
    pos=$(( pos + 1 ))
  done

  # Build horizontal border line
  hborder() {
    local left="$1" mid="$2" right="$3"
    local line="$left"
    local col=1
    local d=0
    for ((col=1; col<pR; col++)); do
      if (( d < ${#divs[@]} && col == divs[d] )); then
        line+="$mid"; d=$((d+1))
      else
        line+="─"
      fi
    done
    line+="$right"
    printf '%b%s%b' "$C_BORDER" "$line" "$RST"
  }

  # Build trailing cells (k8s, path, git) with same divider style
  [ -n "$segment_k8s" ] && cells+=("$segment_k8s")
  cells+=("$segment_path")
  [ -n "$segment_git" ] && cells+=("$segment_git")

  # Recompute widths for the added cells
  widths=()
  for c in "${cells[@]}"; do widths+=($(( $(visible_len "$c") + 2 ))); done

  # Row: cell │ cell │ ... │ cell
  local row=""
  for ((i=0; i<${#cells[@]}; i++)); do
    local content=" ${cells[$i]} "
    local vlen=$(visible_len "$content")
    local pad=$(( widths[i] - vlen ))
    (( pad < 0 )) && pad=0
    printf -v padstr '%*s' "$pad" ""
    (( i > 0 )) && row+=$(printf '%b│%b' "$C_BORDER" "$RST")
    row+=$(printf '%b%s' "$RST" "$content${padstr}")
  done

  # Render single line with cell dividers
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

  # Row 1: environment
  local r1_segs=("$segment_host")
  [ -n "$segment_k8s" ] && r1_segs+=("$segment_k8s")
  r1_segs+=("$segment_path")
  [ -n "$segment_git" ] && r1_segs+=("$segment_git")

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
