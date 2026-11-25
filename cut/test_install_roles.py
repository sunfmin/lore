# /// script
# requires-python = ">=3.11"
# ///
"""Test of cut/install-roles on a fixture host (lore#4).

A fresh HOME holds rolesmith's source for this library, whose url git
redirects to a local bare copy of this repo, and four projects on rolesmith's
projects record: a worker role directory, a role directory that is a git
checkout of its rolesmith.toml, a role directory that no longer exists, and a
project outside the role directories. The library's main then moves one
commit. Only the role directory moves to it; a second run changes nothing.

Run: uv run --script cut/test_install_roles.py
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "cut" / "install-roles"
URL = "https://github.com/sunfmin/lore"


def run(cmd, env, cwd=None, check=True):
    p = subprocess.run(cmd, env=env, cwd=cwd, capture_output=True, text=True)
    if check and p.returncode != 0:
        raise AssertionError(f"{cmd} exited {p.returncode}:\n{p.stdout}\n{p.stderr}")
    return p


def revs(project):
    record = tomllib.loads((Path(project) / "rolesmith.toml").read_text())
    return {r["name"]: r["rev"] for r in record["role"]}


class InstallRoles(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(os.path.realpath(tempfile.mkdtemp(prefix="install-roles-")))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        home = self.tmp / "home"
        home.mkdir()
        upstream = self.tmp / "lore.git"
        gitconfig = self.tmp / "gitconfig"
        gitconfig.write_text(
            f'[url "file://{upstream}"]\n\tinsteadOf = {URL}\n'
            "[user]\n\tname = fixture\n\temail = fixture@example.invalid\n"
            "[init]\n\tdefaultBranch = main\n"
        )
        env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "GIT_"))}
        env.update(HOME=str(home), GIT_CONFIG_GLOBAL=str(gitconfig), GIT_CONFIG_NOSYSTEM="1")
        self.env = env

        run(["git", "init", "-q", "--bare", "-b", "main", str(upstream)], env)
        run(["git", "-C", str(REPO), "push", "-q", str(upstream), "HEAD:refs/heads/main"], env)
        self.first = run(["git", "-C", str(upstream), "rev-parse", "main"], env).stdout.strip()
        run(["rolesmith", "source", "add", "felix", URL], env)

        roles = home / ".local" / "share" / "roles"
        self.role_dir = roles / "coder"
        self.checkout = roles / "checked-in"
        self.gone = roles / "gone"
        self.outside = self.tmp / "elsewhere"
        for d in (self.role_dir, self.checkout, self.gone, self.outside):
            d.mkdir(parents=True)
            run(["rolesmith", "use", "coder", "--into", "claude-code", "--project", str(d)], env)
        run(["git", "init", "-q"], env, cwd=self.checkout)
        run(["git", "add", "rolesmith.toml"], env, cwd=self.checkout)
        run(["git", "commit", "-q", "-m", "pin roles"], env, cwd=self.checkout)
        shutil.rmtree(self.gone)

        work = self.tmp / "work"
        run(["git", "clone", "-q", str(upstream), str(work)], env)
        run(["git", "commit", "-q", "--allow-empty", "-m", "a promoted change"], env, cwd=work)
        run(["git", "push", "-q", "origin", "main"], env, cwd=work)
        self.second = run(["git", "-C", str(work), "rev-parse", "HEAD"], env).stdout.strip()

    def install(self):
        p = run([sys.executable, str(SCRIPT)], self.env, check=False)
        self.assertEqual(p.returncode, 0, p.stderr)
        lines = [json.loads(l) for l in p.stdout.splitlines()]
        return {Path(l["project"]): l for l in lines}

    def test_updates_only_role_directories_and_is_idempotent(self):
        first = self.install()
        self.assertEqual(set(first), {self.role_dir, self.checkout, self.gone, self.outside})

        moved = first[self.role_dir]
        self.assertEqual(moved["status"], "updated")
        self.assertEqual(moved["before"], {"coder": self.first})
        self.assertEqual(moved["after"], {"coder": self.second})
        self.assertEqual(revs(self.role_dir), {"coder": self.second})

        for project, why in (
            (self.checkout, "git checkout"),
            (self.gone, "missing"),
            (self.outside, "not a role directory"),
        ):
            self.assertEqual(first[project]["status"], "skipped", first[project])
            self.assertIn(why, first[project]["why"])
        self.assertEqual(revs(self.checkout), {"coder": self.first})
        self.assertEqual(revs(self.outside), {"coder": self.first})

        tree = {p: p.read_bytes() for p in self.role_dir.rglob("*") if p.is_file()}
        again = self.install()
        self.assertEqual(again[self.role_dir]["status"], "unchanged")
        self.assertEqual(again[self.role_dir]["after"], {"coder": self.second})
        self.assertEqual({p: p.read_bytes() for p in self.role_dir.rglob("*") if p.is_file()}, tree)

    def test_a_failed_update_fails_the_run(self):
        (self.role_dir / "rolesmith.toml").write_text("not toml [[[")
        p = run([sys.executable, str(SCRIPT)], self.env, check=False)
        self.assertNotEqual(p.returncode, 0)
        line = next(json.loads(l) for l in p.stdout.splitlines()
                    if Path(json.loads(l)["project"]) == self.role_dir)
        self.assertEqual(line["status"], "failed")


if __name__ == "__main__":
    unittest.main()
