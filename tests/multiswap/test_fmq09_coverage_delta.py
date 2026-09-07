from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
BASE_PATH = HERE / "qualification_coverage_snapshot.json"
DELTA_PATH = HERE / "qualification_coverage_delta_fmq09.json"


def git_blob_sha(path: Path) -> str:
    data = path.read_bytes()
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


class TestFMQ09CoverageDelta(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.base = json.loads(BASE_PATH.read_text(encoding="utf-8"))
        cls.delta = json.loads(DELTA_PATH.read_text(encoding="utf-8"))
        cls.base_by_id = {row["id"]: row for row in cls.base["entries"]}

    def test_delta_pins_exact_fmq08_snapshot_blob(self) -> None:
        pin = self.delta["base_coverage_snapshot"]
        self.assertEqual(pin["work_unit"], "F-MQ08")
        self.assertEqual(pin["path"], "tests/multiswap/qualification_coverage_snapshot.json")
        self.assertEqual(pin["blob_sha"], git_blob_sha(BASE_PATH))

    def test_only_p01_is_promoted(self) -> None:
        promotions = self.delta["promotions"]
        self.assertEqual(len(promotions), 1)
        promotion = promotions[0]
        self.assertEqual(promotion["id"], "P01")
        self.assertFalse(self.base_by_id["P01"]["synthetic_executable"])
        self.assertFalse(promotion["synthetic_executable_before"])
        self.assertTrue(promotion["synthetic_executable_after"])
        self.assertFalse(promotion["real_physics_executable"])
        self.assertFalse(promotion["production_runtime_qualified"])

    def test_effective_summary_is_exact_delta_from_fmq08(self) -> None:
        base_summary = self.base["summary"]
        after = self.delta["effective_summary_after_delta"]
        increments = sum(
            int(row["synthetic_executable_after"])
            - int(row["synthetic_executable_before"])
            for row in self.delta["promotions"]
        )
        self.assertEqual(after["requirements_total"], base_summary["requirements_total"])
        self.assertEqual(
            after["synthetic_executable"],
            base_summary["synthetic_executable"] + increments,
        )
        self.assertEqual(after["synthetic_executable"], 27)
        self.assertEqual(after["real_physics_executable"], 0)
        self.assertEqual(after["production_runtime_qualified"], 0)

    def test_p01_remains_blocked_for_real_and_production_claims(self) -> None:
        promotion = self.delta["promotions"][0]
        self.assertEqual(
            promotion["to_class"],
            "SYNTHETIC_EXECUTABLE_WAITING_REAL_AND_FMR",
        )
        self.assertIn("F-CI/F-KT", promotion["blocking_owners"])
        self.assertIn("F-MR", promotion["blocking_owners"])
        self.assertGreaterEqual(len(self.delta["nonclaims"]), 3)

    def test_qualification_only_boundary(self) -> None:
        self.assertEqual(self.delta["workstream"], "F-MQ")
        self.assertEqual(self.delta["work_unit"], "F-MQ09")
        self.assertFalse(self.delta["production_code_change_allowed"])
        self.assertEqual(
            self.delta["status"],
            "PASS_SYNTHETIC_P01_COVERAGE_DELTA / REAL_AND_PRODUCTION_OPEN",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
