"""The new inheritance route must fail closed on either side of the delta."""
import json
import unittest
from pathlib import Path
from unittest.mock import patch
import check_swap431_coverage as gate


class InheritanceTests(unittest.TestCase):
    def setUp(self):
        self.name = 'SWAP431_IMPLEMENTATION_REACHABILITY_REVIEW.json'
        self.record = json.loads((gate.AUDIT / 'evidence' / self.name).read_text())
        self.head = '78acf56f931763d2e1d4924b3dea0742f231d2e8'

    def check(self):
        gate.validate_inherited_review(self.name, self.record, self.head)

    def test_reviewed_delta(self):
        self.check()

    def test_unknown_baseline(self):
        self.head = '0' * 40
        with self.assertRaises(AssertionError):
            self.check()

    def corrupt(self, target):
        original = Path.read_bytes
        def changed(path):
            raw = original(path)
            return raw + b'\n' if path == target else raw
        with patch.object(Path, 'read_bytes', changed):
            with self.assertRaises(AssertionError):
                self.check()

    def test_historical_record_mutation(self):
        self.corrupt(gate.AUDIT / 'evidence' / self.name)

    def test_changed_dependency_mutation(self):
        self.corrupt(gate.ROOT / 'src/runtime/mod_fmr_serialized_reference_backend.f90')

    def test_unchanged_dependency_mutation(self):
        self.corrupt(gate.ROOT / 'src/solver/mod_b110_default_mvg_provider.f90')


if __name__ == '__main__':
    unittest.main()
