import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
ADMISSION = ROOT / "tests" / "multiswap" / "fmq19_fsi05_production_workspace_admission.json"
STATUS = ROOT / "tests" / "multiswap" / "fmq19_status.json"


class Fmq19AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.adm = json.loads(ADMISSION.read_text())
        cls.status = json.loads(STATUS.read_text())

    def test_exact_fsi05_lineage(self):
        src = self.adm["source"]
        self.assertEqual(src["qualification_head"], "0227ae94edc3364b013f831f1efa6aaccac29b11")
        self.assertEqual(src["production_materialization"], "1fe1bf4790955594290ba1233d5684542799bf9e")
        self.assertEqual(src["tested_postimage"], "56c21448a2a0be716d497ac34db8c5eec60dd246")
        self.assertEqual(src["documented_postimage"], "11b3138e05b1a5c59033134e870f6ffb58e6a9f6")
        self.assertEqual(src["status"], "QUALIFIED_PRODUCTION_WORKSPACE_SEAM_FOCUSED_ROUTES_ONLY")

    def test_production_workspace_seam_is_admitted(self):
        p = self.adm["admitted_production_source_primitives"]
        required_true = [
            "production_headcalc_workspace_seam_committed",
            "explicit_worker_or_job_owned_workspace",
            "adapter_passes_existing_richards_workspace",
            "legacy_one_argument_headcalc_call_preserved",
            "main_newton_jacobian_scratch_worker_owned",
            "band_solver_scratch_worker_owned",
            "workspace_poison_reset_main_and_band",
            "common_workspace_1_2_4_8_thread_isolation",
        ]
        for key in required_true:
            self.assertTrue(p[key], key)
        self.assertFalse(p["persistent_column_state_contains_solver_scratch"])

    def test_matrix_coverage_is_not_promoted(self):
        cov = self.adm["coverage"]
        self.assertEqual(cov["matrix_total"], 35)
        self.assertEqual(cov["synthetic_executable"], 27)
        self.assertEqual(cov["real_physics_executable"], 0)
        self.assertEqual(cov["production_runtime_qualified"], 0)
        self.assertEqual(cov["matrix_promotions"], [])
        self.assertEqual(cov["production_source_prerequisite_rows"], ["P06", "P19"])

    def test_real_headcalc_parallel_rows_remain_fail_closed(self):
        eff = self.adm["matrix_row_effect"]
        self.assertIn("NOT_PROMOTED", eff["P03"])
        self.assertIn("NOT_PROMOTED", eff["P18"])
        self.assertIn("NO_FULL_REAL_ROW_PROMOTION", eff["P06"])
        self.assertIn("REAL_HEADCALC_MULTIWORKER_NOT_MET", eff["P19"])

    def test_full_interval_and_mass_rows_remain_fail_closed(self):
        eff = self.adm["matrix_row_effect"]
        self.assertIn("NO_FULL_REAL_SWAP_INTERVAL", eff["P11"])
        self.assertIn("NO_FULL_UNROUNDED_SWAP_WATER_BALANCE", eff["P16"])
        hard = self.adm["hard_nonclaims"]
        self.assertFalse(hard["full_real_swap_interval_executed"])
        self.assertFalse(hard["full_swap_water_balance_identity_qualified"])

    def test_hard_nonclaims_all_false(self):
        for key, value in self.adm["hard_nonclaims"].items():
            self.assertFalse(value, key)

    def test_fvq11_is_context_not_evidence(self):
        ctx = self.adm["non_consumed_context"]
        self.assertEqual(ctx["fvq11_head_observed"], "7584f0c38d407913304eea05fd343f2f7fef31cc")
        self.assertFalse(ctx["fvq11_qualified"])

    def test_status_is_checkpoint_or_final(self):
        self.assertTrue(self.status["persisted"])
        if self.status["qualified"]:
            self.assertTrue(self.status["tested"])
            self.assertEqual(
                self.status["status"],
                "QUALIFIED_FSI05_PRODUCTION_WORKSPACE_SEAM_ADMITTED_NO_MATRIX_ROW_PROMOTION",
            )
        else:
            self.assertFalse(self.status["tested"])
            self.assertEqual(
                self.status["status"],
                "PERSISTED_FSI05_PRODUCTION_WORKSPACE_ADMISSION_CANDIDATE",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
