import copy
import unittest
from tools.vq import fvq08_temporal_characterization_gate as gate

class FVQ08GateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fvq05 = gate.load_json("integration/f-vq/F-VQ05_TEMPORAL_PROFILE_READINESS.json")
        cls.readiness = gate.load_json("integration/f-vq/F-VQ08_TEMPORAL_CHARACTERIZATION_READINESS.json")
        cls.matrix = gate.load_json("integration/f-vq/F-VQ08_ADMISSION_MATRIX.json")
        cls.status = gate.load_json("integration/f-vq/F-VQ08_STATUS.json")
        cls.fci10 = gate.load_json("integration/f-ci/evidence/F-CI10_LOCAL_HUPSEL_MASS_CANDIDATE.json")
        cls.fci11 = gate.load_json("integration/f-ci/evidence/F-CI11_LOCAL_GENERIC_INTERVAL_GATE.json")
        cls.runner = gate.read("tests/fci/run_fci07_full_b1_10_gate.sh")

    def test_fvq05_contract_is_exact_and_fail_closed(self):
        self.assertTrue(all(gate.validate_fvq05(copy.deepcopy(self.fvq05)).values()))

    def test_fvq05_rejects_invented_numeric_limit(self):
        x = copy.deepcopy(self.fvq05); x["current_numeric_limits"]["h_cm"] = 0.01
        self.assertFalse(gate.validate_fvq05(x)["numeric_limits_all_null"])

    def test_readiness_accepts_exact_blocked_boundary(self):
        self.assertTrue(all(gate.validate_readiness(copy.deepcopy(self.readiness)).values()))

    def test_readiness_rejects_wrong_ttutil_environment_name(self):
        x = copy.deepcopy(self.readiness); x["real_full_runner"]["required_environment"][1] = "TTUTIL_ROOT"
        self.assertFalse(gate.validate_readiness(x)["runner_env_exact"])

    def test_readiness_rejects_process_scope_promotion(self):
        x = copy.deepcopy(self.readiness); x["optional_process_scope_complete"] = True
        self.assertFalse(gate.validate_readiness(x)["process_scope_incomplete"])

    def test_source_evidence_is_real_but_temporal_metric_unqualified(self):
        self.assertTrue(all(gate.validate_source_evidence(copy.deepcopy(self.fci10), copy.deepcopy(self.fci11)).values()))

    def test_source_evidence_rejects_temporal_metric_promotion(self):
        x = copy.deepcopy(self.fci11); x["temporal_error_metric_qualified"] = True
        self.assertFalse(gate.validate_source_evidence(self.fci10, x)["fci11_temporal_metric_not_qualified"])

    def test_runner_requires_external_real_assets(self):
        self.assertTrue(all(gate.validate_runner(self.runner).values()))

    def test_matrix_matches_current_status(self):
        self.assertTrue(all(gate.validate_matrix(copy.deepcopy(self.matrix), self.status.get("qualified") is True).values()))

    def test_matrix_rejects_production_profile_promotion(self):
        x = copy.deepcopy(self.matrix); x["claims"][5]["claim_qualified"] = True
        self.assertFalse(gate.validate_matrix(x, False)["blocked_and_prohibited_false"])

    def test_matrix_rejects_mass_relaxation(self):
        x = copy.deepcopy(self.matrix); x["claims"][8]["claim_qualified"] = True
        self.assertFalse(gate.validate_matrix(x, False)["blocked_and_prohibited_false"])

if __name__ == "__main__": unittest.main()
