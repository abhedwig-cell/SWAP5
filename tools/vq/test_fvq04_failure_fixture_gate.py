import copy
import json
import tempfile
import unittest
from pathlib import Path

from tools.vq.fvq04_failure_fixture_gate import ROOT, validate_candidate


class Fvq04FailureFixtureGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.candidate = json.loads(
            (ROOT / "tools/vq/cases/fvq04-real-failure-fixture-candidate.json").read_text(encoding="utf-8")
        )

    def test_current_candidate_is_explicitly_blocked(self):
        checks = validate_candidate(copy.deepcopy(self.candidate))
        self.assertTrue(all(checks.values()), checks)
        self.assertFalse(self.candidate["real_terminal_failure_physics_qualified"])
        self.assertEqual(self.candidate["status"], "BLOCKED_MISSING_EXTERNAL_EXECUTION_INPUTS")

    def test_metadata_only_promotion_fails(self):
        c = copy.deepcopy(self.candidate)
        c["qualification_requested"] = True
        c["real_terminal_failure_physics_qualified"] = True
        c["status"] = "QUALIFIED_REAL_B1_10_TERMINAL_FAILURE"
        checks = validate_candidate(c)
        self.assertFalse(all(checks.values()))
        self.assertFalse(checks["promotion_has_complete_external_identity"])
        self.assertFalse(checks["promotion_has_complete_execution_observation"])
        self.assertFalse(checks["promotion_evidence_file_hash_matches"])

    def test_testdouble_status_cannot_be_substituted_for_real_execution(self):
        c = copy.deepcopy(self.candidate)
        c["qualification_requested"] = True
        c["real_terminal_failure_physics_qualified"] = True
        c["status"] = "QUALIFIED_REAL_B1_10_TERMINAL_FAILURE"
        c["execution"]["returned_trial_status"] = "B1_10_TRIAL_STATUS_RETRYABLE_NUMERICAL"
        c["execution"]["failed_trial_state_restored"] = True
        c["execution"]["trial_mass_valid"] = False
        c["execution"]["rejected_trial_committed"] = False
        checks = validate_candidate(c)
        self.assertFalse(checks["promotion_has_complete_execution_observation"])

    def test_solver_policy_mutation_is_never_admissible(self):
        c = copy.deepcopy(self.candidate)
        c["policy_integrity"]["solver_tolerances_modified_for_fixture"] = True
        checks = validate_candidate(c)
        self.assertFalse(checks["solver_tolerances_not_modified"])

    def test_physical_case_mutation_to_force_failure_is_never_admissible(self):
        c = copy.deepcopy(self.candidate)
        c["case"]["physical_case_modified_to_force_failure"] = True
        checks = validate_candidate(c)
        self.assertFalse(checks["case_not_modified_to_force_failure"])

    def test_execution_evidence_path_is_mandatory_for_promotion(self):
        c = copy.deepcopy(self.candidate)
        c["qualification_requested"] = True
        c["real_terminal_failure_physics_qualified"] = True
        c["status"] = "QUALIFIED_REAL_B1_10_TERMINAL_FAILURE"
        c["source"]["verified_external_source_tree_supplied"] = True
        c["ttutil"]["verified_external_root_supplied"] = True
        c["ttutil"]["provenance_manifest_sha256"] = "1" * 64
        c["case"]["verified_external_case_supplied"] = True
        c["case"]["case_manifest_sha256"] = "2" * 64
        c["execution"].update({
            "real_b1_10_physics_executed_for_terminal_failure": True,
            "terminal_minimum_dt_marker_observed": True,
            "returned_trial_status": "B1_10_TRIAL_STATUS_RETRYABLE_NUMERICAL",
            "failed_trial_state_restored": True,
            "trial_mass_valid": False,
            "rejected_trial_committed": False,
            "repeat_count": 2,
            "execution_evidence_path": "integration/f-vq/evidence/DOES_NOT_EXIST.json",
            "execution_evidence_sha256": "3" * 64,
        })
        checks = validate_candidate(c)
        self.assertTrue(checks["promotion_has_complete_external_identity"])
        self.assertTrue(checks["promotion_has_complete_execution_observation"])
        self.assertFalse(checks["promotion_evidence_file_hash_matches"])


if __name__ == "__main__":
    unittest.main()
