from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "performance"))

from mp_workloads import (  # noqa: E402
    B12_PARAMETERS,
    B12_ROW,
    load_catalog,
    readiness_summary,
    validate_catalog,
)

CATALOG = ROOT / "benchmarks" / "performance" / "workload-catalog.json"


class WorkloadCatalogTests(unittest.TestCase):
    def setUp(self) -> None:
        self.catalog = load_catalog(CATALOG)

    def test_catalog_valid(self) -> None:
        self.assertEqual(validate_catalog(self.catalog), [])

    def test_corrected_reference_tracks_provenance_repaired_snapshot(self) -> None:
        policy = self.catalog["reference_policy"]
        self.assertEqual(policy["corrected_legacy"], "B1.5p1")
        self.assertEqual(
            policy["corrected_legacy_oracle_status"], "PENDING_VQ_IDENTITY_GATE"
        )

    def test_invalid_repaired_snapshot_name_fails(self) -> None:
        changed = copy.deepcopy(self.catalog)
        changed["reference_policy"]["corrected_legacy"] = "B1.5x"
        self.assertTrue(
            any("corrected_legacy" in error for error in validate_catalog(changed))
        )

    def test_all_six_families_present(self) -> None:
        self.assertEqual(
            {workload["family"] for workload in self.catalog["workloads"]},
            {f"MP-B0{number}" for number in range(1, 7)},
        )

    def test_b12_is_parameter_locked_not_ready(self) -> None:
        b12 = next(
            workload
            for workload in self.catalog["workloads"]
            if workload["id"] == "MP-B04-B12-HYDRAULIC-STRESS"
        )
        self.assertEqual(b12["status"], "parameter-locked")
        self.assertEqual(b12["stress_profile"]["source_row"], B12_ROW)
        self.assertEqual(b12["stress_profile"]["parameters"], B12_PARAMETERS)

    def test_b12_change_fails_closed(self) -> None:
        changed = copy.deepcopy(self.catalog)
        b12 = next(
            workload
            for workload in changed["workloads"]
            if workload["id"] == "MP-B04-B12-HYDRAULIC-STRESS"
        )
        b12["stress_profile"]["parameters"]["NPAR"] = 1.2
        self.assertIn(
            "B12 parameter map does not match locked source row",
            validate_catalog(changed),
        )

    def test_duplicate_ids_fail(self) -> None:
        changed = copy.deepcopy(self.catalog)
        changed["workloads"][1]["id"] = changed["workloads"][0]["id"]
        self.assertTrue(
            any("duplicate workload id" in error for error in validate_catalog(changed))
        )

    def test_readiness_summary_does_not_promote_blocked_cases(self) -> None:
        summary = readiness_summary(self.catalog)
        self.assertEqual(summary["workload_count"], 6)
        self.assertEqual(summary["ready_ids"], ["MP-B01-HUPSEL-SINGLE"])


if __name__ == "__main__":
    unittest.main()
