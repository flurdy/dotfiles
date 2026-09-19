# Beads inventory and cached drift

`beads-all [--ready] [-s STATUSES] [--all] [ROOT]` lists work in discovered stores,
deduplicating canonical repository paths. ROOT defaults to `BEADS_ALL_ROOT`, then
`~/Code/flurdy`. Discovery remains bounded to `.beads` directories 2–4 levels down.
Disposable `.artifacts` stores are excluded, alongside `tbd`, `node_modules` and `.git`.

Each displayed store includes a Dolt header, for example:

```text
Dolt: diverged +2/-3 (local abc1234; cached origin/main@def5678); pending changes
```

- `+N/-M` counts commits unique to the local and cached remote histories, respectively.
  Labels are `even`, `ahead`, `behind` or `diverged`.
- These are **cached refs, not live remote status**. Even does not mean the remote is
  current. Commit dates are not fetch timestamps. This command never fetches, pulls,
  pushes, starts a server, changes configuration or records freshness state.
- Prefer the active branch's configured upstream. Without one, compare to the cached
  `origin/<active-branch>` only if `origin` is configured. No other remote is guessed.
- Pending versioned table changes (`dolt_status`) are reported separately from committed
  drift; ignored/internal table changes do not count. A moving
  snapshot, missing remote/ref, stopped server, unsupported store or failed reader
  is reported explicitly, never as a healthy zero count. Raw query errors are hidden.
- The task filters are unchanged, but every discovered store is visible by default;
  a store without matching work is labelled `(none)` beside its drift state. `--all`
  remains accepted as a compatibility no-op. Listing failures remain visible instead
  of looking empty.
- Drift-reader failures do not fail the whole listing or hide healthy stores. Each
  drift subprocess has a ten-second timeout; the existing task-listing commands
  retain their native CLI timeout behavior.

Dependencies: Bash (with `mapfile`), the existing GNU-style find/realpath/xargs tools,
Beads, and Python 3.10+ for `bin/beads-drift.py`. Missing Python leaves the task list
usable with an unavailable drift label. Embedded reads additionally require Dolt.
The read interfaces were checked with Beads 1.2.2 and Dolt 2.3.1; unsupported schemas
fail as unavailable. Server stores are queried through scoped read-only `bd sql`.
Embedded stores require a canonical `.beads/embeddeddolt` location with one database;
redirected/ambiguous storage is not guessed. `BEADS_DIR`/`BEADS_DB`/`BD_DB` overrides
are refused because they could make every scoped command read the same store.
All child commands receive `BEADS_DOLT_AUTO_START=false` (supported by Beads 1.2.2),
so a stopped server stays stopped even if it disappears between status and query.
No persistent configuration is changed.

Remote refresh and synchronization remain separately authorized operations. Do not
use `bd federation status` as a read-only substitute: it may fetch even with
`--readonly`.

## Offline checks

```sh
python3 -B -m unittest discover -s tests -p test_beads_all.py
bash -n bin/beads-all
shellcheck bin/beads-all
```

The fixtures use temporary stores and fake `bd`/`dolt` executables. They exercise the
renderer, routing and query protocol without contacting production stores or remotes.
