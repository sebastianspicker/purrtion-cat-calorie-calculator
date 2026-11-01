"""Check the real source-export command against synthetic public/private files."""
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


class SourceArchiveTests(unittest.TestCase):
    def test_private_notes_stay_local_and_public_source_still_ships(self):
        repository = pathlib.Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory) / "fixture"
            (root / "script").mkdir(parents=True)
            shutil.copyfile(repository / "script/package_source.py", root / "script/package_source.py")
            private = [
                "THINGS_TO_DO_LEDGER.md", "nested/Mixed_Ledger.md", "AGENTS.md", "nested/AGENT.md", "nested/claude.md",
                "GEMINI.md", ".github/copilot-instructions.md",
                ".claude/session.json", ".codex/environments/environment.toml", ".agents/handoff.md",
                "ALPHA_AUDIT_REPORT.md", "ALPHA_IMPLEMENTATION_LEDGER.md", "ALPHA_PR_DESCRIPTION.md", ".env",
            ]
            public = [
                "LICENSE", "docs/ENGINE.md", "ALPHA_KNOWN_ISSUES.md", ".env.example",
                ".github/workflows/ci.yml", "tests/browser_smoke.py", "apps/web/index.ts",
            ]
            for name in private + public:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("Synthetic source-export fixture\n")
            outside = pathlib.Path(directory) / "outside.txt"
            outside.write_text("Do not follow this link\n")
            (root / "linked.txt").symlink_to(outside)
            output = pathlib.Path(directory) / "source.zip"
            subprocess.run([sys.executable, str(root / "script/package_source.py"), str(output)],
                           check=True, capture_output=True, text=True)
            with zipfile.ZipFile(output) as archive:
                names = set(archive.namelist())
            prefix = "cat-calorie-calculator/"
            for name in private + ["linked.txt"]:
                self.assertNotIn(prefix + name, names, name)
            for name in public:
                self.assertIn(prefix + name, names, name)


if __name__ == "__main__":
    unittest.main()
