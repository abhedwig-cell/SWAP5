import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
ADMISSION = ROOT / "tests/multiswap/fmq17_fsi03_admission.json"
STATUS = ROOT / "tests/multiswap/fmq17_status.json"


class Fmq17AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.adm = json.loads(ADMISSION.read_text())
        cls.status = json.loads(STATUS.read_text())

    def test_exact_fsi03_lineage(self):
        src = self.adm["source"]
        self.assertEqual(src["qualification_head"], "c14ad3e032dd0285825051d8cf0e7d11ade01cd6")
        self.assertEqual(src["tested_postimage"], "79e3e9052a4f68306b8c826b063497247fd339d6")
        self.assertEqual(src["qualification_blob"], "c51e97a347127acaaf7d5e9db86f15a6200d500d")
        self.assertEqual(src["adapter_blob"], "84366a4b312a86806cc3aa78a7257c3a7a95d2f1")
        self.assertEqual(src["test_blob"], "fbeefb6c84624d87a7c77ef59f7558b92a81e4e2")
        self.assertEqual(src["gate_blob"], "cd2b9faf33f819c775d3047236f4e5a087c6c404")
        self.assertEqual(src["workflow_conclusion"], "success")

    def test_admitted_scope_is_contract_only(self):
        scope = self.adm["admitted_fsi03_scope"]
        self.assertTrue(all(scope.values()))
        self.assertEqual(self.adm["mq_row_prerequisite_effect"]["P05_clone"],
                         "SOURCE_BOUND_ADAPTER_PREREQUISITE_ADMITTED_TESTDOUBLE_ONLY")
        self.assertEqual(self.adm["mq_row_prerequisite_effect"]["P08_retry_isolation"],
                         "SOURCE_BOUND_ADAPTER_PREREQUISITE_ADMITTED_TESTDOUBLE_ONLY")
        self.assertEqual(self.adm["mq_row_prerequisite_effect"]["P19_scratch_poison"],
                         "SOURCE_BOUND_ADAPTER_PREREQUISITE_ADMITTED_TESTDOUBLE_ONLY")

    def test_real_and_parallel_claims_remain_closed(self):
        nonclaims = self.adm["hard_nonclaims"]
        self.assertTrue(all(value is False for value in nonclaims.values()))
        effects = self.adm["mq_row_prerequisite_effect"]
        self.assertTrue(effects["P03_worker_count"].startswith("NOT_PROMOTED"))
        self.assertTrue(effects["P18_worker_interleave"].startswith("NOT_PROMOTED"))
        self.assertTrue(effects["P16_per_column_mass"].startswith("NOT_PROMOTED"))

    def test_matrix_coverage_not_promoted(self):
        coverage = self.adm["coverage"]
        self.assertEqual(coverage["matrix_total"], 35)
        self.assertEqual(coverage["synthetic_executable"], 27)
        self.assertEqual(coverage["real_physics_executable"], 0)
        self.assertEqual(coverage["production_runtime_qualified"], 0)
        self.assertEqual(coverage["matrix_promotions"], [])

    def test_fvq09_is_not_used_as_real_physics_evidence(self):
        guard = self.adm["fvq09_guard"]
        self.assertTrue(guard["qualified"])
        self.assertEqual(guard["decision"], "QUALIFIED_REAL_TEMPORAL_HARNESS_CONTRACT_ONLY")
        self.assertFalse(guard["real_b1_10_temporal_characterization_qualified"])
        self.assertEqual(guard["canonical_reference_admission"], "BLOCKED_FAIL_CLOSED")

    def test_status_is_consistent_pre_or_post_qualification(self):
        self.assertTrue(self.status["persisted"])
        if self.status["qualified"]:
            self.assertTrue(self.status["tested"])
            self.assertEqual(
                self.status["status"],
                "QUALIFIED_FSI03_SOURCE_BOUND_ADAPTER_ADMITTED_NO_REAL_PHYSICS_PROMOTION",
            )
            q = self.status["qualification"]
            self.assertEqual(q["conclusion"], "success")
            self.assertEqual(q["python_admission_tests"], "PASS_6_OF_6")
            self.assertEqual(q["external_scope_verifier"], "PASS")
            self.assertEqual(q["exact_fsi03_tested_postimage_gate"], "PASS")
        else:
            self.assertFalse(self.status["tested"])
            self.assertEqual(
                self.status["status"],
                "PERSISTED_FSI03_SOURCE_BOUND_ADMISSION_CANDIDATE",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
