from __future__ import annotations
import unittest

from t0_harness import synthetic_columns, synthetic_states
from transactional_isolation_harness import (
    run_independent_references,
    run_transactional_multiswap,
)


class TransactionalIsolationTests(unittest.TestCase):
    def test_p07_terminal_failure_rolls_back_only_failed_column(self) -> None:
        columns = synthetic_columns(17, templates=3)
        states = synthetic_states(columns)
        baseline = run_transactional_multiswap(
            columns, states, t0=10, t1=13, batch_size=5, worker_count=4
        )
        failed = run_transactional_multiswap(
            columns,
            states,
            t0=10,
            t1=13,
            batch_size=5,
            worker_count=4,
            fail_columns={9},
            poison_scratch=True,
            poison_seed=70,
        )
        self.assertEqual(failed.columns[9].committed_state, states[9])
        self.assertEqual(failed.columns[9].route, ("failed",))
        self.assertEqual(failed.columns[9].counters["rollbacks"], 1)
        self.assertEqual(failed.columns[9].counters["commits"], 0)
        for cid in set(states) - {9}:
            self.assertEqual(
                failed.columns[cid].semantic_payload(),
                baseline.columns[cid].semantic_payload(),
            )

    def test_p08_retry_restarts_from_checkpoint_and_isolates_others(self) -> None:
        columns = synthetic_columns(8)
        states = synthetic_states(columns)
        baseline = run_transactional_multiswap(
            columns, states, t0=3, t1=6, batch_size=4, worker_count=4
        )
        retried = run_transactional_multiswap(
            columns,
            states,
            t0=3,
            t1=6,
            batch_size=4,
            worker_count=4,
            retry_once_columns={3},
            poison_scratch=True,
            poison_seed=91,
        )
        self.assertEqual(
            retried.columns[3].committed_state,
            baseline.columns[3].committed_state,
        )
        self.assertEqual(
            retried.columns[3].committed_mass,
            baseline.columns[3].committed_mass,
        )
        self.assertEqual(retried.columns[3].route, ("retry", "accepted"))
        self.assertEqual(retried.columns[3].counters["attempts"], 2)
        self.assertEqual(retried.columns[3].counters["retries"], 1)
        self.assertEqual(retried.columns[3].counters["rollbacks"], 1)
        self.assertEqual(retried.columns[3].counters["commits"], 1)
        for cid in set(states) - {3}:
            self.assertEqual(
                retried.columns[cid].semantic_payload(),
                baseline.columns[cid].semantic_payload(),
            )

    def test_p18_17_columns_interleaved_equal_independent_references(self) -> None:
        columns = synthetic_columns(17, templates=3)
        states = synthetic_states(columns)
        retry = {2, 7, 13}
        interleaved = run_transactional_multiswap(
            columns,
            states,
            t0=1,
            t1=4,
            batch_size=5,
            worker_count=4,
            ordering="seeded",
            seed=123,
            retry_once_columns=retry,
            poison_scratch=True,
            poison_seed=456,
        )
        refs = run_independent_references(
            columns,
            states,
            t0=1,
            t1=4,
            retry_once_columns=retry,
        )
        self.assertTrue(
            any(attempt == 2 for _, attempt, _, _, _ in interleaved.execution_log)
        )
        for cid in states:
            self.assertEqual(
                interleaved.columns[cid].semantic_payload(),
                refs[cid].semantic_payload(),
            )

    def test_p19_scratch_poison_patterns_do_not_change_results(self) -> None:
        columns = synthetic_columns(17)
        states = synthetic_states(columns)
        retry = {4, 9, 15}
        clean = run_transactional_multiswap(
            columns,
            states,
            t0=0,
            t1=2,
            batch_size=5,
            worker_count=4,
            ordering="seeded",
            seed=22,
            retry_once_columns=retry,
        )
        poisoned_a = run_transactional_multiswap(
            columns,
            states,
            t0=0,
            t1=2,
            batch_size=5,
            worker_count=4,
            ordering="seeded",
            seed=22,
            retry_once_columns=retry,
            poison_scratch=True,
            poison_seed=1,
        )
        poisoned_b = run_transactional_multiswap(
            columns,
            states,
            t0=0,
            t1=2,
            batch_size=5,
            worker_count=4,
            ordering="seeded",
            seed=22,
            retry_once_columns=retry,
            poison_scratch=True,
            poison_seed=999999,
        )
        self.assertEqual(clean.canonical_hash(), poisoned_a.canonical_hash())
        self.assertEqual(clean.canonical_hash(), poisoned_b.canonical_hash())

    def test_order_worker_batch_independence_under_retries_31_columns(self) -> None:
        columns = synthetic_columns(31, templates=4)
        states = synthetic_states(columns)
        retry = {1, 8, 17, 31}
        serial = run_transactional_multiswap(
            columns,
            states,
            t0=7,
            t1=11,
            batch_size=1,
            worker_count=1,
            ordering="forward",
            retry_once_columns=retry,
            poison_scratch=True,
            poison_seed=8,
        )
        reverse = run_transactional_multiswap(
            columns,
            states,
            t0=7,
            t1=11,
            batch_size=8,
            worker_count=4,
            ordering="reverse",
            retry_once_columns=retry,
            poison_scratch=True,
            poison_seed=9,
        )
        seeded = run_transactional_multiswap(
            columns,
            states,
            t0=7,
            t1=11,
            batch_size=17,
            worker_count=8,
            ordering="seeded",
            seed=431,
            retry_once_columns=retry,
            poison_scratch=True,
            poison_seed=10,
        )
        self.assertEqual(serial.canonical_hash(), reverse.canonical_hash())
        self.assertEqual(serial.canonical_hash(), seeded.canonical_hash())

    def test_retry_and_failure_coexist_32_columns(self) -> None:
        columns = synthetic_columns(32, templates=4)
        states = synthetic_states(columns)
        retry = {5, 11, 27}
        failures = {16, 32}
        run = run_transactional_multiswap(
            columns,
            states,
            t0=2,
            t1=5,
            batch_size=7,
            worker_count=8,
            ordering="seeded",
            seed=5,
            retry_once_columns=retry,
            fail_columns=failures,
            poison_scratch=True,
            poison_seed=17,
        )
        baseline = run_transactional_multiswap(
            columns,
            states,
            t0=2,
            t1=5,
            batch_size=7,
            worker_count=8,
            ordering="seeded",
            seed=5,
        )
        self.assertEqual(run.run_counters["retries"], 3)
        self.assertEqual(run.run_counters["failures"], 2)
        self.assertEqual(run.run_counters["rollbacks"], 5)
        self.assertEqual(run.run_counters["commits"], 30)
        self.assertEqual(run.run_counters["attempts"], 35)
        for cid in failures:
            self.assertEqual(run.columns[cid].committed_state, states[cid])
        for cid in set(states) - failures:
            self.assertEqual(
                run.columns[cid].committed_state,
                baseline.columns[cid].committed_state,
            )

    def test_p13_template_grouping_does_not_change_target_outcome(self) -> None:
        columns = synthetic_columns(8, templates=2)
        states = synthetic_states(columns)
        target = columns[5]
        cid = target.column_id
        multi = run_transactional_multiswap(
            columns,
            states,
            t0=1,
            t1=3,
            batch_size=3,
            worker_count=4,
            ordering="reverse",
            retry_once_columns={cid},
        )
        single = run_transactional_multiswap(
            [target],
            {cid: states[cid]},
            t0=1,
            t1=3,
            batch_size=1,
            worker_count=1,
            retry_once_columns={cid},
        )
        self.assertEqual(
            multi.columns[cid].semantic_payload(),
            single.columns[cid].semantic_payload(),
        )

    def test_rejected_trial_mass_is_not_double_counted(self) -> None:
        columns = synthetic_columns(1)
        states = synthetic_states(columns)
        spec = columns[0]
        cid = spec.column_id
        run = run_transactional_multiswap(
            columns,
            states,
            t0=4,
            t1=7,
            batch_size=1,
            worker_count=1,
            retry_once_columns={cid},
        )
        mass = run.columns[cid].committed_mass
        duration = 3
        self.assertEqual(mass["inflow"], spec.inflow_units_per_tick * duration)
        self.assertEqual(mass["outflow"], spec.outflow_units_per_tick * duration)
        self.assertEqual(mass["residual"], 0)
        self.assertEqual(run.columns[cid].counters["attempts"], 2)
        self.assertEqual(run.columns[cid].counters["commits"], 1)

    def test_invalid_retry_failure_sets_fail_closed(self) -> None:
        columns = synthetic_columns(2)
        states = synthetic_states(columns)
        with self.assertRaises(ValueError):
            run_transactional_multiswap(
                columns,
                states,
                t0=0,
                t1=1,
                batch_size=1,
                worker_count=1,
                retry_once_columns={1},
                fail_columns={1},
            )
        with self.assertRaises(ValueError):
            run_transactional_multiswap(
                columns,
                states,
                t0=0,
                t1=1,
                batch_size=1,
                worker_count=1,
                retry_once_columns={99},
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
