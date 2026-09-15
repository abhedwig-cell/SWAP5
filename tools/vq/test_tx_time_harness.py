from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.vq.tx_time_harness import (
    CASE_IDS,
    check_stored_evidence,
    evidence_projection,
    run_fixture_suite,
)


class TxTimeHarnessTests(unittest.TestCase):
    def case(self, report: dict, case_id: str) -> dict:
        return next(item for item in report["cases"] if item["case_id"] == case_id)

    def test_complete_fixture_suite_passes_without_physics_claim(self) -> None:
        report = run_fixture_suite()
        self.assertEqual(report["harness_status"], "PASS")
        self.assertEqual(report["qualification_scope"], "VERIFIER_HARNESS_ONLY")
        self.assertEqual(report["b2_physics_status"], "NOT_EVALUATED")
        self.assertFalse(report["production_physics_executed"])
        self.assertFalse(report["production_mass_tolerance_qualified"])
        self.assertEqual(report["case_count"], len(CASE_IDS))
        self.assertEqual(report["missing_cases"], [])
        self.assertEqual(
            {item["case_id"] for item in report["cases"]},
            set(CASE_IDS),
        )
        self.assertTrue(all(item["status"] == "PASS" for item in report["cases"]))

    def test_rollback_mutation_is_detected(self) -> None:
        report = run_fixture_suite({"rollback_mutates_committed"})
        case = self.case(report, "TX-ROLLBACK-01")
        self.assertEqual(case["status"], "FAIL")
        self.assertFalse(case["checks"]["retry_physical_start_is_committed_state"])

    def test_duplicate_commit_is_detected(self) -> None:
        report = run_fixture_suite({"duplicate_commit"})
        case = self.case(report, "TX-COMMIT-01")
        self.assertEqual(case["status"], "FAIL")
        self.assertFalse(case["checks"]["single_commit"])

    def test_rejected_trial_double_accounting_is_detected(self) -> None:
        report = run_fixture_suite({"double_counts_rejected"})
        case = self.case(report, "TX-ACCOUNT-01")
        self.assertEqual(case["status"], "FAIL")
        self.assertFalse(case["checks"]["committed_external_exactly_once"])
        self.assertFalse(case["checks"]["committed_result_exactly_once"])
        self.assertFalse(case["checks"]["storage_delta_exactly_once"])

    def test_rerun_nondeterminism_is_detected(self) -> None:
        report = run_fixture_suite({"rerun_nondeterministic"})
        case = self.case(report, "TX-RERUN-01")
        self.assertEqual(case["status"], "FAIL")
        self.assertFalse(case["checks"]["same_physical_result"])
        self.assertFalse(case["checks"]["same_committed_endpoint"])

    def test_forcing_replay_drift_is_detected(self) -> None:
        report = run_fixture_suite({"forcing_replay_drift"})
        case = self.case(report, "TX-BC-REPLAY-01")
        self.assertEqual(case["status"], "FAIL")
        self.assertFalse(case["checks"]["forcing_signature_replayed"])
        self.assertFalse(case["checks"]["accepted_amount_matches_original_forcing"])

    def test_warm_start_cannot_replace_physical_start(self) -> None:
        report = run_fixture_suite({"warm_start_changes_physical_start"})
        case = self.case(report, "TX-WARM-01")
        self.assertEqual(case["status"], "FAIL")
        self.assertFalse(case["checks"]["warm_physical_start_is_committed_state"])

    def test_calendar_snap_is_detected_away_from_midnight(self) -> None:
        report = run_fixture_suite({"calendar_snap"})
        self.assertEqual(self.case(report, "TIME-00")["status"], "PASS")
        for case_id in ("TIME-06", "TIME-18", "TIME-36"):
            case = self.case(report, case_id)
            self.assertEqual(case["status"], "FAIL")
            self.assertFalse(case["checks"]["returned_t0_exact"])

    def test_split_noncomposability_is_detected_without_exporting_tolerance(self) -> None:
        report = run_fixture_suite({"split_noncomposable"})
        case = self.case(report, "TIME-SPLIT")
        self.assertEqual(case["status"], "FAIL")
        self.assertFalse(case["checks"]["final_endpoint_exact_fixture_equivalence"])
        self.assertFalse(case["checks"]["external_amount_exact_fixture_equivalence"])
        self.assertFalse(case["checks"]["result_amount_exact_fixture_equivalence"])
        self.assertEqual(case["details"]["comparison_tolerance"], 0.0)
        self.assertFalse(case["details"]["production_tolerance_qualified"])

    def test_stored_evidence_drift_is_detected(self) -> None:
        report = run_fixture_suite()
        projection = evidence_projection(report)
        projection["case_status"]["TX-ROLLBACK-01"] = "FAIL"
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.json"
            path.write_text(json.dumps(projection), encoding="utf-8")
            check = check_stored_evidence(report, path)
        self.assertFalse(check["consistent"])
        self.assertIn("case_status", check["mismatches"])


if __name__ == "__main__":
    unittest.main()
