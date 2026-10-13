#!/usr/bin/env python3
"""Structural guard for one hydraulic-provenance preservation route.

Static proof only: does not replace scientific O0/O2 or full F-CI execution.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
FILE = ROOT / 'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'


class HydraulicProvenanceRouting(unittest.TestCase):
    def test_single_owner_and_cross_preservation_route(self):
        text = FILE.read_text()
        self.assertEqual(text.count('local crop_hydraulic_provenance_changed=0'), 1)
        self.assertEqual(text.count(
            'src/runtime/mod_fmr_crop_accepted_hydraulic_provenance.f90 ) crop_hydraulic_provenance_changed=1 ;;'), 1)
        guard = '  if (( crop_hydraulic_provenance_changed )); then'
        self.assertEqual(text.count(guard), 1)
        start = text.index(guard)
        end = text.index('\n  fi', start)
        block = text[start:end]
        self.assertEqual(block.count('bash tests/fmig431/run_crop_accepted_hydraulic_provenance.sh'), 1)
        self.assertEqual(block.count('bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh'), 1)
        self.assertIn('fail ', block)


if __name__ == '__main__':
    unittest.main()
