from __future__ import annotations

import argparse
import json
import math
import statistics
import threading
import time
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Callable, Iterable, Iterator, Mapping, MutableMapping, Sequence

SCHEMA_VERSION = "mp-benchmark-record-v1"

TIMING_CATEGORIES = (
    "constitutive",
    "residual",
    "jacobian",
    "linear_solve",
    "newton_control",
    "soil_water_other",
    "surface_atmosphere",
    "crop_et_root",
    "drainage_irrigation",
    "macropore",
    "thermal",
    "solute",
    "crop_growth_nutrients",
    "transaction",
    "runtime_batching",
    "diagnostics",
    "other_kernel",
)

COUNTER_NAMES = (
    "newton_iterations",
    "residual_evaluations",
    "jacobian_builds",
    "linear_solves",
    "backtracking_attempts",
    "retries",
    "timestep_reductions",
    "alternative_linear_solves",
)

MEMORY_NAMES = (
    "persistent_column_state",
    "optional_state",
    "column_bookkeeping",
    "parameter_references",
    "checkpoint",
    "warm_start",
    "worker_scratch_reserved",
    "worker_scratch_peak",
    "jacobian_factorisation",
    "newton_residual_vectors",
    "constitutive_intermediates",
    "process_peak_rss",
)


@dataclass(frozen=True)
class IntervalContext:
    run_id: str
    code_revision: str
    case_id: str
    column_id: str | int
    template_id: str
    physics_signature: str
    numerical_policy_id: str
    execution_class: str
    n_nodes: int
    t0: str
    t1: str
    soil_profile_id: str | None = None
    worker_id: str | int | None = None
    batch_id: str | int | None = None

    def validate(self) -> None:
        for name in (
            "run_id",
            "code_revision",
            "case_id",
            "template_id",
            "physics_signature",
            "numerical_policy_id",
            "execution_class",
            "t0",
            "t1",
        ):
            value = getattr(self, name)
            if not isinstance(value, str) or not value:
                raise ValueError(f"{name} must be a non-empty string")
        if len(self.code_revision) < 7:
            raise ValueError("code_revision must contain at least 7 characters")
        if self.n_nodes < 1:
            raise ValueError("n_nodes must be >= 1")


class _NullIntervalRecorder:
    __slots__ = ()

    @contextmanager
    def span(self, category: str) -> Iterator[None]:
        yield

    def increment(self, name: str, amount: int = 1) -> None:
        return None

    def set_memory(self, name: str, value_bytes: int) -> None:
        return None

    def finish(
        self,
        *,
        accepted: bool,
        mass_balance_residual: float,
        mass_balance_passed: bool,
        mass_balance_tolerance: float | None = None,
        fallback_provenance: str | None = None,
        environment: Mapping[str, Any] | None = None,
    ) -> None:
        return None


class IntervalRecorder:
    def __init__(
        self,
        owner: "MeasurementCollector",
        context: IntervalContext,
        clock_ns: Callable[[], int],
    ) -> None:
        context.validate()
        self._owner = owner
        self._context = context
        self._clock_ns = clock_ns
        self._start_ns = clock_ns()
        self._timing_ns: MutableMapping[str, int] = {name: 0 for name in TIMING_CATEGORIES}
        self._counters: MutableMapping[str, int] = {name: 0 for name in COUNTER_NAMES}
        self._memory: MutableMapping[str, int] = {}
        self._active_span: str | None = None
        self._finished = False

    @contextmanager
    def span(self, category: str) -> Iterator[None]:
        self._ensure_open()
        if category not in TIMING_CATEGORIES:
            raise ValueError(f"unknown timing category: {category}")
        if self._active_span is not None:
            raise RuntimeError(
                f"timing spans are exclusive; {self._active_span!r} is already active"
            )
        self._active_span = category
        started = self._clock_ns()
        try:
            yield
        finally:
            elapsed = self._clock_ns() - started
            if elapsed < 0:
                raise RuntimeError("measurement clock moved backwards")
            self._timing_ns[category] += elapsed
            self._active_span = None

    def increment(self, name: str, amount: int = 1) -> None:
        self._ensure_open()
        if name not in self._counters:
            raise ValueError(f"unknown counter: {name}")
        if not isinstance(amount, int) or amount < 0:
            raise ValueError("counter increment must be a non-negative integer")
        self._counters[name] += amount

    def set_memory(self, name: str, value_bytes: int) -> None:
        self._ensure_open()
        if name not in MEMORY_NAMES:
            raise ValueError(f"unknown memory category: {name}")
        if not isinstance(value_bytes, int) or value_bytes < 0:
            raise ValueError("memory value must be a non-negative integer")
        self._memory[name] = value_bytes

    def finish(
        self,
        *,
        accepted: bool,
        mass_balance_residual: float,
        mass_balance_passed: bool,
        mass_balance_tolerance: float | None = None,
        fallback_provenance: str | None = None,
        environment: Mapping[str, Any] | None = None,
    ) -> dict[str, Any]:
        self._ensure_open()
        if self._active_span is not None:
            raise RuntimeError("cannot finish an interval while a timing span is active")
        if mass_balance_tolerance is not None and mass_balance_tolerance < 0:
            raise ValueError("mass_balance_tolerance must be non-negative")

        elapsed_ns = self._clock_ns() - self._start_ns
        if elapsed_ns < 0:
            raise RuntimeError("measurement clock moved backwards")

        timing_seconds = {
            "total": elapsed_ns / 1_000_000_000.0,
            **{
                key: value / 1_000_000_000.0
                for key, value in self._timing_ns.items()
                if value
            },
        }
        record: dict[str, Any] = {
            "schema_version": SCHEMA_VERSION,
            **asdict(self._context),
            "accepted": bool(accepted),
            "fallback_provenance": fallback_provenance,
            "mass_balance": {
                "residual": float(mass_balance_residual),
                "tolerance": (
                    None if mass_balance_tolerance is None else float(mass_balance_tolerance)
                ),
                "passed": bool(mass_balance_passed),
            },
            "counters": dict(self._counters),
            "timing_seconds": timing_seconds,
        }
        if self._memory:
            record["memory_bytes"] = dict(self._memory)
        if environment:
            record["environment"] = dict(environment)

        self._finished = True
        self._owner._append(record)
        return record

    def _ensure_open(self) -> None:
        if self._finished:
            raise RuntimeError("interval measurement is already finished")


class MeasurementCollector:
    """Measurement-only collector for per-column interval records.

    The disabled path returns a no-op recorder and deliberately does not read the
    clock. The collector never decides whether a physical result is acceptable;
    acceptance and mass-balance status are supplied by the caller.
    """

    def __init__(
        self,
        *,
        enabled: bool = True,
        clock_ns: Callable[[], int] = time.perf_counter_ns,
    ) -> None:
        self.enabled = enabled
        self._clock_ns = clock_ns
        self._records: list[dict[str, Any]] = []
        self._lock = threading.Lock()
        self._null = _NullIntervalRecorder()

    def begin_interval(
        self, context: IntervalContext
    ) -> IntervalRecorder | _NullIntervalRecorder:
        if not self.enabled:
            return self._null
        return IntervalRecorder(self, context, self._clock_ns)

    def _append(self, record: dict[str, Any]) -> None:
        with self._lock:
            self._records.append(record)

    def records(self) -> list[dict[str, Any]]:
        with self._lock:
            return [dict(record) for record in self._records]

    def clear(self) -> None:
        with self._lock:
            self._records.clear()

    def write_jsonl(self, path: str | Path) -> None:
        with Path(path).open("w", encoding="utf-8") as handle:
            for record in self.records():
                handle.write(json.dumps(record, sort_keys=True))
                handle.write("\n")


def _percentile(sorted_values: Sequence[float], q: float) -> float:
    if not sorted_values:
        return 0.0
    if len(sorted_values) == 1:
        return float(sorted_values[0])
    position = (len(sorted_values) - 1) * q
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return float(sorted_values[lower])
    fraction = position - lower
    return float(
        sorted_values[lower] * (1.0 - fraction) + sorted_values[upper] * fraction
    )


def _distribution(values: Sequence[float]) -> dict[str, float]:
    if not values:
        return {
            "min": 0.0,
            "mean": 0.0,
            "p50": 0.0,
            "p90": 0.0,
            "p95": 0.0,
            "p99": 0.0,
            "max": 0.0,
        }
    ordered = sorted(float(value) for value in values)
    return {
        "min": ordered[0],
        "mean": statistics.fmean(ordered),
        "p50": _percentile(ordered, 0.50),
        "p90": _percentile(ordered, 0.90),
        "p95": _percentile(ordered, 0.95),
        "p99": _percentile(ordered, 0.99),
        "max": ordered[-1],
    }


def _top_fraction_share(values: Sequence[float], fraction: float) -> float:
    if not values:
        return 0.0
    total = sum(values)
    if total <= 0:
        return 0.0
    count = max(1, math.ceil(len(values) * fraction))
    return sum(sorted(values, reverse=True)[:count]) / total


def aggregate_records(records: Iterable[Mapping[str, Any]]) -> dict[str, Any]:
    rows = list(records)
    total_times = [float(row["timing_seconds"]["total"]) for row in rows]

    phase_totals: dict[str, float] = {name: 0.0 for name in TIMING_CATEGORIES}
    counter_totals: dict[str, int] = {name: 0 for name in COUNTER_NAMES}
    by_template: dict[str, list[float]] = {}
    by_execution_class: dict[str, list[float]] = {}
    by_batch: dict[str, list[float]] = {}
    worker_totals: dict[str, float] = {}

    accepted = 0
    balance_failed = 0
    for row in rows:
        if row.get("accepted"):
            accepted += 1
        if not bool(row.get("mass_balance", {}).get("passed", False)):
            balance_failed += 1

        timing = row.get("timing_seconds", {})
        for phase in TIMING_CATEGORIES:
            phase_totals[phase] += float(timing.get(phase, 0.0))
        counters = row.get("counters", {})
        for name in COUNTER_NAMES:
            counter_totals[name] += int(counters.get(name, 0))

        total = float(timing.get("total", 0.0))
        template = str(row.get("template_id", "<missing>"))
        execution = str(row.get("execution_class", "<missing>"))
        by_template.setdefault(template, []).append(total)
        by_execution_class.setdefault(execution, []).append(total)

        batch_id = row.get("batch_id")
        if batch_id is not None:
            by_batch.setdefault(str(batch_id), []).append(total)
        worker_id = row.get("worker_id")
        if worker_id is not None:
            key = str(worker_id)
            worker_totals[key] = worker_totals.get(key, 0.0) + total

    batch_divergence = []
    for values in by_batch.values():
        if not values:
            continue
        median = _percentile(sorted(values), 0.50)
        if median > 0:
            batch_divergence.append(max(values) / median)

    worker_imbalance = 0.0
    if worker_totals:
        mean_worker = statistics.fmean(worker_totals.values())
        if mean_worker > 0:
            worker_imbalance = max(worker_totals.values()) / mean_worker

    return {
        "record_count": len(rows),
        "accepted_count": accepted,
        "mass_balance_failure_count": balance_failed,
        "total_cpu_seconds": sum(total_times),
        "total_time_distribution_seconds": _distribution(total_times),
        "top_1pct_total_time_share": _top_fraction_share(total_times, 0.01),
        "phase_totals_seconds": {
            name: value for name, value in phase_totals.items() if value
        },
        "counter_totals": counter_totals,
        "template_distributions_seconds": {
            key: _distribution(values) for key, values in sorted(by_template.items())
        },
        "execution_class_distributions_seconds": {
            key: _distribution(values)
            for key, values in sorted(by_execution_class.items())
        },
        "batch_divergence_max_over_median": _distribution(batch_divergence),
        "worker_load_seconds": dict(sorted(worker_totals.items())),
        "worker_load_max_over_mean": worker_imbalance,
    }


def read_jsonl(path: str | Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with Path(path).open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                records.append(json.loads(stripped))
            except json.JSONDecodeError as exc:
                raise ValueError(f"invalid JSON on line {line_number}: {exc}") from exc
    return records


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="SWAP5 MP measurement utility")
    sub = parser.add_subparsers(dest="command", required=True)
    aggregate = sub.add_parser("aggregate", help="aggregate benchmark JSONL records")
    aggregate.add_argument("input", type=Path)
    aggregate.add_argument("--output", type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    if args.command == "aggregate":
        summary = aggregate_records(read_jsonl(args.input))
        text = json.dumps(summary, indent=2, sort_keys=True) + "\n"
        if args.output:
            args.output.write_text(text, encoding="utf-8")
        else:
            print(text, end="")
        return 0
    raise AssertionError("unreachable")


if __name__ == "__main__":
    raise SystemExit(main())
