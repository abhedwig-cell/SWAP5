from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from hashlib import sha256
import json
import random
from typing import Iterable, Mapping, Sequence

from t0_harness import (
    ColumnSpec,
    ColumnState,
    Job,
    WorkerScratch,
    build_batches,
    clone_states,
    flatten_jobs,
    ordered_jobs,
    validate_unique_column_ids,
)


@dataclass(frozen=True)
class TransactionalColumnResult:
    column_id: int
    status: str
    committed_state: ColumnState
    route: tuple[str, ...]
    counters: Mapping[str, int]
    committed_mass: Mapping[str, int]

    def semantic_payload(self) -> dict:
        return {
            "status": self.status,
            "state": {
                "water_units": self.committed_state.water_units,
                "cursor": self.committed_state.cursor,
            },
            "route": list(self.route),
            "counters": dict(sorted(self.counters.items())),
            "committed_mass": dict(sorted(self.committed_mass.items())),
        }


@dataclass(frozen=True)
class TransactionalRunResult:
    columns: Mapping[int, TransactionalColumnResult]
    run_counters: Mapping[str, int]
    execution_log: tuple[tuple[int, int, int, str, str], ...]

    def canonical_payload(self) -> dict:
        return {
            "columns": {
                str(cid): result.semantic_payload()
                for cid, result in sorted(self.columns.items())
            },
            "run_counters": dict(sorted(self.run_counters.items())),
        }

    def canonical_hash(self) -> str:
        text = json.dumps(self.canonical_payload(), sort_keys=True, separators=(",", ":"))
        return sha256(text.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class _QueueItem:
    job: Job
    attempt: int


class DeterministicTransactionalTestKernel:
    """Exact-arithmetic trial kernel. It has no SWAP scientific meaning."""

    def trial(
        self,
        spec: ColumnSpec,
        checkpoint: ColumnState,
        t0: int,
        t1: int,
        scratch: WorkerScratch,
    ) -> tuple[ColumnState, dict[str, int], dict[str, int]]:
        if t1 <= t0:
            raise ValueError("t1 must be greater than t0")
        scratch.reset_for_job(spec.column_id)
        duration = t1 - t0
        inflow = spec.inflow_units_per_tick * duration
        outflow = spec.outflow_units_per_tick * duration
        scratch.temp_units = checkpoint.water_units + inflow - outflow
        candidate = ColumnState(
            water_units=scratch.temp_units,
            cursor=checkpoint.cursor + 1,
        )
        trial_mass = {
            "storage_start": checkpoint.water_units,
            "storage_end": candidate.water_units,
            "inflow": inflow,
            "outflow": outflow,
            "residual": candidate.water_units - checkpoint.water_units - inflow + outflow,
        }
        counters = {
            "attempts": 1,
            "kernel_calls": 1,
            "synthetic_ops": duration
            + abs(spec.inflow_units_per_tick)
            + abs(spec.outflow_units_per_tick),
        }
        return candidate, counters, trial_mass


def _zero_counters() -> dict[str, int]:
    return {
        "attempts": 0,
        "kernel_calls": 0,
        "retries": 0,
        "rollbacks": 0,
        "commits": 0,
        "failures": 0,
        "synthetic_ops": 0,
    }


def _add_counters(target: dict[str, int], row: Mapping[str, int]) -> None:
    for key, value in row.items():
        target[key] = target.get(key, 0) + int(value)


def _zero_committed_mass(state: ColumnState) -> dict[str, int]:
    return {
        "storage_start": state.water_units,
        "storage_end": state.water_units,
        "inflow": 0,
        "outflow": 0,
        "residual": 0,
    }


def run_transactional_multiswap(
    columns: Sequence[ColumnSpec],
    states: Mapping[int, ColumnState],
    *,
    t0: int,
    t1: int,
    batch_size: int,
    worker_count: int,
    ordering: str = "forward",
    seed: int = 0,
    retry_once_columns: Iterable[int] = (),
    fail_columns: Iterable[int] = (),
    poison_scratch: bool = False,
    poison_seed: int = 0,
) -> TransactionalRunResult:
    if worker_count < 1:
        raise ValueError("worker_count must be >= 1")
    validate_unique_column_ids(columns)
    column_map = {column.column_id: column for column in columns}
    if set(states) != set(column_map):
        raise ValueError("states must match columns exactly")

    retry_set = set(retry_once_columns)
    fail_set = set(fail_columns)
    known = set(column_map)
    if retry_set - known:
        raise ValueError(f"unknown retry columns {sorted(retry_set-known)}")
    if fail_set - known:
        raise ValueError(f"unknown fail columns {sorted(fail_set-known)}")
    if retry_set & fail_set:
        raise ValueError("retry_once_columns and fail_columns must be disjoint")

    checkpoints = clone_states(states)
    workers = [WorkerScratch() for _ in range(worker_count)]
    batches = build_batches(columns, batch_size)
    initial_jobs = ordered_jobs(flatten_jobs(batches), ordering, seed)
    queue = deque(_QueueItem(job=job, attempt=1) for job in initial_jobs)
    routes: dict[int, list[str]] = {cid: [] for cid in known}
    counters: dict[int, dict[str, int]] = {cid: _zero_counters() for cid in known}
    results: dict[int, TransactionalColumnResult] = {}
    execution_log: list[tuple[int, int, int, str, str]] = []
    kernel = DeterministicTransactionalTestKernel()
    rng = random.Random(poison_seed)
    ordinal = 0

    while queue:
        item = queue.popleft()
        cid = item.job.column_id
        worker_id = ordinal % worker_count
        ordinal += 1
        scratch = workers[worker_id]
        if poison_scratch:
            scratch.poison(rng.randrange(1, 2**31))

        checkpoint = checkpoints[cid]
        candidate, trial_counters, trial_mass = kernel.trial(
            column_map[cid], checkpoint, t0, t1, scratch
        )
        _add_counters(counters[cid], trial_counters)

        if cid in fail_set:
            outcome = "failed"
            counters[cid]["rollbacks"] += 1
            counters[cid]["failures"] += 1
            routes[cid].append(outcome)
            results[cid] = TransactionalColumnResult(
                column_id=cid,
                status=outcome,
                committed_state=checkpoint,
                route=tuple(routes[cid]),
                counters=dict(counters[cid]),
                committed_mass=_zero_committed_mass(checkpoint),
            )
        elif cid in retry_set and item.attempt == 1:
            outcome = "retry"
            counters[cid]["retries"] += 1
            counters[cid]["rollbacks"] += 1
            routes[cid].append(outcome)
            queue.append(_QueueItem(job=item.job, attempt=2))
        else:
            outcome = "accepted"
            if trial_mass["residual"] != 0:
                raise RuntimeError(f"synthetic hard mass gate failed for column {cid}")
            counters[cid]["commits"] += 1
            routes[cid].append(outcome)
            results[cid] = TransactionalColumnResult(
                column_id=cid,
                status=outcome,
                committed_state=candidate,
                route=tuple(routes[cid]),
                counters=dict(counters[cid]),
                committed_mass=trial_mass,
            )

        execution_log.append(
            (cid, item.attempt, worker_id, item.job.batch_id, outcome)
        )

    if set(results) != known:
        raise RuntimeError("scheduler did not produce one terminal result per column")

    run_counters = _zero_counters()
    for result in results.values():
        _add_counters(run_counters, result.counters)

    return TransactionalRunResult(
        columns=results,
        run_counters=run_counters,
        execution_log=tuple(execution_log),
    )


def run_independent_references(
    columns: Sequence[ColumnSpec],
    states: Mapping[int, ColumnState],
    *,
    t0: int,
    t1: int,
    retry_once_columns: Iterable[int] = (),
    fail_columns: Iterable[int] = (),
) -> dict[int, TransactionalColumnResult]:
    retry_set = set(retry_once_columns)
    fail_set = set(fail_columns)
    references: dict[int, TransactionalColumnResult] = {}
    for column in columns:
        cid = column.column_id
        result = run_transactional_multiswap(
            [column],
            {cid: states[cid]},
            t0=t0,
            t1=t1,
            batch_size=1,
            worker_count=1,
            retry_once_columns={cid} if cid in retry_set else (),
            fail_columns={cid} if cid in fail_set else (),
        )
        references[cid] = result.columns[cid]
    return references
