from __future__ import annotations

import json
import math
import os
import re
import resource
import statistics
import subprocess
import sys
from pathlib import Path

WARMUPS = 2
PAIRS = 12
TARGET_RESOLUTION = 0.05
K = 2.0
EXPECTED_CASES = 36
EXPECTED_REPETITIONS = 200
EXPECTED_SOLVES = EXPECTED_CASES * EXPECTED_REPETITIONS

PATTERNS = {
    "route": re.compile(r"^F_ROSS15_ROUTE=(.+)$", re.MULTILINE),
    "case_count": re.compile(r"^F_ROSS15_CASE_COUNT=(\d+)$", re.MULTILINE),
    "inner_repetitions": re.compile(r"^F_ROSS15_INNER_REPETITIONS=(\d+)$", re.MULTILINE),
    "timed_solve_count": re.compile(r"^F_ROSS15_TIMED_SOLVE_COUNT=(\d+)$", re.MULTILINE),
    "solver_cpu_seconds": re.compile(r"^F_ROSS15_SOLVER_CPU_SECONDS=\s*([0-9.Ee+-]+)$", re.MULTILINE),
    "checksum": re.compile(r"^F_ROSS15_CHECKSUM=\s*([0-9.Ee+-]+)$", re.MULTILINE),
}


def parse_output(text: str) -> dict:
    out = {}
    for key, pattern in PATTERNS.items():
        m = pattern.search(text)
        if not m:
            raise RuntimeError(f"missing output marker: {key}")
        value = m.group(1).strip()
        if key in {"case_count", "inner_repetitions", "timed_solve_count"}:
            out[key] = int(value)
        elif key in {"solver_cpu_seconds", "checksum"}:
            out[key] = float(value)
        else:
            out[key] = value
    if "F_ROSS15_GATE=PASS" not in text:
        raise RuntimeError("benchmark executable did not report PASS")
    if out["case_count"] != EXPECTED_CASES:
        raise RuntimeError(f"case-count drift: {out['case_count']}")
    if out["inner_repetitions"] != EXPECTED_REPETITIONS:
        raise RuntimeError(f"repetition-count drift: {out['inner_repetitions']}")
    if out["timed_solve_count"] != EXPECTED_SOLVES:
        raise RuntimeError(f"timed-solve-count drift: {out['timed_solve_count']}")
    if not math.isfinite(out["solver_cpu_seconds"]) or out["solver_cpu_seconds"] <= 0:
        raise RuntimeError("invalid internal solver CPU time")
    if not math.isfinite(out["checksum"]):
        raise RuntimeError("invalid checksum")
    return out


def run_one(exe: Path, route: str, cycle: int, measured: bool, cpu: int) -> dict:
    env = os.environ.copy()
    env["SWAP5_ROSS15_ROUTE"] = route

    def pin() -> None:
        os.sched_setaffinity(0, {cpu})

    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    completed = subprocess.run(
        [str(exe)],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        preexec_fn=pin,
        check=False,
    )
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    if completed.returncode != 0:
        sys.stderr.write(completed.stdout)
        raise RuntimeError(f"{route} executable failed with {completed.returncode}")
    parsed = parse_output(completed.stdout)
    if parsed["route"] != route:
        raise RuntimeError(f"route marker drift: expected {route}, got {parsed['route']}")
    row = {
        "cycle": cycle,
        "measured": measured,
        "route": route,
        "solver_cpu_seconds": parsed["solver_cpu_seconds"],
        "child_cpu_seconds": (after.ru_utime + after.ru_stime) - (before.ru_utime + before.ru_stime),
        "checksum": parsed["checksum"],
        "case_count": parsed["case_count"],
        "inner_repetitions": parsed["inner_repetitions"],
        "timed_solve_count": parsed["timed_solve_count"],
        "cpu": cpu,
    }
    print("F_ROSS15_SAMPLE=" + json.dumps(row, sort_keys=True, separators=(",", ":")), flush=True)
    return row


def distribution(values: list[float]) -> dict:
    return {
        "n": len(values),
        "mean": statistics.fmean(values),
        "median": statistics.median(values),
        "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
        "min": min(values),
        "max": max(values),
    }


def summarize(samples: list[dict], cpu: int) -> dict:
    by_cycle: dict[int, dict[str, dict]] = {}
    for row in samples:
        by_cycle.setdefault(row["cycle"], {})[row["route"]] = row
    if len(by_cycle) != PAIRS:
        raise RuntimeError("incomplete pair count")
    solver_deltas = []
    child_deltas = []
    speedups = []
    for cycle in range(PAIRS):
        pair = by_cycle.get(cycle, {})
        if set(pair) != {"REFERENCE", "ROSSFAST"}:
            raise RuntimeError(f"incomplete pair {cycle}")
        ref = pair["REFERENCE"]
        ross = pair["ROSSFAST"]
        solver_deltas.append(ross["solver_cpu_seconds"] / ref["solver_cpu_seconds"] - 1.0)
        child_deltas.append(ross["child_cpu_seconds"] / ref["child_cpu_seconds"] - 1.0)
        speedups.append(ref["solver_cpu_seconds"] / ross["solver_cpu_seconds"])

    solver_dist = distribution(solver_deltas)
    child_dist = distribution(child_deltas)
    speedup_dist = distribution(speedups)
    mde = K * solver_dist["stdev"] / math.sqrt(PAIRS)
    child_mde = K * child_dist["stdev"] / math.sqrt(PAIRS)
    mean_delta = solver_dist["mean"]
    if mean_delta < -mde:
        outcome = "SCREENING_ROSSFAST_FASTER"
    elif mean_delta > mde:
        outcome = "SCREENING_REFERENCE_FASTER"
    else:
        outcome = "SCREENING_NOT_RESOLVED"

    return {
        "schema": "swap5.f-ross15.performance-screen-result.v1",
        "host_class": "GITHUB_HOSTED_SHARED_SCREENING_ONLY",
        "formal_qualified_speedup_claim": False,
        "target_cpu": cpu,
        "warmup_runs_per_variant": WARMUPS,
        "measured_pairs": PAIRS,
        "inner_repetitions_per_case": EXPECTED_REPETITIONS,
        "case_count": EXPECTED_CASES,
        "timed_solve_calls_per_process": EXPECTED_SOLVES,
        "primary_metric": "fortran_cpu_time_solver_region_seconds",
        "paired_relative_delta_definition": "rossfast/reference - 1",
        "solver_relative_delta": solver_dist,
        "solver_speedup_reference_over_rossfast": speedup_dist,
        "resolution_multiplier": K,
        "minimum_detectable_relative_effect": mde,
        "target_resolution_relative": TARGET_RESOLUTION,
        "target_resolution_qualified": mde <= TARGET_RESOLUTION,
        "effect_resolved": abs(mean_delta) > mde,
        "secondary_child_cpu_relative_delta": child_dist,
        "secondary_child_cpu_mde": child_mde,
        "outcome": outcome,
        "claim_boundary": "Screening evidence only. Formal performance admission requires repetition on an MP-admitted isolated host.",
    }


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross15_performance.py <executable> <result.json>")
    exe = Path(sys.argv[1]).resolve()
    result_path = Path(sys.argv[2])
    if not hasattr(os, "sched_getaffinity") or not hasattr(os, "sched_setaffinity"):
        raise RuntimeError("CPU affinity unavailable")
    visible = sorted(os.sched_getaffinity(0))
    if not visible:
        raise RuntimeError("no visible CPUs")
    cpu = visible[0]
    print(f"F_ROSS15_VISIBLE_CPUS={','.join(str(x) for x in visible)}")
    print(f"F_ROSS15_TARGET_CPU={cpu}")

    for warmup in range(WARMUPS):
        for route in ("REFERENCE", "ROSSFAST"):
            run_one(exe, route, -(warmup + 1), False, cpu)

    samples = []
    for cycle in range(PAIRS):
        order = ("REFERENCE", "ROSSFAST") if cycle % 2 == 0 else ("ROSSFAST", "REFERENCE")
        for route in order:
            samples.append(run_one(exe, route, cycle, True, cpu))

    summary = summarize(samples, cpu)
    result_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("F_ROSS15_RESULT=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("F_ROSS15_SCREENING_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
