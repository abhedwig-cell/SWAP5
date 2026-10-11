from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.performance.mp_measure import (
    IntervalContext,
    MeasurementCollector,
    aggregate_records,
    read_jsonl,
)


class FakeClock:
    def __init__(self, values: list[int]) -> None:
        self.values = iter(values)
        self.calls = 0

    def __call__(self) -> int:
        self.calls += 1
        return next(self.values)


def context(
    column_id: int = 1,
    batch_id: str = "b1",
    worker_id: str = "w1",
) -> IntervalContext:
    return IntervalContext(
        run_id="run-1",
        code_revision="1234567",
        case_id="case-a",
        column_id=column_id,
        template_id="tpl-full-richards",
        physics_signature="soil+crop+drainage",
        numerical_policy_id="reference",
        execution_class="normal",
        n_nodes=40,
        t0="2026-01-01T03:15:00Z",
        t1="2026-01-01T09:45:00Z",
        worker_id=worker_id,
        batch_id=batch_id,
    )


class MeasurementCollectorTests(unittest.TestCase):
    def test_disabled_collector_does_not_read_clock_or_store_records(self) -> None:
        clock = FakeClock([1])
        collector = MeasurementCollector(enabled=False, clock_ns=clock)
        recorder = collector.begin_interval(context())
        with recorder.span("constitutive"):
            value = sum(range(10))
        recorder.increment("newton_iterations")
        recorder.set_memory("worker_scratch_peak", 1024)
        result = recorder.finish(
            accepted=True,
            mass_balance_residual=0.0,
            mass_balance_passed=True,
            mass_balance_tolerance=1e-10,
        )
        self.assertEqual(value, 45)
        self.assertIsNone(result)
        self.assertEqual(clock.calls, 0)
        self.assertEqual(collector.records(), [])

    def test_collector_emits_schema_aligned_interval_record(self) -> None:
        clock = FakeClock([0, 10, 30, 100])
        collector = MeasurementCollector(clock_ns=clock)
        recorder = collector.begin_interval(context())
        with recorder.span("constitutive"):
            pass
        recorder.increment("newton_iterations", 2)
        recorder.increment("linear_solves", 1)
        recorder.set_memory("persistent_column_state", 800)
        recorder.set_memory("worker_scratch_peak", 1600)
        record = recorder.finish(
            accepted=True,
            mass_balance_residual=1e-12,
            mass_balance_passed=True,
            mass_balance_tolerance=1e-10,
        )

        self.assertEqual(record["schema_version"], "mp-benchmark-record-v1")
        self.assertEqual(record["timing_clock_kind"], "monotonic_elapsed")
        self.assertAlmostEqual(record["timing_seconds"]["constitutive"], 20e-9)
        self.assertAlmostEqual(record["timing_seconds"]["total"], 100e-9)
        self.assertEqual(record["counters"]["newton_iterations"], 2)
        self.assertEqual(record["counters"]["linear_solves"], 1)
        self.assertEqual(record["memory_bytes"]["persistent_column_state"], 800)
        self.assertEqual(record["memory_bytes"]["worker_scratch_peak"], 1600)
        self.assertTrue(record["mass_balance"]["passed"])
        self.assertEqual(len(collector.records()), 1)

    def test_measurement_hooks_do_not_change_deterministic_result(self) -> None:
        def compute(enabled: bool) -> tuple[int, list[int]]:
            collector = MeasurementCollector(enabled=enabled)
            original = [1, 2, 3, 4]
            state = list(original)
            recorder = collector.begin_interval(context())
            with recorder.span("other_kernel"):
                result = sum(x * x for x in state)
            recorder.finish(
                accepted=True,
                mass_balance_residual=0.0,
                mass_balance_passed=True,
            )
            self.assertEqual(state, original)
            return result, state

        self.assertEqual(compute(False), compute(True))

    def test_nested_timing_spans_are_rejected_to_preserve_exclusive_accounting(self) -> None:
        clock = FakeClock([0, 1, 2])
        collector = MeasurementCollector(clock_ns=clock)
        recorder = collector.begin_interval(context())
        with self.assertRaises(RuntimeError):
            with recorder.span("constitutive"):
                with recorder.span("jacobian"):
                    pass

    def test_aggregate_reports_tail_batch_and_worker_elapsed_metrics(self) -> None:
        records = []
        totals = [1.0, 1.0, 2.0, 10.0]
        workers = ["w1", "w1", "w2", "w2"]
        for index, (total, worker) in enumerate(zip(totals, workers), start=1):
            records.append(
                {
                    "timing_seconds": {"total": total, "jacobian": total / 10},
                    "counters": {
                        "newton_iterations": index,
                        "residual_evaluations": 0,
                        "jacobian_builds": 0,
                        "linear_solves": 0,
                        "backtracking_attempts": 0,
                        "retries": 0,
                        "timestep_reductions": 0,
                        "alternative_linear_solves": 0,
                    },
                    "accepted": True,
                    "mass_balance": {"passed": index != 4},
                    "template_id": "tpl-a",
                    "execution_class": "normal",
                    "batch_id": "batch-a",
                    "worker_id": worker,
                }
            )

        summary = aggregate_records(records)
        self.assertEqual(summary["record_count"], 4)
        self.assertEqual(summary["timing_clock_kind"], "monotonic_elapsed")
        self.assertEqual(summary["mass_balance_failure_count"], 1)
        self.assertEqual(summary["counter_totals"]["newton_iterations"], 10)
        self.assertAlmostEqual(summary["sum_interval_elapsed_seconds"], 14.0)
        self.assertAlmostEqual(summary["top_1pct_interval_elapsed_share"], 10 / 14)
        self.assertAlmostEqual(
            summary["batch_divergence_max_over_median"]["max"], 10 / 1.5
        )
        self.assertAlmostEqual(summary["worker_attributed_elapsed_seconds"]["w1"], 2.0)
        self.assertAlmostEqual(summary["worker_attributed_elapsed_seconds"]["w2"], 12.0)
        self.assertAlmostEqual(summary["worker_attributed_elapsed_max_over_mean"], 12 / 7)
        self.assertNotIn("total_cpu_seconds", summary)
        self.assertNotIn("worker_load_seconds", summary)

    def test_jsonl_roundtrip(self) -> None:
        clock = FakeClock([0, 100])
        collector = MeasurementCollector(clock_ns=clock)
        recorder = collector.begin_interval(context())
        recorder.finish(
            accepted=True,
            mass_balance_residual=0.0,
            mass_balance_passed=True,
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "records.jsonl"
            collector.write_jsonl(path)
            loaded = read_jsonl(path)
            self.assertEqual(loaded, collector.records())
            json.dumps(loaded)


if __name__ == "__main__":
    unittest.main()
