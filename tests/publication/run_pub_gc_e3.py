from __future__ import annotations

import argparse
import csv
import json
import math
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
SUPPORT = ROOT / "tests" / "fgc" / "support"
sys.path.insert(0, str(SUPPORT))

from fgc44_real_swap_ctypes import Fgc44RealSwap

DAY_TO_S = 86400.0
T_TOTAL_DAY = 4.0e-4
T_TOTAL_S = T_TOTAL_DAY * DAY_TO_S
DRIVE_TOTAL_M = 0.002
U_BASE = 3.402936037279093e-5
HEAD_TOL_M = 1.0e-8
MAX_TRIALS_PER_WINDOW = 40
BRACKET_RADII_M = (0.00025, 0.0005, 0.001, 0.002, 0.004, 0.008, 0.016)
WINDOW_COUNTS = (16, 8, 4, 2, 1)
FEEDBACK = {
    "weak": 0.05,
    "moderate": 0.30,
    "strong": 0.80,
    "supercritical-control": 1.20,
}
METHODS = ("implicit", "loose")


class CaseInfrastructureError(RuntimeError):
    pass


def finite(*values: float) -> bool:
    return all(math.isfinite(v) for v in values)


def run_case(library: Path, method: str, feedback_class: str, n_windows: int) -> dict[str, Any]:
    target = FEEDBACK[feedback_class]
    beta = target / U_BASE
    dt_day = T_TOTAL_DAY / n_windows
    dt_s = dt_day * DAY_TO_S
    drive_step = DRIVE_TOTAL_M / n_windows

    swap = Fgc44RealSwap(library)
    try:
        _, _, href = swap.initialize_window(dt_day)
    except Exception as exc:
        return {
            "status": "INITIALIZE_FAILED",
            "error": str(exc),
            "method": method,
            "feedback_class": feedback_class,
            "target_cstar": target,
            "beta": beta,
            "n_windows": n_windows,
            "dt_day": dt_day,
            "dt_s": dt_s,
        }

    e1 = swap.e1_diagnostics()
    u_window = float(e1["u"])
    c_pred = abs(beta * u_window)
    initial_storage = swap.committed_storage()

    trial_evaluations = 0
    status, q_ref = swap.trial_status(href)
    trial_evaluations += 1
    if status != 0 or not math.isfinite(q_ref):
        return {
            "status": "REFERENCE_FLUX_FAILED",
            "trial_status": status,
            "method": method,
            "feedback_class": feedback_class,
            "target_cstar": target,
            "beta": beta,
            "n_windows": n_windows,
            "dt_day": dt_day,
            "dt_s": dt_s,
            "u_window": u_window,
            "c_pred": c_pred,
        }
    swap.discard()

    h_current = href
    q_lag = q_ref
    cumulative_exchange_m = 0.0
    max_abs_closure_m = 0.0
    final_closure_m = 0.0
    accepted_windows = 0
    window_records: list[dict[str, Any]] = []

    def coupling_residual(h: float, h_start: float, q: float) -> float:
        return h - (h_start + drive_step + beta * dt_s * (q - q_ref))

    def evaluate(h: float, h_start: float) -> tuple[int, float, float, float]:
        nonlocal trial_evaluations
        st, q = swap.trial_status(h)
        trial_evaluations += 1
        if st != 0:
            return st, math.nan, math.nan, math.nan
        q_diag, bottom_cm = swap.last_trial_diagnostics()
        if not finite(q, q_diag, bottom_cm):
            swap.discard()
            return 999, math.nan, math.nan, math.nan
        if abs(q - q_diag) > 64.0 * sys.float_info.epsilon * max(1.0, abs(q)):
            swap.discard()
            return 998, math.nan, math.nan, math.nan
        return 0, q, bottom_cm * 0.01, coupling_residual(h, h_start, q)

    def implicit_window(h_start: float) -> tuple[str, float, float, float, float, int]:
        eval_start = trial_evaluations
        center = h_start + drive_step

        st, q, exchange_m, f = evaluate(center, h_start)
        if st != 0:
            return f"SWAP_TRIAL_FAILED:{st}", math.nan, math.nan, math.nan, math.nan, trial_evaluations - eval_start
        if abs(f) <= HEAD_TOL_M:
            return "OK", center, q, exchange_m, f, trial_evaluations - eval_start
        swap.discard()

        bracket = None
        for radius in BRACKET_RADII_M:
            if trial_evaluations - eval_start >= MAX_TRIALS_PER_WINDOW:
                break
            left = center - radius
            st_l, q_l, ex_l, f_l = evaluate(left, h_start)
            if st_l != 0:
                return f"SWAP_TRIAL_FAILED:{st_l}", math.nan, math.nan, math.nan, math.nan, trial_evaluations - eval_start
            if abs(f_l) <= HEAD_TOL_M:
                return "OK", left, q_l, ex_l, f_l, trial_evaluations - eval_start
            swap.discard()

            if trial_evaluations - eval_start >= MAX_TRIALS_PER_WINDOW:
                break
            right = center + radius
            st_r, q_r, ex_r, f_r = evaluate(right, h_start)
            if st_r != 0:
                return f"SWAP_TRIAL_FAILED:{st_r}", math.nan, math.nan, math.nan, math.nan, trial_evaluations - eval_start
            if abs(f_r) <= HEAD_TOL_M:
                return "OK", right, q_r, ex_r, f_r, trial_evaluations - eval_start
            swap.discard()

            if f_l == 0.0 or f_r == 0.0 or f_l * f_r < 0.0:
                bracket = [left, right, f_l, f_r]
                break

        if bracket is None:
            return "NO_BRACKET", math.nan, math.nan, math.nan, math.nan, trial_evaluations - eval_start

        a, b, fa, fb = bracket
        while trial_evaluations - eval_start < MAX_TRIALS_PER_WINDOW:
            mid = 0.5 * (a + b)
            st_m, q_m, ex_m, f_m = evaluate(mid, h_start)
            if st_m != 0:
                return f"SWAP_TRIAL_FAILED:{st_m}", math.nan, math.nan, math.nan, math.nan, trial_evaluations - eval_start
            if abs(f_m) <= HEAD_TOL_M:
                return "OK", mid, q_m, ex_m, f_m, trial_evaluations - eval_start
            swap.discard()
            if fa * f_m < 0.0:
                b, fb = mid, f_m
            else:
                a, fa = mid, f_m

        return "ITERATION_LIMIT", math.nan, math.nan, math.nan, math.nan, trial_evaluations - eval_start

    for window_index in range(1, n_windows + 1):
        if window_index > 1:
            try:
                swap.begin_next_window(dt_day)
            except Exception as exc:
                return {
                    "status": "NEXT_WINDOW_FAILED",
                    "error": str(exc),
                    "method": method,
                    "feedback_class": feedback_class,
                    "target_cstar": target,
                    "beta": beta,
                    "n_windows": n_windows,
                    "dt_day": dt_day,
                    "dt_s": dt_s,
                    "u_window": u_window,
                    "c_pred": c_pred,
                    "q_ref_m_per_s": q_ref,
                    "accepted_windows": accepted_windows,
                    "trial_evaluations": trial_evaluations,
                    "windows": window_records,
                }

        h_start = h_current
        if method == "loose":
            h_accept = h_start + drive_step + beta * dt_s * (q_lag - q_ref)
            st, q_accept, exchange_m, closure = evaluate(h_accept, h_start)
            window_evals = 1
            route = "OK" if st == 0 else f"SWAP_TRIAL_FAILED:{st}"
        else:
            route, h_accept, q_accept, exchange_m, closure, window_evals = implicit_window(h_start)

        if route != "OK":
            return {
                "status": route,
                "method": method,
                "feedback_class": feedback_class,
                "target_cstar": target,
                "beta": beta,
                "n_windows": n_windows,
                "dt_day": dt_day,
                "dt_s": dt_s,
                "u_window": u_window,
                "c_pred": c_pred,
                "q_ref_m_per_s": q_ref,
                "initial_head_m": href,
                "initial_storage_native": initial_storage,
                "accepted_windows": accepted_windows,
                "trial_evaluations": trial_evaluations,
                "windows": window_records,
            }

        if not finite(h_accept, q_accept, exchange_m, closure):
            return {
                "status": "NONFINITE_RESULT",
                "method": method,
                "feedback_class": feedback_class,
                "n_windows": n_windows,
                "accepted_windows": accepted_windows,
                "trial_evaluations": trial_evaluations,
            }

        if not swap.swap_preflight():
            return {
                "status": "SWAP_PREFLIGHT_FAILED",
                "method": method,
                "feedback_class": feedback_class,
                "n_windows": n_windows,
                "accepted_windows": accepted_windows,
                "trial_evaluations": trial_evaluations,
            }

        try:
            swap.commit_swap()
        except Exception as exc:
            return {
                "status": "SWAP_COMMIT_FAILED",
                "error": str(exc),
                "method": method,
                "feedback_class": feedback_class,
                "n_windows": n_windows,
                "accepted_windows": accepted_windows,
                "trial_evaluations": trial_evaluations,
            }

        accepted_windows += 1
        h_current = h_accept
        q_lag = q_accept
        cumulative_exchange_m += exchange_m
        max_abs_closure_m = max(max_abs_closure_m, abs(closure))
        final_closure_m = closure
        window_records.append(
            {
                "window_index": window_index,
                "head_start_m": h_start,
                "head_accepted_m": h_accept,
                "q_swap_m_per_s": q_accept,
                "bottom_exchange_m": exchange_m,
                "closure_m": closure,
                "trial_evaluations": window_evals,
            }
        )

    final_storage = swap.committed_storage()
    revision, time_day, _, _ = swap.state()
    if revision != n_windows or abs(time_day - T_TOTAL_DAY) > 1.0e-12:
        raise CaseInfrastructureError(
            f"committed timeline mismatch revision={revision} time={time_day} expected windows={n_windows}"
        )

    return {
        "status": "OK",
        "method": method,
        "feedback_class": feedback_class,
        "target_cstar": target,
        "beta": beta,
        "n_windows": n_windows,
        "dt_day": dt_day,
        "dt_s": dt_s,
        "u_window": u_window,
        "c_pred": c_pred,
        "q_ref_m_per_s": q_ref,
        "initial_head_m": href,
        "initial_storage_native": initial_storage,
        "accepted_windows": accepted_windows,
        "trial_evaluations": trial_evaluations,
        "final_head_m": h_current,
        "final_storage_native": final_storage,
        "storage_change_native": final_storage - initial_storage,
        "cumulative_bottom_exchange_m": cumulative_exchange_m,
        "max_abs_closure_m": max_abs_closure_m,
        "final_closure_m": final_closure_m,
        "windows": window_records,
    }


def child_main(args: argparse.Namespace) -> int:
    result = run_case(Path(args.library), args.method, args.feedback_class, args.n_windows)
    Path(args.output).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    return 0


def run_child(library: Path, method: str, feedback_class: str, n_windows: int, out: Path) -> dict[str, Any]:
    cmd = [
        sys.executable,
        str(Path(__file__).resolve()),
        "--case",
        "--library",
        str(library),
        "--method",
        method,
        "--feedback-class",
        feedback_class,
        "--n-windows",
        str(n_windows),
        "--output",
        str(out),
    ]
    completed = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    if completed.returncode != 0:
        raise CaseInfrastructureError(
            f"child process failed ({feedback_class}/{n_windows}/{method})\n"
            f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )
    return json.loads(out.read_text())


def main_matrix() -> int:
    library = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    outdir = Path(os.environ.get("PUB_GC_EVIDENCE_DIR", ROOT / "build" / "pub-gc-e3")).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    records: list[dict[str, Any]] = []
    case_dir = outdir / "cases"
    case_dir.mkdir(exist_ok=True)

    for feedback_class in FEEDBACK:
        for n_windows in WINDOW_COUNTS:
            for method in METHODS:
                path = case_dir / f"{feedback_class}-{n_windows}-{method}.json"
                record = run_child(library, method, feedback_class, n_windows, path)
                records.append(record)
                print(
                    "E3_CASE "
                    f"feedback={feedback_class} windows={n_windows} method={method} "
                    f"status={record.get('status')} trials={record.get('trial_evaluations','NA')}"
                )

    repeat_path = case_dir / "moderate-4-implicit-repeat.json"
    repeat = run_child(library, "implicit", "moderate", 4, repeat_path)
    primary = next(
        r for r in records
        if r["feedback_class"] == "moderate" and r["n_windows"] == 4 and r["method"] == "implicit"
    )

    repeatability = False
    if primary.get("status") == "OK" and repeat.get("status") == "OK":
        repeatability = (
            abs(primary["final_head_m"] - repeat["final_head_m"]) <= 1.0e-12
            and abs(primary["final_storage_native"] - repeat["final_storage_native"]) <= 1.0e-12
            and abs(primary["cumulative_bottom_exchange_m"] - repeat["cumulative_bottom_exchange_m"]) <= 1.0e-14
            and primary["trial_evaluations"] == repeat["trial_evaluations"]
            and primary["status"] == repeat["status"]
        )

    references: dict[str, dict[str, Any]] = {}
    for feedback_class in FEEDBACK:
        ref = next(
            r for r in records
            if r["feedback_class"] == feedback_class and r["n_windows"] == 16 and r["method"] == "implicit"
        )
        if ref.get("status") == "OK":
            references[feedback_class] = ref

    for record in records:
        ref = references.get(record["feedback_class"])
        if record.get("status") == "OK" and ref is not None:
            record["delta_head_vs_short_ref_m"] = record["final_head_m"] - ref["final_head_m"]
            record["abs_delta_head_vs_short_ref_m"] = abs(record["delta_head_vs_short_ref_m"])
            record["delta_storage_vs_short_ref_native"] = record["final_storage_native"] - ref["final_storage_native"]
            record["abs_delta_storage_vs_short_ref_native"] = abs(record["delta_storage_vs_short_ref_native"])
            record["delta_exchange_vs_short_ref_m"] = (
                record["cumulative_bottom_exchange_m"] - ref["cumulative_bottom_exchange_m"]
            )
            record["abs_delta_exchange_vs_short_ref_m"] = abs(record["delta_exchange_vs_short_ref_m"])

    result = {
        "schema": "pub-gc-e3-result-v1",
        "canonical_baseline": "06e585cc16710da00267deed878567ca1936fe7e",
        "total_horizon_day": T_TOTAL_DAY,
        "total_horizon_s": T_TOTAL_S,
        "external_head_drive_total_m": DRIVE_TOTAL_M,
        "u_base": U_BASE,
        "head_closure_tolerance_m": HEAD_TOL_M,
        "feedback_targets": FEEDBACK,
        "window_counts": WINDOW_COUNTS,
        "repeatability_pass": repeatability,
        "reference_feedback_classes": sorted(references),
        "records": records,
        "repeat_record": repeat,
    }
    (outdir / "PUB_GC_E3_RESULT.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

    fields = [
        "feedback_class", "target_cstar", "beta", "n_windows", "dt_day", "dt_s",
        "method", "status", "u_window", "c_pred", "trial_evaluations",
        "accepted_windows", "initial_head_m", "final_head_m", "initial_storage_native",
        "final_storage_native", "storage_change_native", "cumulative_bottom_exchange_m",
        "max_abs_closure_m", "final_closure_m", "delta_head_vs_short_ref_m",
        "abs_delta_head_vs_short_ref_m", "delta_storage_vs_short_ref_native",
        "abs_delta_storage_vs_short_ref_native", "delta_exchange_vs_short_ref_m",
        "abs_delta_exchange_vs_short_ref_m",
    ]
    with (outdir / "PUB_GC_E3_MATRIX.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for record in records:
            writer.writerow(record)

    status_counts: dict[str, int] = {}
    for record in records:
        status_counts[record["status"]] = status_counts.get(record["status"], 0) + 1

    print(f"PUB_GC_E3_CASE_COUNT={len(records)}")
    print(f"PUB_GC_E3_OK_CASE_COUNT={status_counts.get('OK',0)}")
    print(f"PUB_GC_E3_REFERENCE_COUNT={len(references)}")
    print("PUB_GC_E3_MATRIX_ATTEMPTED=PASS")
    if repeatability:
        print("PUB_GC_E3_REPEATABILITY=PASS")
    else:
        print("PUB_GC_E3_REPEATABILITY=FAIL")
        return 2
    print("PUB_GC_E3_EVIDENCE_RUN=PASS")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", action="store_true")
    parser.add_argument("--library")
    parser.add_argument("--method", choices=METHODS)
    parser.add_argument("--feedback-class", choices=tuple(FEEDBACK))
    parser.add_argument("--n-windows", type=int, choices=WINDOW_COUNTS)
    parser.add_argument("--output")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    if args.case:
        if not all((args.library, args.method, args.feedback_class, args.n_windows, args.output)):
            raise SystemExit("missing child case arguments")
        raise SystemExit(child_main(args))
    raise SystemExit(main_matrix())
