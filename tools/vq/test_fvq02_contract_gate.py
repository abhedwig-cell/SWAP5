from __future__ import annotations

import unittest

from tools.vq import fvq02_contract_gate as gate


class Fvq02ContractGateTests(unittest.TestCase):
    def test_live_assessment_passes_without_physics_upgrade(self):
        result = gate.assess()
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["canonical_reference_admission"], "BLOCKED_FAIL_CLOSED")
        self.assertFalse(result["production_physics_qualified"])
        self.assertFalse(result["production_source_changed"])

    def test_historical_assets_are_exact(self):
        checks = gate.check_provenance()
        self.assertTrue(checks["asset_set_exact"])
        self.assertTrue(checks["live_blobs_exact"])
        self.assertTrue(checks["stale_candidate_excluded"])

    def test_historical_harness_remains_verifier_only(self):
        checks = gate.check_harness()
        self.assertTrue(checks["live_harness_pass"])
        self.assertTrue(checks["live_physics_not_evaluated"])
        self.assertTrue(checks["live_production_physics_false"])
        self.assertTrue(checks["eleven_cases_pass"])

    def test_fci12_scope_remains_narrow(self):
        checks = gate.check_fci12()
        self.assertTrue(checks["generic_binding_admitted"])
        self.assertTrue(checks["reference_interval_blocked"])
        self.assertTrue(checks["end_to_end_blocked"])
        self.assertTrue(checks["evidence_scope_testdouble_explicit"])

    def test_reference_readiness_is_fail_closed(self):
        checks = gate.check_readiness()
        self.assertTrue(all(checks.values()))

    def test_matrix_blocks_production_claims(self):
        data = gate._json(gate.MATRIX)
        checks = gate.validate_matrix(data)
        self.assertTrue(checks["blocked_never_qualified"])
        self.assertTrue(checks["testdouble_never_physics_qualified"])
        self.assertTrue(checks["fci12_binding_scope_narrow"])
        self.assertTrue(checks["reference_execution_blocked"])

    def test_branch_changes_qualification_paths_only(self):
        checks = gate.check_no_production_changes()
        self.assertTrue(checks["diff_readable"])
        self.assertTrue(checks["qualification_paths_only"])
        self.assertFalse(checks["production_source_changed"])


if __name__ == "__main__":
    unittest.main()
