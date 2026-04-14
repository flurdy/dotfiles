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

host=$(hostname -s)

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
  for ((i=0; i<filled; i++)); do bar+="▰"; done
  local empty_bar=""
  for ((i=0; i<empty; i++)); do empty_bar+="▱"; done

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
segment_model="${C_MODEL}${BOLD}[${model_short}]${RST}"

# Hostname
segment_host="${C_HOST}${BOLD}${host}${RST}"

# K8s context
segment_k8s=""
if command -v kubectl &>/dev/null; then
  k8s_ctx=$(kubectl config current-context 2>/dev/null)
  if [ -n "$k8s_ctx" ]; then
    segment_k8s="${C_K8S}☸ ${k8s_ctx}${RST}"
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
segment_path="${C_PATH}$(abbrev_path "$cwd")${RST}"

# Git branch + status
segment_git=""
if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir &>/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" describe --tags --exact-match 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    dirty=""
    if ! git -C "$cwd" diff --quiet 2>/dev/null; then dirty="●"; fi
    untracked=""
    if [ -n "$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | head -1)" ]; then untracked="…"; fi
    staged=""
    if ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then staged="✚"; fi

    status_icons="${dirty}${untracked}${staged}"
    wt_icon=""
    # Detect git worktree: .git is a file (not dir) in worktrees, or compare common-dir vs git-dir
    if [ -f "$cwd/.git" ] || [ "$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)" != "$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)" ]; then
      wt_icon=" 🌳"
    fi
    if [ -n "$status_icons" ]; then
      segment_git="${C_GIT_DIRTY} ${branch} ${status_icons}${wt_icon}${RST}"
    else
      segment_git="${C_GIT} ${branch}${wt_icon}${RST}"
    fi
  fi
fi

# Effort level (read from settings.json)
segment_effort=""
effort_val=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)
if [ -n "$effort_val" ]; then
  segment_effort="${C_EFFORT}⚡${effort_val}${RST}"
fi

line1="${segment_model}"
[ -n "$segment_effort" ] && line1="${line1} ${segment_effort}"
line1="${line1}${SEP}${segment_host}"
[ -n "$segment_k8s" ] && line1="${line1}${SEP}${segment_k8s}"
line1="${line1}${SEP}${segment_path}"
[ -n "$segment_git" ] && line1="${line1}${SEP}${segment_git}"

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

line2="       ${segment_ctx}${SEP}${segment_5h}${SEP}${segment_7d}${SEP}${segment_cost}"
line2="${line2}${SEP}${segment_time}"

# ===== Output =====
printf "%b\n%b" "$line1" "$line2"
