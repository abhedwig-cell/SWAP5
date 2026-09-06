from __future__ import annotations

import unittest

from tools.performance.mp_host_admission import select_cpu, summarize


def payload():
    digest = "a" * 64

    def pair(cycle: int, off: float, on: float):
        return {
            "cycle": cycle,
            "off_child_cpu_seconds": off,
            "on_child_cpu_seconds": on,
            "off_wall_elapsed_seconds": off,
            "on_wall_elapsed_seconds": on,
        }

    return {
        "schema_version": "mp-host-admission-v1",
        "target_resolution_relative": 0.1,
        "resolution_multiplier": 2.0,
        "preflight": {
            "cpu_cv_limit_relative": 0.1,
            "selected_cpu": 1,
            "candidates": {
                "0": {
                    "child_cpu_seconds": [1.0, 1.2, 0.9],
                    "wall_elapsed_seconds": [1.0, 1.2, 0.9],
                    "throttled_events": 0,
                },
                "1": {
                    "child_cpu_seconds": [1.0, 1.01, 0.99],
                    "wall_elapsed_seconds": [1.0, 1.01, 0.99],
                    "throttled_events": 0,
                },
            },
        },
        "pilot": {
            "pairs": [
                {"off_child_cpu_seconds": 1.0, "on_child_cpu_seconds": 1.01},
                {"off_child_cpu_seconds": 1.0, "on_child_cpu_seconds": 0.99},
            ],
            "predeclared_final_pairs": 2,
        },
        "final": {
            "pairs": [pair(0, 1.0, 1.01), pair(1, 1.0, 0.99)],
            "physical_output_hashes": {"bal": digest},
            "physical_output_distinct_counts": {"bal": 1},
            "physical_output_observations": 4,
            "measured_sample_throttled_events": 0,
            "measured_sample_throttled_usec": 0,
        },
        "host": {
            "cpu_max": "max 100000",
            "cpuset": "0-1",
            "qualification_window_before": {"nr_throttled": 4, "throttled_usec": 20},
            "qualification_window_after": {"nr_throttled": 4, "throttled_usec": 20},
        },
    }


class HostAdmissionTests(unittest.TestCase):
    def test_selects_quietest_non_throttled_cpu(self) -> None:
        cpu, _ = select_cpu(payload()["preflight"])
        self.assertEqual(cpu, 1)

    def test_summary_can_admit_clean_host(self) -> None:
        summary = summarize(payload())
        self.assertTrue(summary["host_admitted_for_cpu_baseline"])

    def test_selection_rule_fails_closed(self) -> None:
        item = payload()
        item["preflight"]["selected_cpu"] = 0
        with self.assertRaisesRegex(ValueError, "selection rule"):
            summarize(item)

    def test_window_throttling_rejects_host(self) -> None:
        item = payload()
        item["host"]["qualification_window_after"]["nr_throttled"] = 5
        self.assertFalse(summarize(item)["host_admitted_for_cpu_baseline"])

    def test_changed_target_requires_new_predeclared_pair_count(self) -> None:
        item = payload()
        item["target_resolution_relative"] = 0.001
        with self.assertRaises(ValueError):
            summarize(item)


if __name__ == "__main__":
    unittest.main()
