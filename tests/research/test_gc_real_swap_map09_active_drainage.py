from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research" / "support"))

from gc_map09_e6_ctypes import Map09ActiveDrainageSwap


EXPECTED_HREF_M = 0.012932896258566275
EXPECTED_U = 0.0005760442426568357
EXPECTED_Q_U_CM_PER_DAY = -0.0023986744863501285
OFFSETS_M = (0.0, -1.0e-8, 1.0e-8, -1.0e-7, 1.0e-7, -1.0e-6, 1.0e-6)
FLOAT_TOL = 1.0e-14
MASS_TOL_CM = 1.0e-10


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def initialize_checked() -> tuple[Map09ActiveDrainageSwap, dict, tuple[int, float, int, float], float]:
    lib = Path(os.environ["MAP09_SWAP_LIB"]).resolve()
    require(lib.is_file(), "missing MAP09 SWAP bridge")
    swap = Map09ActiveDrainageSwap(lib)
    _, _, href = swap.initialize()
    pred = swap.predictor()
    require(swap.drainage_coverage(), "predictor lost E6 drainage tangent coverage")
    require(bool(pred["mass_complete"]), "predictor mass incomplete")
    require(
        math.isclose(href, EXPECTED_HREF_M, rel_tol=0.0, abs_tol=FLOAT_TOL),
        f"E6 reference head drift: {href}",
    )
    require(
        math.isclose(float(pred["h_end_m"]), EXPECTED_HREF_M, rel_tol=0.0, abs_tol=FLOAT_TOL),
        f"E6 predictor end head drift: {pred['h_end_m']}",
    )
    require(
        math.isclose(float(pred["u"]), EXPECTED_U, rel_tol=0.0, abs_tol=FLOAT_TOL),
        f"E6 u drift: {pred['u']}",
    )
    require(
        math.isclose(
            float(pred["q_u_cm_per_day"]),
            EXPECTED_Q_U_CM_PER_DAY,
            rel_tol=0.0,
            abs_tol=FLOAT_TOL,
        ),
        f"E6 q_u drift: {pred['q_u_cm_per_day']}",
    )
    origin = swap.state()
    require(origin == (0, 0.0, 0, 0.0), f"dirty MAP09 origin: {origin}")
    return swap, pred, origin, href


def child_probe(mode: str, offset_m: float, result_path: Path) -> None:
    swap, pred, origin, href = initialize_checked()
    head = href + offset_m

    if mode == "participant":
        status, q = swap.try_trial(head)
        if status == 0:
            require(math.isfinite(q), "nonfinite participant q")
            swap.discard()
        final_state = swap.state()
        require(final_state == origin, f"participant diagnostic mutated authority: {origin} -> {final_state}")
        result = {
            "mode": mode,
            "offset_m": offset_m,
            "head_m": head,
            "participant_status": status,
            "q_swap_m_per_s": q if status == 0 else None,
            "predictor": pred,
            "origin_state": list(origin),
            "final_state": list(final_state),
        }
    elif mode == "raw":
        diag = swap.corrector_diagnostics(head)
        final_state = swap.state()
        require(final_state == origin, f"raw diagnostic mutated authority: {origin} -> {final_state}")
        result = {
            "mode": mode,
            "offset_m": offset_m,
            "head_m": head,
            **diag,
            "predictor": pred,
            "origin_state": list(origin),
            "final_state": list(final_state),
        }
    else:
        raise AssertionError(f"unknown mode: {mode}")

    result_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("GC_MAP09_CHILD=" + json.dumps(result, sort_keys=True, separators=(",", ":")))


def run_child(mode: str, offset_m: float, workdir: Path, tag: str) -> dict:
    result_path = workdir / f"{tag}.json"
    proc = subprocess.run(
        [
            sys.executable,
            str(Path(__file__).resolve()),
            "--mode",
            mode,
            "--offset-m",
            f"{offset_m:.17g}",
            "--result",
            str(result_path),
        ],
        check=False,
        text=True,
        capture_output=True,
        env=os.environ.copy(),
    )
    if proc.stdout:
        print(proc.stdout, end="")
    if proc.stderr:
        print(proc.stderr, end="", file=sys.stderr)
    require(proc.returncode == 0, f"{mode} child failed at offset {offset_m}: {proc.returncode}")
    return json.loads(result_path.read_text(encoding="utf-8"))


def parent_main() -> None:
    with tempfile.TemporaryDirectory(prefix="gc-map09-") as tmp:
        workdir = Path(tmp)

        ref_participant = run_child("participant", 0.0, workdir, "reference-participant")
        ref_raw = run_child("raw", 0.0, workdir, "reference-raw")

        print(
            "GC_MAP09_REFERENCE="
            + json.dumps(
                {
                    "participant_status": ref_participant["participant_status"],
                    "q_swap_m_per_s": ref_participant["q_swap_m_per_s"],
                    "raw": {
                        k: ref_raw[k]
                        for k in (
                            "result_status",
                            "completed",
                            "candidate_ready",
                            "transaction_calls",
                            "accepted_substeps",
                            "attempts",
                            "retries",
                            "trial_rollbacks",
                            "solver_rejections",
                            "temporal_rejections",
                            "temporal_unavailable_rejections",
                            "mass_rejections",
                            "internal_retries",
                            "mass_complete",
                            "mass_residual_native",
                            "max_temporal_indicator",
                            "min_accepted_substep_day",
                            "max_accepted_substep_day",
                        )
                    },
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )

        # Preregistered hard stop. Do not probe offsets if the reference corrector
        # itself is outside the research backend's admitted whole-window route.
        require(
            int(ref_participant["participant_status"]) == 0,
            f"MAP09_REFERENCE_CORRECTOR_NOT_ADMITTED status={ref_participant['participant_status']} raw={ref_raw}",
        )
        require(bool(ref_raw["completed"]), f"reference raw corrector incomplete: {ref_raw}")
        require(bool(ref_raw["candidate_ready"]), f"reference candidate unavailable: {ref_raw}")
        require(bool(ref_raw["mass_complete"]), f"reference mass incomplete: {ref_raw}")
        require(
            abs(float(ref_raw["mass_residual_native"])) <= MASS_TOL_CM,
            f"reference mass residual: {ref_raw['mass_residual_native']}",
        )

        rows = []
        for index, offset in enumerate(OFFSETS_M[1:], start=1):
            participant = run_child("participant", offset, workdir, f"participant-{index}")
            raw = run_child("raw", offset, workdir, f"raw-{index}")
            row = {
                "offset_m": offset,
                "head_m": participant["head_m"],
                "participant_status": int(participant["participant_status"]),
                "q_swap_m_per_s": participant["q_swap_m_per_s"],
                "raw_result_status": int(raw["result_status"]),
                "completed": bool(raw["completed"]),
                "candidate_ready": bool(raw["candidate_ready"]),
                "mass_complete": bool(raw["mass_complete"]),
                "mass_residual_native": float(raw["mass_residual_native"]),
                "accepted_substeps": int(raw["accepted_substeps"]),
                "attempts": int(raw["attempts"]),
                "retries": int(raw["retries"]),
                "solver_rejections": int(raw["solver_rejections"]),
                "temporal_rejections": int(raw["temporal_rejections"]),
                "mass_rejections": int(raw["mass_rejections"]),
                "internal_retries": int(raw["internal_retries"]),
            }
            rows.append(row)
            print("GC_MAP09_ROW=" + json.dumps(row, sort_keys=True, separators=(",", ":")))

        valid_offsets = [float(r["offset_m"]) for r in rows if int(r["participant_status"]) == 0]
        symmetric_pairs = []
        for delta in (1.0e-8, 1.0e-7, 1.0e-6):
            if (-delta in valid_offsets) and (delta in valid_offsets):
                symmetric_pairs.append(delta)

        print("GC_MAP09_VALID_OFFSETS_M=" + ",".join(f"{x:.17g}" for x in valid_offsets))
        print("GC_MAP09_SYMMETRIC_VALID_DELTAS_M=" + ",".join(f"{x:.17g}" for x in symmetric_pairs))
        print("GC_MAP09_E6_PREDICTOR_IDENTITY=PASS")
        print("GC_MAP09_REFERENCE_CORRECTOR_ADMITTED=PASS")
        print("GC_MAP09_REFERENCE_MASS_CLOSURE=PASS")
        print("GC_MAP09_ZERO_AUTHORITY_MUTATION=PASS")
        print("GC_MAP09_CHARACTERIZATION_RECORDED=PASS")
        print("GC_MAP09_LIVE_GATE=PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("participant", "raw"))
    parser.add_argument("--offset-m", type=float)
    parser.add_argument("--result", type=Path)
    args = parser.parse_args()

    if args.mode is None:
        require(args.offset_m is None and args.result is None, "incomplete child arguments")
        parent_main()
    else:
        require(args.offset_m is not None and args.result is not None, "incomplete child arguments")
        child_probe(args.mode, float(args.offset_m), args.result)


if __name__ == "__main__":
    main()
