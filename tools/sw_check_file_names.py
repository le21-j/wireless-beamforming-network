#!/usr/bin/env python3
"""Check team prefixes on tracked project files."""

import argparse
from pathlib import Path, PurePosixPath
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PREFIXES = ("sw_", "hw_", "rf_")
SHARED_DOCS = {
    "docs/backlog.md", "docs/github-issues.md", "docs/github-setup.md",
    "docs/project-plan.md", "docs/reading-guide.md",
}


# =============================================================================
# Team names and the few files whose names are fixed by other tools
# =============================================================================

def naming_error(path):
    path = PurePosixPath(path)
    name = path.name
    # Metadata and shared entry points keep their names.
    if (any(part.startswith(".") for part in path.parts)
            or name in {"README.md", "LICENSE", "COPYING"}
            or str(path) in SHARED_DOCS
            or path.parts[0] == "third_party"):
        return None
    if path.suffix.lower() in {".sv", ".v", ".vh"}:
        required = "hw_"
    elif "rf" in path.parts[:-1]:
        required = "rf_"
    else:
        required = None
    if required and not name.startswith(required):
        return f"{path}: use {required} for this team"
    if not name.startswith(PREFIXES):
        return f"{path}: start the filename with sw_, hw_ or rf_"
    return None


# =============================================================================
# Check the Git index so generated files and local outputs stay out of the rule
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    paths = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=ROOT).decode("utf-8").split("\0")
    paths = [path for path in paths if path]
    errors = [error for path in paths if (error := naming_error(path))]
    if errors:
        print("\n".join(errors))
        return 1
    print(f"Team filename check passed for {len(paths)} tracked files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
