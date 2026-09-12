import copy
import json
import unittest
from pathlib import Path

from tools.vq import fvq12_fkt05_fsi05_gate as gate

ROOT = Path(__file__).resolve().parents[2]


class Fvq12AdmissionTests(unittest.TestCase):
    def status(self):
        return json.loads((ROOT / "integration/f-vq/F-VQ12_STATUS.json").read_text(encoding="utf-8"))

    def matrix(self):
        return json.loads((ROOT / "integration/f-vq/F-VQ12_ADMISSION_MATRIX.json").read_text(encoding="utf-8"))

    def test_current_gate_passes(self):
        result = gate.validate_all()
        self.assertEqual(result["status"], "PASS", result.get("failed"))
        self.assertFalse(result["composed_runtime_qualified"])
        self.assertFalse(result["full_reference_solver_reentrancy_qualified"])
        self.assertFalse(result["full_unrounded_swap_mass_identity_qualified"])

    def test_composed_runtime_cannot_be_promoted(self):
        status = self.status()
        status["fkt05_fsi05_composed_runtime_qualified"] = True
        self.assertFalse(gate.validate_status(status)["composition_false"])

    def test_full_reentrancy_cannot_be_promoted(self):
        status = self.status()
        status["full_reference_solver_reentrancy_qualified"] = True
        self.assertFalse(gate.validate_status(status)["reentrancy_false"])

    def test_full_mass_cannot_be_promoted(self):
        status = self.status()
        status["full_unrounded_swap_mass_identity_qualified"] = True
        self.assertFalse(gate.validate_status(status)["mass_false"])

    def test_reference_and_multiswap_remain_blocked(self):
        status = self.status()
        status["production_reference_admission"] = "ADMITTED"
        status["production_multiswap_admission"] = True
        checks = gate.validate_status(status)
        self.assertFalse(checks["reference_blocked"])
        self.assertFalse(checks["multiswap_false"])

    def test_blocked_claim_cannot_be_promoted(self):
        matrix = self.matrix()
        status = self.status()
        mutated = copy.deepcopy(matrix)
        for claim in mutated["claims"]:
            if claim["claim_id"] == "FVQ12-C06":
                claim["claim_qualified"] = True
        self.assertFalse(gate.validate_matrix(mutated, status)["blocked_flags_false"])

    def test_pretest_positive_claim_cannot_self_promote(self):
        matrix = self.matrix()
        status = self.status()
        status["qualified"] = False
        mutated = copy.deepcopy(matrix)
        for claim in mutated["claims"]:
            if claim["claim_id"] == "FVQ12-C02":
                claim["claim_qualified"] = True
        self.assertFalse(gate.validate_matrix(mutated, status)["qualifiable_flags_follow_status"])

    def test_optional_paths_remain_incomplete(self):
        status = self.status()
        status["optional_workspace_paths_complete"] = True
        self.assertFalse(gate.validate_status(status)["optional_false"])


if __name__ == "__main__":
    unittest.main()
