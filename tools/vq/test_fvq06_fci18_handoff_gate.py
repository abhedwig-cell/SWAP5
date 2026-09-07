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
    def test_current_readiness_is_fail_closed(self):
        checks = gate.validate_readiness(load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json"))
        self.assertTrue(all(checks.values()), checks)

    def test_promoting_fci18_handoff_without_green_fci_is_rejected(self):
        readiness = copy.deepcopy(load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json"))
        readiness["fci18_handoff_qualified"] = True
        checks = gate.validate_readiness(readiness)
        self.assertFalse(checks["handoff_blocked"])

    def test_promoting_downstream_release_is_rejected(self):
        readiness = copy.deepcopy(load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json"))
        readiness["downstream_release_admitted_by_fvq06"] = True
        checks = gate.validate_readiness(readiness)
        self.assertFalse(checks["no_fvq_release"])

    def test_blocked_matrix_claims_cannot_be_promoted(self):
        matrix = copy.deepcopy(load("integration/f-vq/F-VQ06_ADMISSION_MATRIX.json"))
        for claim in matrix["claims"]:
            if claim["claim_id"] == "FVQ06-C04":
                claim["claim_qualified"] = True
        checks = gate.validate_matrix(matrix)
        self.assertFalse(checks["fci18_handoff_not_promoted"])

    def test_candidate_delta_contains_no_production_or_reference_source(self):
        paths = gate.changed(gate.FCI17_BASIS, gate.FCI18_CANDIDATE)
        self.assertFalse(any(p.startswith("src/") for p in paths), paths)
        self.assertFalse(any(p.startswith("reference/swap-4.3.1/") for p in paths), paths)

    def test_pr_merge_context_fragility_is_present_and_not_reinterpreted_as_pass(self):
        gate_text = (ROOT / "tools/fci/fci18_exit_scope_ownership_gate.py").read_text(encoding="utf-8")
        workflow = (ROOT / ".github/workflows/fci-canonical.yml").read_text(encoding="utf-8")
        readiness = load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json")
        self.assertIn('"HEAD^", "HEAD"', gate_text)
        self.assertIn("pull_request:", workflow)
        self.assertFalse(readiness["fci18_handoff_qualified"])

    def test_fvq05_reference_and_temporal_blocks_are_preserved(self):
        evidence = load("integration/f-vq/evidence/F-VQ05_QUALIFICATION.json")
        self.assertFalse(evidence["production_temporal_profile_qualified"])
        self.assertFalse(evidence["real_b1_10_temporal_acceptance_qualified"])
        self.assertEqual(evidence["canonical_reference_admission"], "BLOCKED_FAIL_CLOSED")


if __name__ == "__main__":
    unittest.main()
