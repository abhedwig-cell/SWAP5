from __future__ import annotations

import unittest

from difficult_column_scenarios import run_failure_scenario, run_retry_scenario


class TestDifficultColumnScheduling(unittest.TestCase):
    def test_d01_15_plus_1_retry_preserves_all_normal_columns(self) -> None:
        scenario = run_retry_scenario(
            16,
            difficult_column_id=16,
            batch_size=5,
            worker_count=4,
            ordering="seeded",
            seed=431,
            poison_seed=73,
        )
        self.assertEqual(len(scenario.normal_column_ids), 15)
        self.assertTrue(scenario.normal_semantics_identical())
        difficult = scenario.candidate.columns[16]
        baseline = scenario.baseline.columns[16]
        self.assertEqual(difficult.status, "accepted")
        self.assertEqual(difficult.route, ("retry", "accepted"))
        self.assertEqual(difficult.committed_state, baseline.committed_state)
        self.assertEqual(difficult.committed_mass, baseline.committed_mass)
        self.assertEqual(difficult.committed_mass["residual"], 0)

    def test_d01_retry_cost_is_exact_and_fully_attributed(self) -> None:
        scenario = run_retry_scenario(
            16,
            difficult_column_id=16,
            batch_size=4,
            worker_count=4,
            ordering="reverse",
            poison_seed=5,
        )
        delta = scenario.difficult_counter_delta()
        baseline_difficult = scenario.baseline.columns[16]
        self.assertEqual(delta["attempts"], 1)
        self.assertEqual(delta["kernel_calls"], 1)
        self.assertEqual(delta["retries"], 1)
        self.assertEqual(delta["rollbacks"], 1)
        self.assertEqual(delta["commits"], 0)
        self.assertEqual(delta["failures"], 0)
        self.assertEqual(delta["synthetic_ops"], baseline_difficult.counters["synthetic_ops"])
        self.assertTrue(scenario.all_extra_cost_is_attributed_to_difficult_column())

    def test_d01_result_is_worker_order_batch_and_poison_independent(self) -> None:
        hashes = set()
        for batch_size, workers, ordering, seed, poison_seed in (
            (1, 1, "forward", 0, 1),
            (3, 2, "reverse", 0, 2),
            (5, 4, "seeded", 17, 3),
            (16, 8, "seeded", 991, 4),
        ):
            scenario = run_retry_scenario(
                16,
                difficult_column_id=16,
                batch_size=batch_size,
                worker_count=workers,
                ordering=ordering,
                seed=seed,
                poison_seed=poison_seed,
            )
            self.assertTrue(scenario.normal_semantics_identical())
            hashes.add(scenario.candidate.canonical_hash())
        self.assertEqual(len(hashes), 1)

    def test_d01_difficult_diagnostics_do_not_leak_to_normals(self) -> None:
        scenario = run_retry_scenario(
            16,
            difficult_column_id=16,
            batch_size=7,
            worker_count=4,
            ordering="seeded",
            seed=7,
            poison_seed=99,
        )
        for cid in scenario.normal_column_ids:
            row = scenario.candidate.columns[cid]
            self.assertEqual(row.route, ("accepted",))
            self.assertEqual(row.counters["attempts"], 1)
            self.assertEqual(row.counters["retries"], 0)
            self.assertEqual(row.counters["rollbacks"], 0)
            self.assertEqual(row.counters["failures"], 0)

    def test_d02_31_plus_1_retry_preserves_normal_columns(self) -> None:
        scenario = run_retry_scenario(
            32,
            difficult_column_id=32,
            batch_size=9,
            worker_count=8,
            ordering="seeded",
            seed=2103,
            poison_seed=88,
        )
        self.assertEqual(len(scenario.normal_column_ids), 31)
        self.assertTrue(scenario.normal_semantics_identical())
        self.assertEqual(scenario.candidate.columns[32].route, ("retry", "accepted"))
        self.assertTrue(scenario.all_extra_cost_is_attributed_to_difficult_column())

    def test_d02_retry_result_is_partition_independent(self) -> None:
        hashes = {
            run_retry_scenario(
                32,
                difficult_column_id=32,
                batch_size=batch_size,
                worker_count=workers,
                ordering=ordering,
                seed=seed,
                poison_seed=seed + 100,
            ).candidate.canonical_hash()
            for batch_size, workers, ordering, seed in (
                (1, 1, "forward", 1),
                (5, 3, "reverse", 2),
                (8, 4, "seeded", 3),
                (13, 8, "seeded", 4),
                (32, 8, "reverse", 5),
            )
        }
        self.assertEqual(len(hashes), 1)

    def test_d02_terminal_failure_is_bounded_and_isolated(self) -> None:
        scenario = run_failure_scenario(
            32,
            difficult_column_id=32,
            batch_size=8,
            worker_count=8,
            ordering="seeded",
            seed=404,
            poison_seed=505,
        )
        self.assertTrue(scenario.normal_semantics_identical())
        difficult = scenario.candidate.columns[32]
        self.assertEqual(difficult.status, "failed")
        self.assertEqual(difficult.route, ("failed",))
        self.assertEqual(difficult.committed_state, scenario.initial_states[32])
        self.assertEqual(difficult.committed_mass["storage_start"], scenario.initial_states[32].water_units)
        self.assertEqual(difficult.committed_mass["storage_end"], scenario.initial_states[32].water_units)
        self.assertEqual(difficult.committed_mass["inflow"], 0)
        self.assertEqual(difficult.committed_mass["outflow"], 0)
        self.assertEqual(difficult.committed_mass["residual"], 0)
        self.assertEqual(scenario.candidate.run_counters["failures"], 1)
        self.assertEqual(scenario.candidate.run_counters["commits"], 31)

    def test_d02_terminal_failure_is_order_worker_batch_independent(self) -> None:
        hashes = set()
        for batch_size, workers, ordering, seed in (
            (1, 1, "forward", 10),
            (4, 2, "reverse", 11),
            (7, 4, "seeded", 12),
            (16, 8, "seeded", 13),
        ):
            scenario = run_failure_scenario(
                32,
                difficult_column_id=32,
                batch_size=batch_size,
                worker_count=workers,
                ordering=ordering,
                seed=seed,
                poison_seed=seed * 13,
            )
            self.assertTrue(scenario.normal_semantics_identical())
            hashes.add(scenario.candidate.canonical_hash())
        self.assertEqual(len(hashes), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
