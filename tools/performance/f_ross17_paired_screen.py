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
WARMUPS = 2
TARGET_RESOLUTION = 0.05
RESOLUTION_MULTIPLIER = 2.0
VARIANTS = ("BASELINE", "CANDIDATE")

MARKERS = {
    "route": re.compile(r"^F_ROSS15_ROUTE=(REFERENCE|ROSSFAST)$", re.MULTILINE),
    "cases": re.compile(r"^F_ROSS15_CASE_COUNT=(\d+)$", re.MULTILINE),
    "repetitions": re.compile(r"^F_ROSS15_INNER_REPETITIONS=(\d+)$", re.MULTILINE),
    "solve_count": re.compile(r"^F_ROSS15_TIMED_SOLVE_COUNT=(\d+)$", re.MULTILINE),
    "solver_cpu": re.compile(r"^F_ROSS15_SOLVER_CPU_SECONDS=\s*([0-9.Ee+\-]+)$", re.MULTILINE),
    "checksum": re.compile(r"^F_ROSS15_CHECKSUM=\s*([0-9.Ee+\-]+)$", re.MULTILINE),
    "gate": re.compile(r"^F_ROSS15_GATE=PASS$", re.MULTILINE),
}


def child_cpu_seconds() -> float:
    u = resource.getrusage(resource.RUSAGE_CHILDREN)
    return float(u.ru_utime + u.ru_stime)


def parse_output(text: str) -> dict:
    out = {}
    for name, pattern in MARKERS.items():
        m = pattern.search(text)
        if not m:
            raise RuntimeError(f"missing marker {name}\n{text}")
        out[name] = True if name == "gate" else m.group(1)
    if out["route"] != "ROSSFAST":
        raise RuntimeError("benchmark route must be ROSSFAST")
    if int(out["cases"]) != 36 or int(out["repetitions"]) != 200 or int(out["solve_count"]) != 7200:
        raise RuntimeError("benchmark dimensions drifted")
    solver_cpu = float(out["solver_cpu"])
    if not math.isfinite(solver_cpu) or solver_cpu <= 0:
        raise RuntimeError("invalid solver CPU time")
    return {
        "solver_cpu_seconds": solver_cpu,
        "checksum_text": str(out["checksum"]),
    }


def run_one(executable: Path, variant: str, cpu: int, cycle: int, measured: bool) -> dict:
    env = os.environ.copy()
    env["SWAP5_ROSS15_ROUTE"] = "ROSSFAST"
    env["OMP_NUM_THREADS"] = "1"

    def pin() -> None:
        os.sched_setaffinity(0, {cpu})

    cb = child_cpu_seconds()
    wb = time.perf_counter_ns()
    p = subprocess.run(
        [str(executable.resolve())],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
        preexec_fn=pin,
    )
    wa = time.perf_counter_ns()
    ca = child_cpu_seconds()
    if p.returncode != 0:
        raise RuntimeError(f"{variant} failed with {p.returncode}\n{p.stdout}")
    row = parse_output(p.stdout)
    row.update({
        "variant": variant,
        "cycle": cycle,
        "measured": measured,
        "child_cpu_seconds": ca - cb,
        "wall_elapsed_seconds": (wa - wb) / 1e9,
        "target_cpu": cpu,
    })
    print("F_ROSS17_SAMPLE=" + json.dumps(row, sort_keys=True, separators=(",", ":")), flush=True)
    return row


def dist(values: list[float]) -> dict:
    return {
        "n": len(values),
        "mean": statistics.fmean(values),
        "median": statistics.median(values),
        "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
        "min": min(values),
        "max": max(values),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline", type=Path, required=True)
    ap.add_argument("--candidate", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()

    if not hasattr(os, "sched_getaffinity") or not hasattr(os, "sched_setaffinity"):
        raise RuntimeError("Linux CPU affinity required")
    visible = sorted(os.sched_getaffinity(0))
    if not visible:
        raise RuntimeError("no visible CPU")
    cpu = visible[0]
    executables = {"BASELINE": args.baseline, "CANDIDATE": args.candidate}
    checksums = {}
    warmups = []
    for _ in range(WARMUPS):
        for v in VARIANTS:
            row = run_one(executables[v], v, cpu, -1, False)
            checksums.setdefault(v, row["checksum_text"])
            if checksums[v] != row["checksum_text"]:
                raise RuntimeError(f"{v} checksum changed during warmup")
            warmups.append(row)

    samples = []
    for cycle in range(PAIRS):
        order = VARIANTS if cycle % 2 == 0 else tuple(reversed(VARIANTS))
        for v in order:
            row = run_one(executables[v], v, cpu, cycle, True)
            checksums.setdefault(v, row["checksum_text"])
            if checksums[v] != row["checksum_text"]:
                raise RuntimeError(f"{v} checksum changed during measured runs")
            samples.append(row)

    by_cycle = {}
    for row in samples:
        by_cycle.setdefault(row["cycle"], {})[row["variant"]] = row
    if len(by_cycle) != PAIRS or any(set(x) != set(VARIANTS) for x in by_cycle.values()):
        raise RuntimeError("incomplete pairs")

    solver_delta = []
    speedup = []
    child_delta = []
    wall_delta = []
    for cycle in sorted(by_cycle):
        b = by_cycle[cycle]["BASELINE"]
        c = by_cycle[cycle]["CANDIDATE"]
        solver_delta.append(c["solver_cpu_seconds"] / b["solver_cpu_seconds"] - 1.0)
        speedup.append(b["solver_cpu_seconds"] / c["solver_cpu_seconds"])
        child_delta.append(c["child_cpu_seconds"] / b["child_cpu_seconds"] - 1.0)
        wall_delta.append(c["wall_elapsed_seconds"] / b["wall_elapsed_seconds"] - 1.0)

    d = dist(solver_delta)
    mde = RESOLUTION_MULTIPLIER * d["stdev"] / math.sqrt(PAIRS)
    mean_delta = d["mean"]
    material_threshold = max(mde, 0.10)
    if mean_delta < -material_threshold:
        outcome = "SCREENING_MATERIAL_IMPROVEMENT"
    elif mean_delta > mde:
        outcome = "SCREENING_REGRESSION"
    else:
        outcome = "SCREENING_SMALL_OR_UNRESOLVED"

    result = {
        "schema": "swap5.f-ross17.performance-screening.v1",
        "workunit": "F-ROSS17",
        "host_class": "GITHUB_HOSTED_SCREENING_ONLY",
        "formal_performance_claim": False,
        "measurement": {
            "warmups_per_variant": WARMUPS,
            "measured_pairs": PAIRS,
            "inner_repetitions_per_case": 200,
            "case_count": 36,
            "timed_solve_calls_per_sample": 7200,
            "target_cpu": cpu,
            "visible_cpus": visible,
            "pair_order": "alternating",
            "outlier_deletion": False,
            "compiler_optimization": "O2",
        },
        "checksums": checksums,
        "candidate_over_baseline_solver_cpu_relative_delta": {
            **d,
            "minimum_detectable_relative_effect": mde,
            "target_resolution_relative": TARGET_RESOLUTION,
            "target_resolution_qualified": mde <= TARGET_RESOLUTION,
            "material_improvement_threshold": material_threshold,
        },
        "baseline_over_candidate_speedup": dist(speedup),
        "whole_child_cpu_relative_delta": dist(child_delta),
        "wall_elapsed_relative_delta": dist(wall_delta),
        "screening_outcome": outcome,
        "samples": samples,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    print(f"F_ROSS17_SCREENING_OUTCOME={outcome}")
    print(f"F_ROSS17_MEAN_RELATIVE_DELTA={mean_delta:.12g}")
    print(f"F_ROSS17_MDE={mde:.12g}")
    print(f"F_ROSS17_MEAN_BASELINE_OVER_CANDIDATE={statistics.fmean(speedup):.12g}")
    print("F_ROSS17_FORMAL_PERFORMANCE_CLAIM=FALSE")
    print("F_ROSS17_PERFORMANCE_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
