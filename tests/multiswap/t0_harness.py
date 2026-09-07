from __future__ import annotations

from dataclasses import dataclass, replace
from hashlib import sha256
import json
import random
from typing import Iterable, Mapping, Sequence


@dataclass(frozen=True)
class ColumnSpec:
    column_id: int
    physics_signature: str
    parameter_id: str
    inflow_units_per_tick: int
    outflow_units_per_tick: int


@dataclass(frozen=True)
class ColumnState:
    water_units: int
    cursor: int = 0


@dataclass(frozen=True)
class Batch:
    batch_id: str
    template_id: str
    column_ids: tuple[int, ...]


@dataclass(frozen=True)
class Job:
    batch_id: str
    template_id: str
    column_id: int


@dataclass(frozen=True)
class ColumnResult:
    column_id: int
    status: str
    committed_state: ColumnState
    batch_id: str
    worker_id: int
    counters: Mapping[str, int]
    mass: Mapping[str, int]


@dataclass(frozen=True)
class RunResult:
    columns: Mapping[int, ColumnResult]
    batch_counters: Mapping[str, Mapping[str, int]]
    run_counters: Mapping[str, int]
    execution_log: tuple[tuple[int, int, str], ...]

    def canonical_payload(self) -> dict:
        return {
            "columns": {
                str(cid): {
                    "status": result.status,
                    "state": {
                        "water_units": result.committed_state.water_units,
                        "cursor": result.committed_state.cursor,
                    },
                    "counters": dict(sorted(result.counters.items())),
                    "mass": dict(sorted(result.mass.items())),
                }
                for cid, result in sorted(self.columns.items())
            },
            "run_counters": dict(sorted(self.run_counters.items())),
        }

    def canonical_hash(self) -> str:
        payload = json.dumps(self.canonical_payload(), sort_keys=True, separators=(",", ":"))
        return sha256(payload.encode("utf-8")).hexdigest()


class DuplicateColumnIdError(ValueError):
    pass


def validate_unique_column_ids(columns: Sequence[ColumnSpec]) -> None:
    seen: set[int] = set()
    for column in columns:
        if column.column_id in seen:
            raise DuplicateColumnIdError(f"duplicate column_id {column.column_id}")
        seen.add(column.column_id)


def template_id_for(column: ColumnSpec) -> str:
    token = column.physics_signature.strip().lower().encode("utf-8")
    return f"tpl-{sha256(token).hexdigest()[:12]}"


def build_batches(columns: Sequence[ColumnSpec], batch_size: int) -> tuple[Batch, ...]:
    if batch_size < 1:
        raise ValueError("batch_size must be >= 1")
    validate_unique_column_ids(columns)
    groups: dict[str, list[int]] = {}
    for column in columns:
        groups.setdefault(template_id_for(column), []).append(column.column_id)
    batches: list[Batch] = []
    for template_id in sorted(groups):
        ids = sorted(groups[template_id])
        for chunk_index, start in enumerate(range(0, len(ids), batch_size)):
            chunk = tuple(ids[start : start + batch_size])
            batches.append(
                Batch(
                    batch_id=f"{template_id}-b{chunk_index:04d}",
                    template_id=template_id,
                    column_ids=chunk,
                )
            )
    return tuple(batches)


def flatten_jobs(batches: Sequence[Batch]) -> list[Job]:
    return [
        Job(batch.batch_id, batch.template_id, column_id)
        for batch in batches
        for column_id in batch.column_ids
    ]


def ordered_jobs(jobs: Sequence[Job], ordering: str, seed: int = 0) -> list[Job]:
    result = list(jobs)
    if ordering == "forward":
        return result
    if ordering == "reverse":
        return list(reversed(result))
    if ordering == "seeded":
        rng = random.Random(seed)
        rng.shuffle(result)
        return result
    raise ValueError(f"unsupported ordering {ordering}")


@dataclass
class WorkerScratch:
    marker: int = 0
    temp_units: int = 0

    def poison(self, marker: int) -> None:
        self.marker = marker
        self.temp_units = marker * 10_000_019

    def reset_for_job(self, column_id: int) -> None:
        self.marker = column_id
        self.temp_units = 0


class DeterministicTestKernel:
    """Cheap exact-arithmetic kernel for runtime qualification only."""

    def advance(
        self,
        spec: ColumnSpec,
        state: ColumnState,
        t0: int,
        t1: int,
        scratch: WorkerScratch,
        *,
        fail: bool = False,
    ) -> tuple[str, ColumnState, dict[str, int], dict[str, int]]:
        if t1 <= t0:
            raise ValueError("t1 must be greater than t0")
        scratch.reset_for_job(spec.column_id)
        duration = t1 - t0
        inflow = spec.inflow_units_per_tick * duration
        outflow = spec.outflow_units_per_tick * duration
        scratch.temp_units = state.water_units + inflow - outflow
        counters = {
            "attempts": 1,
            "kernel_calls": 1,
            "commits": 0 if fail else 1,
            "failures": 1 if fail else 0,
            "synthetic_ops": duration + abs(spec.inflow_units_per_tick) + abs(spec.outflow_units_per_tick),
        }
        if fail:
            mass = {
                "storage_start": state.water_units,
                "storage_end": state.water_units,
                "inflow": 0,
                "outflow": 0,
                "residual": 0,
            }
            return "failed", state, counters, mass
        endpoint = ColumnState(water_units=scratch.temp_units, cursor=state.cursor + 1)
        residual = endpoint.water_units - state.water_units - inflow + outflow
        mass = {
            "storage_start": state.water_units,
            "storage_end": endpoint.water_units,
            "inflow": inflow,
            "outflow": outflow,
            "residual": residual,
        }
        return "accepted", endpoint, counters, mass


def _sum_counters(rows: Iterable[Mapping[str, int]]) -> dict[str, int]:
    total: dict[str, int] = {}
    for row in rows:
        for key, value in row.items():
            total[key] = total.get(key, 0) + int(value)
    return total


def run_multiswap(
    columns: Sequence[ColumnSpec],
    states: Mapping[int, ColumnState],
    *,
    t0: int,
    t1: int,
    batch_size: int,
    worker_count: int,
    ordering: str = "forward",
    seed: int = 0,
    fail_columns: Iterable[int] = (),
    poison_scratch: bool = False,
) -> RunResult:
    if worker_count < 1:
        raise ValueError("worker_count must be >= 1")
    validate_unique_column_ids(columns)
    column_map = {column.column_id: column for column in columns}
    if set(states) != set(column_map):
        raise ValueError("states must match columns exactly")
    batches = build_batches(columns, batch_size)
    jobs = ordered_jobs(flatten_jobs(batches), ordering, seed)
    workers = [WorkerScratch() for _ in range(worker_count)]
    if poison_scratch:
        for index, scratch in enumerate(workers, start=1):
            scratch.poison(10_000 + index)
    fail_set = set(fail_columns)
    kernel = DeterministicTestKernel()
    results: dict[int, ColumnResult] = {}
    execution_log: list[tuple[int, int, str]] = []

    for ordinal, job in enumerate(jobs):
        worker_id = ordinal % worker_count
        scratch = workers[worker_id]
        status, endpoint, counters, mass = kernel.advance(
            column_map[job.column_id],
            states[job.column_id],
            t0,
            t1,
            scratch,
            fail=job.column_id in fail_set,
        )
        if job.column_id in results:
            raise RuntimeError(f"duplicate execution of column {job.column_id}")
        results[job.column_id] = ColumnResult(
            column_id=job.column_id,
            status=status,
            committed_state=endpoint,
            batch_id=job.batch_id,
            worker_id=worker_id,
            counters=counters,
            mass=mass,
        )
        execution_log.append((job.column_id, worker_id, job.batch_id))

    if set(results) != set(column_map):
        raise RuntimeError("scheduler lost one or more columns")

    by_batch: dict[str, list[Mapping[str, int]]] = {}
    for result in results.values():
        by_batch.setdefault(result.batch_id, []).append(result.counters)
    batch_counters = {
        batch_id: _sum_counters(rows) for batch_id, rows in sorted(by_batch.items())
    }
    run_counters = _sum_counters(result.counters for result in results.values())
    return RunResult(
        columns=results,
        batch_counters=batch_counters,
        run_counters=run_counters,
        execution_log=tuple(execution_log),
    )


def clone_states(states: Mapping[int, ColumnState]) -> dict[int, ColumnState]:
    return {column_id: replace(state) for column_id, state in states.items()}


def synthetic_columns(count: int, *, templates: int = 2) -> list[ColumnSpec]:
    if count < 1:
        return []
    if templates < 1:
        raise ValueError("templates must be >= 1")
    return [
        ColumnSpec(
            column_id=index + 1,
            physics_signature=f"physics-{index % templates}",
            parameter_id=f"par-{(index * 7) % 5}",
            inflow_units_per_tick=10 + (index % 4),
            outflow_units_per_tick=3 + (index % 3),
        )
        for index in range(count)
    ]


def synthetic_states(columns: Sequence[ColumnSpec]) -> dict[int, ColumnState]:
    return {
        column.column_id: ColumnState(water_units=1000 + 17 * column.column_id)
        for column in columns
    }
