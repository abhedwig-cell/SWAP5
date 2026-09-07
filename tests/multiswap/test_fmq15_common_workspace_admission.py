import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parent
ADMISSION = ROOT / "fmq15_common_workspace_isolation.json"
STATUS = ROOT / "fmq15_status.json"


class Fmq15AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.admission = json.loads(ADMISSION.read_text())
        cls.status = json.loads(STATUS.read_text())

    def test_exact_lineage(self):
        self.assertEqual(
            self.admission["lineage"]["fmq14_head"],
            "eebf665d0123feb1e0c6fd694b58ec6635cd7cc2",
        )
        self.assertEqual(
            self.admission["lineage"]["fsi02_qualified_head"],
            "da1d5da0d909c5ce55efa17507b805bffd6b82f9",
        )
        self.assertEqual(self.admission["requirements_baseline"]["row_count"], 35)

    def test_multiswap_gate_shape(self):
        gate = self.admission["executable_gate"]
        self.assertEqual(gate["logical_columns"], 256)
        self.assertEqual(gate["worker_counts"], [1, 2, 4, 8])
        self.assertEqual(gate["column_orders"], ["forward", "reverse"])
        self.assertTrue(gate["poison_before_every_column"])
        self.assertTrue(gate["reset_before_every_column"])
        self.assertTrue(gate["workspace_reused_across_columns"])
        self.assertTrue(gate["workspace_payload_must_scale_with_workers_not_columns"])
        self.assertEqual(gate["compile_modes"], ["O0", "O2"])

    def test_only_common_layer_rows_are_admitted(self):
        self.assertEqual(
            self.admission["qualified_scope_if_gate_passes"],
            {
                "P06": "COMMON_SOLVER_WORKSPACE_REUSE_EXECUTABLE_ON_PRODUCTION_INTERFACE",
                "P19": "COMMON_SOLVER_SCRATCH_POISON_RESET_EXECUTABLE_ON_PRODUCTION_INTERFACE",
            },
        )
        coverage = self.admission["coverage_effect"]
        self.assertEqual(coverage["matrix_promotions"], [])
        self.assertEqual(coverage["common_layer_executable_rows_after"], ["P06", "P19"])
        self.assertEqual(coverage["synthetic_executable_after"], 27)
        self.assertEqual(coverage["real_physics_executable_after"], 0)
        self.assertEqual(coverage["production_runtime_qualified_after"], 0)

    def test_physics_and_runtime_stay_fail_closed(self):
        nonclaims = self.admission["explicit_nonclaims"]
        for key, value in nonclaims.items():
            self.assertFalse(value, key)

    def test_checkpoint_is_qualification_only(self):
        self.assertEqual(self.status["mode"], "QUALIFICATION_ONLY")
        self.assertFalse(self.status["production_source_changed"])
        self.assertFalse(self.status["downstream_basis"]["fsi03_new_evidence_present"])
        self.assertFalse(self.status["downstream_basis"]["fvq09_qualified"])
        self.assertFalse(self.status["downstream_basis"]["fmr_branch_present"])


if __name__ == "__main__":
    unittest.main()
