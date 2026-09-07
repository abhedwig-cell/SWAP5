import json
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
OVERLAY = HERE / "fmq12_fkt01_admission.json"
STATUS = HERE / "fmq12_status.json"

EXPECTED_DELTA_IDS = ["P05", "P12", "P14", "P16", "P21", "P22"]
EXPECTED_FKT_HEAD = "62f27672bbb74066ece202de8898597e655aed3d"
EXPECTED_FMQ11 = "e581efae0b5d466709b590d1727d84835919b32d"


def load(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


class Fmq12Fkt01AdmissionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.overlay = load(OVERLAY)
        cls.status = load(STATUS)
        cls.deltas = {item["id"]: item for item in cls.overlay["ownership_deltas"]}

    def test_exact_lineage_is_pinned(self):
        self.assertEqual(self.status["fmq_parent"]["commit"], EXPECTED_FMQ11)
        self.assertEqual(self.overlay["fkt01_evidence"]["head"], EXPECTED_FKT_HEAD)
        self.assertEqual(
            self.overlay["fkt01_evidence"]["qualification_evidence_commit"],
            "e350d84e975e9f6ab4475658566f623b0e46f9ac",
        )
        self.assertEqual(self.overlay["fkt01_evidence"]["workflow_run"], 34117279573)
        self.assertEqual(self.overlay["fkt01_evidence"]["qualification_status"], "QUALIFIED")

    def test_only_expected_ownership_deltas_are_present(self):
        self.assertEqual([item["id"] for item in self.overlay["ownership_deltas"]], EXPECTED_DELTA_IDS)
        self.assertEqual(len(self.deltas), 6)

    def test_fkt_is_removed_only_where_qualified(self):
        for rid in EXPECTED_DELTA_IDS:
            before = self.deltas[rid]["before"]["remaining_owners"]
            after = self.deltas[rid]["after"]["remaining_owners"]
            self.assertIn("F-KT", before)
            self.assertNotIn("F-KT", after)
        self.assertEqual(self.deltas["P05"]["after"]["remaining_owners"], [])
        self.assertEqual(self.deltas["P12"]["after"]["remaining_owners"], ["F-VQ"])
        self.assertEqual(self.deltas["P14"]["after"]["remaining_owners"], ["F-VQ"])
        self.assertEqual(self.deltas["P16"]["after"]["remaining_owners"], ["F-VQ"])
        self.assertEqual(self.deltas["P21"]["after"]["remaining_owners"], ["F-MR"])
        self.assertEqual(self.deltas["P22"]["after"]["remaining_owners"], ["F-MR"])

    def test_no_real_or_runtime_promotion_is_claimed(self):
        effect = self.overlay["coverage_effect"]
        self.assertEqual(effect["synthetic_executable_before"], 27)
        self.assertEqual(effect["synthetic_executable_after"], 27)
        self.assertEqual(effect["real_physics_executable_before"], 0)
        self.assertEqual(effect["real_physics_executable_after"], 0)
        self.assertEqual(effect["production_runtime_qualified_before"], 0)
        self.assertEqual(effect["production_runtime_qualified_after"], 0)
        self.assertEqual(effect["coverage_promotions"], [])

    def test_fkt_scope_remains_fail_closed_for_real_reference(self):
        not_admitted = self.overlay["not_admitted_by_fkt01"]
        for key in (
            "real_b1_10_reference_execution",
            "complete_optional_process_qualification",
            "solver_reentrancy",
            "production_multiswap_runtime",
            "modflow_coupling",
            "complete_real_event_mass_fixture",
        ):
            self.assertTrue(not_admitted[key])
        self.assertTrue(self.overlay["admitted_fkt01_properties"]["reference_execution_admission_remains_fail_closed"])

    def test_fsi_and_fmr_are_not_invented(self):
        downstream = self.overlay["downstream_state"]
        self.assertEqual(downstream["fsi_head_observed"], "7f906fcc53a4133b0e410eac7cf79fbb4eb672ab")
        self.assertFalse(downstream["fsi_has_post_fci18_implementation_evidence"])
        self.assertFalse(downstream["fmr_branch_present"])

    def test_decision_is_ownership_only(self):
        self.assertEqual(
            self.overlay["decision"],
            "ADMIT_FKT01_KERNEL_BOUNDARY_RECLASSIFY_OWNERSHIP_NO_COVERAGE_PROMOTION",
        )
        self.assertEqual(self.status["mode"], "QUALIFICATION_ONLY")
        self.assertFalse(self.status["production_source_changed"])


if __name__ == "__main__":
    unittest.main()
