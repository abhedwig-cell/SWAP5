"""The new inheritance route must fail closed on either side of the delta."""
import json
import copy
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

    def test_later_ledger_is_not_a_new_science_baseline(self):
        ledger = json.loads((gate.AUDIT / 'SWAP431_FUNCTIONAL_COVERAGE_MASTER.json').read_text())
        self.assertNotEqual(ledger['canonical_head'], gate.HISTORICAL_BASE)
        self.assertEqual(gate.historical_baseline(ledger), gate.HISTORICAL_BASE)
        self.head = ledger['canonical_head']
        self.check()

    def test_unknown_historical_baseline(self):
        with self.assertRaises(AssertionError):
            gate.historical_baseline({'canonical_head': self.head,
                                     'historical_evidence_baseline': '0' * 40})

    def test_foreign_projection_preimage(self):
        with self.assertRaises(AssertionError):
            gate.validate_source_dependency(gate.BACKEND, '0' * 64)

    def test_projection_default_cannot_be_enabled(self):
        original = Path.read_bytes
        def changed(path):
            raw = original(path)
            return raw.replace(b'profile_groundwater_projection = .false.',
                               b'profile_groundwater_projection = .true.') if path == gate.ROOT / gate.BACKEND else raw
        expected = 'a1c9baa710b487709c9036a88bf9ab28be5f68b0c0541dd117c2543958de188a'
        with patch.object(Path, 'read_bytes', changed), self.assertRaises(AssertionError):
            gate.validate_source_dependency(gate.BACKEND, expected)

    def test_unrelated_changed_source_cannot_use_projection_exception(self):
        with self.assertRaises(AssertionError):
            gate.validate_source_dependency('src/solver/mod_b110_default_mvg_provider.f90', '0' * 64)

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


class AuthorityLocatorTests(unittest.TestCase):
    def setUp(self):
        self.ledger = json.loads((gate.AUDIT / 'SWAP431_FUNCTIONAL_COVERAGE_MASTER.json').read_text())

    def test_exact_later_field(self):
        gate.validate_authority_locator('integration/audits/MC_MET01_STATUS.json daily_demand_successor at d30728087f3d7d8e9e37a5e0a3507f14bb29f7c9', self.ledger)

    def test_missing_source(self):
        with self.assertRaises(AssertionError):
            gate.validate_authority_locator('src/absent-coverage-control.f90', self.ledger)

    def test_missing_field(self):
        with self.assertRaises(AssertionError):
            gate.validate_authority_locator('integration/audits/MC_MET01_STATUS.json nonexistent_field', self.ledger)

    def test_prose_is_not_file_authority(self):
        with self.assertRaises(AssertionError):
            gate.validate_authority_locator('PR #1125; everything passed', self.ledger)

    def test_traversal(self):
        with self.assertRaises(AssertionError):
            gate.validate_authority_locator('../AGENTS.md', self.ledger)

    def test_noncanonical_ref(self):
        with self.assertRaises(AssertionError):
            gate.validate_authority_locator('AGENTS.md at ' + '0' * 40, self.ledger)

    def active(self):
        return copy.deepcopy(next(e for e in self.ledger['capabilities'] if e['capability_id'] == 'SW431-ET-PMTRAD'))

    def test_bounded_positive(self):
        gate.validate_bounded_reachability(self.active(), self.ledger)

    def test_bounded_without_receipt(self):
        entry = self.active()
        entry['production_reachability']['bounded_receipt'] = 'absent'
        with self.assertRaises(AssertionError):
            gate.validate_bounded_reachability(entry, self.ledger)

    def test_fullcap_cannot_be_inferred_from_bounded(self):
        ledger = copy.deepcopy(self.ledger)
        ledger['bounded_owner_receipts']['mc_met01_daily_demand_20261012']['full_capability'] = True
        with self.assertRaises(AssertionError):
            gate.validate_bounded_reachability(self.active(), ledger)

    def test_bounded_cannot_claim_missing_implementation(self):
        entry = self.active()
        entry['implementation_absence_proven'] = True
        with self.assertRaises(AssertionError):
            gate.validate_bounded_reachability(entry, self.ledger)


if __name__ == '__main__':
    unittest.main()
