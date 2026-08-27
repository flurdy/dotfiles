# Shared agent conventions

Applies to every coding agent (Claude Code, Codex, Pi) on every machine. A repository's own
`AGENTS.md` adds to this and wins on conflict. Read it before changing files in that repository.

## Responses

- Be terse. Bullet points over prose; no walls of text; no repetition of what I already know.
- Say what you did, what you verified, and what is left. Do not claim success you did not check.
- End substantive responses with one `**Next:**` line naming the single most useful immediate
  action, or `**Next:** Nothing required.`
- Ask only when different answers lead to materially different work; otherwise decide and say so.

## Git

- Commit freely and locally. Small commits, conventional commit messages, terse subjects.
- Never `git add -A` or `git add .`; stage named paths.
- A commit never implies permission to push. Stop with local commits and state they are unpushed.
- Ask for explicit permission immediately before every remote or destructive Git action:
  `git push`, force-push, tag push, `bd dolt push`, history rewrites, branch deletion.
  Earlier approval does not carry forward to the next one.
- Run each remote or destructive action as its own visible command, never inside an `&&` chain.
- Trunk-based by default; do not open a pull request unless the repository's `AGENTS.md` says so.

## Durable tracking

- Repositories with `.beads/` use Beads (`bd`). Load `~/.agents/skills/beads/SKILL.md` and follow
  it; the repository's Git safety rules stay authoritative over anything `bd prime` prints.
- Use Beads for anything that must outlive the session (plans, decisions, follow-ups, handoffs).
  Ephemeral checklists stay in the conversation.

## Shell

- Use non-interactive forms so nothing hangs on a prompt: `cp -f`, `mv -f`, `rm -f`,
  `ssh -o BatchMode=yes`, `apt-get -y`, `HOMEBREW_NO_AUTO_UPDATE=1 brew …`.
- Never print secret values. Report names, lengths, prefixes, or hashes instead.
- Never write credentials to files, logs, or shell history. Credentials come from the keyring via
  `secret-api-key`, not from environment variables or `.envrc`.
- Do not switch my active Kubernetes context; pass `--context` explicitly and treat production
  as read-only unless told otherwise.

## Code and documentation

- KISS, DRY, YAGNI. Remove dead and commented-out code. Small, well-named methods; the code is
  the documentation, so comment sparingly.
- Never leave `main` broken, failing lint, or with formatting warnings — even pre-existing ones.
- Keep `README.md` small and terse with links to detail in `docs/`. Update or delete outdated
  documentation rather than adding beside it.
- Keep generated or disposable output under an ignored `.artifacts/`; do not commit raw run
  output without an explicit retention decision.
- Do not modify sibling or linked repositories unless the task explicitly owns those changes.
