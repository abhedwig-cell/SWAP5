from __future__ import annotations

import copy
import unittest

from tools.performance.mp_cpu_baseline import (
    required_pair_count,
    summarize_samples,
    validate_plan,
    validate_samples,
)

PLAN = {
    "schema_version": "mp-cpu-baseline-plan-v1",
    "primary_metric": "child_cpu_seconds",
    "secondary_metric": "wall_elapsed_seconds",
    "pilot_paired_stdev": 0.03303993093797261,
    "target_resolution_relative": 0.01,
    "resolution_multiplier": 2.0,
    "predeclared_pairs": 44,
    "warmup_runs_per_variant": 3,
    "affinity": {"target_cpus": [0]},
    "expected_exit_code": 100,
    "physical_outputs": ["result.bal"],
    "variants": {
        "off": {"environment": {"X": "0"}},
        "on": {"environment": {"X": "1"}},
    },
    "executable_sha256": "a" * 64,
}


def row(cycle: int, variant: str, cpu: float, wall: float, digest: str = "a" * 64) -> dict:
    return {
        "schema_version": "mp-cpu-baseline-samples-v1",
        "cycle": cycle,
        "variant": variant,
        "child_cpu_seconds": cpu,
        "wall_elapsed_seconds": wall,
        "target_affinity_cpus": [0],
        "hashes": {"result.bal": digest, "result.blc": "b" * 64},
    }


class CpuBaselineTests(unittest.TestCase):
    def test_pilot_recommends_44_pairs(self) -> None:
        self.assertEqual(required_pair_count(0.03303993093797261, 0.01, 2.0), 44)

    def test_plan_valid(self) -> None:
        self.assertEqual(validate_plan(PLAN), [])

    def test_plan_pair_count_fails_closed(self) -> None:
        changed = copy.deepcopy(PLAN)
        changed["predeclared_pairs"] = 43
        self.assertTrue(any("44" in error for error in validate_plan(changed)))

    def test_affinity_change_fails(self) -> None:
        rows = [row(0, "off", 1.0, 1.0), row(0, "on", 1.01, 1.01)]
        rows[1]["target_affinity_cpus"] = [1]
        self.assertIn(
            "target CPU affinity changed across samples",
            validate_samples(rows, baseline_variant="off", measured_variant="on"),
        )

    def test_hash_change_fails(self) -> None:
        rows = [row(0, "off", 1.0, 1.0), row(0, "on", 1.01, 1.01, "c" * 64)]
        self.assertTrue(
            any(
                "physical output hash changed" in error
                for error in validate_samples(rows, baseline_variant="off", measured_variant="on")
            )
        )

    def test_summary_separates_cpu_and_wall(self) -> None:
        rows = []
        for cycle in range(4):
            rows.extend([row(cycle, "off", 1.0, 2.0), row(cycle, "on", 1.01, 2.04)])
        summary = summarize_samples(
            rows,
            baseline_variant="off",
            measured_variant="on",
            target_resolution_relative=0.01,
            resolution_multiplier=2.0,
        )
        self.assertAlmostEqual(
            summary["metrics"]["child_cpu_seconds"]["relative_delta"]["mean"], 0.01
        )
        self.assertAlmostEqual(
            summary["metrics"]["wall_elapsed_seconds"]["relative_delta"]["mean"], 0.02
        )
        self.assertTrue(summary["production_baseline_resolution_qualified"])


if __name__ == "__main__":
    unittest.main()
