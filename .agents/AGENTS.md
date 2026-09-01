# Shared agent conventions

A repository's own `AGENTS.md`/`CLAUDE.md` adds to this and wins on conflict; read it first.

## Responses

- Be terse: tables and bullets over prose; no repetition of what I already know.
- Any explanation or findings response longer than ~8 lines opens with a one- or two-sentence
  **TL;DR** in plain language — what it means, not what you did. Detail follows for those who
  read on.
- Say what you did, what you verified, and what is left. Never claim success you did not check.
- End substantive responses with one `**Next:**` line naming the single most useful action, or
  `**Next:** Nothing required.`
- Ask only when different answers lead to materially different work; otherwise decide and say so.

## Git

- Commit freely and locally: small commits, conventional messages, terse subjects.
- Never `git add -A` / `git add .`; stage named paths.
- A commit never implies permission to push. Stop with local commits and say they are unpushed.
- Ask immediately before every remote or destructive action (`push`, force-push, tag push, history
  rewrite, branch deletion), one visible command each, never in an `&&` chain. Earlier approval
  does not carry forward.

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
