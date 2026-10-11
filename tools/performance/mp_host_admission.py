from __future__ import annotations

import argparse
import json
import math
import statistics
from pathlib import Path
from typing import Any, Mapping, Sequence

from tools.performance.mp_cpu_baseline import required_pair_count

SCHEMA_VERSION = "mp-host-admission-v1"
SUMMARY_VERSION = "mp-host-admission-summary-v1"


def _finite_positive(value: object) -> bool:
    return isinstance(value, (int, float)) and math.isfinite(float(value)) and float(value) > 0


def _cv(values: Sequence[float]) -> float:
    vals = [float(v) for v in values]
    if len(vals) < 2 or any(not _finite_positive(v) for v in vals):
        raise ValueError("preflight series must contain at least two finite positive values")
    mean = statistics.fmean(vals)
    return statistics.stdev(vals) / mean


def select_cpu(preflight: Mapping[str, Any]) -> tuple[int, dict[str, float]]:
    candidates = preflight.get("candidates")
    if not isinstance(candidates, Mapping) or not candidates:
        raise ValueError("preflight.candidates must be a non-empty object")
    eligible: list[tuple[float, int, dict[str, float]]] = []
    for key, value in candidates.items():
        if not isinstance(value, Mapping):
            raise ValueError("each preflight candidate must be an object")
        cpu = int(key)
        cpu_values = value.get("child_cpu_seconds")
        wall_values = value.get("wall_elapsed_seconds")
        if not isinstance(cpu_values, list) or not isinstance(wall_values, list):
            raise ValueError("preflight candidate timing series are required")
        cpu_cv = _cv(cpu_values)
        wall_cv = _cv(wall_values)
        throttled = int(value.get("throttled_events", 0))
        if throttled == 0:
            eligible.append((cpu_cv, cpu, {"child_cpu_cv": cpu_cv, "wall_elapsed_cv": wall_cv}))
    if not eligible:
        raise ValueError("no non-throttled preflight CPU candidate")
    _, cpu, metrics = min(eligible, key=lambda item: (item[0], item[1]))
    return cpu, metrics


def _paired_distribution(pairs: Sequence[Mapping[str, Any]], metric: str) -> dict[str, float | int]:
    deltas: list[float] = []
    for pair in pairs:
        off = float(pair[f"off_{metric}"])
        on = float(pair[f"on_{metric}"])
        if off <= 0 or on <= 0 or not math.isfinite(off) or not math.isfinite(on):
            raise ValueError(f"{metric} pair values must be finite and > 0")
        deltas.append(on / off - 1.0)
    if len(deltas) < 2:
        raise ValueError("at least two final pairs are required")
    stdev = statistics.stdev(deltas)
    return {
        "n": len(deltas),
        "mean": statistics.fmean(deltas),
        "median": statistics.median(deltas),
        "stdev": stdev,
        "min": min(deltas),
        "max": max(deltas),
    }


def summarize(payload: Mapping[str, Any]) -> dict[str, Any]:
    if payload.get("schema_version") != SCHEMA_VERSION:
        raise ValueError(f"schema_version must be {SCHEMA_VERSION}")
    target = float(payload.get("target_resolution_relative"))
    multiplier = float(payload.get("resolution_multiplier"))
    if target <= 0 or multiplier <= 0:
        raise ValueError("target resolution and multiplier must be > 0")

    preflight = payload.get("preflight")
    pilot = payload.get("pilot")
    final = payload.get("final")
    host = payload.get("host")
    if not all(isinstance(x, Mapping) for x in (preflight, pilot, final, host)):
        raise ValueError("preflight, pilot, final and host objects are required")

    selected_cpu, selected_metrics = select_cpu(preflight)
    declared_selected = int(preflight.get("selected_cpu"))
    if declared_selected != selected_cpu:
        raise ValueError(f"preflight.selected_cpu must follow deterministic selection rule: {selected_cpu}")
    cv_limit = float(preflight.get("cpu_cv_limit_relative"))

    pilot_pairs = pilot.get("pairs")
    if not isinstance(pilot_pairs, list) or len(pilot_pairs) < 2:
        raise ValueError("pilot.pairs must contain at least two pairs")
    pilot_dist = _paired_distribution(pilot_pairs, "child_cpu_seconds")
    required = required_pair_count(float(pilot_dist["stdev"]), target, multiplier)
    if int(pilot.get("predeclared_final_pairs")) != required:
        raise ValueError(f"pilot.predeclared_final_pairs must equal {required}")

    final_pairs = final.get("pairs")
    if not isinstance(final_pairs, list) or len(final_pairs) != required:
        raise ValueError(f"final.pairs must contain exactly {required} predeclared pairs")
    cpu_dist = _paired_distribution(final_pairs, "child_cpu_seconds")
    wall_dist = _paired_distribution(final_pairs, "wall_elapsed_seconds")
    cpu_mde = multiplier * float(cpu_dist["stdev"]) / math.sqrt(required)
    wall_mde = multiplier * float(wall_dist["stdev"]) / math.sqrt(required)

    physical_hashes = final.get("physical_output_hashes")
    distinct_counts = final.get("physical_output_distinct_counts")
    observations = final.get("physical_output_observations")
    if not isinstance(physical_hashes, Mapping) or not physical_hashes:
        raise ValueError("final.physical_output_hashes must be non-empty")
    if not isinstance(distinct_counts, Mapping) or set(distinct_counts) != set(physical_hashes):
        raise ValueError("physical_output_distinct_counts must cover every physical output")
    for name, digest in physical_hashes.items():
        if not isinstance(name, str) or not isinstance(digest, str) or len(digest) != 64:
            raise ValueError("physical output hashes must be SHA-256 strings")
    if observations != 2 * required:
        raise ValueError("physical_output_observations must equal two observations per final pair")
    physical_equal = all(int(distinct_counts[name]) == 1 for name in physical_hashes)
    sample_throttled_events = int(final.get("measured_sample_throttled_events", 0))
    sample_throttled_usec = int(final.get("measured_sample_throttled_usec", 0))

    window_before = host.get("qualification_window_before")
    window_after = host.get("qualification_window_after")
    if not isinstance(window_before, Mapping) or not isinstance(window_after, Mapping):
        raise ValueError("host qualification window snapshots are required")
    window_throttle_events = int(window_after.get("nr_throttled", 0)) - int(window_before.get("nr_throttled", 0))
    window_throttle_usec = int(window_after.get("throttled_usec", 0)) - int(window_before.get("throttled_usec", 0))
    if window_throttle_events < 0 or window_throttle_usec < 0:
        raise ValueError("host throttling counters moved backwards")

    gates = {
        "deterministic_cpu_selection": declared_selected == selected_cpu,
        "preflight_cpu_cv_within_limit": selected_metrics["child_cpu_cv"] <= cv_limit,
        "physical_output_equality": physical_equal,
        "no_measured_sample_throttling": sample_throttled_events == 0 and sample_throttled_usec == 0,
        "no_qualification_window_throttling": window_throttle_events == 0 and window_throttle_usec == 0,
        "cpu_resolution_qualified": cpu_mde <= target,
    }
    admitted = all(gates.values())
    return {
        "schema_version": SUMMARY_VERSION,
        "selected_cpu": selected_cpu,
        "selected_cpu_preflight": selected_metrics,
        "pilot": {
            "pair_count": len(pilot_pairs),
            "paired_child_cpu": pilot_dist,
            "required_final_pairs": required,
        },
        "final": {
            "pair_count": required,
            "paired_child_cpu": {**cpu_dist, "minimum_detectable_relative_effect": cpu_mde},
            "paired_wall_elapsed": {**wall_dist, "minimum_detectable_relative_effect": wall_mde},
            "physical_output_hashes": dict(sorted((str(k), str(v)) for k, v in physical_hashes.items())),
            "measured_sample_throttled_events": sample_throttled_events,
            "measured_sample_throttled_usec": sample_throttled_usec,
        },
        "host": {
            "cpu_max": host.get("cpu_max"),
            "cpuset": host.get("cpuset"),
            "qualification_window_throttled_events": window_throttle_events,
            "qualification_window_throttled_usec": window_throttle_usec,
        },
        "target_resolution_relative": target,
        "gates": gates,
        "host_admitted_for_cpu_baseline": admitted,
        "cpu_baseline_established": admitted,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Summarize MP host-admission evidence")
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args(argv)
    payload = json.loads(args.evidence.read_text(encoding="utf-8"))
    print(json.dumps(summarize(payload), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
