#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import math
import pathlib


EXPECTED_HISTORIES = {f"G{i:02d}" for i in range(6)}
EXPECTED_STEPS = 1024
EXPECTED_STATES = 6 * EXPECTED_STEPS
HARD_MASS_GATE_CM = 1.0e-12


def fields(payload: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in payload.split("|"):
        if "=" in part:
            key, value = part.split("=", 1)
            out[key] = value
    return out


def as_bool(value: str) -> bool:
    return value.strip().upper() in {"T", "TRUE", ".TRUE.", "1"}


def nonzero_sign(value: float) -> int:
    if value > 0.0:
        return 1
    if value < 0.0:
        return -1
    return 0


def reversal_steps(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    events: list[dict[str, object]] = []
    previous_sign = 0
    previous_step = None
    for row in sorted(rows, key=lambda r: int(r["STEP"])):
        value = float(row["BOTTOM_FLUX"])
        sign = nonzero_sign(value)
        if sign == 0:
            continue
        step = int(row["STEP"])
        if previous_sign != 0 and sign != previous_sign:
            events.append({
                "step": step,
                "previous_nonzero_step": previous_step,
                "from_sign": previous_sign,
                "to_sign": sign,
                "terminal_bottom_flux_cm_per_day": value,
            })
        previous_sign = sign
        previous_step = step
    return events


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=pathlib.Path)
    parser.add_argument("--repeat", required=True, type=pathlib.Path)
    parser.add_argument("--prereg", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    args = parser.parse_args()

    raw = args.input.read_text()
    repeat = args.repeat.read_text()
    prereg = json.loads(args.prereg.read_text())
    repeat_identity = raw == repeat

    states: list[dict[str, str]] = []
    nodes: dict[tuple[str, int], dict[int, tuple[float, float]]] = collections.defaultdict(dict)
    history_pass: list[dict[str, str]] = []
    fallbacks: list[dict[str, str]] = []
    summary: dict[str, str] = {}

    for line in raw.splitlines():
        if "LAREGW1_STATE|" in line:
            states.append(fields(line.split("LAREGW1_STATE|", 1)[1]))
        elif "LAREGW1_NODE|" in line:
            row = fields(line.split("LAREGW1_NODE|", 1)[1])
            nodes[(row["HISTORY"], int(row["STEP"]))][int(row["NODE"])] = (
                float(row["H"]), float(row["THETA"])
            )
        elif "LAREGW1_HISTORY_PASS|" in line:
            history_pass.append(fields(line.split("LAREGW1_HISTORY_PASS|", 1)[1]))
        elif "LAREGW1_FALLBACK|" in line:
            fallbacks.append(fields(line.split("LAREGW1_FALLBACK|", 1)[1]))
        elif line.startswith("LAREGW1_") and "=" in line and "|" not in line:
            key, value = line.split("=", 1)
            summary[key] = value.strip()

    by_history: dict[str, list[dict[str, str]]] = collections.defaultdict(list)
    for row in states:
        by_history[row["HISTORY"]].append(row)

    expected_keys = {(history, step) for history in EXPECTED_HISTORIES for step in range(1, EXPECTED_STEPS + 1)}
    observed_keys = {(row["HISTORY"], int(row["STEP"])) for row in states}

    structure_ok = (
        len(states) == EXPECTED_STATES
        and set(by_history) == EXPECTED_HISTORIES
        and all(len(by_history[h]) == EXPECTED_STEPS for h in EXPECTED_HISTORIES)
        and observed_keys == expected_keys
        and set(nodes) == expected_keys
        and all(set(nodes[key]) == set(range(1, 17)) for key in expected_keys)
        and len(history_pass) == len(EXPECTED_HISTORIES)
        and {row["HISTORY"] for row in history_pass} == EXPECTED_HISTORIES
    )

    finite_ok = True
    max_abs_mass = 0.0
    theta_min = math.inf
    theta_max = -math.inf
    head_min = math.inf
    head_max = -math.inf
    fallback_state_count = 0

    for row in states:
        numeric = [
            float(row["TOTAL_STORAGE"]),
            float(row["UPPER_STORAGE"]),
            float(row["LOWER_STORAGE"]),
            float(row["TOP_EXCHANGE"]),
            float(row["BOTTOM_OUTWARD_EXCHANGE"]),
            float(row["BOTTOM_FLUX"]),
            float(row["MASS"]),
        ]
        finite_ok &= all(math.isfinite(value) for value in numeric)
        max_abs_mass = max(max_abs_mass, abs(float(row["MASS"])))
        fallback_state_count += int(as_bool(row["FALLBACK"]))

    for profile in nodes.values():
        for head, theta in profile.values():
            finite_ok &= math.isfinite(head) and math.isfinite(theta)
            head_min = min(head_min, head)
            head_max = max(head_max, head)
            theta_min = min(theta_min, theta)
            theta_max = max(theta_max, theta)

    histories: dict[str, object] = {}
    for history in sorted(EXPECTED_HISTORIES):
        rows = sorted(by_history[history], key=lambda r: int(r["STEP"]))
        bottom_flux = [float(r["BOTTOM_FLUX"]) for r in rows]
        histories[history] = {
            "state_count": len(rows),
            "first_symbol": rows[0]["SYMBOL"],
            "last_symbol": rows[-1]["SYMBOL"],
            "bottom_flux_min_cm_per_day": min(bottom_flux),
            "bottom_flux_max_cm_per_day": max(bottom_flux),
            "cumulative_bottom_outward_exchange_cm": sum(float(r["BOTTOM_OUTWARD_EXCHANGE"]) for r in rows),
            "reversal_events": reversal_steps(rows),
            "fallback_state_count": sum(int(as_bool(r["FALLBACK"])) for r in rows),
            "final_total_storage_cm": float(rows[-1]["TOTAL_STORAGE"]),
            "final_upper_storage_cm": float(rows[-1]["UPPER_STORAGE"]),
            "final_lower_storage_cm": float(rows[-1]["LOWER_STORAGE"]),
        }

    fallback_classes = collections.Counter(row.get("CLASS", "UNKNOWN") for row in fallbacks)
    summary_ok = (
        summary.get("LAREGW1_HISTORY_COUNT") == "6"
        and summary.get("LAREGW1_STEPS_PER_HISTORY") == str(EXPECTED_STEPS)
        and summary.get("LAREGW1_STATE_COUNT") == str(EXPECTED_STATES)
        and summary.get("LAREGW1_EXECUTION_COMPLETE") == "PASS"
    )
    prereg_ok = (
        prereg["phase"] == "PREREGISTERED_BEFORE_NEW_GW_LIBRARY_EXECUTION"
        and prereg["stage_A"]["maximum_steps_per_long_history"] == EXPECTED_STEPS
        and all(history["steps"] == EXPECTED_STEPS for history in prereg["stage_A"]["histories"])
        and prereg["firewalls"][0] == "NO_LARE_DYNAMICS_IN_RS1_GW"
    )

    qualified = all([
        repeat_identity,
        structure_ok,
        finite_ok,
        summary_ok,
        prereg_ok,
        max_abs_mass <= HARD_MASS_GATE_CM,
        fallback_state_count == len(fallbacks),
    ])

    decision = (
        "LARE_RS1_GW_STAGE_A_REFERENCE_LIBRARY_QUALIFIED"
        if qualified
        else "LARE_RS1_GW_STAGE_A_REFERENCE_LIBRARY_NO_GO"
    )

    result = {
        "schema": "swap5.lare.rs1.gw.stage-a-result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-RS1-GW-A",
        "decision": decision,
        "reference_library": {
            "qualified": qualified,
            "state_count": len(states),
            "history_count": len(by_history),
            "steps_per_history": EXPECTED_STEPS,
            "node_record_count": sum(len(profile) for profile in nodes.values()),
            "structure_pass": structure_ok,
            "finite_pass": finite_ok,
            "repeat_stdout_bitwise_identity": repeat_identity,
            "max_abs_step_mass_residual_cm": max_abs_mass,
            "hard_mass_gate_cm": HARD_MASS_GATE_CM,
            "fallback_count": len(fallbacks),
            "fallback_state_count": fallback_state_count,
            "fallback_classes": dict(fallback_classes),
            "theta_range": [theta_min, theta_max],
            "pressure_head_range_cm": [head_min, head_max],
        },
        "histories": histories,
        "control": {
            "G00_first_64_steps_role": "current-canonical replay of the historical H02 forcing shape, followed by preregistered HOLD relaxation",
            "historical_ROMV_full_order_second_reversal_step": prereg["known_control"]["full_order_second_bottom_flux_reversal_step"],
            "historical_ROMV_failed_reduced_second_reversal_step": prereg["known_control"]["historical_reduced_prediction_step"],
            "current_G00_reversal_events": histories.get("G00", {}).get("reversal_events", []),
            "historical_step_is_not_an_acceptance_oracle_for_changed_current_reference": True,
        },
        "input_sha256": hashlib.sha256(raw.encode()).hexdigest(),
        "repeat_sha256": hashlib.sha256(repeat.encode()).hexdigest(),
        "preregistration_sha256": hashlib.sha256(args.prereg.read_bytes()).hexdigest(),
        "lare_dynamics_executed": False,
        "closure_model_fit": False,
        "production_rom_authorized": False,
    }

    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": result["schema"],
        "decision": decision,
        "reference_library": result["reference_library"],
        "control": result["control"],
    }, sort_keys=True))
    return 0 if qualified else 2


if __name__ == "__main__":
    raise SystemExit(main())
