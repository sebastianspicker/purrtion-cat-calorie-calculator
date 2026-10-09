#!/usr/bin/env python3
"""Create a clean source ZIP. Excludes build output, dependencies, git internals and QA screenshots."""
from fnmatch import fnmatch
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import sys
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT.parent / "purrtion-scaffold.zip"
EXCLUDE = {".git", "node_modules", "dist", ".build", ".swiftpm", "DerivedData", ".DS_Store", "__pycache__", ".venv", "venv",
           "playwright-results", "playwright-report", "test-results", "coverage", ".nyc_output", ".pytest_cache", "screenshots",
           # Private notes, ledgers and agent working state (mirrors .gitignore).
           "private", "ledger", ".ruff_cache", ".mypy_cache", ".agents", ".cc-writes", "scratch", "tmp", ".idea", ".vscode", "xcuserdata"}
# Personal data, secrets and local-only files, matched against the file name (mirrors .gitignore).
EXCLUDE_NAMES = (".env*", "*.pem", "*.key", "*.p12", "*.p8", "*.mobileprovision", "*.provisionprofile", "*.keychain*", ".netrc", ".npmrc",
                 "*.private.*", "*.ledger", "*.ledger.*", "LEDGER*.md", "settings.local.json", "CLAUDE.local.md", "AGENTS.local.md",
                 "purrtion-plan*.json", "purrtion-portions*.csv", "purrtion-recovery*.json", "plan-backup-*.json", "plan-v1-backup*.json", "plan.json",
                 "*.plan.json", "*.log", "junit*.xml", "*.lcov", "*.xcuserstate", "*.zip", "._*", "Thumbs.db")
def excluded(relative: Path) -> bool:
    if any(part in EXCLUDE for part in relative.parts): return True
    if relative.parts[0] == ".codex" and relative.parts[1:2] != ("environments",): return True
    return relative.name != ".env.example" and any(fnmatch(relative.name, pattern) for pattern in EXCLUDE_NAMES)
with ZipFile(OUTPUT, "w", ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(ROOT.rglob("*")):
        relative = path.relative_to(ROOT)
        # Symlinks are skipped so a link inside the repo cannot pull an outside file into the archive.
        if path.is_file() and not path.is_symlink() and path != OUTPUT and not excluded(relative):
            archive.write(path, Path("cat-calorie-calculator") / relative)
print(OUTPUT)
