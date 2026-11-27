import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools import ci_targets


class TargetRulesTest(unittest.TestCase):
    def test_product_boundaries(self):
        cases = {
            "plugins/omarchy-waypoint/Panel.qml": {"quickshell"},
            "android/build.gradle": {"android"},
            "qml/mobile/Main.qml": {"android"},
            "qml/Main.qml": {"linux"},
            "src/cli/main.cpp": {"linux", "quickshell"},
            "src/core/TaskStore.cpp": {"linux", "android"},
            "src/mobile/MobileController.cpp": {"linux", "android"},
            "src/sync/SyncProtocol.cpp": {"linux", "android", "server"},
            "server/src/main.rs": {"server"},
            "Cargo.lock": {"server"},
            "README.md": set(),
            "docs/setup.md": set(),
            ".github/workflows/ci.yml": ci_targets.ALL,
            "new-build-config": ci_targets.ALL,
        }
        for path, expected in cases.items():
            with self.subTest(path=path):
                self.assertEqual(ci_targets.targets_for(path), expected)


class RevisionRangeTest(unittest.TestCase):
    def setUp(self):
        self.repo = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.git("init", "-q")
        self.git("config", "user.name", "CI Test")
        self.git("config", "user.email", "ci@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", str(self.repo / "no-hooks"))
        self.base = self.commit({"README.md": "first\n"})

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, text=True).strip()

    def commit(self, files):
        for relative, contents in files.items():
            path = self.repo / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents)
        self.git("add", ".")
        self.git("commit", "-qm", "Test change")
        return self.git("rev-parse", "HEAD")

    def select(self, base, head):
        output = subprocess.check_output(
            ["python3", str(Path(ci_targets.__file__).resolve())],
            cwd=self.repo,
            env={**os.environ, "CI_BASE": base, "CI_HEAD": head},
            text=True,
        )
        return {line.split("=")[0] for line in output.splitlines() if line.endswith("=true")}

    def test_multiple_commits_and_cross_component_rename(self):
        self.commit({"android/Old.qml": "rename me\n"})
        before_rename = self.commit({"server/src/main.rs": "fn main() {}\n"})
        self.git("mv", "android/Old.qml", "install.sh")
        head = self.commit({})
        self.assertEqual(self.select(self.base, before_rename), {"android", "server"})
        self.assertEqual(self.select(before_rename, head), {"linux", "android"})

    def test_plugin_change_with_release_bump_skips_app_builds(self):
        def versions(version, dependency):
            return {
                "CMakeLists.txt": f"project(Waypoint VERSION {version} LANGUAGES CXX)\n",
                "server/Cargo.toml": f'[package]\nname = "waypoint-api"\nversion = "{version}"\n',
                "Cargo.lock": f'[[package]]\nname = "waypoint-api"\nversion = "{version}"\n'
                              f'\n[[package]]\nname = "tokio"\nversion = "{dependency}"\n',
                "plugins/omarchy-waypoint/manifest.json": f'{{\n  "version": "{version}",\n  "name": "Waypoint"\n}}\n',
            }

        base = self.commit(versions("0.2.27", "1.0.0"))
        release = self.commit(versions("0.2.28", "1.0.0"))
        self.assertEqual(self.select(base, release), ci_targets.ALL)
        head = self.commit({"plugins/omarchy-waypoint/Panel.qml": "Item {}\n"})
        self.assertEqual(self.select(base, head), {"quickshell"})
        head = self.commit(versions("0.2.28", "1.0.1"))
        self.assertEqual(self.select(base, head), {"quickshell", "server"})

    def test_docs_only_and_unknown_base(self):
        head = self.commit({"docs/setup.md": "docs only\n"})
        self.assertEqual(self.select(self.base, head), set())
        self.assertEqual(self.select("0" * 40, head), ci_targets.ALL)
