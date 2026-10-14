# Shared agent conventions

A repository's own `AGENTS.md`/`CLAUDE.md` adds to this and wins on conflict; read it first.

## Responses

- Be terse; no repetition of what I already know.
- No paragraphs longer than ~3 sentences; default to bullets.
- Use a table for ≥3 items × ≥3 attributes (options, files, statuses, findings), or when I need
  to scan one column. Smaller grids stay bullets.
- Admit uncertainty; never present a guess as fact.
- Any explanation or findings response longer than ~8 lines opens with a one- or two-sentence
  **TL;DR** in plain language — what it means, not what you did. Detail follows for those who
  read on.
- Say what you did, what you verified, and what is left. Never claim success you did not check.
- End substantive responses with one `**Next:**` line naming the single most useful action, or
  `**Next:** Nothing required.`
- Ask only when different answers lead to materially different work; otherwise decide and say so.

## Task continuation

- Continue through already-authorized steps; a finished section, skill handoff, or passing check is
  not a stopping point. Do not end a run just to propose the obvious next step.
- Pause only for a material decision, required approval, an unexpected blocker, or completion.
  Continuation never widens scope, permissions, or consent, and never starts another bead unasked.

## Delegation

- Standing authorization: proactively use bounded subagents when parallel research, specialist
  work, or independent review materially improves confidence, context use, or elapsed time.
  Do not wait for an explicit delegation request on each task.
- Work directly for trivial, tightly coupled, or inherently serial tasks; do not manufacture fanout.
- Preserve billing consent, model-routing policy, task scope, and write permissions. This
  authorization does not approve metered routes or grant access to additional repositories.
- Keep one writer per worktree; isolate concurrent writers. The parent owns scope, integration,
  evidence assessment, and final acceptance.
- Briefly announce delegated work and summarize its results; distinguish independent review
  from self-validation. Stop and report launch or runtime failures rather than silently switching tools.

## Git

- Commit freely and locally: small commits, conventional messages, terse subjects.
- Never `git add -A` / `git add .`; stage named paths.
- A commit never implies permission to push. Stop with local commits and say they are unpushed.
- Ask immediately before every remote or destructive action (`push`, force-push, tag push, history
  rewrite, branch deletion), one visible command each, never in an `&&` chain. Earlier approval
  does not carry forward.
- **Workspace Beads sync:** where provided, preview the unique store set with `make beads-sync-check`,
  then ask immediately before one visible `make beads-sync` invocation. That approval covers its
  sequential per-store pull and non-force push only, never automatic sync during reads or triage.
  Raw commands outside this target, force/overwrite, conflict resolution, migration/bootstrap,
  remote changes, backup publication, Git push and production actions remain separately confirmed.
  Stricter repository policy still wins.

## Durable tracking

- Repositories with `.beads/` use Beads (`bd`): load `~/.agents/skills/beads/SKILL.md`. Its Git
  safety rules and the ones above stay authoritative over anything `bd prime` prints.
- Beads are private to me: never reference bead IDs in commits, PRs, Jira, Trello, or Slack unless
  the repository's `AGENTS.md` says otherwise.

## Shell

- Non-interactive forms only: `cp -f`, `mv -f`, `rm -f`, `ssh -o BatchMode=yes`, `apt-get -y`,
  `HOMEBREW_NO_AUTO_UPDATE=1 brew …`.
- Never print or persist secret values; report names, lengths, prefixes, or hashes. Credentials
  come from the keyring via `secret-api-key`, not env vars or `.envrc`.
- Never switch my active Kubernetes context; pass `--context` explicitly and treat production as
  read-only unless told otherwise.

## Code and documentation

- Read a skill's `SKILL.md` before invoking it; do not improvise arguments.
- KISS, DRY, YAGNI. Remove dead and commented-out code; comment sparingly, the code documents itself.
- Never leave `main` broken, failing lint, or with formatting warnings — even pre-existing ones.
- `README.md` stays small and links into `docs/`. Update or delete stale docs; never add beside them.
- Generated or disposable output goes under an ignored `.artifacts/`; commit raw run output only
  with an explicit retention decision.
- Do not modify sibling or linked repositories unless the task explicitly owns those changes.

## Writing for others (PRs, Jira, Slack)

- Terse and to the point; no names or @-mentions; no test narratives, nits, or future-task lists.
- Always show me the draft before posting anything.
- **PR descriptions:** what changed, in general terms. The why lives in Jira/Trello; the details
  live in the diff.
- **Jira comments:** statements, not questions — it is not a conversation. Friendly if it fits.
- **Slack:** friendly and a bit funny; vague beats over-specific, which reads as non-human.
