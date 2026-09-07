from __future__ import annotations

import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from t0_harness import (
    ColumnSpec,
    DuplicateColumnIdError,
    build_batches,
    clone_states,
    run_multiswap,
    synthetic_columns,
    synthetic_states,
    template_id_for,
    validate_unique_column_ids,
)


class T0HarnessTests(unittest.TestCase):
    def test_r01_column_ids_stable_and_duplicates_rejected(self) -> None:
        columns = synthetic_columns(4)
        validate_unique_column_ids(columns)
        states = synthetic_states(columns)
        result = run_multiswap(columns, states, t0=0, t1=1, batch_size=2, worker_count=2)
        self.assertEqual(set(result.columns), {1, 2, 3, 4})
        duplicate = list(columns) + [columns[0]]
        with self.assertRaises(DuplicateColumnIdError):
            validate_unique_column_ids(duplicate)

    def test_r02_template_classification_deterministic_and_homogeneous(self) -> None:
        columns = synthetic_columns(8, templates=3)
        self.assertEqual(template_id_for(columns[0]), template_id_for(columns[3]))
        self.assertNotEqual(template_id_for(columns[0]), template_id_for(columns[1]))
        for batch in build_batches(columns, batch_size=4):
            signatures = {
                column.physics_signature
                for column in columns
                if column.column_id in batch.column_ids
            }
            self.assertEqual(len(signatures), 1)

    def test_r03_partition_covers_17_exactly_once(self) -> None:
        columns = synthetic_columns(17, templates=3)
        batches = build_batches(columns, batch_size=5)
        flattened = [cid for batch in batches for cid in batch.column_ids]
        self.assertEqual(sorted(flattened), list(range(1, 18)))
        self.assertEqual(len(flattened), len(set(flattened)))

    def test_r04_dispatch_executes_each_job_once(self) -> None:
        columns = synthetic_columns(8)
        states = synthetic_states(columns)
        result = run_multiswap(columns, states, t0=2, t1=5, batch_size=3, worker_count=4)
        executed = [column_id for column_id, _, _ in result.execution_log]
        self.assertEqual(sorted(executed), list(range(1, 9)))
        self.assertEqual(len(executed), len(set(executed)))
        self.assertTrue(all(0 <= worker_id < 4 for _, worker_id, _ in result.execution_log))

    def test_r05_and_p09_failure_isolation(self) -> None:
        columns = synthetic_columns(17)
        states = synthetic_states(columns)
        baseline = run_multiswap(columns, states, t0=0, t1=2, batch_size=4, worker_count=4)
        failed = run_multiswap(
            columns,
            states,
            t0=0,
            t1=2,
            batch_size=4,
            worker_count=4,
            fail_columns={9},
        )
        self.assertEqual(failed.columns[9].status, "failed")
        self.assertEqual(failed.columns[9].committed_state, states[9])
        for column_id in set(range(1, 18)) - {9}:
            self.assertEqual(
                failed.columns[column_id].committed_state,
                baseline.columns[column_id].committed_state,
            )
            self.assertEqual(failed.columns[column_id].mass, baseline.columns[column_id].mass)
        self.assertEqual(failed.run_counters["failures"], 1)
        self.assertEqual(failed.run_counters["commits"], 16)

    def test_r06_and_p02_ordering_independence(self) -> None:
        columns = synthetic_columns(17, templates=3)
        states = synthetic_states(columns)
        forward = run_multiswap(columns, states, t0=4, t1=7, batch_size=5, worker_count=4)
        reverse = run_multiswap(
            columns, states, t0=4, t1=7, batch_size=5, worker_count=4, ordering="reverse"
        )
        seeded = run_multiswap(
            columns,
            states,
            t0=4,
            t1=7,
            batch_size=5,
            worker_count=4,
            ordering="seeded",
            seed=431,
        )
        self.assertEqual(forward.canonical_hash(), reverse.canonical_hash())
        self.assertEqual(forward.canonical_hash(), seeded.canonical_hash())

    def test_r07_and_p15_diagnostics_aggregate_exactly(self) -> None:
        columns = synthetic_columns(8)
        states = synthetic_states(columns)
        result = run_multiswap(columns, states, t0=0, t1=3, batch_size=3, worker_count=4)
        per_column_commits = sum(r.counters["commits"] for r in result.columns.values())
        per_column_calls = sum(r.counters["kernel_calls"] for r in result.columns.values())
        self.assertEqual(result.run_counters["commits"], per_column_commits)
        self.assertEqual(result.run_counters["kernel_calls"], per_column_calls)
        self.assertEqual(
            sum(batch["commits"] for batch in result.batch_counters.values()),
            result.run_counters["commits"],
        )

    def test_r08_deterministic_checkpoint_replay_two_intervals(self) -> None:
        columns = synthetic_columns(8)
        checkpoint = synthetic_states(columns)

        first_a = run_multiswap(
            columns,
            clone_states(checkpoint),
            t0=10,
            t1=12,
            batch_size=3,
            worker_count=4,
            ordering="seeded",
            seed=17,
            poison_scratch=True,
        )
        states_a = {cid: row.committed_state for cid, row in first_a.columns.items()}
        second_a = run_multiswap(
            columns,
            states_a,
            t0=12,
            t1=15,
            batch_size=5,
            worker_count=3,
            ordering="reverse",
            poison_scratch=True,
        )

        first_b = run_multiswap(
            columns,
            clone_states(checkpoint),
            t0=10,
            t1=12,
            batch_size=8,
            worker_count=1,
            ordering="reverse",
            poison_scratch=True,
        )
        states_b = {cid: row.committed_state for cid, row in first_b.columns.items()}
        second_b = run_multiswap(
            columns,
            states_b,
            t0=12,
            t1=15,
            batch_size=2,
            worker_count=8,
            ordering="seeded",
            seed=99,
            poison_scratch=True,
        )

        self.assertEqual(first_a.canonical_hash(), first_b.canonical_hash())
        self.assertEqual(second_a.canonical_hash(), second_b.canonical_hash())
        self.assertTrue(all(row.mass["residual"] == 0 for row in second_a.columns.values()))

    def test_p03_worker_count_independence_testdouble(self) -> None:
        columns = synthetic_columns(8)
        states = synthetic_states(columns)
        hashes = {
            run_multiswap(
                columns,
                states,
                t0=0,
                t1=2,
                batch_size=3,
                worker_count=workers,
                ordering="seeded",
                seed=88,
                poison_scratch=True,
            ).canonical_hash()
            for workers in (1, 2, 3, 4, 8)
        }
        self.assertEqual(len(hashes), 1)

    def test_p04_batch_size_independence(self) -> None:
        columns = synthetic_columns(17, templates=3)
        states = synthetic_states(columns)
        hashes = {
            run_multiswap(
                columns,
                states,
                t0=1,
                t1=4,
                batch_size=batch_size,
                worker_count=4,
                ordering="seeded",
                seed=51,
            ).canonical_hash()
            for batch_size in (1, 3, 5, 8, 17)
        }
        self.assertEqual(len(hashes), 1)

    def test_p05_clone_identity(self) -> None:
        columns = synthetic_columns(3)
        states = synthetic_states(columns)
        cloned = clone_states(states)
        self.assertEqual(states, cloned)
        self.assertIsNot(states, cloned)
        cloned[1] = type(cloned[1])(water_units=9999, cursor=cloned[1].cursor)
        self.assertNotEqual(states[1], cloned[1])

    def test_p06_scratch_poisoning_is_reconstructible(self) -> None:
        columns = synthetic_columns(8)
        states = synthetic_states(columns)
        clean = run_multiswap(columns, states, t0=0, t1=2, batch_size=4, worker_count=8)
        poisoned = run_multiswap(
            columns,
            states,
            t0=0,
            t1=2,
            batch_size=4,
            worker_count=8,
            poison_scratch=True,
        )
        self.assertEqual(clean.canonical_hash(), poisoned.canonical_hash())

    def test_p12_local_forcing_change_does_not_touch_other_columns(self) -> None:
        columns = synthetic_columns(8)
        states = synthetic_states(columns)
        baseline = run_multiswap(columns, states, t0=0, t1=3, batch_size=4, worker_count=4)
        changed = list(columns)
        target = changed[4]
        changed[4] = ColumnSpec(
            column_id=target.column_id,
            physics_signature=target.physics_signature,
            parameter_id=target.parameter_id,
            inflow_units_per_tick=target.inflow_units_per_tick + 100,
            outflow_units_per_tick=target.outflow_units_per_tick,
        )
        rerun = run_multiswap(changed, states, t0=0, t1=3, batch_size=4, worker_count=4)
        self.assertNotEqual(
            baseline.columns[target.column_id].committed_state,
            rerun.columns[target.column_id].committed_state,
        )
        for column_id in set(range(1, 9)) - {target.column_id}:
            self.assertEqual(
                baseline.columns[column_id].committed_state,
                rerun.columns[column_id].committed_state,
            )


if __name__ == "__main__":
    unittest.main()
