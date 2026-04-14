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

# --- Helper: progress bar ---
# Usage: progress_bar <percentage> <width>
progress_bar() {
  local pct=${1%.*}  # truncate to int
  local width=${2:-10}
  local filled=$(( pct * width / 100 ))
  # Show at least 1 filled block if percentage > 0
  [ "$pct" -gt 0 ] && [ "$filled" -eq 0 ] && filled=1
  [ $filled -gt $width ] && filled=$width
  local empty=$(( width - filled ))

  # Color based on severity
  local fill_color="$C_BAR_FILL"
  if [ "$pct" -ge 80 ]; then
    fill_color="$C_BAR_CRIT"
  elif [ "$pct" -ge 60 ]; then
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

# Context window
pct_ctx=${ctx_pct%.*}
bar_ctx=$(progress_bar "$pct_ctx" 6)
segment_ctx="${bar_ctx} ${C_LABEL}ctx${RST}"

# Session cost
cost_fmt=$(printf "%.2f" "$cost_usd")
segment_cost="${C_COST}\$${cost_fmt}${RST}"

# Session duration
duration_fmt=$(fmt_duration "$duration_ms")
segment_time="${C_TIME}⏱ ${duration_fmt}${RST}"

# ===== TABLE LAYOUT WITH BORDERS =====

C_BORDER='\033[38;2;70;70;70m'
ANSI_STRIP=$'s/\x1b\[[0-9;]*[mK]//g'

# Visible length: strip ANSI codes, count characters
visible_len() {
  printf '%b' "$1" | sed "$ANSI_STRIP" | tr -d '\n' | wc -m | tr -d ' '
}

# Pad a colored string to target visible width
pad_right() {
  local content="$1" target="$2"
  local vlen pad
  vlen=$(visible_len "$content")
  pad=$(( target - vlen ))
  (( pad < 0 )) && pad=0
  printf '%b' "$content"
  printf '%*s' "$pad" ""
}

# Repeat a character n times
rpt() {
  local char="$1" n="$2" s=""
  for ((i=0; i<n; i++)); do s+="$char"; done
  printf '%s' "$s"
}

# Build a border line: total_width fill [pos char ...]
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

PAD=1  # spaces on each side of cell content

# Column content
seg_c1_r1="${segment_model}"
[ -n "$segment_effort" ] && seg_c1_r1="${segment_model} ${segment_effort}"
seg_c2_r1="$segment_host"
seg_c3_r1="$segment_k8s"
seg_c4_r1="$segment_path"
seg_c5_r1="$segment_git"
seg_c1_r2="$segment_ctx"
seg_c2_r2="$segment_5h"
seg_c3_r2="$segment_7d"
seg_c4_r2="$segment_cost"
seg_c5_r2="$segment_time"

# Shared column widths (max of both rows + padding)
l11=$(visible_len "$seg_c1_r1"); l12=$(visible_len "$seg_c1_r2")
l21=$(visible_len "$seg_c2_r1"); l22=$(visible_len "$seg_c2_r2")
l31=$(visible_len "$seg_c3_r1"); l32=$(visible_len "$seg_c3_r2")
c1=$(( (l11>l12?l11:l12) + 2*PAD ))
c2=$(( (l21>l22?l21:l22) + 2*PAD ))
c3=$(( (l31>l32?l31:l32) + 2*PAD ))

# Independent last column widths
r1c4=$(( $(visible_len "$seg_c4_r1") + 2*PAD ))
r1c5=$(( $(visible_len "$seg_c5_r1") + 2*PAD ))
r2c4=$(( $(visible_len "$seg_c4_r2") + 2*PAD ))
r2c5=$(( $(visible_len "$seg_c5_r2") + 2*PAD ))

has_git=0
[ -n "$seg_c5_r1" ] && has_git=1

# Total last-section width must match between rows
(( has_git )) && total_last_r1=$(( r1c4 + 1 + r1c5 )) || total_last_r1=$r1c4
total_last_r2=$(( r2c4 + 1 + r2c5 ))

if (( total_last_r1 >= total_last_r2 )); then
  total_last=$total_last_r1
  r2c5=$(( total_last - r2c4 - 1 ))
else
  total_last=$total_last_r2
  if (( has_git )); then
    r1c5=$(( total_last - r1c4 - 1 ))
  else
    r1c4=$total_last
  fi
fi

# Junction positions (0-indexed character offsets in the border lines)
total_width=$(( 1 + c1 + 1 + c2 + 1 + c3 + 1 + total_last + 1 ))
ps1=$(( 1 + c1 ))
ps2=$(( ps1 + 1 + c2 ))
ps3=$(( ps2 + 1 + c3 ))
pr1=$(( ps3 + 1 + r1c4 ))   # row1 path/git divider
pr2=$(( ps3 + 1 + r2c4 ))   # row2 cost/time divider
pR=$(( total_width - 1 ))   # right outer border

# Top border: row1 column structure
top_args=("$total_width" "─" 0 "┌" $ps1 "┬" $ps2 "┬" $ps3 "┬")
(( has_git )) && top_args+=($pr1 "┬")
top_args+=($pR "┐")
top_line=$(build_border_line "${top_args[@]}")

# Middle border: shared ┼, then ┴/┬ where rows diverge
mid_args=("$total_width" "─" 0 "├" $ps1 "┼" $ps2 "┼" $ps3 "┼")
if (( has_git )); then
  if   (( pr1 == pr2 )); then mid_args+=($pr1 "┼")
  elif (( pr1 <  pr2 )); then mid_args+=($pr1 "┴" $pr2 "┬")
  else                        mid_args+=($pr2 "┬" $pr1 "┴")
  fi
else
  mid_args+=($pr2 "┬")
fi
mid_args+=($pR "┤")
mid_line=$(build_border_line "${mid_args[@]}")

# Bottom border: row2 column structure
bot_line=$(build_border_line "$total_width" "─" 0 "└" $ps1 "┴" $ps2 "┴" $ps3 "┴" $pr2 "┴" $pR "┘")

# Row 1
row1() {
  printf '%b│%b' "$C_BORDER" "$RST"
  pad_right " $seg_c1_r1 " $c1
  printf '%b│%b' "$C_BORDER" "$RST"
  pad_right " $seg_c2_r1 " $c2
  printf '%b│%b' "$C_BORDER" "$RST"
  pad_right " $seg_c3_r1 " $c3
  printf '%b│%b' "$C_BORDER" "$RST"
  pad_right " $seg_c4_r1 " $r1c4
  if (( has_git )); then
    printf '%b│%b' "$C_BORDER" "$RST"
    pad_right " $seg_c5_r1 " $r1c5
  fi
  printf '%b│%b' "$C_BORDER" "$RST"
}

# Row 2
row2() {
  printf '%b│%b' "$C_BORDER" "$RST"
  pad_right " $seg_c1_r2 " $c1
  printf '%b│%b' "$C_BORDER" "$RST"
  pad_right " $seg_c2_r2 " $c2
  printf '%b│%b' "$C_BORDER" "$RST"
  pad_right " $seg_c3_r2 " $c3
  printf '%b│%b' "$C_BORDER" "$RST"
  pad_right " $seg_c4_r2 " $r2c4
  printf '%b│%b' "$C_BORDER" "$RST"
  pad_right " $seg_c5_r2 " $r2c5
  printf '%b│%b' "$C_BORDER" "$RST"
}

# ===== Output =====
printf '%b\n' "$top_line"
printf '%b\n' "$(row1)"
printf '%b\n' "$mid_line"
printf '%b\n' "$(row2)"
printf '%b'   "$bot_line"
