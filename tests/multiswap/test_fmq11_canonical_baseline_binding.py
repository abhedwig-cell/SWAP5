import json
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
BINDING_PATH = HERE / "fmq11_canonical_binding.json"
STATUS_PATH = HERE / "fmq11_status.json"

EXPECTED_IDS = [
    "R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08",
    "P01", "P02", "P03", "P04", "P05", "P06", "P07", "P08", "P09", "P10", "P11",
    "P12", "P13", "P14", "P15", "P16", "P17", "P18", "P19", "P20", "P21", "P22",
    "D01", "D02", "S01", "PFX01", "PFX02",
]

EXPECTED_BLOBS = {
    "src/transaction/mod_transaction_reference.f90": "4a573316b77252b56bcb429fd519aa57123e9a06",
    "src/runtime/mod_canonical_contracts.f90": "55cd8a9dc529bb2d057845f212b7efff6c80c553",
    "src/runtime/mod_canonical_interval_runtime.f90": "f0bfb2c1359c39b4708350b756aa2211fb982be4",
    "src/runtime/mod_a23bu_worker_execution_context.f90": "2a190d206200ad201c37c9a82d3e32e651d37a37",
    "src/adapter/mod_b1_10_process_checkpoint.f90": "4084f979d86e0a97d2b7b570af38ad44d85dca6c",
    "src/adapter/mod_b1_10_mass_seam.f90": "4b205a9b7df465deffe5a34349da91f2102f3f51",
    "src/adapter/mod_b1_10_physical_interval_executor.f90": "6097e9e338ed823fe89f5e2d854992e0d3e4b798",
    "src/adapter/mod_b1_10_recoverable_reference_model.f90": "e4a37554359f25efb120f55eea7465559a94938d",
    "src/adapter/mod_b1_10_reference_model.f90": "366a4df93a829413bed552b050ca723544e31ce4",
    "src/adapter/mod_b1_10_reference_policy_candidate_model.f90": "594436176333e9fb04121dcf287b507a93723dfe",
}


def load(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


class Fmq11CanonicalBaselineBindingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binding = load(BINDING_PATH)
        cls.status = load(STATUS_PATH)
        cls.entries = {entry["id"]: entry for entry in cls.binding["entries"]}

    def test_exact_fmq_and_canonical_lineage_is_pinned(self):
        self.assertEqual(
            self.binding["lineage"]["fmq10_head"],
            "831110d0c6f1838e3583391b5e9266a2f5f95ebb",
        )
        self.assertEqual(
            self.binding["lineage"]["fci18_closeout_head"],
            "7f906fcc53a4133b0e410eac7cf79fbb4eb672ab",
        )
        self.assertEqual(
            self.binding["lineage"]["fci_development_baseline_exit_head"],
            "1eceed967b12396b8bbc832f897376378463adce",
        )
        self.assertEqual(
            self.binding["lineage"]["qualified_production_source_head"],
            "da5026d8b87ad2f3c7912360891839a120ecccb6",
        )
        self.assertEqual(
            self.binding["lineage"]["fvq07_head"],
            "4ae2fc87970d46ff2103553930e583dd05a59f0b",
        )

    def test_requirements_baseline_and_all_35_ids_are_preserved(self):
        baseline = self.binding["requirements_baseline"]
        self.assertEqual(baseline["git_blob_sha1"], "4b53b71375833ae94e788da8b6eab0dc2e6c1dad")
        self.assertEqual(baseline["row_count"], 35)
        ids = [entry["id"] for entry in self.binding["entries"]]
        self.assertEqual(ids, EXPECTED_IDS)
        self.assertEqual(len(set(ids)), 35)

    def test_exact_canonical_source_blobs_are_pinned(self):
        self.assertEqual(self.binding["canonical_source_blob_pins"], EXPECTED_BLOBS)

    def test_fci_exit_removed_as_remaining_blocker(self):
        for entry in self.binding["entries"]:
            for owner in entry["remaining_owners"]:
                self.assertNotIn("F-CI", owner)
        self.assertTrue(self.status["canonical_exit"]["downstream_release_allowed"])
        self.assertEqual(self.status["canonical_exit"]["fci18_status"], "QUALIFIED_EXIT")

    def test_core_canonical_prerequisites_are_bound(self):
        self.assertEqual(
            self.entries["P05"]["canonical_binding"],
            "CANONICAL_STATE_CLONE_PREREQUISITE_BOUND",
        )
        self.assertEqual(
            self.entries["P07"]["canonical_binding"],
            "CANONICAL_TRANSACTION_ATOMICITY_BOUND_REAL_AND_FMR_OPEN",
        )
        self.assertEqual(
            self.entries["P08"]["canonical_binding"],
            "CANONICAL_RETRY_ROLLBACK_BOUND_REAL_AND_FMR_OPEN",
        )
        self.assertEqual(
            self.entries["P12"]["canonical_binding"],
            "CANONICAL_FORCING_API_BOUND_REAL_LOCALITY_OPEN",
        )
        self.assertEqual(
            self.entries["P15"]["canonical_binding"],
            "CANONICAL_DIAGNOSTICS_FIELDS_BOUND_AGGREGATION_WAITING_FMR",
        )

    def test_mass_and_real_reference_are_still_fail_closed(self):
        obs = self.binding["canonical_contract_observations"]
        self.assertFalse(obs["canonical_interval_runtime_sets_complete_mass"])
        self.assertFalse(obs["b1_10_reference_execution_admitted"])
        self.assertEqual(
            self.binding["contract_bindings"]["MQ-MASS-01"]["status"],
            "CONTRACT_PARTIAL_REFERENCE_RECORD_BLOCKED",
        )
        self.assertEqual(
            self.entries["P16"]["canonical_binding"],
            "CANONICAL_MASS_CONTRACT_PARTIAL_REAL_RECORD_BLOCKED",
        )

    def test_no_coverage_promotion_is_claimed(self):
        effect = self.binding["coverage_effect"]
        self.assertEqual(effect["synthetic_executable_before"], 27)
        self.assertEqual(effect["synthetic_executable_after"], 27)
        self.assertEqual(effect["real_physics_executable_before"], 0)
        self.assertEqual(effect["real_physics_executable_after"], 0)
        self.assertEqual(effect["production_runtime_qualified_before"], 0)
        self.assertEqual(effect["production_runtime_qualified_after"], 0)
        self.assertEqual(effect["promotions"], [])
        self.assertEqual(
            self.binding["decision"],
            "CANONICAL_BASELINE_BOUND_NO_REAL_OR_PRODUCTION_PROMOTION",
        )

    def test_remaining_ownership_is_explicit(self):
        self.assertIn("F-VQ", self.entries["P10"]["remaining_owners"])
        self.assertIn("F-VQ", self.entries["P11"]["remaining_owners"])
        self.assertIn("F-SI", self.entries["P19"]["remaining_owners"])
        self.assertIn("F-MR", self.entries["P20"]["remaining_owners"])
        self.assertIn("F-KT", self.entries["P21"]["remaining_owners"])

    def test_status_is_qualification_only_and_consistent(self):
        self.assertEqual(self.status["mode"], "QUALIFICATION_ONLY")
        self.assertFalse(self.status["production_source_changed"])
        self.assertEqual(
            self.status["fvq_handoff"]["canonical_reference_admission"],
            "BLOCKED_FAIL_CLOSED",
        )


if __name__ == "__main__":
    unittest.main()
