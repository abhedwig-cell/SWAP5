#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent


def load_module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


c3 = load_module("bc2c3", "analyze_lare_bc2_c3_signed_bias_case.py")
c1 = c3.c1
c0 = c3.c0

PRIMARY_DT = c3.PRIMARY_DT
CROSS_DT = c3.CROSS_DT
DTS = (PRIMARY_DT, CROSS_DT)
OBS_DT = c3.OBS_DT
GATE = c3.GATE
NFIXED = c3.NFIXED
PHYS_N = c3.PHYS_N
IDX_WB = c3.IDX_WB
IDX_WT = c3.IDX_WT
THETA_S = c3.THETA_S
FAMILY_MEMBERS = c3.FAMILY_MEMBERS
ELEMENTARY_KEYS = c3.ELEMENTARY_KEYS

PHASES = {
    "RISE_1": (1, 256, -1),
    "FALL": (257, 512, +1),
    "RISE_2": (513, 768, -1),
}
TAILS = {
    "FALL_TAIL": (258, 512),
    "RISE_2_TAIL": (514, 768),
}
REVERSALS = (257, 513)


def sign(x: float) -> int:
    return 1 if x > 0.0 else (-1 if x < 0.0 else 0)


def route_records(d: float, dt: float, init_meta, init_nodes, states, nodes):
    records = []
    max_add = 0.0
    max_teacher_ledger = 0.0
    max_reference_ledger = 0.0
    max_q90_teacher_identity = 0.0
    max_q90_reference_identity = 0.0
    max_shape_mass_neutral = 0.0

    for step in range(1, c0.HISTORY_STEPS["WT_CYCLE"] + 1):
        y0, p0, _ = c1.exact_reference_state(
            "WT_CYCLE", step - 1, d, init_meta, init_nodes, states, nodes
        )
        yr, p1, _ = c1.exact_reference_state(
            "WT_CYCLE", step, d, init_meta, init_nodes, states, nodes
        )
        H0 = float(p0["H"])
        H1 = float(p1["H"])
        teacher = c1.advance_interval(y0, H0, H1, dt, d)
        yt = np.asarray(teacher["y"][:PHYS_N], dtype=float)
        y0p = np.asarray(y0[:PHYS_N], dtype=float)
        yrp = np.asarray(yr[:PHYS_N], dtype=float)

        qteach = c3.fixed_fluxes_from_storage(y0p[:NFIXED], yt[:NFIXED])
        qref = c3.fixed_fluxes_from_storage(y0p[:NFIXED], yrp[:NFIXED])
        refs = c1.reference_fluxes("WT_CYCLE", step, p0, p1, states)

        max_q90_teacher_identity = max(
            max_q90_teacher_identity, abs(float(qteach[-1]) - float(teacher["q90"]))
        )
        max_q90_reference_identity = max(
            max_q90_reference_identity, abs(float(qref[-1]) - float(refs["q90"]))
        )

        Gi_teacher = (
            float(yt[IDX_WB] - y0p[IDX_WB]) / OBS_DT
            - float(qteach[-1])
            + float(teacher["qi"])
        )
        Gi_ref = (
            float(yrp[IDX_WB] - y0p[IDX_WB]) / OBS_DT
            - float(qref[-1])
            + float(refs["qi"])
        )

        errors = {}
        for j, key in enumerate(c3.FIXED_KEYS):
            errors[key] = float(qteach[j] - qref[j])
        errors["QI"] = float(teacher["qi"]) - float(refs["qi"])
        errors["QH"] = float(teacher["qH"]) - float(refs["qH"])
        errors["GEOMETRY_GI"] = Gi_teacher - Gi_ref

        contrib = c3.contribution_vectors(errors)
        summed = np.sum(np.stack(list(contrib.values())), axis=0)
        local = yt - yrp
        max_add = max(max_add, float(np.max(np.abs(summed - local))))

        tledger = (
            float(np.sum(yt - y0p))
            + float(teacher["qH"]) * OBS_DT
            - THETA_S * (H1 - H0)
        )
        rledger = (
            float(np.sum(yrp - y0p))
            + float(refs["qH"]) * OBS_DT
            - THETA_S * (H1 - H0)
        )
        max_teacher_ledger = max(max_teacher_ledger, abs(tledger))
        max_reference_ledger = max(max_reference_ledger, abs(rledger))

        for key in ELEMENTARY_KEYS:
            _, residual = c3.shape_rms(contrib[key], H1, d)
            max_shape_mass_neutral = max(max_shape_mass_neutral, abs(residual))

        records.append({
            "step": step,
            "H0": H0,
            "H1": H1,
            "dH": H1 - H0,
            "errors": errors,
            "contrib": contrib,
        })

    hard = {
        "max_channel_state_additivity_residual_cm": max_add,
        "max_teacher_physical_ledger_residual_cm": max_teacher_ledger,
        "max_reference_physical_ledger_residual_cm": max_reference_ledger,
        "max_teacher_q90_reconstruction_identity_cm_per_day": max_q90_teacher_identity,
        "max_reference_q90_reconstruction_identity_cm_per_day": max_q90_reference_identity,
        "max_mass_neutral_projection_residual_cm": max_shape_mass_neutral,
        "gate": GATE,
    }
    hard["qualified"] = max(hard[k] for k in hard if k != "gate") <= GATE
    return records, hard


def family_interval_vector(record, members):
    return np.sum(
        np.stack([record["contrib"][member] for member in members]), axis=0
    )


def summarize_segment(records, start: int, end: int, d: float):
    selected = records[start - 1:end]
    if len(selected) != end - start + 1:
        raise ValueError("segment selection mismatch")
    families = {}

    for family, members in FAMILY_MEMBERS.items():
        biases = np.asarray(
            [sum(float(row["errors"][m]) for m in members) for row in selected],
            dtype=float,
        )
        vectors = [family_interval_vector(row, members) for row in selected]
        shape_values = [
            c3.shape_rms(v, float(row["H1"]), d)[0]
            for row, v in zip(selected, vectors)
        ]
        cumulative = np.sum(np.stack(vectors), axis=0)
        families[family] = c3.summarize_channel(
            biases, shape_values, cumulative, float(selected[-1]["H1"]), d
        )

    rank = sorted(
        families,
        key=lambda name: (
            -families[name]["cumulative_injection_shape_rms_theta_at_final_geometry"],
            name,
        ),
    )
    return {
        "steps": [start, end],
        "interval_count": len(selected),
        "H_start_cm": float(selected[0]["H0"]),
        "H_end_cm": float(selected[-1]["H1"]),
        "dH_total_cm": float(selected[-1]["H1"] - selected[0]["H0"]),
        "family_rank_by_phase_local_cumulative_shape_injection": rank,
        "families": families,
    }


def cancellation_ratio(segments, family: str):
    signed = [
        float(segments[name]["families"][family]["signed_integrated_bias_cm"])
        for name in ("RISE_1", "FALL", "RISE_2")
    ]
    denominator = sum(abs(x) for x in signed)
    ratio = 0.0 if denominator == 0.0 else 1.0 - abs(sum(signed)) / denominator
    return {
        "phase_signed_integrated_bias_cm": signed,
        "has_both_signs": any(x > 0.0 for x in signed) and any(x < 0.0 for x in signed),
        "directional_cancellation_ratio": float(ratio),
    }


def run_width_route(d: float, dt: float, init_meta, init_nodes, states, nodes):
    records, hard = route_records(d, dt, init_meta, init_nodes, states, nodes)

    # Frozen A2 direction-run authority. No response quantity enters this check.
    for name, (start, end, expected_sign) in PHASES.items():
        signs = {sign(float(records[step - 1]["dH"])) for step in range(start, end + 1)}
        if signs != {expected_sign}:
            raise ValueError(f"{name} dH sign authority mismatch: {signs}")

    segments = {
        name: summarize_segment(records, start, end, d)
        for name, (start, end, _) in PHASES.items()
    }
    tails = {
        name: summarize_segment(records, start, end, d)
        for name, (start, end) in TAILS.items()
    }
    reversals = {
        str(step): summarize_segment(records, step, step, d)
        for step in REVERSALS
    }
    running = {
        str(boundary): summarize_segment(records, 1, boundary, d)
        for boundary in (256, 512, 768)
    }

    phase_tops = {
        name: row["family_rank_by_phase_local_cumulative_shape_injection"][0]
        for name, row in segments.items()
    }
    tail_tops = {
        name: row["family_rank_by_phase_local_cumulative_shape_injection"][0]
        for name, row in tails.items()
    }
    reversal_tops = {
        step: row["family_rank_by_phase_local_cumulative_shape_injection"][0]
        for step, row in reversals.items()
    }

    return {
        "dt_day": dt,
        "hard_checks": hard,
        "phases": segments,
        "tails": tails,
        "reversal_intervals": reversals,
        "cycle_running": running,
        "phase_top_families": phase_tops,
        "tail_top_families": tail_tops,
        "reversal_top_families": reversal_tops,
        "cancellation": {
            "QI": cancellation_ratio(segments, "QI"),
            "QH": cancellation_ratio(segments, "QH"),
            "Q90": cancellation_ratio(segments, "Q90"),
        },
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--reference", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--c3", required=True, type=pathlib.Path)
    ap.add_argument("--c3a", required=True, type=pathlib.Path)
    ap.add_argument("--width", required=True, type=float)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    c3result = json.loads(args.c3.read_text())
    c3a = json.loads(args.c3a.read_text())

    assert pre["phase"] == "PREREGISTERED_AFTER_C3_CLOSEOUT_BEFORE_PHASE_RESOLVED_BIAS_EXECUTION"
    assert c3result["decision"] == "BC2_C3_SIGNED_LOCAL_BIAS_LEDGER_MAPPED"
    assert c3a["decision"] == "REGIME_DEPENDENT_BIAS_INJECTION"
    assert args.width in tuple(float(x) for x in pre["model_policy"]["widths_cm"])

    init_meta, init_nodes, states, nodes = c0.b0.load_reference(args.reference)
    routes = {}
    failures = {}
    for dt in DTS:
        key = f"{dt:.8f}"
        try:
            routes[key] = run_width_route(
                args.width, dt, init_meta, init_nodes, states, nodes
            )
            if not routes[key]["hard_checks"]["qualified"]:
                failures[key] = "HARD_GATE_FAILED"
        except (ValueError, RuntimeError, FloatingPointError) as exc:
            failures[key] = str(exc)

    pk = f"{PRIMARY_DT:.8f}"
    ck = f"{CROSS_DT:.8f}"
    complete = not failures and pk in routes and ck in routes

    route_rank_match = {}
    if complete:
        for group in ("phases", "tails", "reversal_intervals"):
            route_rank_match[group] = {
                name: (
                    routes[pk][group][name]["family_rank_by_phase_local_cumulative_shape_injection"]
                    == routes[ck][group][name]["family_rank_by_phase_local_cumulative_shape_injection"]
                )
                for name in routes[pk][group]
            }

    c3_whole_top = c3result["cases"][str(args.width)]["WT_CYCLE"]["routes"][pk][
        "family_rank_by_cumulative_shape_injection"
    ][0]

    result = {
        "schema": "swap5.lare.bc2.c4d.case-result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-C4D",
        "width_cm": args.width,
        "decision": "BC2_C4D_PHASE_RESOLVED_CYCLE_MAPPED" if complete else "BC2_C4D_CASE_BLOCKED",
        "complete": complete,
        "whole_cycle_C3_top_family": c3_whole_top,
        "routes": routes,
        "primary_cross_rank_match": route_rank_match,
        "failures": failures,
        "model_changed": False,
        "next_model_change_authorized": False,
        "production_rom_authorized": False,
    }

    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    if complete:
        print(json.dumps({
            "decision": result["decision"],
            "width_cm": args.width,
            "whole_cycle_C3_top_family": c3_whole_top,
            "primary_phase_tops": routes[pk]["phase_top_families"],
            "primary_tail_tops": routes[pk]["tail_top_families"],
            "primary_reversal_tops": routes[pk]["reversal_top_families"],
            "primary_QI_cancellation": routes[pk]["cancellation"]["QI"],
            "primary_QH_cancellation": routes[pk]["cancellation"]["QH"],
            "rank_match": route_rank_match,
            "hard_checks": routes[pk]["hard_checks"],
        }, sort_keys=True))
    else:
        print(json.dumps({"decision": result["decision"], "failures": failures}, sort_keys=True))
    return 0 if complete else 2


if __name__ == "__main__":
    raise SystemExit(main())
