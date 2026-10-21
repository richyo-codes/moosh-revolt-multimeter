"""Exercise packaging path handling without builds, downloads, or containers.

Run with: python3 tools/test_flatpak_scripts.py
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = (
    "build_flatpak.sh",
    "build_flatpak_gtk4.sh",
    "build_flatpak_container.sh",
)
APP_ID = "ca.richyoung.mooshrevolt"


class FlatpakPathsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="moosh-flatpak-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "project"
        (self.root / "tools").mkdir(parents=True)
        for script in SCRIPTS:
            shutil.copy2(SOURCE_ROOT / "tools" / script, self.root / "tools")
        shutil.copytree(SOURCE_ROOT / "flatpak", self.root / "flatpak")
        (self.root / "linux/assets/icons").mkdir(parents=True)
        (self.root / "LICENSE").touch()
        for variant in ("linux", "linux-gtk4"):
            bundle = self.root / "build" / variant / "x64/release/bundle"
            (bundle / "lib").mkdir(parents=True)
            (bundle / "lib/libapp.so").touch()
            binary = bundle / "mooshrevolt"
            binary.touch(mode=0o755)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        mock = self.bin / "mock"
        mock.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, pathlib, sys\n"
            "tool = pathlib.Path(sys.argv[0]).name\n"
            "with open(os.environ['MOOSH_TEST_LOG'], 'a') as log:\n"
            "    log.write(json.dumps([tool, os.getcwd(), sys.argv[1:]]) + '\\n')\n"
        )
        mock.chmod(0o755)
        for tool in ("flatpak", "flatpak-builder", "flutter", "patchelf", "ldd", "podman"):
            (self.bin / tool).symlink_to(mock)
        self.log = self.base / "calls.jsonl"
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        MOOSH_TEST_LOG=str(self.log), CI="false", GITHUB_ACTIONS="false")

    def run_script(self, script, *args, ci=False):
        env = dict(self.env, CI="true" if ci else "false")
        return subprocess.run(
            ["bash", str(self.root / "tools" / script), *args],
            cwd=self.base, env=env, capture_output=True, text=True,
        )

    def calls(self, tool):
        entries = [json.loads(line) for line in self.log.read_text().splitlines()]
        return [(cwd, args) for name, cwd, args in entries if name == tool]

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_gtk3_output_and_skip_build_in_either_order(self):
        for args in (("--skip-build", "--out-dir", "external work/gtk3"),
                     ("--out-dir=external work/gtk3", "--skip-build")):
            with self.subTest(args=args):
                self.assert_success(self.run_script(SCRIPTS[0], *args))
                output = self.base / "external work/gtk3"
                builder = self.calls("flatpak-builder")[-1][1]
                self.assertIn(f"--state-dir={output}/flatpak-state", builder)
                self.assertIn(f"--repo={output}/flatpak-repo", builder)
                self.assertEqual(builder[-2], str(output / "flatpak"))
                self.assertEqual(self.calls("flatpak")[-1][1], [
                    "build-bundle", str(output / "flatpak-repo"),
                    str(output / f"{APP_ID}.flatpak"), APP_ID,
                ])
                self.assertEqual(self.calls("flutter"), [])

    def test_gtk3_default_output_and_flutter_working_directory(self):
        self.assert_success(self.run_script(SCRIPTS[0]))
        self.assertEqual(self.calls("flutter"), [(str(self.root), ["build", "linux", "--release"])])
        builder = self.calls("flatpak-builder")[0][1]
        self.assertEqual(builder[-2], str(self.root / "build/flatpak"))
        self.assertIn(f"--state-dir={self.root}/build/flatpak-state", builder)

    def test_gtk4_staging_and_builder_use_output_directory(self):
        bundle = self.root / "build/linux-gtk4/x64/release/bundle"
        self.assert_success(self.run_script(
            SCRIPTS[1], "--out-dir=external work/gtk4", f"--bundle-dir={bundle}",
        ))
        output = self.base / "external work/gtk4"
        builder = self.calls("flatpak-builder")[0][1]
        self.assertIn(f"--state-dir={output}/state", builder)
        self.assertIn(f"--repo={output}/repo", builder)
        self.assertEqual(builder[-2], str(output / "build"))
        self.assertEqual(Path(builder[-1]).parent.parent, output)
        self.assertEqual(list(output.glob("flatpak-stage.*")), [])
        self.assertEqual(self.calls("flatpak")[-1][1][2], str(output / f"{APP_ID}.gtk4.flatpak"))

    def test_gtk4_ci_forwards_output_and_staged_bundle_to_container(self):
        bundle = self.root / "build/linux-gtk4/x64/release/bundle"
        self.assert_success(self.run_script(
            SCRIPTS[1], "--out-dir", "external work/ci", "--bundle-dir", str(bundle), ci=True,
        ))
        output = self.base / "external work/ci"
        args = self.calls("podman")[0][1]
        self.assertIn(f"{output}:/output:Z", args)
        self.assertTrue(any(arg.startswith(str(output / "flatpak-stage."))
                            and arg.endswith("/bundle:/bundle:ro,Z") for arg in args))
        self.assertIn("--state-dir=/output/flatpak-state", args[-1])
        self.assertEqual(list(output.glob("flatpak-stage.*")), [])

    def test_container_mounts_custom_output(self):
        self.assert_success(self.run_script(SCRIPTS[2], "--out-dir=external work/container"))
        self.assertIn(f"{self.base}/external work/container:/output:Z", self.calls("podman")[0][1])

    def test_help_and_invalid_arguments_do_not_invoke_tools(self):
        for script in SCRIPTS:
            with self.subTest(script=script):
                result = self.run_script(script, "--help")
                self.assert_success(result)
                self.assertIn("--out-dir", result.stdout)
                for args in (("--out-dir",), ("--out-dir=",), ("--out-dir", ""),
                             ("--out-dir", "--help"), ("--unknown",)):
                    result = self.run_script(script, *args)
                    self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
