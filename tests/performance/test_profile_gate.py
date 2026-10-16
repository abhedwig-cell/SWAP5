#!/usr/bin/env python3
"""Opt-in smoke/negative checks for the F-CI timing probe; no SWAP5 physics."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[2] / 'tools/performance/profile_gate.py'


class ProfileGateSmoke(unittest.TestCase):
    def test_compilation_and_exit_status(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            source = root / 'smoke.f90'
            source.write_text('program smoke\nprint *, 42\nend program\n')
            binary = root / 'smoke'
            evidence = root / 'success.json'
            cmd = [sys.executable, str(TOOL), '--output', str(evidence), '--',
                   'bash', '-c', 'gfortran -O2 "$1" -o "$2" && "$2"', '_',
                   str(source), str(binary)]
            completed = subprocess.run(cmd, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            payload = json.loads(evidence.read_text())
            self.assertEqual(payload['gate_returncode'], 0)
            self.assertEqual(payload['compiler_invocations'], 1)
            self.assertEqual(payload['compiler_events'][0]['returncode'], 0)
            self.assertIn('42', subprocess.check_output([str(binary)], text=True))
            second = subprocess.run(cmd, capture_output=True, text=True)
            self.assertNotEqual(second.returncode, 0)
            self.assertEqual(json.loads(evidence.read_text()), payload)

    def test_failed_gate_and_missing_compiler_invocations(self):
        with tempfile.TemporaryDirectory() as name:
            path = Path(name) / 'failure.json'
            completed = subprocess.run(
                [sys.executable, str(TOOL), '--output', str(path), '--',
                 'bash', '-c', 'exit 19'], capture_output=True, text=True)
            self.assertEqual(completed.returncode, 19)
            payload = json.loads(path.read_text())
            self.assertEqual(payload['gate_returncode'], 19)
            self.assertEqual(payload['compiler_invocations'], 0)


    def test_compiler_failure_is_recorded(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            invalid = root / 'invalid.f90'
            invalid.write_text('not valid Fortran\\n')
            report = root / 'compiler-failure.json'
            outcome = subprocess.run(
                [sys.executable, str(TOOL), '--output', str(report), '--',
                 'gfortran', '-c', str(invalid), '-o', str(root / 'invalid.o')],
                capture_output=True, text=True)
            self.assertNotEqual(outcome.returncode, 0)
            entry = json.loads(report.read_text())
            self.assertEqual(entry['gate_returncode'], outcome.returncode)
            self.assertEqual(entry['compiler_invocations'], 1)
            self.assertNotEqual(entry['compiler_events'][0]['returncode'], 0)

if __name__ == '__main__':
    unittest.main()
