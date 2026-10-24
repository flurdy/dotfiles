"""Offline CLI contracts: no real Secret Service or credential values are used."""

import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMAND = ROOT / "bin/secret-api-key"
SERVICE = "test-service"
PROJECT = "test-project"
COLLECTION = "/org/freedesktop/secrets/collection/test"
TARGET = COLLECTION + "/target"
SENTINEL = "synthetic-test-token"

FAKE_CLI = r'''
import json
from pathlib import Path
import os
import sys

args = sys.argv[1:]
name = Path(sys.argv[0]).name
state_path = Path(os.environ["FAKE_STATE"])
state = json.loads(state_path.read_text())
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps([name, args]) + "\n")

def fail():
    print("Unsupported fake CLI operation", file=sys.stderr)
    sys.exit(97)

def reply(signature, data):
    print(json.dumps({"type": signature, "data": data}))

if name == "secret-tool":
    if args and args[0] == "lookup":
        print("synthetic-test-token", end="")
    elif args and args[0] == "store":
        sys.stdin.read()
    else:
        fail()
    sys.exit(0)

if name != "busctl":
    fail()
if "--" in args:
    args = args[args.index("--") + 1:]
else:
    args = [arg for arg in args if arg not in (
        "--user", "--json=short", "--timeout=5", "--allow-interactive-authorization=no",
    )]
if len(args) < 5 or args[1] != "org.freedesktop.secrets":
    fail()
operation, _, path, interface, member, *tail = args
service_interface = "org.freedesktop.Secret.Service"
item_interface = "org.freedesktop.Secret.Item"
collection = "/org/freedesktop/secrets/collection/test"
items = state["items"]
fault = state.get("fault")
if member == state.get("fail_member") or (
    member == "SearchItems" and state.get("searches") == 2 and fault == "verification_error"
):
    print("synthetic-test-token", file=sys.stderr)
    sys.exit(1)
if member == state.get("malformed_member"):
    print('{"type":"aoao","data":null}')
    sys.exit(0)
if operation == "call" and interface == service_interface:
    if path != "/org/freedesktop/secrets":
        fail()
    if member == "ReadAlias" and tail == ["s", "login"]:
        reply("o", [collection])
    elif member == "SearchItems" and len(tail) >= 2 and tail[0] == "a{ss}":
        count = int(tail[1])
        values = tail[2:]
        if len(values) != count * 2:
            fail()
        query = dict(zip(values[::2], values[1::2]))
        state["searches"] = state.get("searches", 0) + 1
        if state["searches"] == 2 and fault == "replace_target":
            original = next(iter(items))
            items[collection + "/replacement"] = items.pop(original)
        state_path.write_text(json.dumps(state))
        unlocked, locked = [], []
        for item_path, item in items.items():
            if all(item["attributes"].get(k) == v for k, v in query.items()):
                (locked if item["locked"] else unlocked).append(item_path)
        reply("aoao", [unlocked, locked])
    else:
        fail()
elif operation == "get-property":
    if path == collection and interface == "org.freedesktop.Secret.Collection" and member == "Locked":
        reply("b", False)
    elif path in items and interface == item_interface:
        item = items[path]
        if member == "Attributes":
            attributes = item["attributes"].copy()
            if fault == "changed_attributes":
                attributes["project"] = "different-project"
            reply("a{ss}", attributes)
        elif member == "Locked":
            reply("b", item["locked"] or fault == "newly_locked")
        else:
            fail()
    else:
        fail()
elif operation == "call" and interface == item_interface and member == "Delete" and not tail:
    if path not in items or items[path]["locked"]:
        fail()
    if fault == "prompt":
        reply("o", ["/org/freedesktop/secrets/prompt/test"])
    else:
        if fault != "delete_noop":
            del items[path]
        state_path.write_text(json.dumps(state))
        reply("o", ["/"])
else:
    fail()
'''


def item(service=SERVICE, project=PROJECT, credential="api-key", locked=False):
    return {
        "attributes": {"service": service, "project": project, "credential": credential},
        "locked": locked,
    }


class SecretApiKeyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="secret-api-key-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.tools = self.root / "bin"
        self.tools.mkdir()
        for tool in ("bash", "cat", "jq", "sort"):
            resolved = shutil.which(tool)
            if not resolved:
                self.fail(f"Test prerequisite unavailable: {tool}")
            (self.tools / tool).symlink_to(resolved)
        for tool in ("busctl", "secret-tool"):
            executable = self.tools / tool
            executable.write_text(f"#!{sys.executable}\n" + FAKE_CLI)
            executable.chmod(0o700)
        self.state = self.root / "state.json"
        self.log = self.root / "calls.jsonl"
        self.items = {TARGET: item()}
        self.behavior = {}
        self.env = {
            "PATH": str(self.tools),
            "HOME": str(self.root),
            "LC_ALL": "C",
            "DBUS_SESSION_BUS_ADDRESS": f"unix:path={self.root}/absent-bus",
            "XDG_RUNTIME_DIR": str(self.root),
            "FAKE_STATE": str(self.state),
            "CALL_LOG": str(self.log),
        }

    def invoke(self, *args, stdin=""):
        self.state.write_text(json.dumps({"items": self.items, **self.behavior}))
        return subprocess.run(
            [str(self.tools / "bash"), str(COMMAND), *args],
            cwd=self.root,
            env=self.env,
            input=stdin,
            text=True,
            capture_output=True,
            check=False,
            timeout=5,
        )

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def remaining(self):
        return json.loads(self.state.read_text())["items"]

    def removal(self, confirmed=False):
        args = ("remove", SERVICE, PROJECT) + (("--confirm",) if confirmed else ())
        result = self.invoke(*args)
        self.assertNotIn(SENTINEL, result.stdout + result.stderr)
        self.assertNotEqual(result.returncode, 97, "implementation called an unsupported fake operation")
        for tool, arguments in self.calls():
            self.assertEqual(tool, "busctl", "removal must not use secret-tool")
            self.assertFalse({"GetSecret", "GetSecrets", "OpenSession"}.intersection(arguments))
        return result

    def assert_no_delete(self):
        self.assertFalse(any("Delete" in args for _, args in self.calls()))
        self.assertEqual(self.remaining(), self.items)

    def assert_search_identity(self):
        searches = [args for _, args in self.calls() if "SearchItems" in args]
        self.assertTrue(searches, "expected an attribute-based preflight")
        for args in searches:
            signature, count, *attributes = args[args.index("SearchItems") + 1:]
            self.assertEqual(signature, "a{ss}")
            self.assertEqual(count, "3")
            self.assertEqual(dict(zip(attributes[::2], attributes[1::2])), item()["attributes"])

    def assert_refused(self, result, reason):
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stdout + result.stderr, re.compile(reason, re.IGNORECASE))
        self.assert_no_delete()

    def test_preview_does_not_delete(self):
        result = self.removal()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(SERVICE, result.stdout + result.stderr)
        self.assertIn(PROJECT, result.stdout + result.stderr)
        self.assertIn("--confirm", result.stdout + result.stderr)
        self.assert_search_identity()
        self.assert_no_delete()

    def test_confirm_deletes_only_selected_item_and_preserves_neighbours(self):
        neighbours = {
            COLLECTION + "/service": item(service=SERVICE + "-other"),
            COLLECTION + "/project": item(project=PROJECT + "-other"),
            COLLECTION + "/credential": item(credential="password"),
        }
        self.items.update(neighbours)
        result = self.removal(confirmed=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.remaining(), neighbours)
        self.assert_search_identity()
        deletes = [args for _, args in self.calls() if "Delete" in args]
        self.assertEqual(len(deletes), 1)
        self.assertIn(TARGET, deletes[0])
        self.assertIn("org.freedesktop.Secret.Item", deletes[0])
        calls = self.calls()
        deletion_index = next(i for i, (_, args) in enumerate(calls) if "Delete" in args)
        self.assertTrue(
            any("SearchItems" in args for _, args in calls[deletion_index + 1:]),
            "deletion requires a fresh verification search",
        )

    def test_missing_target_refuses_without_deleting_neighbour(self):
        self.items = {COLLECTION + "/neighbour": item(project=PROJECT + "-other")}
        self.assert_refused(self.removal(confirmed=True), r"not found|no matching|missing")
        self.assert_search_identity()

    def test_duplicate_unlocked_matches_refuse(self):
        self.items[COLLECTION + "/duplicate"] = item()
        self.assert_refused(self.removal(confirmed=True), r"duplicate|ambiguous|multiple|more than one")
        self.assert_search_identity()

    def test_locked_duplicate_is_not_ignored(self):
        self.items[COLLECTION + "/duplicate"] = item(locked=True)
        self.assert_refused(self.removal(confirmed=True), r"duplicate|ambiguous|multiple|locked")
        self.assert_search_identity()

    def test_single_locked_match_refuses(self):
        self.items[TARGET]["locked"] = True
        self.assert_refused(self.removal(confirmed=True), r"locked")
        self.assert_search_identity()

    def test_changed_attributes_refuse(self):
        self.behavior = {"fault": "changed_attributes"}
        self.assert_refused(self.removal(confirmed=True), r"attributes|changed|mismatch")

    def test_newly_locked_target_refuses(self):
        self.behavior = {"fault": "newly_locked"}
        self.assert_refused(self.removal(confirmed=True), r"locked")

    def test_replaced_target_refuses_without_deleting_either_item(self):
        self.behavior = {"fault": "replace_target"}
        result = self.removal(confirmed=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stdout + result.stderr, r"[Cc]hanged")
        self.assertFalse(any("Delete" in args for _, args in self.calls()))
        self.assertEqual(self.remaining(), {COLLECTION + "/replacement": item()})

    def test_prompt_is_not_treated_as_success_or_automatically_run(self):
        self.behavior = {"fault": "prompt"}
        result = self.removal(confirmed=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stdout + result.stderr, r"[Pp]rompt")
        self.assertEqual(self.remaining(), self.items)
        self.assertEqual(sum("Delete" in args for _, args in self.calls()), 1)
        self.assertFalse(any("Prompt" in args for _, args in self.calls()))

    def test_failed_verification_does_not_claim_success(self):
        self.behavior = {"fault": "delete_noop"}
        result = self.removal(confirmed=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stdout + result.stderr, r"[Vv]erif|still|remain")
        self.assertEqual(self.remaining(), self.items)
        self.assertEqual(sum("Delete" in args for _, args in self.calls()), 1)

    def test_search_errors_are_redacted_and_do_not_delete(self):
        self.behavior = {"fail_member": "SearchItems"}
        self.assert_refused(self.removal(confirmed=True), r"failed|unavailable|error")

    def test_malformed_search_does_not_delete(self):
        self.behavior = {"malformed_member": "SearchItems"}
        self.assert_refused(self.removal(confirmed=True), r"invalid|malformed|failed")

    def test_delete_failure_is_not_retried_or_leaked(self):
        self.behavior = {"fail_member": "Delete"}
        result = self.removal(confirmed=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sum("Delete" in args for _, args in self.calls()), 1)
        self.assertEqual(self.remaining(), self.items)

    def test_invalid_attributes_or_lock_state_never_delete(self):
        for member in ("Attributes", "Locked"):
            with self.subTest(member=member):
                self.behavior = {"malformed_member": member}
                self.assert_refused(self.removal(confirmed=True), r"invalid|unavailable")

    def test_metadata_read_failure_never_deletes(self):
        for member in ("Attributes", "Locked"):
            with self.subTest(member=member):
                self.behavior = {"fail_member": member}
                self.assert_refused(self.removal(confirmed=True), r"failed")

    def test_malformed_delete_reply_does_not_claim_success(self):
        self.behavior = {"malformed_member": "Delete"}
        result = self.removal(confirmed=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not confirmed", result.stderr)
        self.assertEqual(sum("Delete" in args for _, args in self.calls()), 1)

    def test_post_delete_read_failure_reports_uncertain_outcome(self):
        self.behavior = {"fault": "verification_error"}
        result = self.removal(confirmed=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not confirmed", result.stderr)
        self.assertEqual(self.remaining(), {})
        self.assertEqual(sum("Delete" in args for _, args in self.calls()), 1)
        self.assertNotRegex(result.stdout, r"[Rr]emoved")

    def test_invalid_names_and_options_never_reach_keyring(self):
        for args in (
            ("remove", "", PROJECT, "--confirm"),
            ("remove", SERVICE, "bad/project", "--confirm"),
            ("remove", SERVICE, PROJECT, "--yes"),
            ("remove", SERVICE, PROJECT, "--confirm", "extra"),
        ):
            with self.subTest(args=args):
                result = self.invoke(*args)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(self.calls(), [])

    def test_option_like_names_are_data_not_busctl_options(self):
        self.items = {TARGET: item(service="--system")}
        result = self.invoke("remove", "--system", PROJECT, "--confirm")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.remaining(), {})
        for tool, args in self.calls():
            self.assertEqual(tool, "busctl")
            self.assertIn("--", args)
            if "SearchItems" in args:
                self.assertLess(args.index("--"), args.index("--system"))

    def test_lookup_keeps_existing_exact_attributes(self):
        result = self.invoke("lookup", SERVICE, PROJECT)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, SENTINEL)
        self.assertEqual(self.calls(), [["secret-tool", [
            "lookup", "service", SERVICE, "project", PROJECT, "credential", "api-key",
        ]]])

    def test_store_keeps_existing_label_and_exact_attributes(self):
        result = self.invoke("store", SERVICE, PROJECT, stdin=SENTINEL)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(self.calls(), [["secret-tool", [
            "store", f"--label={PROJECT} {SERVICE} API key",
            "service", SERVICE, "project", PROJECT, "credential", "api-key",
        ]]])

    def test_list_projects_keeps_credential_filter(self):
        self.items.update({
            COLLECTION + "/project": item(project="another-project"),
            COLLECTION + "/credential": item(project="unrelated", credential="password"),
        })
        result = self.invoke("list-projects")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["another-project", PROJECT])
        self.assert_no_delete()

    def test_search_keeps_case_insensitive_service_filter(self):
        self.items.update({
            COLLECTION + "/service": item(service="different"),
            COLLECTION + "/credential": item(credential="password"),
        })
        result = self.invoke("search", "TEST-SERVICE")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, f"{SERVICE}\t{PROJECT}\n")
        self.assert_no_delete()

    def test_list_keeps_metadata_only_project_filter(self):
        self.items.update({
            COLLECTION + "/second": item(service="another-service"),
            COLLECTION + "/project": item(project="another-project"),
            COLLECTION + "/credential": item(service="unrelated", credential="password"),
        })
        result = self.invoke("list", PROJECT)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["another-service", SERVICE])
        self.assertTrue(all(tool == "busctl" for tool, _ in self.calls()))
        self.assertNotIn(SENTINEL, result.stdout + result.stderr)
        self.assert_no_delete()


if __name__ == "__main__":
    unittest.main()
