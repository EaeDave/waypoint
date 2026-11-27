#!/usr/bin/env python3
"""Select CI jobs from the complete revision range being tested."""

import os
import re
import subprocess
import sys

ALL = frozenset({"linux", "android", "server", "quickshell"})
CLIENTS = frozenset({"linux", "android"})
VERSION = rb"[0-9]+\.[0-9]+\.[0-9]+"
VERSION_FIELDS = {
    "CMakeLists.txt": rb"^project\(Waypoint VERSION (" + VERSION + rb") LANGUAGES CXX\)$",
    "server/Cargo.toml": rb'^\[package\]\nname = "waypoint-api"\nversion = "(' + VERSION + rb')"$',
    "Cargo.lock": rb'^\[\[package\]\]\nname = "waypoint-api"\nversion = "(' + VERSION + rb')"$',
    "plugins/omarchy-waypoint/manifest.json": rb'^  "version": "(' + VERSION + rb')",$',
}


def targets_for(path):
    if path.startswith(("docs/", ".agents/", ".claude/")) or path in {
        "README.md", "AGENTS.md", "CLAUDE.md", "skills-lock.json",
    }:
        return set()
    if path.startswith("plugins/omarchy-waypoint/"):
        return {"quickshell"}
    if path.startswith(("android/", "qml/mobile/", ".maestro/")) or path == "bin/build-android":
        return {"android"}
    if path.startswith("server/") or path in {"Cargo.toml", "Cargo.lock", "Dockerfile", ".dockerignore", "compose.yaml"}:
        return {"server"}
    if path.startswith(("src/ipc/", "src/cli/", "src/daemon/")):
        return {"linux", "quickshell"}
    if path.startswith("src/sync/SyncProtocol."):
        return CLIENTS | {"server"}
    if path.startswith(("src/core/", "src/mobile/", "src/sync/", "src/update/UpdateChecker", "qml/data/", "qml/fonts/")) or path in {
        "CMakeLists.txt", "CMakePresets.json",
    }:
        return CLIENTS
    if path.startswith(("src/app/", "src/reminders/", "qml/", "packaging/", "tests/")) or path in {
        "src/update/LinuxUpdaterMain.cpp", "bin/package-linux", "bin/setup", "install.sh",
    }:
        return {"linux"}
    return ALL


def git(*args):
    return subprocess.check_output(["git", *args])


def mask_version(contents, field):
    match = re.search(field, contents, re.MULTILINE)
    if match is None:
        return contents
    return contents[:match.start(1)] + b"<version>" + contents[match.end(1):]


def changed_targets(base, head):
    if not base or not head or not base.strip("0"):
        return ALL
    try:
        paths = git("diff", "--name-only", "--no-renames", "-z", base, head, "--")
        targets = set()
        version_only = False
        for path in filter(None, os.fsdecode(paths).split("\0")):
            field = VERSION_FIELDS.get(path)
            if field and mask_version(git("show", f"{base}:{path}"), field) == mask_version(
                git("show", f"{head}:{path}"), field
            ):
                version_only = True
                continue
            targets.update(targets_for(path))
            if targets == ALL:
                break
        # An explicit release without an affected component still gets full CI.
        return ALL if version_only and not targets else targets
    except subprocess.CalledProcessError:
        print("Could not classify the revision range; running full CI.", file=sys.stderr)
        return ALL


if __name__ == "__main__":
    selected = changed_targets(os.environ.get("CI_BASE"), os.environ.get("CI_HEAD"))
    for target in sorted(ALL):
        print(f"{target}={'true' if target in selected else 'false'}")
