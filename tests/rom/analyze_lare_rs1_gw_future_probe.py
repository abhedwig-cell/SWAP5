#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import json
import math
import pathlib

HARD_MASS_GATE_CM = 1.0e-12


def fields(payload: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in payload.split("|"):
        if "=" in part:
            key, value = part.split("=", 1)
            out[key] = value
    return out


def sign(value: float) -> int:
    if value > 0.0:
        return 1
    if value < 0.0:
        return -1
    return 0


def reversal_steps(rows: list[tuple[int, float]]) -> list[int]:
    result: list[int] = []
    prev = 0
    for step, value in sorted(rows):
        current = sign(value)
        if current == 0:
            continue
        if prev != 0 and current != prev:
            result.append(step)
        prev = current
    return result


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, type=pathlib.Path)
    ap.add_argument("--repeat", required=True, type=pathlib.Path)
    ap.add_argument("--reference", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    raw = args.input.read_text()
    repeat = args.repeat.read_text()
    refraw = args.reference.read_text()
    prereg = json.loads(args.prereg.read_text())

    pairs = prereg["frozen_collision_pairs"]
    probes = [row["id"] for row in prereg["future_probes"]["probe_definitions"]]
    horizons = [int(x) for x in prereg["future_probes"]["horizon_steps"]]

    expected_starts: set[tuple[str, int]] = set()
    for pair in pairs:
        expected_starts.add((pair["a"]["history"], int(pair["a"]["step"])))
        expected_starts.add((pair["b"]["history"], int(pair["b"]["step"])))

    reference_nodes: dict[tuple[str, int], dict[int, tuple[float, float]]] = {}
    for line in refraw.splitlines():
        if "LAREGW1_NODE|" not in line:
            continue
        row = fields(line.split("LAREGW1_NODE|", 1)[1])
        key = (row["HISTORY"], int(row["STEP"]))
        if key not in expected_starts:
            continue
        reference_nodes.setdefault(key, {})[int(row["NODE"])] = (
            float(row["H"]), float(row["THETA"])
        )

    start_nodes: dict[tuple[str, int], dict[int, tuple[float, float]]] = {}
    endpoint_rows: dict[tuple[str, int, str, int], dict[str, float | int]] = {}
    step_rows: dict[tuple[str, int, str], list[tuple[int, float]]] = collections.defaultdict(list)
    fallback_classes = collections.Counter()
    max_step_mass = 0.0
    unique_start_marker = None

    for line in raw.splitlines():
        if "LAREGW1P_START_NODE|" in line:
            row = fields(line.split("LAREGW1P_START_NODE|", 1)[1])
            key = (row["HISTORY"], int(row["STEP"]))
            start_nodes.setdefault(key, {})[int(row["NODE"])] = (
                float(row["H"]), float(row["THETA"])
            )
        elif "LAREGW1P_PROBE|" in line:
            row = fields(line.split("LAREGW1P_PROBE|", 1)[1])
            key = (
                row["HISTORY"], int(row["START_STEP"]),
                row["PROBE"], int(row["HORIZON_STEP"])
            )
            if key in endpoint_rows:
                raise SystemExit(f"duplicate endpoint row {key}")
            endpoint_rows[key] = {
                "d_total": float(row["D_TOTAL_STORAGE"]),
                "d_upper": float(row["D_UPPER_STORAGE"]),
                "d_lower": float(row["D_LOWER_STORAGE"]),
                "cum_top": float(row["CUM_TOP_EXCHANGE"]),
                "cum_bottom": float(row["CUM_BOTTOM_OUTWARD_EXCHANGE"]),
                "terminal_bottom_flux": float(row["TERMINAL_BOTTOM_FLUX"]),
                "fallback_count": int(row["FALLBACK_COUNT"]),
                "max_abs_mass": float(row["MAX_ABS_MASS"]),
            }
        elif "LAREGW1P_STEP|" in line:
            row = fields(line.split("LAREGW1P_STEP|", 1)[1])
            key = (row["HISTORY"], int(row["START_STEP"]), row["PROBE"])
            step = int(row["STEP"])
            flux = float(row["BOTTOM_FLUX"])
            mass = abs(float(row["MASS"]))
            max_step_mass = max(max_step_mass, mass)
            step_rows[key].append((step, flux))
        elif "LAREGW1P_FALLBACK|" in line:
            row = fields(line.split("LAREGW1P_FALLBACK|", 1)[1])
            fallback_classes[row.get("CLASS", "UNKNOWN")] += 1
        elif line.startswith("LAREGW1P_UNIQUE_START_COUNT="):
            unique_start_marker = int(line.rsplit("=", 1)[1])

    start_identity = True
    identity_failures = []
    for key in sorted(expected_starts):
        ref = reference_nodes.get(key, {})
        got = start_nodes.get(key, {})
        if set(ref) != set(range(1, 17)) or set(got) != set(range(1, 17)):
            start_identity = False
            identity_failures.append({"history": key[0], "step": key[1], "reason": "missing_nodes"})
            continue
        for node in range(1, 17):
            if ref[node] != got[node]:
                start_identity = False
                identity_failures.append({
                    "history": key[0], "step": key[1], "node": node,
                    "reference_h": ref[node][0], "probe_h": got[node][0],
                    "reference_theta": ref[node][1], "probe_theta": got[node][1],
                })
                break

    expected_endpoint_keys = {
        (history, step, probe, horizon)
        for history, step in expected_starts
        for probe in probes
        for horizon in horizons
    }
    expected_step_keys = {
        (history, step, probe)
        for history, step in expected_starts
        for probe in probes
    }
    endpoint_structure = set(endpoint_rows) == expected_endpoint_keys
    step_structure = (
        set(step_rows) == expected_step_keys
        and all(len(rows) == 1024 for rows in step_rows.values())
    )

    comparisons = []
    probe_pair_summaries = []
    sign_mismatch_records = 0
    reversal_sequence_mismatch_records = 0

    maxima = {
        "delta_total_storage_cm": 0.0,
        "delta_upper_storage_cm": 0.0,
        "delta_lower_storage_cm": 0.0,
        "cumulative_bottom_exchange_cm": 0.0,
        "terminal_bottom_flux_cm_per_day": 0.0,
    }

    for pair in pairs:
        pair_id = pair["id"]
        ka = (pair["a"]["history"], int(pair["a"]["step"]))
        kb = (pair["b"]["history"], int(pair["b"]["step"]))

        for probe in probes:
            rev_a = reversal_steps(step_rows.get((ka[0], ka[1], probe), []))
            rev_b = reversal_steps(step_rows.get((kb[0], kb[1], probe), []))
            reversal_match = rev_a == rev_b
            if not reversal_match:
                reversal_sequence_mismatch_records += 1

            probe_pair_summaries.append({
                "pair_id": pair_id,
                "probe": probe,
                "a_reversal_steps": rev_a,
                "b_reversal_steps": rev_b,
                "reversal_sequence_match": reversal_match,
            })

            for horizon in horizons:
                a = endpoint_rows.get((ka[0], ka[1], probe, horizon))
                b = endpoint_rows.get((kb[0], kb[1], probe, horizon))
                if a is None or b is None:
                    continue

                diffs = {
                    "delta_total_storage_cm": abs(float(a["d_total"]) - float(b["d_total"])),
                    "delta_upper_storage_cm": abs(float(a["d_upper"]) - float(b["d_upper"])),
                    "delta_lower_storage_cm": abs(float(a["d_lower"]) - float(b["d_lower"])),
                    "cumulative_bottom_exchange_cm": abs(float(a["cum_bottom"]) - float(b["cum_bottom"])),
                    "terminal_bottom_flux_cm_per_day": abs(
                        float(a["terminal_bottom_flux"]) - float(b["terminal_bottom_flux"])
                    ),
                }
                for key, value in diffs.items():
                    maxima[key] = max(maxima[key], value)

                sa = sign(float(a["terminal_bottom_flux"]))
                sb = sign(float(b["terminal_bottom_flux"]))
                mismatch = sa != sb
                if mismatch:
                    sign_mismatch_records += 1

                comparisons.append({
                    "pair_id": pair_id,
                    "probe": probe,
                    "horizon_step": horizon,
                    "horizon_day": horizon * 0.0008,
                    "differences": diffs,
                    "terminal_bottom_flux_sign_a": sa,
                    "terminal_bottom_flux_sign_b": sb,
                    "terminal_bottom_flux_sign_mismatch": mismatch,
                    "a_fallback_count": int(a["fallback_count"]),
                    "b_fallback_count": int(b["fallback_count"]),
                })

    top_bottom = sorted(
        comparisons,
        key=lambda row: (
            -row["differences"]["cumulative_bottom_exchange_cm"],
            -row["differences"]["terminal_bottom_flux_cm_per_day"],
            row["pair_id"], row["probe"], row["horizon_step"]
        )
    )[:12]
    top_storage = sorted(
        comparisons,
        key=lambda row: (
            -row["differences"]["delta_total_storage_cm"],
            -row["differences"]["delta_lower_storage_cm"],
            row["pair_id"], row["probe"], row["horizon_step"]
        )
    )[:12]

    complete = all([
        raw == repeat,
        start_identity,
        endpoint_structure,
        step_structure,
        unique_start_marker == len(expected_starts),
        max_step_mass <= HARD_MASS_GATE_CM,
        "LAREGW1P_EXECUTION_COMPLETE=PASS" in raw,
    ])

    result = {
        "schema": "swap5.lare.rs1.gw.future-probe-result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-RS1-GW-P1",
        "decision": (
            "LARE_RS1_GW_TWO_LAYER_RESPONSE_AMBIGUITY_MEASURED"
            if complete else
            "LARE_RS1_GW_FUTURE_PROBE_EVIDENCE_BLOCKED"
        ),
        "evidence_complete": complete,
        "repeat_stdout_bitwise_identity": raw == repeat,
        "unique_start_state_count": len(expected_starts),
        "start_state_identity_with_stage_A_library": start_identity,
        "start_identity_failures": identity_failures[:8],
        "endpoint_record_count": len(endpoint_rows),
        "expected_endpoint_record_count": len(expected_endpoint_keys),
        "step_series_count": len(step_rows),
        "expected_step_series_count": len(expected_step_keys),
        "step_structure_complete": step_structure,
        "max_abs_committed_mass_residual_cm": max_step_mass,
        "hard_mass_gate_cm": HARD_MASS_GATE_CM,
        "fallback_class_counts": dict(fallback_classes),
        "pair_count": len(pairs),
        "probe_count": len(probes),
        "horizons": horizons,
        "comparison_record_count": len(comparisons),
        "terminal_bottom_flux_sign_mismatch_record_count": sign_mismatch_records,
        "pair_probe_reversal_sequence_mismatch_count": reversal_sequence_mismatch_records,
        "maximum_response_difference": maxima,
        "top_bottom_exchange_ambiguity_records": top_bottom,
        "top_storage_ambiguity_records": top_storage,
        "pair_probe_reversal_summaries": probe_pair_summaries,
        "hydrological_acceptance_adjudicated": False,
        "acceptance_note": (
            "No purpose threshold is applied here. A later envelope work unit must source and "
            "freeze hydrological tolerances independently of these observed pair responses."
        ),
        "pair_reselection_after_response": False,
        "lare_dynamics_executed": False,
        "closure_model_fit": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": result["schema"],
        "decision": result["decision"],
        "evidence_complete": complete,
        "maximum_response_difference": maxima,
        "terminal_bottom_flux_sign_mismatch_record_count": sign_mismatch_records,
        "pair_probe_reversal_sequence_mismatch_count": reversal_sequence_mismatch_records,
    }, sort_keys=True))
    return 0 if complete else 2


if __name__ == "__main__":
    raise SystemExit(main())
