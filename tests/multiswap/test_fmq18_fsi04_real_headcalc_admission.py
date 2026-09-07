import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
ADMISSION = ROOT / "tests/multiswap/fmq18_fsi04_real_headcalc_admission.json"
STATUS = ROOT / "tests/multiswap/fmq18_status.json"


class Fmq18AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.adm = json.loads(ADMISSION.read_text())
        cls.status = json.loads(STATUS.read_text())

    def test_exact_fsi04_lineage(self):
        src = self.adm["source"]
        self.assertEqual(src["qualification_head"], "c76f794b93522bea3a80a6880bc95ef5671cb914")
        self.assertEqual(src["tested_postimage"], "0cfbefc271447b4b53eeee50c1dfbb2acaf020df")
        self.assertEqual(src["qualification_blob"], "fdfc028191a347fc2bdcec2d136788c4f9a84177")
        self.assertEqual(src["gate_blob"], "b8bbe5d6c2eb86bda995d77ec44e813ffbe84d85")
        self.assertEqual(src["canonical_headcalc_blob"], "225b9f2cc1ecff01414b5691799103b92bc068c5")
        self.assertEqual(src["workflow_run"], 34122972659)
        self.assertEqual(src["workflow_conclusion"], "success")

    def test_real_headcalc_primitives_are_admitted(self):
        self.assertTrue(all(self.adm["admitted_real_headcalc_primitives"].values()))
        fixture = self.adm["focused_fixture"]
        self.assertEqual(fixture["active_nodes"], 4)
        self.assertEqual(fixture["expected_nonlinear_iterations"], 1)
        self.assertEqual(fixture["expected_jacobian_builds"], 1)
        self.assertEqual(fixture["expected_linear_solves"], 1)

    def test_matrix_rows_remain_fail_closed(self):
        effects = self.adm["matrix_row_effect"]
        self.assertIn("NO_ROW_PROMOTION", effects["P06"])
        self.assertIn("NO_REAL_SWAP_INTERVAL", effects["P11"])
        self.assertIn("NOT_FULL_SWAP_WATER_BALANCE", effects["P16"])
        self.assertIn("MIN_2_COLUMNS_2_WORKERS_NOT_MET", effects["P19"])
        self.assertTrue(effects["P03"].startswith("NOT_PROMOTED"))
        self.assertTrue(effects["P18"].startswith("NOT_PROMOTED"))

    def test_main_coverage_not_promoted(self):
        coverage = self.adm["coverage"]
        self.assertEqual(coverage["matrix_total"], 35)
        self.assertEqual(coverage["synthetic_executable"], 27)
        self.assertEqual(coverage["real_physics_executable"], 0)
        self.assertEqual(coverage["production_runtime_qualified"], 0)
        self.assertEqual(coverage["matrix_promotions"], [])
        self.assertEqual(coverage["focused_real_headcalc_prerequisite_rows"], ["P06", "P11", "P16", "P19"])

    def test_hard_nonclaims_all_false(self):
        self.assertTrue(all(value is False for value in self.adm["hard_nonclaims"].values()))

    def test_status_is_valid_checkpoint_or_final(self):
        self.assertTrue(self.status["persisted"])
        if self.status["qualified"]:
            self.assertTrue(self.status["tested"])
            self.assertEqual(
                self.status["status"],
                "QUALIFIED_FSI04_REAL_HEADCALC_FOCUSED_ADMITTED_NO_MATRIX_ROW_PROMOTION",
            )
        else:
            self.assertFalse(self.status["tested"])
            self.assertEqual(
                self.status["status"],
                "PERSISTED_FSI04_REAL_HEADCALC_FOCUSED_ADMISSION_CANDIDATE",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
