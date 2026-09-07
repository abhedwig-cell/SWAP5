from __future__ import annotations

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MATRIX = ROOT / "tests" / "multiswap" / "qualification_matrix.json"

REQUIRED_FIELDS = {
    "id",
    "property",
    "layer",
    "invariants",
    "min_columns",
    "min_workers",
    "kernel",
    "interval",
    "fixture",
    "expected_result",
    "mass_gate",
    "determinism",
    "cost",
    "frequency",
    "status",
    "dependency",
    "reuse",
}
VALID_LAYERS = {"MQ-T0", "MQ-T1", "MQ-T2", "MQ-T3", "MQ-T4", "MQ-P"}
VALID_KERNELS = {"testdouble", "real_swap", "both"}
VALID_COSTS = {"tiny", "small", "medium", "long"}
VALID_FREQUENCIES = {"every commit", "integration", "nightly", "release"}
VALID_STATUSES = {"executable", "blocked", "interface-needed"}
MANDATORY_PROPERTIES = {f"P{number:02d}" for number in range(1, 23)}
HARD_REAL_MASS_PROPERTIES = {"P10", "P11", "P16", "P17", "S01"}


class QualificationMatrixTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.matrix = json.loads(MATRIX.read_text(encoding="utf-8"))
        cls.entries = cls.matrix["entries"]
        cls.by_id = {entry["id"]: entry for entry in cls.entries}

    def test_work_unit_is_qualification_only(self) -> None:
        self.assertEqual(self.matrix["workstream"], "F-MQ")
        self.assertEqual(self.matrix["work_unit"], "F-MQ01")
        self.assertFalse(self.matrix["production_code_change_allowed"])
        self.assertEqual(self.matrix["canonical_production_baseline_authority"], "F-CI")

    def test_every_entry_has_complete_contract(self) -> None:
        for entry in self.entries:
            self.assertEqual(set(entry), REQUIRED_FIELDS, entry["id"])
            self.assertIn(entry["layer"], VALID_LAYERS, entry["id"])
            self.assertIn(entry["kernel"], VALID_KERNELS, entry["id"])
            self.assertIn(entry["cost"], VALID_COSTS, entry["id"])
            self.assertIn(entry["frequency"], VALID_FREQUENCIES, entry["id"])
            self.assertIn(entry["status"], VALID_STATUSES, entry["id"])
            self.assertGreaterEqual(entry["min_columns"], 1, entry["id"])
            self.assertGreaterEqual(entry["min_workers"], 1, entry["id"])
            self.assertTrue(entry["invariants"], entry["id"])
            self.assertTrue(all(1 <= number <= 30 for number in entry["invariants"]), entry["id"])
            if entry["status"] in {"blocked", "interface-needed"}:
                self.assertTrue(entry["dependency"].strip(), entry["id"])

    def test_ids_are_unique(self) -> None:
        ids = [entry["id"] for entry in self.entries]
        self.assertEqual(len(ids), len(set(ids)))

    def test_all_22_required_multiswap_properties_are_present(self) -> None:
        self.assertTrue(MANDATORY_PROPERTIES.issubset(self.by_id))

    def test_all_required_layers_and_performance_lane_are_present(self) -> None:
        observed = {entry["layer"] for entry in self.entries}
        self.assertTrue(VALID_LAYERS.issubset(observed))

    def test_real_water_replay_and_mass_properties_have_hard_mass_gates(self) -> None:
        for property_id in HARD_REAL_MASS_PROPERTIES:
            self.assertIn("hard", self.by_id[property_id]["mass_gate"].lower(), property_id)

    def test_t0_and_t1_remain_correctness_scale(self) -> None:
        for entry in self.entries:
            if entry["layer"] == "MQ-T0":
                self.assertLessEqual(entry["min_columns"], 32, entry["id"])
                self.assertNotEqual(entry["cost"], "long", entry["id"])
            if entry["layer"] == "MQ-T1":
                self.assertLessEqual(entry["min_columns"], 8, entry["id"])
                self.assertEqual(entry["kernel"], "real_swap", entry["id"])
                self.assertIn(entry["frequency"], {"integration", "nightly", "release"}, entry["id"])

    def test_long_scientific_regression_is_not_every_commit(self) -> None:
        scientific = self.by_id["S01"]
        self.assertEqual(scientific["layer"], "MQ-T4")
        self.assertEqual(scientific["cost"], "long")
        self.assertIn(scientific["frequency"], {"nightly", "release"})

    def test_throughput_scale_is_separate_from_correctness_scale(self) -> None:
        throughput = self.by_id["PFX02"]
        self.assertEqual(throughput["layer"], "MQ-P")
        self.assertGreaterEqual(throughput["min_columns"], 100000)
        self.assertEqual(throughput["frequency"], "release")
        self.assertIn("wall clock", throughput["expected_result"].lower())


if __name__ == "__main__":
    unittest.main()
