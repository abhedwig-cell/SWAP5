import copy
import unittest
from tools.vq import fvq07_final_fci_exit_gate as gate

class FVQ07GateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.readiness = gate.load_json("integration/f-vq/F-VQ07_EXIT_HANDOFF_READINESS.json")
        cls.matrix = gate.load_json("integration/f-vq/F-VQ07_ADMISSION_MATRIX.json")
        cls.exit = gate.load_json("integration/f-ci/F-CI_EXIT_GATES.json")

    def test_readiness_accepts_exact_basis(self):
        self.assertTrue(all(gate.validate_readiness(copy.deepcopy(self.readiness)).values()))

    def test_readiness_rejects_wrong_closeout_run(self):
        x = copy.deepcopy(self.readiness); x["basis"]["fci18_closeout_push_run"] += 1
        self.assertFalse(gate.validate_readiness(x)["closeout_exact"])

    def test_exit_snapshot_requires_ten_qualified_gates(self):
        self.assertTrue(all(gate.validate_exit_snapshot(copy.deepcopy(self.exit)).values()))

    def test_exit_snapshot_rejects_unqualified_gate(self):
        x = copy.deepcopy(self.exit); x["gates"]["CI-G05"]["status"] = "TESTED"
        self.assertFalse(gate.validate_exit_snapshot(x)["all_qualified"])

    def test_pretest_matrix_matches_unqualified_status(self):
        self.assertTrue(all(gate.validate_matrix(copy.deepcopy(self.matrix), False).values()))

    def test_matrix_rejects_reference_promotion(self):
        x = copy.deepcopy(self.matrix); x["claims"][5]["claim_qualified"] = True
        self.assertFalse(gate.validate_matrix(x, False)["blocked_claims_false"])

    def test_matrix_rejects_temporal_promotion(self):
        x = copy.deepcopy(self.matrix); x["claims"][6]["claim_qualified"] = True
        self.assertFalse(gate.validate_matrix(x, False)["blocked_claims_false"])

    def test_matrix_requires_target_flags_to_follow_status(self):
        x = copy.deepcopy(self.matrix); x["claims"][0]["claim_qualified"] = True
        self.assertFalse(gate.validate_matrix(x, False)["target_flags_match_status"])

if __name__ == "__main__": unittest.main()
