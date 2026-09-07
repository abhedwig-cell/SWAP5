import copy
import json
import unittest
from pathlib import Path

from tools.vq import fvq11_downstream_source_bound_gate as gate

ROOT = Path(__file__).resolve().parents[2]


class Fvq11DownstreamSourceBoundGateTests(unittest.TestCase):
    def load_status(self):
        return json.loads((ROOT / "integration/f-vq/F-VQ11_STATUS.json").read_text(encoding="utf-8"))

    def load_matrix(self):
        return json.loads((ROOT / "integration/f-vq/F-VQ11_ADMISSION_MATRIX.json").read_text(encoding="utf-8"))

    def test_current_pretest_gate_passes(self):
        result = gate.validate_all()
        self.assertEqual(result["status"], "PASS", result.get("failed"))
        self.assertFalse(result["fkt05_admitted"])
        self.assertFalse(result["composed_runtime_qualified"])

    def test_fkt05_cannot_be_promoted(self):
        status = self.load_status()
        status["fkt05_admitted"] = True
        self.assertFalse(gate.validate_status(status)["fkt05_false"])

    def test_composed_runtime_cannot_be_promoted(self):
        status = self.load_status()
        status["fkt04_fsi04_composed_runtime_qualified"] = True
        self.assertFalse(gate.validate_status(status)["composition_false"])

    def test_production_headcalc_seam_cannot_be_promoted(self):
        status = self.load_status()
        status["production_workspace_headcalc_seam_qualified"] = True
        self.assertFalse(gate.validate_status(status)["production_seam_false"])

    def test_full_mass_claim_cannot_be_promoted(self):
        status = self.load_status()
        status["full_unrounded_swap_mass_identity_qualified_by_fsi04"] = True
        self.assertFalse(gate.validate_status(status)["full_mass_false"])

    def test_blocked_matrix_claim_cannot_be_promoted(self):
        status = self.load_status()
        matrix = self.load_matrix()
        mutated = copy.deepcopy(matrix)
        for claim in mutated["claims"]:
            if claim["claim_id"] == "FVQ11-C09":
                claim["claim_qualified"] = True
        self.assertFalse(gate.validate_matrix(mutated, status)["blocked_flags_false"])

    def test_pretest_qualifiable_claim_cannot_self_promote(self):
        status = self.load_status()
        matrix = self.load_matrix()
        mutated = copy.deepcopy(matrix)
        for claim in mutated["claims"]:
            if claim["claim_id"] == "FVQ11-C01":
                claim["claim_qualified"] = True
        self.assertFalse(gate.validate_matrix(mutated, status)["qualifiable_flags_follow_status"])

    def test_reference_and_multiswap_remain_blocked(self):
        status = self.load_status()
        status["production_reference_admission"] = "ADMITTED"
        status["production_multiswap_admission"] = True
        checks = gate.validate_status(status)
        self.assertFalse(checks["reference_blocked"])
        self.assertFalse(checks["multiswap_false"])


if __name__ == "__main__":
    unittest.main()
