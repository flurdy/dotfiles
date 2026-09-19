"""Offline regression tests; fake CLIs never contact real stores or remotes."""

import importlib.util
import json
import os
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "bin/beads-drift.py"
LOCAL = "a" * 32
REMOTE = "b" * 32
SNAPSHOT = {
    "branch": "main",
    "local_hash": LOCAL,
    "remote_hash": REMOTE,
    "remote_name": "origin",
    "target": "origin/main",
    "remote_count": 1,
    "dirty": False,
}
FAKE_CLI = """#!/usr/bin/env python3
import json, os, pathlib, sys
args=sys.argv[1:]
assert os.environ.get('BEADS_DOLT_AUTO_START') == 'false'
name=pathlib.Path(sys.argv[0]).name
with open(os.environ['CALL_LOG'],'a') as log:
    log.write(json.dumps([name,args])+'\\n')
if name == 'bd':
    repo=pathlib.Path(args[args.index('-C')+1]) if '-C' in args else pathlib.Path.cwd()
else:
    repo=pathlib.Path(args[args.index('--data-dir')+1]).parent.parent
case=json.loads((repo/'case.json').read_text())
if 'list' in args or 'ready' in args:
    if case.get('list_error'):
        print('private diagnostic must not leak',file=sys.stderr)
        sys.exit(1)
    print(case.get('listing','fixture task'))
elif 'status' in args:
    if case.get('embedded'):
        print(json.dumps({'mode':'embedded','data_dir':str(repo/'.beads/embeddeddolt')}))
    else:
        print(json.dumps({'running':not case.get('stopped',False)}))
elif 'sql' in args:
    if case.get('sql_error'):
        print('private diagnostic must not leak',file=sys.stderr)
        sys.exit(1)
    if case.get('malformed'):
        print('not json')
        sys.exit(0)
    query=args[args.index('-q')+1] if '-q' in args else args[-1]
    row=case['snapshot'].copy()
    if 'DOLT_LOG' in query:
        row.update(ahead=case.get('ahead',0),behind=case.get('behind',0))
        if case.get('moved'):
            row['local_hash']='c'*32
    print(json.dumps({'rows':[row]} if name=='dolt' else [row]))
else:
    sys.exit(99)
"""


class DriftTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "tools"
        self.bin.mkdir()
        for name in ("bd", "dolt"):
            p = self.bin / name
            p.write_text(FAKE_CLI)
            p.chmod(0o755)
        self.log = self.root / "calls.jsonl"
        self.env = os.environ.copy()
        for key in ("BEADS_DIR", "BEADS_DB", "BD_DB"):
            self.env.pop(key, None)
        self.env.update(
            PATH=str(self.bin) + os.pathsep + self.env["PATH"], CALL_LOG=str(self.log)
        )
        self.store = self.root / "store"
        self.store.mkdir()
        (self.store / ".beads").mkdir()
        self.case = {"snapshot": SNAPSHOT.copy()}

    def save(self):
        (self.store / "case.json").write_text(json.dumps(self.case))

    def helper(self):
        self.save()
        result = subprocess.run(
            ["python3", "-B", str(HELPER), str(self.store)],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("private diagnostic", result.stdout + result.stderr)
        return result.stdout

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_four_commit_states(self):
        for ahead, behind, label in (
            (0, 0, "even"),
            (3, 0, "ahead"),
            (0, 2, "behind"),
            (3, 2, "diverged"),
        ):
            with self.subTest(label=label):
                self.case.update(ahead=ahead, behind=behind)
                output = self.helper()
                self.assertIn(label, output)
                self.assertIn(f"+{ahead}/-{behind}", output)
                self.assertIn("cached origin/main@bbbbbbb", output)
                self.assertIn("local aaaaaaa", output)

    def test_stopped_server_is_not_queried(self):
        self.case["stopped"] = True
        self.assertIn("server not running", self.helper())
        self.assertFalse(any("sql" in args for _, args in self.calls()))

    def test_invalid_commit_counts_are_unavailable(self):
        for count in (-1, "3", True):
            self.case["ahead"] = count
            self.assertIn("invalid commit counts", self.helper())

    def test_pending_is_separate_from_commit_counts(self):
        self.case["snapshot"]["dirty"] = True
        self.assertIn("pending changes", self.helper())
        self.assertIn("even", self.helper())

    def test_no_remote_or_cached_ref(self):
        self.case["snapshot"].update(remote_count=0, remote_hash=None)
        self.assertIn("no remote", self.helper())
        self.case["snapshot"]["remote_count"] = 1
        self.assertIn("no cached ref", self.helper())
        self.assertFalse(any("DOLT_LOG" in " ".join(args) for _, args in self.calls()))

    def test_unavailable_results_do_not_leak_diagnostics(self):
        for flag in ("sql_error", "malformed", "moved"):
            with self.subTest(flag=flag):
                self.case = {"snapshot": SNAPSHOT.copy(), flag: True}
                self.assertIn("unavailable", self.helper())
        self.case = {"snapshot": dict(SNAPSHOT, local_hash="bad'); CALL anything()")}
        self.assertIn("unavailable", self.helper())

    def test_tracking_target_is_not_hardcoded_in_renderer(self):
        self.case["snapshot"].update(remote_name="work", target="work/topic")
        self.assertIn("cached work/topic@", self.helper())

    def test_embedded_uses_native_dolt_without_auto_gc(self):
        self.case["embedded"] = True
        (self.store / ".beads/embeddeddolt/fixture/.dolt").mkdir(parents=True)
        self.assertIn("cached", self.helper())
        native = [args for name, args in self.calls() if name == "dolt"]
        self.assertEqual(len(native), 2)
        self.assertTrue(
            all("--disable-auto-gc" in args and "--use-db" in args for args in native)
        )
        self.assertFalse(
            any(name == "bd" and "sql" in args for name, args in self.calls())
        )

    def test_ambiguous_or_linked_embedded_database_is_refused(self):
        self.case["embedded"] = True
        base = self.store / ".beads/embeddeddolt"
        (base / "one/.dolt").mkdir(parents=True)
        (base / "two/.dolt").mkdir(parents=True)
        self.assertIn("unavailable", self.helper())
        self.assertFalse(any(name == "dolt" for name, _ in self.calls()))

    def test_commands_are_scoped_read_only_and_hash_ranges(self):
        self.helper()
        for name, args in self.calls():
            self.assertFalse(
                {"fetch", "pull", "push", "federation", "commit", "start"} & set(args)
            )
            if name == "bd":
                self.assertIn("--readonly", args)
                self.assertIn("--sandbox", args)
                self.assertEqual(args[args.index("-C") + 1], str(self.store))
            if "sql" in args and "DOLT_LOG" in args[-1]:
                self.assertIn(f"'{REMOTE}..{LOCAL}'", args[-1])
                self.assertIn(f"'{LOCAL}..{REMOTE}'", args[-1])

    def test_timeout_is_bounded_and_redacted(self):
        spec = importlib.util.spec_from_file_location("beads_drift", HELPER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with (
            patch.object(
                module.subprocess,
                "run",
                side_effect=subprocess.TimeoutExpired("private command", 10),
            ) as run,
            self.assertRaisesRegex(module.Unavailable, "timed out"),
        ):
            module.run_json(["bd"])
        self.assertEqual(run.call_args.kwargs["timeout"], 10)

    def test_snapshot_query_selects_configured_or_conventional_target(self):
        spec = importlib.util.spec_from_file_location("beads_drift", HELPER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        db = sqlite3.connect(":memory:")
        self.addCleanup(db.close)
        db.row_factory = sqlite3.Row
        db.create_function("active_branch", 0, lambda: "topic")
        db.create_function("CONCAT", -1, lambda *v: None if None in v else "".join(v))
        db.executescript("""
          CREATE TABLE dolt_branches (name,hash,remote,branch,dirty);
          CREATE TABLE dolt_remote_branches (name,hash);
          CREATE TABLE dolt_remotes (name);
          CREATE TABLE dolt_status (table_name);
          INSERT INTO dolt_remotes VALUES ('origin'),('work');
        """)
        db.execute(
            "INSERT INTO dolt_branches VALUES (?,?,?,?,?)",
            ("topic", LOCAL, "work", "release", 0),
        )
        db.executemany(
            "INSERT INTO dolt_remote_branches VALUES (?,?)",
            [("remotes/work/release", REMOTE), ("remotes/origin/topic", LOCAL)],
        )
        db.execute("UPDATE dolt_branches SET dirty=1")
        row = dict(db.execute(module.SNAPSHOT).fetchone())
        self.assertEqual(
            row["dirty"], 0, "ignored branch dirt is not pending versioned work"
        )
        db.execute("INSERT INTO dolt_status VALUES ('issues')")
        self.assertEqual(db.execute(module.SNAPSHOT).fetchone()["dirty"], 1)
        self.assertEqual((row["target"], row["remote_hash"]), ("work/release", REMOTE))
        db.execute("UPDATE dolt_branches SET remote=''")
        row = dict(db.execute(module.SNAPSHOT).fetchone())
        self.assertEqual((row["target"], row["remote_hash"]), ("origin/topic", LOCAL))
        db.execute("DELETE FROM dolt_remotes WHERE name='origin'")
        self.assertEqual(db.execute(module.SNAPSHOT).fetchone()["remote_count"], 0)
        db.execute("DELETE FROM dolt_remote_branches")
        self.assertIsNone(db.execute(module.SNAPSHOT).fetchone()["remote_hash"])

    def test_override_and_escaping_storage_are_refused_before_queries(self):
        self.env["BD_DB"] = "/not-this-store"
        self.assertIn("override", self.helper())
        self.assertFalse(self.log.exists())
        self.env.pop("BD_DB")
        self.case["embedded"] = True
        outside = self.root / "outside"
        (outside / "fixture/.dolt").mkdir(parents=True)
        (self.store / ".beads/embeddeddolt").symlink_to(outside)
        self.assertIn("unexpected embedded location", self.helper())
        self.assertFalse(any(name == "dolt" for name, _ in self.calls()))

    def test_invalid_or_missing_snapshot_fields_fail_closed(self):
        for key, value in [
            ("dirty", None),
            ("remote_count", "1"),
            ("remote_hash", "not-a-hash"),
        ]:
            with self.subTest(key=key):
                self.case = {"snapshot": dict(SNAPSHOT, **{key: value})}
                self.assertIn("unavailable", self.helper())
        self.case = {"snapshot": SNAPSHOT.copy()}
        del self.case["snapshot"]["remote_hash"]
        self.assertIn("incomplete snapshot", self.helper())

    def test_listing_flags_and_alias_dedup(self):
        self.save()
        (self.root / "alias").symlink_to(self.store, target_is_directory=True)
        result = subprocess.run(
            [str(ROOT / "bin/beads-all"), "--ready", str(self.root)],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("fixture task"), 1)
        self.assertIn("cached", result.stdout)
        ready = [args for _, args in self.calls() if "ready" in args]
        self.assertEqual(len(ready), 1)
        self.assertIn("--readonly", ready[0])

    def test_empty_store_is_default_and_all_is_compatible(self):
        self.case.update(listing="", ahead=2)
        self.save()
        cmd = [str(ROOT / "bin/beads-all"), "-s", "open", str(self.root)]
        default = subprocess.run(
            cmd, env=self.env, capture_output=True, text=True, timeout=20, check=False
        )
        compatibility = subprocess.run(
            cmd[:1] + ["--all"] + cmd[1:],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
        self.assertEqual(default.returncode, 0, default.stderr)
        self.assertEqual(compatibility.returncode, 0, compatibility.stderr)
        self.assertEqual(default.stdout, compatibility.stdout)
        self.assertIn("ahead", default.stdout)
        self.assertIn("(none)", default.stdout)
        calls = [args for _, args in self.calls() if "list" in args]
        self.assertTrue(all(args[args.index("-s") + 1] == "open" for args in calls))

    def test_discovery_excludes_disposable_stores(self):
        self.save()
        (self.root / ".artifacts/old/.beads").mkdir(parents=True)
        result = subprocess.run(
            [str(ROOT / "bin/beads-all"), "--all", str(self.root)],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
        self.assertNotIn(".artifacts/old", result.stdout)
        self.assertIn("fixture task", result.stdout)

    def test_listing_error_is_not_an_empty_store(self):
        self.case["list_error"] = True
        self.save()
        result = subprocess.run(
            [str(ROOT / "bin/beads-all"), "--all", str(self.root)],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
        self.assertIn("listing unavailable", result.stdout)
        self.assertNotIn("(none)", result.stdout)
        self.assertNotIn("private diagnostic", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
