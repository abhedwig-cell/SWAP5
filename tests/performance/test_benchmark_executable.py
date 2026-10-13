#!/usr/bin/env python3
"""Opt-in standalone benchmark behavioral tests; not SWAP5 physics qualification."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[2] / 'tools/performance/benchmark_executable.py'


class BenchmarkTests(unittest.TestCase):
    def run_benchmark(self, root, filename, program, repeats=3):
        path = root / filename
        completed = subprocess.run(
            [sys.executable, str(TOOL), '--repeat', str(repeats),
             '--require-stable-stdout', '--output', str(path),
             '--', *program], capture_output=True, text=True)
        return completed, json.loads(path.read_text())

    def test_stable_and_preserve_existing_evidence(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            cmd = ['/bin/echo', 'stable']
            result, data = self.run_benchmark(root, 'stable.json', cmd)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(data['events']), 3)
            self.assertTrue(data['stdout_stable'])
            repeat = subprocess.run(
                [sys.executable, str(TOOL), '--output', str(root / 'stable.json'),
                 '--', *cmd], capture_output=True)
            self.assertNotEqual(repeat.returncode, 0)

    def test_variable_output_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            result, data = self.run_benchmark(
                Path(temp), 'variable.json', ['/bin/date', '+%s%N'])
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertFalse(data['stdout_stable'])

    def test_failed_execution_is_not_repeated(self):
        with tempfile.TemporaryDirectory() as temp:
            result, data = self.run_benchmark(
                Path(temp), 'failure.json', ['/bin/false'])
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(len(data['events']), 1)
            self.assertNotEqual(data['events'][0]['exit_code'], 0)


if __name__ == '__main__':
    unittest.main()
