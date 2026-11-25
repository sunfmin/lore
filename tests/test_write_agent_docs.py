# /// script
# requires-python = ">=3.11"
# ///
"""Test of the new-repo skill's write-agent-docs on fixture repos (lore#6).

An empty repo gets all three agent docs; a second run changes nothing; an
edited docs/agents/issue-tracker.md is refused, named, and kept unless
--force; an existing CLAUDE.md (or AGENTS.md) has only its Agent skills block
written, added when it has none.

Run: uv run --script tests/test_write_agent_docs.py
"""

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent / "roles" / "tech-lead" / "skills" / "new-repo"
SCRIPT = SKILL / "write-agent-docs"
FILES = ["docs/agents/issue-tracker.md", "docs/agents/domain.md", "CLAUDE.md"]


class WriteAgentDocs(unittest.TestCase):
    def setUp(self):
        self.repo = Path(tempfile.mkdtemp(prefix="write-agent-docs-"))
        self.addCleanup(shutil.rmtree, self.repo, ignore_errors=True)

    def run_script(self, *args):
        p = subprocess.run([str(SCRIPT), *args], cwd=self.repo, capture_output=True, text=True)
        lines = [json.loads(line) for line in p.stdout.splitlines()]
        return p.returncode, {line["file"]: line for line in lines}, p.stderr

    def snapshot(self):
        return {str(f.relative_to(self.repo)): f.read_text() for f in self.repo.rglob("*") if f.is_file()}

    def test_empty_repo_gets_all_three_and_a_second_run_changes_nothing(self):
        code, out, err = self.run_script("widget")
        self.assertEqual(code, 0, err)
        self.assertEqual({f: out[f]["status"] for f in FILES}, {f: "written" for f in FILES})
        tracker = (self.repo / "docs/agents/issue-tracker.md").read_text()
        self.assertIn("factorium issue add|list|show|comment|block widget", tracker)
        self.assertIn("{checkout}", (SKILL / "agent-docs" / "issue-tracker.md").read_text())
        self.assertNotIn("{checkout}", tracker)
        claude = (self.repo / "CLAUDE.md").read_text()
        self.assertTrue(claude.startswith("# widget\n"))
        self.assertIn("## Agent skills\n", claude)
        self.assertIn("factorium issue … widget", claude)
        before = self.snapshot()
        code, out, err = self.run_script("widget")
        self.assertEqual(code, 0, err)
        self.assertEqual({f: out[f]["status"] for f in FILES}, {f: "unchanged" for f in FILES})
        self.assertEqual(self.snapshot(), before)

    def test_edited_issue_tracker_is_refused_named_and_kept_unless_forced(self):
        self.run_script("widget")
        edited = self.repo / "docs/agents/issue-tracker.md"
        edited.write_text(edited.read_text() + "\nOur own note.\n")
        mine = edited.read_text()
        code, out, err = self.run_script("widget")
        self.assertEqual(code, 1)
        self.assertEqual(out["docs/agents/issue-tracker.md"]["status"], "differs")
        self.assertIn("Our own note.", out["docs/agents/issue-tracker.md"]["diff"])
        self.assertIn("docs/agents/issue-tracker.md", err)
        self.assertEqual(out["docs/agents/domain.md"]["status"], "unchanged")
        self.assertEqual(edited.read_text(), mine)
        code, out, err = self.run_script("widget", "--force")
        self.assertEqual(code, 0, err)
        self.assertEqual(out["docs/agents/issue-tracker.md"]["status"], "written")
        self.assertNotIn("Our own note.", edited.read_text())

    def test_existing_claude_md_gets_only_its_agent_skills_block(self):
        (self.repo / "CLAUDE.md").write_text(
            "# widget\n\nThe repo's own line.\n\n## Agent skills\n\nstale\n\n## Build\n\n`make`\n"
        )
        code, out, err = self.run_script("widget")
        self.assertEqual(code, 1)
        self.assertEqual(out["CLAUDE.md"]["status"], "differs")
        code, out, err = self.run_script("widget", "--force")
        self.assertEqual(code, 0, err)
        claude = (self.repo / "CLAUDE.md").read_text()
        self.assertTrue(claude.startswith("# widget\n\nThe repo's own line.\n\n## Agent skills\n\n### Issue tracker"))
        self.assertNotIn("stale", claude)
        self.assertTrue(claude.endswith("\n## Build\n\n`make`\n"))
        self.assertEqual(self.run_script("widget")[1]["CLAUDE.md"]["status"], "unchanged")

    def test_agents_md_without_the_block_has_it_added(self):
        (self.repo / "AGENTS.md").write_text("# widget\n\nThe repo's own line.\n")
        code, out, err = self.run_script("widget")
        self.assertEqual(code, 0, err)
        self.assertEqual(out["AGENTS.md"]["status"], "written")
        self.assertNotIn("CLAUDE.md", out)
        self.assertFalse((self.repo / "CLAUDE.md").exists())
        agents = (self.repo / "AGENTS.md").read_text()
        self.assertTrue(agents.startswith("# widget\n\nThe repo's own line.\n\n## Agent skills\n"))
        self.assertEqual(self.run_script("widget")[1]["AGENTS.md"]["status"], "unchanged")


if __name__ == "__main__":
    unittest.main()
