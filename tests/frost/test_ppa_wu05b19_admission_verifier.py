#!/usr/bin/env python3
"""Falsify the source-bound evidence verifier without editing protected files."""
import copy
import gzip
import json
import unittest
import verify_ppa_wu05b19_admission as gate


class AdmissionVerifierTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = json.loads(gzip.decompress((gate.ROOT /
            'docs/audits/evidence/PPA_WU05B19_LOCAL_REPLAY.json.gz').read_bytes()))

    def test_complete(self):
        self.assertTrue(gate.validate_record(self.record)['passed'])

    def reject(self, mutate):
        record = copy.deepcopy(self.record)
        mutate(record)
        with self.assertRaises((ValueError, KeyError)):
            gate.validate_record(record)

    def test_missing_gate(self):
        self.reject(lambda r: r['gates'].pop('component'))

    def test_failed_gate(self):
        self.reject(lambda r: r['gates']['component'].update(passed=False))

    def test_source_drift(self):
        self.reject(lambda r: r.update(production_source_tree='0' * 40))

    def test_dependency_drift(self):
        self.reject(lambda r: r['source_sha256'].update({
            'src/process/mod_frost_divdra_drainage_effect.f90': '0' * 64}))

    def test_moving_guard_original_identity(self):
        self.reject(lambda r: r['source_sha256'].update({
            'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh': '0' * 64}))

    def test_missing_preservation(self):
        self.reject(lambda r: r['receipts'].pop(next(k for k in r['receipts']
                                                   if '/preservation/' in k)))

    def test_corrupt_stdout(self):
        self.reject(lambda r: r['logs'].update({next(k for k in r['logs']
            if '/o0/case-1-fine-8192.log' in k): 'B19_CASE_1_RUNTIME=PASS\n'}))

    def test_incomplete_runtime_matrix(self):
        self.reject(lambda r: r['gates']['signed_runtime']['trajectories'].pop())

    def test_component_matrix(self):
        self.reject(lambda r: r['gates']['component']['receipt'].update(cases=4535))


if __name__ == '__main__':
    unittest.main()
