import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parent
OVERLAY = ROOT / "fmq16_fsi03_failclosed_admission.json"
STATUS = ROOT / "fmq16_status.json"


class Fmq16AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.overlay = json.loads(OVERLAY.read_text())
        cls.status = json.loads(STATUS.read_text())

    def test_exact_lineage_is_pinned(self):
        lineage = self.overlay["lineage"]
        self.assertEqual(lineage["fmq15_head"], "b687bb434c35112ef8e9721452ff7dacb4b66b43")
        self.assertEqual(lineage["fsi02_qualified_head"], "da1d5da0d909c5ce55efa17507b805bffd6b82f9")
        self.assertEqual(lineage["fsi03_unqualified_head"], "5bb86d267b8f80ce40e33e78b4d29a35ea3d83d3")
        self.assertEqual(lineage["fsi03_failed_workflow_run"], 34120806552)

    def test_fsi03_is_fail_closed(self):
        admission = self.overlay["fsi03_admission"]
        self.assertFalse(admission["allowed"])
        self.assertEqual(admission["workflow_conclusion"], "failure")
        self.assertFalse(admission["formal_qualification_postimage_present"])
        self.assertIn("compare-reals", admission["failure_signature"])

    def test_no_matrix_coverage_promotion(self):
        effect = self.overlay["coverage_effect"]
        self.assertEqual(effect["synthetic_executable_before"], 27)
        self.assertEqual(effect["synthetic_executable_after"], 27)
        self.assertEqual(effect["real_physics_executable_before"], 0)
        self.assertEqual(effect["real_physics_executable_after"], 0)
        self.assertEqual(effect["production_runtime_qualified_before"], 0)
        self.assertEqual(effect["production_runtime_qualified_after"], 0)
        self.assertEqual(effect["promotions"], [])

    def test_physical_mass_and_parallel_claims_remain_blocked(self):
        cap = self.overlay["fsi03_observed_capability"]
        self.assertFalse(cap["unrounded_mass_balance_residual_available"])
        self.assertFalse(cap["parallel_multiswap_backend_qualified"])
        self.assertFalse(cap["macropore_supported"])
        self.assertFalse(cap["implicit_conductivity_mode_supported"])

    def test_protected_rows_cannot_be_promoted(self):
        rows = {item["id"]: item for item in self.overlay["protected_rows"]}
        for row_id in ("P03", "P10", "P11", "P16", "P18", "S01"):
            self.assertEqual(rows[row_id]["decision"], "NO_PROMOTION")
        self.assertEqual(rows["P19"]["decision"], "COMMON_LAYER_ONLY")

    def test_status_is_persisted_not_qualified_before_gate(self):
        self.assertTrue(self.status["persisted"])
        self.assertFalse(self.status["production_source_changed"])
        self.assertIn(self.status["status"], {
            "PERSISTED_FSI03_FAIL_CLOSED_ADMISSION_BARRIER",
            "QUALIFIED_FSI03_FAIL_CLOSED_BARRIER_NO_COVERAGE_PROMOTION",
        })


if __name__ == "__main__":
    unittest.main()
