from __future__ import annotations

import argparse
import json
import math
import os
import platform
import re
import resource
import statistics
import subprocess
import time
from pathlib import Path

PAIRS = 12
WARMUPS_PER_VARIANT = 2
TARGET_RESOLUTION = 0.05
RESOLUTION_MULTIPLIER = 2.0
ROUTES = ("REFERENCE", "ROSSFAST")

MARKERS = {
    "route": re.compile(r"^F_ROSS23_ROUTE=(REFERENCE|ROSSFAST)$", re.MULTILINE),
    "cases": re.compile(r"^F_ROSS23_CASE_COUNT=(\d+)$", re.MULTILINE),
    "repetitions": re.compile(r"^F_ROSS23_INNER_REPETITIONS=(\d+)$", re.MULTILINE),
    "solve_count": re.compile(r"^F_ROSS23_TIMED_SOLVE_COUNT=(\d+)$", re.MULTILINE),
    "solver_cpu": re.compile(r"^F_ROSS23_SOLVER_CPU_SECONDS=\s*([0-9.Ee+\-]+)$", re.MULTILINE),
    "checksum": re.compile(r"^F_ROSS23_CHECKSUM=\s*([0-9.Ee+\-]+)$", re.MULTILINE),
    "gate": re.compile(r"^F_ROSS23_GATE=PASS$", re.MULTILINE),
    "paired_valid": re.compile(r"^F_ROSS23_PAIRED_VALID=(\d+)$", re.MULTILINE),
    "admissible": re.compile(r"^F_ROSS23_PAIRED_VALID_ADMISSIBLE=(\d+)$", re.MULTILINE),
    "discrepancy_fail": re.compile(r"^F_ROSS23_PAIRED_VALID_DISCREPANCY_FAIL=(\d+)$", re.MULTILINE),
    "reference_invalid": re.compile(r"^F_ROSS23_REFERENCE_ROUTE_INVALID=(\d+)$", re.MULTILINE),
    "rossfast_invalid": re.compile(r"^F_ROSS23_ROSSFAST_ROUTE_INVALID=(\d+)$", re.MULTILINE),
    "both_invalid": re.compile(r"^F_ROSS23_BOTH_ROUTES_INVALID=(\d+)$", re.MULTILINE),
}


def child_cpu_seconds() -> float:
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    return float(usage.ru_utime + usage.ru_stime)


def cpu_model() -> str | None:
    try:
        for line in Path("/proc/cpuinfo").read_text(errors="replace").splitlines():
            if line.lower().startswith("model name") and ":" in line:
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return None


def parse_output(text: str, expected_route: str) -> dict:
    values: dict[str, object] = {}
    for name, pattern in MARKERS.items():
        match = pattern.search(text)
        if not match:
            raise RuntimeError(f"missing benchmark marker: {name}\n{text}")
        if name == "gate":
            values[name] = True
        else:
            values[name] = match.group(1)
    if values["route"] != expected_route:
        raise RuntimeError(f"route mismatch: expected {expected_route}, got {values['route']}")
    if int(values["cases"]) != 216 or int(values["repetitions"]) != 200:
        raise RuntimeError("frozen characterization dimensions drifted")
    paired_valid = int(values["paired_valid"])
    if int(values["solve_count"]) != paired_valid * 200:
        raise RuntimeError("timed solve count is not restricted to the paired-valid subset")
    solver_cpu = float(values["solver_cpu"])
    if not math.isfinite(solver_cpu) or solver_cpu <= 0:
        raise RuntimeError("solver CPU time must be finite and positive")
    return {
        "route": expected_route,
        "solver_cpu_seconds": solver_cpu,
        "checksum_text": str(values["checksum"]),
        "case_count": 216,
        "inner_repetitions": 200,
        "timed_solve_count": int(values["solve_count"]),
        "diagnostic_counts": {
            "paired_valid": paired_valid,
            "admissible_under_historical_six_material_thresholds": int(values["admissible"]),
            "discrepancy_fail_against_historical_six_material_thresholds": int(values["discrepancy_fail"]),
            "reference_invalid": int(values["reference_invalid"]),
            "rossfast_invalid": int(values["rossfast_invalid"]),
            "both_invalid": int(values["both_invalid"]),
        },
    }


def run_one(executable: Path, route: str, target_cpu: int, cycle: int, measured: bool) -> dict:
    env = os.environ.copy()
    env["SWAP5_ROSS23_ROUTE"] = route
    env["OMP_NUM_THREADS"] = "1"

    def pin_child() -> None:
        os.sched_setaffinity(0, {target_cpu})

    cpu_before = child_cpu_seconds()
    wall_before = time.perf_counter_ns()
    completed = subprocess.run(
        [str(executable.resolve())],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
        preexec_fn=pin_child,
    )
    wall_after = time.perf_counter_ns()
    cpu_after = child_cpu_seconds()
    if completed.returncode != 0:
        raise RuntimeError(f"{route} benchmark failed with {completed.returncode}\n{completed.stdout}")
    parsed = parse_output(completed.stdout, route)
    case_lines = [line for line in completed.stdout.splitlines() if line.startswith("F_ROSS23_CASE|")]
    parsed["case_matrix"] = case_lines
    parsed.update({
        "cycle": cycle,
        "measured": measured,
        "child_cpu_seconds": cpu_after - cpu_before,
        "wall_elapsed_seconds": (wall_after - wall_before) / 1.0e9,
        "target_cpu": target_cpu,
    })
    return parsed


def distribution(values: list[float]) -> dict:
    return {
        "n": len(values),
        "mean": statistics.fmean(values),
        "median": statistics.median(values),
        "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
        "min": min(values),
        "max": max(values),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    if not hasattr(os, "sched_getaffinity") or not hasattr(os, "sched_setaffinity"):
        raise RuntimeError("Linux CPU affinity is required")
    visible = sorted(os.sched_getaffinity(0))
    if not visible:
        raise RuntimeError("no visible CPU available")
    target_cpu = visible[0]

    checksums: dict[str, str] = {}
    warmups: list[dict] = []
    for _ in range(WARMUPS_PER_VARIANT):
        for route in ROUTES:
            row = run_one(args.executable, route, target_cpu, -1, False)
            prior = checksums.setdefault(route, row["checksum_text"])
            if row["checksum_text"] != prior:
                raise RuntimeError(f"{route} checksum changed during warmup")
            warmups.append(row)

    samples: list[dict] = []
    for cycle in range(PAIRS):
        order = ROUTES if cycle % 2 == 0 else tuple(reversed(ROUTES))
        for route in order:
            row = run_one(args.executable, route, target_cpu, cycle, True)
            prior = checksums.setdefault(route, row["checksum_text"])
            if row["checksum_text"] != prior:
                raise RuntimeError(f"{route} checksum changed across measured runs")
            samples.append(row)

    by_cycle: dict[int, dict[str, dict]] = {}
    for row in samples:
        by_cycle.setdefault(int(row["cycle"]), {})[str(row["route"])] = row
    if len(by_cycle) != PAIRS or any(set(pair) != set(ROUTES) for pair in by_cycle.values()):
        raise RuntimeError("incomplete paired measurement")

    solver_deltas = []
    solver_speedups = []
    child_deltas = []
    wall_deltas = []
    for cycle in sorted(by_cycle):
        pair = by_cycle[cycle]
        ref = pair["REFERENCE"]
        ross = pair["ROSSFAST"]
        solver_deltas.append(ross["solver_cpu_seconds"] / ref["solver_cpu_seconds"] - 1.0)
        solver_speedups.append(ref["solver_cpu_seconds"] / ross["solver_cpu_seconds"])
        child_deltas.append(ross["child_cpu_seconds"] / ref["child_cpu_seconds"] - 1.0)
        wall_deltas.append(ross["wall_elapsed_seconds"] / ref["wall_elapsed_seconds"] - 1.0)

    solver_dist = distribution(solver_deltas)
    mde = RESOLUTION_MULTIPLIER * float(solver_dist["stdev"]) / math.sqrt(PAIRS)
    mean_delta = float(solver_dist["mean"])
    if mean_delta < -mde:
        screening = "SCREENING_ROSSFAST_FASTER"
    elif mean_delta > mde:
        screening = "SCREENING_REFERENCE_FASTER"
    else:
        screening = "SCREENING_NOT_RESOLVED"

    result = {
        "schema": "swap5.f-ross23.performance-screening-result.v1",
        "workunit": "F-ROSS23",
        "phase": "MEASURED_SHARED_HOST_SCREENING",
        "measurement": {
            "warmups_per_variant": WARMUPS_PER_VARIANT,
            "pair_count": PAIRS,
            "inner_repetitions_per_case": 200,
            "paired_valid_case_count": samples[0]["diagnostic_counts"]["paired_valid"],
            "attempted_case_count": 216,
            "timed_solves_per_sample": samples[0]["timed_solve_count"],
            "timing_scope": "PAIRED_VALID_SUBSET_ONLY_AFTER_UNEXPECTED_ROUTE_INVALIDITY",
            "primary_metric": "solver_cpu_seconds",
            "target_cpu": target_cpu,
            "visible_affinity_cpus": visible,
            "pair_order": "alternating",
            "outlier_deletion": False,
        },
        "host": {
            "platform": platform.platform(),
            "machine": platform.machine(),
            "cpu_model": cpu_model(),
            "formal_isolated_host_admitted": False,
            "classification": "GITHUB_HOSTED_SCREENING_ONLY",
        },
        "route_checksums": checksums,
        "solver_cpu_relative_delta_rossfast_over_reference_minus_one": {
            **solver_dist,
            "resolution_multiplier": RESOLUTION_MULTIPLIER,
            "minimum_detectable_relative_effect": mde,
            "target_resolution_relative": TARGET_RESOLUTION,
            "target_resolution_qualified": mde <= TARGET_RESOLUTION,
            "effect_resolved": abs(mean_delta) > mde,
        },
        "solver_speedup_reference_over_rossfast": distribution(solver_speedups),
        "whole_child_cpu_relative_delta": distribution(child_deltas),
        "wall_elapsed_relative_delta": distribution(wall_deltas),
        "screening_outcome": screening,
        "qualified_speedup_claim": False,
        "claim_boundary": "Shared GitHub-hosted result is screening evidence only. Formal speedup requires replay on an MP-admitted isolated performance host.",
        "diagnostic_counts": samples[0]["diagnostic_counts"],
        "case_matrix": samples[0]["case_matrix"],
        "samples": [{k:v for k,v in row.items() if k != "case_matrix"} for row in samples],
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    print(f"F_ROSS23_SCREENING_OUTCOME={screening}")
    print(f"F_ROSS23_MEAN_RELATIVE_DELTA={mean_delta:.12g}")
    print(f"F_ROSS23_MDE={mde:.12g}")
    print(f"F_ROSS23_MEAN_SPEEDUP={statistics.fmean(solver_speedups):.12g}")
    print("F_ROSS23_FORMAL_SPEEDUP_CLAIM=FALSE")
    print("F_ROSS23_SCREENING_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
