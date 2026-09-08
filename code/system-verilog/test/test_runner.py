"""Check make's failure handling without running a hardware simulation."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


MAKEFILE = Path(__file__).resolve().parents[1] / "Makefile"


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copy(MAKEFILE, self.root / "Makefile")
        (self.root / "rtl").mkdir()
        (self.root / "test").mkdir()
        (self.root / "test/tb_example.sv").touch()
        self.write_tool("compiler", "exit 0")
        self.write_tool("simulator", "echo 'PASS tb_example'")

    def write_tool(self, name, body):
        path = self.root / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def run_make(self, name="example"):
        return subprocess.run(
            ["make", "test", f"NAME={name}", "IVERILOG=./compiler", "VVP=./simulator"],
            cwd=self.root,
            capture_output=True,
            text=True,
            env={**os.environ, "MAKEFLAGS": "", "MFLAGS": ""},
        )

    def test_success(self):
        for output in ("PASS tb_example", "  PASS  example - all checks good"):
            with self.subTest(output=output):
                self.write_tool("simulator", f"echo '{output}'")
                result = self.run_make()
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("PASS  example", result.stdout)

    def test_compile_failure_skips_simulation(self):
        self.write_tool("compiler", "echo 'compile failed'; exit 1")
        self.write_tool("simulator", "touch simulator-ran; echo 'PASS tb_example'")
        result = self.run_make()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("compile failed", result.stdout)
        self.assertFalse((self.root / "simulator-ran").exists())

    def test_simulator_failure_after_pass(self):
        self.write_tool("simulator", "echo 'PASS tb_example'; exit 1")
        self.assertNotEqual(self.run_make().returncode, 0)

    def test_missing_or_misleading_pass(self):
        for output in (
            "",
            "diagnostic: PASS tb_example",
            "PASS tb_example\nFAIL assertion",
            "PASS tb_example\n  FAIL assertion",
            "PASS tb_example\nERROR: assertion",
            "PASS tb_example\nFATAL: assertion",
        ):
            with self.subTest(output=output):
                self.write_tool("simulator", f"printf '%s\\n' '{output}'")
                self.assertNotEqual(self.run_make().returncode, 0)

    def test_stale_pass_log(self):
        self.assertEqual(self.run_make().returncode, 0)
        self.write_tool("simulator", "exit 0")
        self.assertNotEqual(self.run_make().returncode, 0)

    def test_unknown_names_cannot_run_other_targets(self):
        for name in ("missing", "clean", "list", "example clean"):
            with self.subTest(name=name):
                build = self.root / ".build"
                build.mkdir(exist_ok=True)
                sentinel = build / "keep"
                sentinel.touch()
                result = self.run_make(name)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Unknown test name", result.stderr)
                self.assertTrue(sentinel.exists())
