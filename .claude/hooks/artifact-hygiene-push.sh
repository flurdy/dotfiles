#!/usr/bin/env bash
# PreToolUse(Bash) gate: run artifact-hygiene before any `git push`; deny on findings or partial coverage.
set -euo pipefail

input="$(cat)"
command="$(printf '%s' "$input" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))')"
printf '%s' "$command" | grep -qE '(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?([[:space:]]+-[^[:space:]]+)*[[:space:]]+push([[:space:]]|$)' || exit 0

cwd="$(printf '%s' "$input" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("cwd",""))')"
repo="$(printf '%s' "$command" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p' | head -1)"
repo="${repo:-$cwd}"
repo="${repo/#\~/$HOME}"

audit="$HOME/.agents/skills/artifact-hygiene/scripts/artifact_hygiene.py"
[[ -x "$audit" ]] || { echo "artifact-hygiene: helper missing at $audit; push denied." >&2; exit 2; }

report="$(cd "$repo" && "$audit" 2>/dev/null)" && status=0 || status=$?

summary="$(printf '%s' "$report" | python3 -c '
import json, sys
from collections import Counter
try:
    r = json.load(sys.stdin)
except ValueError:
    print("unreadable report"); sys.exit(0)
partial = [c["source"] + ":" + ",".join(c.get("errors") or ["partial"]) for c in r.get("coverage", []) if c.get("status") != "complete"]
counts = Counter((f["severity"] if "severity" in f else "?", f["category"]) for f in r.get("findings", []))
if partial: print("partial coverage: " + "; ".join(partial))
for (sev, cat), n in sorted(counts.items()): print(f"{n} {sev} {cat}")
print("verdict: " + str(r.get("verdict")))
')"

# Pass on a complete audit whose only findings are informational (for example the
# audit's own history); anything high/medium/low or partial coverage still denies.
if [[ "$status" -eq 0 ]] && ! printf '%s' "$summary" | grep -qE '^[0-9]+ (high|medium|low|\?) '; then
  exit 0
fi

{
  echo "artifact-hygiene denied 'git push' for $repo (exit $status):"
  printf '%s\n' "$summary"
  echo "Run /artifact-hygiene for the full redacted report; fix findings, or install gitleaks if coverage is partial."
} >&2
exit 2
