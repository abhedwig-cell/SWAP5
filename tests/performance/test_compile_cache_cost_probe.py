#!/usr/bin/env python3
"""Guard that diagnostic cache remains behaviorally based on canonical V1.

This structural check is not a substitute for actual compiler negative controls.
"""
import ast
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'tools/fci/compile_cache_trial.py'
PROBE = ROOT / 'tools/performance/compile_cache_cost_probe.py'

class CacheProbe(unittest.TestCase):
    def test_cache_key_and_validation_paths_unchanged(self):
        baseline = BASE.read_text()
        candidate = PROBE.read_text()
        for critical in [
            "inputs = {'version': 1, 'tool': file_hash(__file__)",
            "'source': file_hash(source)",
            "'toolchain': chain",
            "'environment': digest(",
            "assert manifest['inputs'] == inputs",
            "assert file_hash(entry / name) == sha",
            "if file_hash(source) != inputs['source'] or toolchain(profile) != chain:",
            "if result.returncode != 0:",
        ]:
            self.assertIn(critical, baseline)
            self.assertIn(critical, candidate)
        for expected in ["'toolchain_seconds': toolchain_seconds",
                         "'prelookup_seconds': key_preparation_seconds",
                         "'lookup_seconds': lookup_seconds"]:
            self.assertIn(expected, candidate)
        ast.parse(candidate, filename=str(PROBE))
        ast.parse(baseline, filename=str(BASE))

    def test_instrumentation_is_not_default(self):
        runner = (ROOT / 'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh').read_text()
        self.assertNotIn('compile_cache_cost_probe.py', runner)
        self.assertNotIn('SWAP5_CACHE_PROFILE', runner)

if __name__ == '__main__':
    unittest.main()
