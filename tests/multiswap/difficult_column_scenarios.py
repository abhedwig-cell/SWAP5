from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping

from t0_harness import ColumnState, synthetic_columns, synthetic_states
from transactional_isolation_harness import (
    TransactionalColumnResult,
    TransactionalRunResult,
    run_transactional_multiswap,
)


@dataclass(frozen=True)
class DifficultScenarioResult:
    baseline: TransactionalRunResult
    candidate: TransactionalRunResult
    initial_states: Mapping[int, ColumnState]
    difficult_column_id: int

    @property
    def normal_column_ids(self) -> tuple[int, ...]:
        return tuple(
            cid for cid in sorted(self.candidate.columns) if cid != self.difficult_column_id
        )

    def normal_semantics_identical(self) -> bool:
        return all(
            self.baseline.columns[cid].semantic_payload()
            == self.candidate.columns[cid].semantic_payload()
            for cid in self.normal_column_ids
        )

    def difficult_counter_delta(self) -> dict[str, int]:
        before = self.baseline.columns[self.difficult_column_id].counters
        after = self.candidate.columns[self.difficult_column_id].counters
        return {
            key: int(after.get(key, 0)) - int(before.get(key, 0))
            for key in sorted(set(before) | set(after))
        }

    def run_counter_delta(self) -> dict[str, int]:
        before = self.baseline.run_counters
        after = self.candidate.run_counters
        return {
            key: int(after.get(key, 0)) - int(before.get(key, 0))
            for key in sorted(set(before) | set(after))
        }

    def all_extra_cost_is_attributed_to_difficult_column(self) -> bool:
        return self.run_counter_delta() == self.difficult_counter_delta()


def run_retry_scenario(
    count: int,
    *,
    difficult_column_id: int,
    batch_size: int,
    worker_count: int,
    ordering: str = "forward",
    seed: int = 0,
    poison_scratch: bool = True,
    poison_seed: int = 0,
) -> DifficultScenarioResult:
    columns = synthetic_columns(count, templates=3)
    states = synthetic_states(columns)
    if difficult_column_id not in states:
        raise ValueError("difficult_column_id must identify one scenario column")

    common = dict(
        t0=20,
        t1=23,
        batch_size=batch_size,
        worker_count=worker_count,
        ordering=ordering,
        seed=seed,
        poison_scratch=poison_scratch,
        poison_seed=poison_seed,
    )
    baseline = run_transactional_multiswap(columns, states, **common)
    candidate = run_transactional_multiswap(
        columns,
        states,
        retry_once_columns={difficult_column_id},
        **common,
    )
    return DifficultScenarioResult(
        baseline=baseline,
        candidate=candidate,
        initial_states=states,
        difficult_column_id=difficult_column_id,
    )


def run_failure_scenario(
    count: int,
    *,
    difficult_column_id: int,
    batch_size: int,
    worker_count: int,
    ordering: str = "forward",
    seed: int = 0,
    poison_scratch: bool = True,
    poison_seed: int = 0,
) -> DifficultScenarioResult:
    columns = synthetic_columns(count, templates=3)
    states = synthetic_states(columns)
    if difficult_column_id not in states:
        raise ValueError("difficult_column_id must identify one scenario column")

    common = dict(
        t0=30,
        t1=34,
        batch_size=batch_size,
        worker_count=worker_count,
        ordering=ordering,
        seed=seed,
        poison_scratch=poison_scratch,
        poison_seed=poison_seed,
    )
    baseline = run_transactional_multiswap(columns, states, **common)
    candidate = run_transactional_multiswap(
        columns,
        states,
        fail_columns={difficult_column_id},
        **common,
    )
    return DifficultScenarioResult(
        baseline=baseline,
        candidate=candidate,
        initial_states=states,
        difficult_column_id=difficult_column_id,
    )
