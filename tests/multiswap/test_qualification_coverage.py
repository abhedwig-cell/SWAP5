from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
MATRIX_PATH = HERE / "qualification_matrix.json"
COVERAGE_PATH = HERE / "qualification_coverage_snapshot.json"

EXPECTED_IDS = (
    tuple(f"R{i:02d}" for i in range(1, 9))
    + tuple(f"P{i:02d}" for i in range(1, 23))
    + ("D01", "D02", "S01", "PFX01", "PFX02")
)


def git_blob_sha(path: Path) -> str:
    data = path.read_bytes()
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


class TestFMQ08QualificationCoverage(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.matrix = json.loads(MATRIX_PATH.read_text(encoding="utf-8"))
        cls.coverage = json.loads(COVERAGE_PATH.read_text(encoding="utf-8"))
        cls.by_id = {row["id"]: row for row in cls.coverage["entries"]}

    def test_requirements_baseline_is_immutable_and_exact(self) -> None:
        baseline = self.coverage["requirements_baseline"]
        self.assertEqual(baseline["path"], "tests/multiswap/qualification_matrix.json")
        self.assertEqual(git_blob_sha(MATRIX_PATH), baseline["blob_sha"])
        self.assertEqual(len(self.matrix["entries"]), baseline["row_count"])
        self.assertEqual(baseline["row_count"], 35)

    def test_coverage_is_exactly_one_row_per_requirement(self) -> None:
        matrix_ids = tuple(row["id"] for row in self.matrix["entries"])
        coverage_ids = tuple(row["id"] for row in self.coverage["entries"])
        self.assertEqual(matrix_ids, EXPECTED_IDS)
        self.assertEqual(coverage_ids, EXPECTED_IDS)
        self.assertEqual(len(set(coverage_ids)), 35)

    def test_summary_is_derived_not_hand_waved(self) -> None:
        entries = self.coverage["entries"]
        summary = self.coverage["summary"]
        self.assertEqual(summary["requirements_total"], len(entries))
        self.assertEqual(
            summary["synthetic_executable"],
            sum(bool(row["synthetic_executable"]) for row in entries),
        )
        self.assertEqual(
            summary["real_physics_executable"],
            sum(bool(row["real_physics_executable"]) for row in entries),
        )
        self.assertEqual(
            summary["production_runtime_qualified"],
            sum(bool(row["production_runtime_qualified"]) for row in entries),
        )
        self.assertEqual(summary["synthetic_executable"], 26)
        self.assertEqual(summary["real_physics_executable"], 0)
        self.assertEqual(summary["production_runtime_qualified"], 0)

    def test_fci06_checkpoint_does_not_false_promote_real_physics(self) -> None:
        obs = self.coverage["canonical_observation"]
        self.assertEqual(obs["latest_work_unit_observed"], "F-CI06")
        self.assertTrue(obs["b1_10_water_checkpoint_postimage_present"])
        self.assertFalse(obs["real_event_fixture_admitted_by_fmq"])
        for pid in ("P10", "P11", "P16", "P17"):
            self.assertFalse(self.by_id[pid]["real_physics_executable"], pid)

    def test_synthetic_runtime_and_isolation_coverage_is_visible(self) -> None:
        expected = {
            *(f"R{i:02d}" for i in range(1, 9)),
            "P02", "P03", "P04", "P05", "P06", "P07", "P08", "P09",
            "P12", "P13", "P15", "P18", "P19", "P20", "P21", "P22",
            "D01", "D02",
        }
        observed = {
            row["id"] for row in self.coverage["entries"]
            if row["synthetic_executable"]
        }
        self.assertEqual(observed, expected)

    def test_no_historical_evidence_can_become_current_production_claim(self) -> None:
        for row in self.coverage["entries"]:
            if any("historical" in item.lower() for item in row["evidence"]):
                self.assertFalse(row["production_runtime_qualified"], row["id"])
                self.assertFalse(row["real_physics_executable"], row["id"])

    def test_coupling_properties_remain_synthetic_only(self) -> None:
        for pid in ("P20", "P21", "P22"):
            row = self.by_id[pid]
            self.assertTrue(row["synthetic_executable"])
            self.assertFalse(row["real_physics_executable"])
            self.assertFalse(row["production_runtime_qualified"])
            self.assertIn("F-SI", row["blocking_owners"])

    def test_difficult_column_properties_wait_for_real_fixture(self) -> None:
        for pid in ("D01", "D02"):
            row = self.by_id[pid]
            self.assertTrue(row["synthetic_executable"])
            self.assertFalse(row["real_physics_executable"])
            self.assertIn("VQ/F-MQ fixture extraction", row["blocking_owners"])

    def test_performance_lane_is_not_relabelled_as_correctness(self) -> None:
        for pid in ("PFX01", "PFX02"):
            row = self.by_id[pid]
            self.assertEqual(row["current_class"], "PERFORMANCE_LANE_NOT_EXECUTED")
            self.assertFalse(row["synthetic_executable"])
            self.assertFalse(row["production_runtime_qualified"])

    def test_status_keeps_real_and_production_claims_closed(self) -> None:
        self.assertEqual(
            self.coverage["status"],
            "PASS_COVERAGE_CONSOLIDATED / NO_REAL_PHYSICS_OR_PRODUCTION_RUNTIME_CLAIM",
        )
        self.assertFalse(self.coverage["production_code_change_allowed"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
