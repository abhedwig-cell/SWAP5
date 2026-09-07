import json
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
OVERLAY = HERE / "fmq13_downstream_boundary_admission.json"
STATUS = HERE / "fmq13_status.json"

EXPECTED_RECLASSIFIED = {
    "P03", "P06", "P10", "P11", "P14", "P16", "P18", "P19", "D01", "D02", "S01"
}


def load(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


class Fmq13DownstreamBoundaryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.overlay = load(OVERLAY)
        cls.status = load(STATUS)
        cls.reclassified = {item["id"]: item for item in cls.overlay["ownership_reclassification"]}

    def test_exact_lineage_is_pinned(self):
        lineage = self.overlay["lineage"]
        self.assertEqual(lineage["fmq12_head"], "e7248ef1813acf942fcae0f8d66c1b4409af4914")
        self.assertEqual(lineage["fsi01_head"], "ae6da038ee7e98dfe1758f5f86b4be0fb48b4743")
        self.assertEqual(lineage["fvq08_head"], "0be60f6da7e575eaf992eb049ce600a4a4b35b58")
        self.assertEqual(lineage["fkt_current_head"], "cbcbfa26d413a661956a2079dc4a1e26c9e3b55c")

    def test_fsi01_is_boundary_only(self):
        fsi = self.overlay["fsi01_admission"]
        self.assertTrue(fsi["qualified_boundary_baseline"])
        self.assertTrue(fsi["common_solver_interface_persisted"])
        self.assertFalse(fsi["common_solver_interface_implemented_in_fsi01"])
        self.assertFalse(fsi["reference_richards_reentrancy_qualified"])
        self.assertFalse(fsi["parallel_multiswap_backend_qualified"])
        self.assertEqual(len(fsi["deferred_solver_tests"]), 9)
        self.assertTrue(all(v == "BLOCKED_BY_COMMON_SOLVER_INTERFACE" for v in fsi["deferred_solver_tests"].values()))

    def test_solver_workspace_contract_is_nonpersistent(self):
        workspace = self.overlay["fsi01_admission"]["workspace_contract"]
        self.assertTrue(workspace["worker_or_active_solve_job_owned"])
        self.assertFalse(workspace["persistent_per_logical_column"])
        self.assertTrue(workspace["poisoning_required"])
        self.assertTrue(workspace["committed_state_forbidden_in_workspace"])
        self.assertTrue(workspace["commit_or_rollback_authority_forbidden_in_solver"])

    def test_fvq08_keeps_real_reference_fail_closed(self):
        vq = self.overlay["fvq08_admission"]
        self.assertTrue(vq["qualified_readiness_boundary"])
        self.assertFalse(vq["real_b1_10_temporal_characterization_qualified"])
        self.assertFalse(vq["production_temporal_profile_qualified"])
        self.assertEqual(vq["canonical_reference_admission"], "BLOCKED_FAIL_CLOSED")
        self.assertFalse(vq["complete_optional_process_scope_qualified"])
        self.assertTrue(vq["hard_mass_separate_absolute_gate"])
        self.assertEqual(vq["blocked_claims"], ["FVQ08-C05", "FVQ08-C06", "FVQ08-C07", "FVQ08-C08"])
        self.assertEqual(vq["prohibited_claim"], "FVQ08-C09")

    def test_no_coverage_promotion(self):
        effect = self.overlay["coverage_effect"]
        self.assertEqual(effect["synthetic_executable_before"], 27)
        self.assertEqual(effect["synthetic_executable_after"], 27)
        self.assertEqual(effect["real_physics_executable_before"], 0)
        self.assertEqual(effect["real_physics_executable_after"], 0)
        self.assertEqual(effect["production_runtime_qualified_before"], 0)
        self.assertEqual(effect["production_runtime_qualified_after"], 0)
        self.assertEqual(effect["promotions"], [])

    def test_expected_ownership_rows_are_reclassified(self):
        self.assertEqual(set(self.reclassified), EXPECTED_RECLASSIFIED)
        self.assertEqual(self.reclassified["P19"]["remaining_owners"], ["F-SI"])
        self.assertEqual(self.reclassified["P10"]["remaining_owners"], ["F-VQ"])
        self.assertEqual(self.reclassified["P18"]["remaining_owners"], ["F-SI", "F-MR"])

    def test_fkt02_has_no_net_capability_delta(self):
        self.assertEqual(
            self.overlay["lineage"]["fkt_current_tree"],
            self.overlay["lineage"]["fkt01_qualified_tree"],
        )
        self.assertFalse(self.overlay["fkt02_observation"]["net_capability_delta_from_fkt01"])

    def test_status_is_qualification_only(self):
        self.assertEqual(self.status["mode"], "QUALIFICATION_ONLY")
        self.assertFalse(self.status["production_source_changed"])
        self.assertFalse(self.status["downstream_observation"]["fmr_branch_present"])
        self.assertEqual(self.overlay["decision"], "QUALIFIED_BOUNDARY_ADMISSION_NO_COVERAGE_PROMOTION")


if __name__ == "__main__":
    unittest.main()
