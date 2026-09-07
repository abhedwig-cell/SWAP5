from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from tools.vq import fvq06_fci18_handoff_gate as gate

ROOT = Path(__file__).resolve().parents[2]


def load(rel: str) -> dict:
    return json.loads((ROOT / rel).read_text(encoding="utf-8"))


class Fvq06Fci18HandoffGateTests(unittest.TestCase):
    def test_current_readiness_splits_scope_from_final_exit(self):
        checks = gate.validate_readiness(load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json"))
        self.assertTrue(all(checks.values()), checks)

    def test_promoting_final_exit_without_gate_commit_is_rejected(self):
        readiness = copy.deepcopy(load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json"))
        readiness["fci18_final_exit_handoff_qualified"] = True
        checks = gate.validate_readiness(readiness)
        self.assertFalse(checks["final_exit_blocked"])

    def test_promoting_downstream_release_is_rejected(self):
        readiness = copy.deepcopy(load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json"))
        readiness["downstream_release_admitted_by_fvq06"] = True
        checks = gate.validate_readiness(readiness)
        self.assertFalse(checks["no_fvq_release"])

    def test_blocked_final_promotion_claim_cannot_be_promoted(self):
        matrix = copy.deepcopy(load("integration/f-vq/F-VQ06_ADMISSION_MATRIX.json"))
        for claim in matrix["claims"]:
            if claim["claim_id"] == "FVQ06-C06":
                claim["claim_qualified"] = True
        checks = gate.validate_matrix(matrix)
        self.assertFalse(checks["final_promotion_not_claimed"])

    def test_source_bound_fci18_delta_contains_no_production_or_reference_source(self):
        paths = gate.changed(gate.FCI17_BASIS, gate.FCI18_SOURCE)
        self.assertFalse(any(p.startswith("src/") for p in paths), paths)
        self.assertFalse(any(p.startswith("reference/swap-4.3.1/") for p in paths), paths)

    def test_pr_merge_failure_is_non_authoritative_and_push_is_qualified(self):
        readiness = load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json")
        self.assertEqual(readiness["qualification_handoff"]["workflow_result"], "SUCCESS")
        failures = readiness["superseded_or_non_authoritative_failure_observations"]
        self.assertTrue(all(item["authoritative_for_fci18_qualification"] is False for item in failures))
        self.assertFalse(readiness["fci18_final_exit_handoff_qualified"])

    def test_fvq05_reference_and_temporal_blocks_are_preserved(self):
        evidence = load("integration/f-vq/evidence/F-VQ05_QUALIFICATION.json")
        self.assertFalse(evidence["production_temporal_profile_qualified"])
        self.assertFalse(evidence["real_b1_10_temporal_acceptance_qualified"])
        self.assertEqual(evidence["canonical_reference_admission"], "BLOCKED_FAIL_CLOSED")

    def test_matrix_keeps_scope_capability_and_release_boundaries(self):
        checks = gate.validate_matrix(load("integration/f-vq/F-VQ06_ADMISSION_MATRIX.json"))
        self.assertTrue(all(checks.values()), checks)


if __name__ == "__main__":
    unittest.main()
