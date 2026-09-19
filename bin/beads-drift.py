"""Report commit drift against cached Dolt refs. Never refresh refs or change a store."""

import argparse
import json
import os
import re
import subprocess
from pathlib import Path

HASH = re.compile(r"[0-9a-v]{32}\Z")
SNAPSHOT = """SELECT b.name AS branch, b.hash AS local_hash,
EXISTS(SELECT 1 FROM dolt_status) AS dirty,
COALESCE(NULLIF(b.remote,''),'origin') AS remote_name,
CONCAT(COALESCE(NULLIF(b.remote,''),'origin'),'/',
       CASE WHEN COALESCE(b.remote,'')='' THEN b.name ELSE b.branch END) AS target,
r.hash AS remote_hash,
(SELECT COUNT(*) FROM dolt_remotes m
 WHERE m.name=COALESCE(NULLIF(b.remote,''),'origin')) AS remote_count
FROM dolt_branches b LEFT JOIN dolt_remote_branches r
ON r.name=CONCAT('remotes/',COALESCE(NULLIF(b.remote,''),'origin'),'/',
                CASE WHEN COALESCE(b.remote,'')='' THEN b.name ELSE b.branch END)
WHERE b.name=active_branch()"""


class Unavailable(Exception):
    pass


def run_json(command):
    try:
        env = dict(os.environ, BEADS_DOLT_AUTO_START="false")
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=10, env=env, check=False
        )
    except subprocess.TimeoutExpired:
        raise Unavailable("read timed out") from None
    except OSError:
        raise Unavailable("reader unavailable") from None
    if result.returncode:
        raise Unavailable("read failed")
    try:
        return json.loads(result.stdout)
    except (ValueError, UnicodeError):
        raise Unavailable("invalid JSON") from None


def query(command, sql):
    result = run_json(command + [sql])
    rows = result.get("rows") if isinstance(result, dict) else result
    if not isinstance(rows, list) or len(rows) != 1 or not isinstance(rows[0], dict):
        raise Unavailable("missing or ambiguous branch evidence")
    return rows[0]


def reader(repo):
    if any(os.environ.get(key) for key in ("BEADS_DIR", "BEADS_DB", "BD_DB")):
        raise Unavailable("store override set")
    beads = repo / ".beads"
    if beads.is_symlink() or (beads / "redirect").exists():
        raise Unavailable("redirected store")
    bd = ["bd", "-C", str(repo), "--readonly", "--sandbox", "--json"]
    status = run_json(bd + ["dolt", "status"])
    if not isinstance(status, dict):
        raise Unavailable("invalid engine status")
    if status.get("mode") == "embedded":
        expected = beads / "embeddeddolt"
        data_dir = status.get("data_dir")
        if (
            not isinstance(data_dir, str)
            or expected.is_symlink()
            or Path(data_dir).resolve() != expected.resolve()
        ):
            raise Unavailable("unexpected embedded location")
        databases = [p for p in expected.iterdir() if (p / ".dolt").is_dir()]
        if (
            len(databases) != 1
            or databases[0].is_symlink()
            or (databases[0] / ".dolt").is_symlink()
        ):
            raise Unavailable("ambiguous embedded database")
        return [
            "dolt",
            "--data-dir",
            str(expected),
            "--use-db",
            databases[0].name,
            "sql",
            "--disable-auto-gc",
            "-r",
            "json",
            "-q",
        ]
    if status.get("running") is not True:
        raise Unavailable("server not running or unsupported engine")
    return bd + ["sql"]


def validate(row):
    required = {
        "branch",
        "local_hash",
        "remote_hash",
        "remote_name",
        "target",
        "remote_count",
        "dirty",
    }
    if not required.issubset(row):
        raise Unavailable("incomplete snapshot")
    for key in ("branch", "target", "remote_name"):
        if not isinstance(row.get(key), str) or not row[key] or len(row[key]) > 512:
            raise Unavailable("invalid tracking evidence")
    for key in ("local_hash", "remote_hash"):
        value = row.get(key)
        if key == "remote_hash" and value is None:
            continue
        if not isinstance(value, str) or not HASH.fullmatch(value):
            raise Unavailable("invalid revision evidence")
    if type(row.get("remote_count")) is not int or row["remote_count"] not in (0, 1):
        raise Unavailable("invalid remote evidence")
    if type(row.get("dirty")) not in (int, bool) or row["dirty"] not in (0, 1):
        raise Unavailable("invalid pending-state evidence")


def describe(repo):
    try:
        command = reader(repo.resolve())
        initial = query(command, SNAPSHOT)
        validate(initial)
        target = json.dumps(initial["target"], ensure_ascii=True)[1:-1]
        pending = "; pending changes" if initial["dirty"] else ""
        if not initial["remote_count"]:
            return f"Dolt: no remote for {target}{pending} (cached only)"
        if initial["remote_hash"] is None:
            return f"Dolt: no cached ref for {target}{pending}"
        local, remote = initial["local_hash"], initial["remote_hash"]
        counts = (
            f"(SELECT COUNT(*) FROM DOLT_LOG('{remote}..{local}')) AS ahead, "
            f"(SELECT COUNT(*) FROM DOLT_LOG('{local}..{remote}')) AS behind, "
        )
        final = query(command, SNAPSHOT.replace("SELECT ", "SELECT " + counts, 1))
        validate(final)
        if any(initial[key] != final[key] for key in initial):
            raise Unavailable("state changed during read")
        ahead, behind = final.get("ahead"), final.get("behind")
        if any(type(n) is not int or n < 0 for n in (ahead, behind)):
            raise Unavailable("invalid commit counts")
        state = (
            "diverged"
            if ahead and behind
            else "ahead"
            if ahead
            else "behind"
            if behind
            else "even"
        )
        return f"Dolt: {state} +{ahead}/-{behind} (local {local[:7]}; cached {target}@{remote[:7]}){pending}"
    except Unavailable as error:
        return f"Dolt: unavailable ({error})"
    except (OSError, ValueError):
        return "Dolt: unavailable (local metadata unreadable)"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repository", type=Path)
    args = parser.parse_args()
    print(describe(args.repository))


if __name__ == "__main__":
    main()
