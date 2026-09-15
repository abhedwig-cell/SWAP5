from __future__ import annotations

import copy
import json
import subprocess
import unittest
from pathlib import Path

from tools.vq import fvq05_temporal_contract_gate as gate

ROOT = Path(__file__).resolve().parents[2]


def load(rel: str) -> dict:
    return json.loads((ROOT / rel).read_text(encoding="utf-8"))


class Fvq05TemporalContractGateTests(unittest.TestCase):
    def test_current_profile_is_fail_closed_and_semantically_valid(self):
        checks = gate.validate_profile(load("integration/f-ci/F-CI14_TEMPORAL_POLICY_PROFILE.json"))
        self.assertTrue(all(checks.values()), checks)

    def test_injecting_numeric_limit_without_profile_qualification_is_rejected(self):
        profile = copy.deepcopy(load("integration/f-ci/F-CI14_TEMPORAL_POLICY_PROFILE.json"))
        profile["acceptance_metrics"]["h_cm"] = 0.01
        checks = gate.validate_profile(profile)
        self.assertFalse(checks["all_numeric_limits_null"])

    def test_threshold_one_does_not_promote_physical_profile(self):
        readiness = load("integration/f-vq/F-VQ05_TEMPORAL_PROFILE_READINESS.json")
        self.assertEqual(readiness["normalized_acceptance_threshold"], 1.0)
        self.assertFalse(readiness["production_temporal_profile_qualified"])
        self.assertFalse(readiness["real_b1_10_temporal_acceptance_qualified"])

    def test_test_fixture_limits_are_not_production_evidence(self):
        readiness = load("integration/f-vq/F-VQ05_TEMPORAL_PROFILE_READINESS.json")
        self.assertFalse(readiness["test_fixture_numeric_limits_are_production_evidence"])
        text = (ROOT / "tests/fci/test_fci14_reference_temporal_policy.f90").read_text(encoding="utf-8")
        self.assertIn("limits%h_cm=0.01_real64", text)
        self.assertIn("numeric profile must remain unqualified", text)

    def test_blocked_matrix_claims_cannot_be_promoted(self):
        matrix = load("integration/f-vq/F-VQ05_ADMISSION_MATRIX.json")
        promoted = copy.deepcopy(matrix)
        for claim in promoted["claims"]:
            if claim["claim_id"] == "FVQ05-C08":
                claim["claim_qualified"] = True
        checks = gate.validate_matrix(promoted)
        self.assertFalse(checks["numeric_profile_blocked"])
        self.assertFalse(checks["FVQ05-C08_not_promoted"])

    def test_reference_execution_stays_fail_closed(self):
        readiness = load("integration/f-vq/F-VQ05_TEMPORAL_PROFILE_READINESS.json")
        self.assertEqual(readiness["canonical_reference_admission"], "BLOCKED_FAIL_CLOSED")
        candidate = (ROOT / "src/adapter/mod_b1_10_reference_policy_candidate_model.f90").read_text(encoding="utf-8")
        self.assertIn("qualified_numeric_profile = .false.", candidate)
        self.assertIn("admitted = self%qualified_numeric_profile .and. self%temporal_limits_bound", candidate)

    def test_no_production_source_change_since_current_overlay(self):
        out = subprocess.check_output(
            ["git", "diff", "--name-only", gate.OVERLAY, "HEAD"], cwd=ROOT, text=True
        )
        self.assertFalse(any(p.startswith("src/") for p in out.splitlines()), out)


if __name__ == "__main__":
    unittest.main()
