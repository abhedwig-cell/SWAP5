import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
OVERLAY = ROOT / "tests/multiswap/fmq20_fkt05_reusable_checkpoint_admission.json"
STATUS = ROOT / "tests/multiswap/fmq20_status.json"


class Fmq20AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.overlay = json.loads(OVERLAY.read_text())
        cls.status = json.loads(STATUS.read_text())

    def test_exact_fkt05_lineage(self):
        src = self.overlay["source"]
        self.assertEqual(src["status_promotion_head"], "f50b8cd20221fac27a2059b6c6192ed0b7384be8")
        self.assertEqual(src["qualification_evidence_commit"], "6911549acbcb62ef8af9ae2d96d5b4f938daf1e2")
        self.assertEqual(src["tested_postimage"], "f7d2ee5e81f1d6686c96114984239e97ba6a8a8a")
        self.assertEqual(src["qualification_blob"], "95efe0016a35cce4989dfb68f021bef69c5af453")
        self.assertEqual(src["gate_blob"], "8957180db3d0d6b650f09829e875e12faf819b52")

    def test_reusable_checkpoint_contract_is_admitted(self):
        p = self.overlay["admitted_checkpoint_primitives"]
        for key in (
            "canonical_production_entrypoint_is_kernel_advance_interval",
            "single_production_entrypoint_preserved",
            "checkpoint_owner_is_fkt",
            "checkpoint_contains_physical_state_clone",
            "checkpoint_contains_lineage_revision_time_provenance",
            "stale_revision_fails_closed",
            "cross_lineage_fails_closed",
            "time_mismatch_fails_closed",
            "rejection_precedes_physical_execution",
            "same_current_checkpoint_reusable",
            "same_committed_state_replay_qualified",
            "generic_t0_t1_preserved",
        ):
            self.assertTrue(p[key], key)

    def test_checkpoint_has_no_wrong_authority_or_scratch(self):
        p = self.overlay["admitted_checkpoint_primitives"]
        for key in (
            "checkpoint_is_persistent_column_state",
            "checkpoint_contains_solver_scratch",
            "checkpoint_contains_warm_start",
            "capture_mutates_committed_state",
            "checkpoint_can_restore_committed_state",
            "checkpoint_can_publish_committed_state",
            "failed_trial_mutates_checkpoint",
            "warm_start_may_change_physical_origin",
        ):
            self.assertFalse(p[key], key)

    def test_p10_p11_get_prerequisite_not_real_promotion(self):
        effect = self.overlay["matrix_row_effect"]
        self.assertIn("REUSABLE_CHECKPOINT_PREREQUISITE_ADMITTED", effect["P10"])
        self.assertIn("SAME_COMMITTED_STATE_REPLAY_PREREQUISITE_ADMITTED", effect["P11"])
        self.assertEqual(self.overlay["coverage"]["matrix_promotions"], [])

    def test_coverage_remains_fail_closed(self):
        coverage = self.overlay["coverage"]
        self.assertEqual(coverage["matrix_total"], 35)
        self.assertEqual(coverage["synthetic_executable"], 27)
        self.assertEqual(coverage["real_physics_executable"], 0)
        self.assertEqual(coverage["production_runtime_qualified"], 0)

    def test_hard_nonclaims_all_false(self):
        self.assertTrue(all(v is False for v in self.overlay["hard_nonclaims"].values()))

    def test_pending_downstream_context_is_not_evidence(self):
        ctx = self.overlay["context_not_consumed_as_evidence"]
        self.assertFalse(ctx["fsi06_qualified"])
        self.assertFalse(ctx["fvq12_qualified"])
        self.assertFalse(ctx["fmr01_qualified"])

    def test_status_is_checkpoint_or_final(self):
        self.assertTrue(self.status["persisted"])
        if self.status["qualified"]:
            self.assertTrue(self.status["tested"])
            self.assertEqual(
                self.status["status"],
                "QUALIFIED_FKT05_REUSABLE_CHECKPOINT_ADMITTED_NO_REAL_OR_RUNTIME_PROMOTION",
            )
        else:
            self.assertEqual(
                self.status["status"],
                "PERSISTED_FKT05_REUSABLE_CHECKPOINT_ADMISSION_CANDIDATE",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
