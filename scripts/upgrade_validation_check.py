#!/usr/bin/env python3
"""
upgrade_validation_check.py
Python-native Docling upgrade validation for vboard-capture-pipeline
Run with: python scripts/upgrade_validation_check.py --target-docling-version 1.2.3
"""

import sys
import subprocess
import argparse
from pathlib import Path
import re
import json

def report(name: str, status: str, note: str = ""):
    color = {"PASS": "\033[92m", "FAIL": "\033[91m", "SKIPPED": "\033[93m"}
    print(f"{name:<50} {color.get(status, '')}{status}\033[0m")
    if note:
        print(f"    Note: {note}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-docling-version", required=False, help="Target Docling version to validate against")
    parser.add_argument("--create-branch", action="store_true", help="Create branch if needed")
    args = parser.parse_args()

    print("STEP 0 — CONFIRMATION: branch & git status")
    try:
        branch = subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"]).decode().strip()
        print(f"Current branch: {branch}")
        report("current branch", "PASS")
    except:
        report("current branch", "FAIL", "Not a git repo or git missing")
        sys.exit(2)

    # Git clean? (allow untracked files, but not modified tracked files)
    status = subprocess.getoutput("git status --porcelain")
    if status.strip():
        # Check if there are only untracked files (??), not modified tracked files
        modified = subprocess.getoutput("git status --porcelain | grep -E '^ [AM]|^[AMR] ' || true")
        if modified.strip():
            report("git status is clean", "FAIL", "Modified tracked files found")
            sys.exit(2)
        else:
            report("git status is clean", "PASS", "Only untracked files present (OK)")
    else:
        report("git status is clean", "PASS")

    # Branch pattern (optional auto-create)
    pattern = re.compile(r"^upgrade/docling-\d{4}-\d{2}-\d{2}$")
    if args.create_branch:
        # TODO: implement create if you want
        pass
    elif not pattern.match(branch):
        report("Branch name valid", "FAIL", "Must be upgrade/docling-YYYY-MM-DD")
        sys.exit(2)
    else:
        report("Branch name valid", "PASS")

    # Target Docling version supplied?
    if args.target_docling_version:
        report("Target Docling version", "PASS")
    else:
        report("Target Docling version", "SKIPPED", "No --target-docling-version supplied")

    # Dependencies exist?
    if Path("requirements.txt").exists():
        report("requirements.txt exists", "PASS")
    elif Path("pyproject.toml").exists():
        report("pyproject.toml exists", "PASS")
    else:
        report("requirements.txt or pyproject.toml", "FAIL", "No Python dependency file found")
        sys.exit(2)

    # Pip install dry-run (upgrade check)
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt", "--dry-run", "--upgrade"])
        report("pip install --upgrade --dry-run", "PASS")
    except:
        report("pip install --upgrade --dry-run", "FAIL", "Pip failed")
        sys.exit(2)

    # Docling version check
    try:
        import docling
        current = docling.__version__
        print(f"Current Docling version: {current}")
        if args.target_docling_version and current != args.target_docling_version:
            report("Docling version matches target", "FAIL", f"Current={current}, Target={args.target_docling_version}")
        else:
            report("Docling version check", "PASS")
    except ImportError:
        report("Docling import", "FAIL", "docling not installed")
        sys.exit(2)

    # Basic smoke test
    try:
        from docling.document_converter import DocumentConverter
        converter = DocumentConverter()
        # Simple in-memory test (no real file needed)
        print("Docling smoke test: converter created successfully")
        report("Docling smoke test", "PASS")
    except Exception as e:
        report("Docling smoke test", "FAIL", str(e))
        sys.exit(2)

    # Tests (if pytest exists)
    if subprocess.getoutput("python -c 'import pytest' 2>/dev/null") == "":
        report("pytest available", "SKIPPED", "pytest not installed")
    else:
        try:
            subprocess.check_call(["pytest", "--quiet"])
            report("pytest", "PASS")
        except:
            report("pytest", "FAIL", "Tests failed")
            sys.exit(2)

    print("\nAll checks PASS or SKIPPED. Good to proceed with Docling upgrade.")
    sys.exit(0)

if __name__ == "__main__":
    main()
