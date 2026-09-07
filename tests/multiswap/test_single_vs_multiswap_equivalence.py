from __future__ import annotations

import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from t0_harness import (
    ColumnSpec,
    ColumnState,
    DeterministicTestKernel,
    WorkerScratch,
    run_multiswap,
    synthetic_columns,
    synthetic_states,
)


TARGET = ColumnSpec(
    column_id=9001,
    physics_signature="physics-1",
    parameter_id="par-target",
    inflow_units_per_tick=17,
    outflow_units_per_tick=4,
)
TARGET_STATE = ColumnState(water_units=4321, cursor=7)


def standalone_result(*, t0: int, t1: int, poison_marker: int | None = None):
    scratch = WorkerScratch()
    if poison_marker is not None:
        scratch.poison(poison_marker)
    kernel = DeterministicTestKernel()
    status, endpoint, counters, mass = kernel.advance(
        TARGET,
        TARGET_STATE,
        t0,
        t1,
        scratch,
        fail=False,
    )
    return status, endpoint, counters, mass


def semantic_multiswap_row(row):
    return row.status, row.committed_state, dict(row.counters), dict(row.mass)


class TestSingleVsMultiSWAPEquivalence(unittest.TestCase):
    def test_p01_direct_standalone_equals_one_column_runtime_exactly(self) -> None:
        expected = standalone_result(t0=11, t1=16)
        result = run_multiswap(
            [TARGET],
            {TARGET.column_id: TARGET_STATE},
            t0=11,
            t1=16,
            batch_size=1,
            worker_count=1,
            poison_scratch=True,
        )
        self.assertEqual(semantic_multiswap_row(result.columns[TARGET.column_id]), expected)
        self.assertEqual(result.run_counters, expected[2])

    def test_p01_target_embedded_in_17_columns_matches_standalone(self) -> None:
        expected = standalone_result(t0=3, t1=9, poison_marker=123456)
        neighbours = synthetic_columns(16, templates=3)
        columns = neighbours + [TARGET]
        states = synthetic_states(neighbours)
        states[TARGET.column_id] = TARGET_STATE

        configurations = (
            (1, 1, "forward", 0),
            (3, 2, "reverse", 0),
            (5, 4, "seeded", 431),
            (8, 8, "seeded", 999),
            (17, 3, "reverse", 0),
        )
        for batch_size, workers, ordering, seed in configurations:
            with self.subTest(
                batch_size=batch_size,
                workers=workers,
                ordering=ordering,
                seed=seed,
            ):
                result = run_multiswap(
                    columns,
                    states,
                    t0=3,
                    t1=9,
                    batch_size=batch_size,
                    worker_count=workers,
                    ordering=ordering,
                    seed=seed,
                    poison_scratch=True,
                )
                self.assertEqual(
                    semantic_multiswap_row(result.columns[TARGET.column_id]),
                    expected,
                )

    def test_p01_neighbour_physics_and_forcing_do_not_change_target(self) -> None:
        expected = standalone_result(t0=20, t1=23)

        neighbours_a = synthetic_columns(8, templates=2)
        neighbours_b = [
            ColumnSpec(
                column_id=column.column_id,
                physics_signature=f"other-{column.column_id % 4}",
                parameter_id=f"other-par-{column.column_id}",
                inflow_units_per_tick=1000 + column.column_id,
                outflow_units_per_tick=200 + column.column_id,
            )
            for column in neighbours_a
        ]

        for neighbours in (neighbours_a, neighbours_b):
            columns = neighbours + [TARGET]
            states = synthetic_states(neighbours)
            states[TARGET.column_id] = TARGET_STATE
            result = run_multiswap(
                columns,
                states,
                t0=20,
                t1=23,
                batch_size=3,
                worker_count=4,
                ordering="seeded",
                seed=73,
                poison_scratch=True,
            )
            self.assertEqual(
                semantic_multiswap_row(result.columns[TARGET.column_id]),
                expected,
            )

    def test_p01_worker_and_batch_attribution_are_not_physical_semantics(self) -> None:
        expected = standalone_result(t0=5, t1=7)
        neighbours = synthetic_columns(16, templates=4)
        columns = neighbours + [TARGET]
        states = synthetic_states(neighbours)
        states[TARGET.column_id] = TARGET_STATE

        rows = []
        for batch_size, workers, ordering, seed in (
            (2, 2, "forward", 0),
            (7, 5, "reverse", 0),
            (16, 8, "seeded", 123),
        ):
            result = run_multiswap(
                columns,
                states,
                t0=5,
                t1=7,
                batch_size=batch_size,
                worker_count=workers,
                ordering=ordering,
                seed=seed,
                poison_scratch=True,
            )
            row = result.columns[TARGET.column_id]
            rows.append(row)
            self.assertEqual(semantic_multiswap_row(row), expected)

        self.assertTrue(len({row.batch_id for row in rows}) > 1 or len({row.worker_id for row in rows}) > 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
