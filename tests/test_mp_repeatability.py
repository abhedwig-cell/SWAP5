from __future__ import annotations

import copy
import unittest

from tools.performance.mp_repeatability import (
    rotating_schedule,
    summarize_samples,
    validate_samples,
)


class RepeatabilityTests(unittest.TestCase):
    def setUp(self) -> None:
        digest = "a" * 64
        self.rows = []
        values = {
            0: {"off": 1.00, "on": 1.02},
            1: {"off": 1.02, "on": 1.01},
            2: {"off": 0.99, "on": 1.00},
        }
        for cycle, variants in values.items():
            for variant, wall in variants.items():
                self.rows.append(
                    {
                        "schema_version": "mp-repeatability-samples-v1",
                        "cycle": cycle,
                        "variant": variant,
                        "wall_seconds": wall,
                        "internal_dynamic_seconds": 0.95 if variant == "on" else None,
                        "hashes": {"result.bal": digest, "result.blc": digest},
                    }
                )

    def test_rotating_schedule_balances_first_position(self) -> None:
        schedule = rotating_schedule(["base", "off", "on"], 3)
        self.assertEqual(
            [schedule[index][1] for index in (0, 3, 6)],
            ["base", "off", "on"],
        )

    def test_validate_samples_accepts_constant_physical_hashes(self) -> None:
        self.assertEqual(validate_samples(self.rows), [])

    def test_changed_physical_hash_fails(self) -> None:
        changed = copy.deepcopy(self.rows)
        changed[-1]["hashes"]["result.bal"] = "b" * 64
        self.assertTrue(
            any("physical output hash changed" in error for error in validate_samples(changed))
        )

    def test_duplicate_cycle_variant_fails(self) -> None:
        changed = copy.deepcopy(self.rows)
        changed.append(copy.deepcopy(changed[0]))
        self.assertTrue(
            any("duplicate cycle/variant" in error for error in validate_samples(changed))
        )

    def test_summary_uses_paired_cycles(self) -> None:
        result = summarize_samples(
            self.rows, baseline_variant="off", measured_variant="on"
        )
        self.assertEqual(result["cycle_count"], 3)
        self.assertEqual(result["sample_count"], 6)
        self.assertEqual(result["paired_comparison"]["relative_delta"]["n"], 3)
        self.assertIn("two_standard_error_scale", result["paired_comparison"])

    def test_missing_pair_fails(self) -> None:
        with self.assertRaises(ValueError):
            summarize_samples(
                self.rows[:-1], baseline_variant="off", measured_variant="on"
            )


if __name__ == "__main__":
    unittest.main()
