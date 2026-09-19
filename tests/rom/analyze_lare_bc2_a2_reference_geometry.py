#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import json
import math
import pathlib

THETA_S = 0.427494
PROFILE_DEPTH_CM = 160.0
MASS_GATE_CM = 1.0e-10
SAT_THETA_TOL = 5.0e-15
EXPECTED_STEPS = {
    "WT_HOLD": 256,
    "WT_RISE": 512,
    "WT_FALL": 512,
    "WT_CYCLE": 768,
}


def fields(payload: str) -> dict[str, str]:
    out = {}
    for part in payload.split("|"):
        if "=" in part:
            k, v = part.split("=", 1)
            out[k] = v
    return out


def diagnose_water_table(nodes: dict[int, dict[str, float]]) -> tuple[float, int]:
    if set(nodes) != set(range(1, 17)):
        raise ValueError("incomplete 16-node profile")
    crossings = []
    for i in range(1, 16):
        a, b = nodes[i], nodes[i + 1]
        ha, hb = a["h"], b["h"]
        if ha == 0.0 or hb == 0.0:
            raise ValueError("zero pressure exactly on a node")
        if ha < 0.0 and hb > 0.0:
            dz = b["z"] - a["z"]
            z_wt = a["z"] + (-ha) * dz / (hb - ha)
            crossings.append((i, -z_wt))
    if len(crossings) != 1:
        raise ValueError(f"expected one strict negative-positive crossing, got {len(crossings)}")
    lower, H = crossings[0]
    if not (0.0 < H < PROFILE_DEPTH_CM):
        raise ValueError(f"water table outside profile: {H}")
    return H, lower


def saturated_audit(nodes: dict[int, dict[str, float]]) -> tuple[int, float]:
    count = 0
    maximum = 0.0
    for row in nodes.values():
        if row["h"] > 0.0:
            count += 1
            maximum = max(maximum, abs(row["theta"] - THETA_S))
    return count, maximum


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, type=pathlib.Path)
    ap.add_argument("--repeat", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--algebra", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    raw = args.input.read_text()
    repeat = args.repeat.read_text()
    prereg = json.loads(args.prereg.read_text())
    algebra = json.loads(args.algebra.read_text())

    assert prereg["phase"] == "PREREGISTERED_BEFORE_MOVING_WATER_TABLE_REFERENCE_GEOMETRY_EXECUTION"
    assert algebra["decision"] == "BC2_SOURCE_ALGEBRA_DISCREPANCY_CONFIRMED"

    initial_meta = {}
    initial_nodes = collections.defaultdict(dict)
    state_meta = {}
    state_nodes = collections.defaultdict(dict)

    for line in raw.splitlines():
        if line.startswith("LAREBC2A2_INITIAL|"):
            row = fields(line.split("|", 1)[1])
            initial_meta[row["HISTORY"]] = {
                "total": float(row["TOTAL_STORAGE"]),
            }
        elif line.startswith("LAREBC2A2_INITIAL_NODE|"):
            row = fields(line.split("|", 1)[1])
            initial_nodes[row["HISTORY"]][int(row["NODE"])] = {
                "z": float(row["Z"]),
                "h": float(row["H"]),
                "theta": float(row["THETA"]),
            }
        elif line.startswith("LAREBC2A2_STATE|"):
            row = fields(line.split("|", 1)[1])
            key = (row["HISTORY"], int(row["STEP"]))
            state_meta[key] = {
                "t0": float(row["T0"]),
                "t1": float(row["T1"]),
                "bottom_head": float(row["BOTTOM_HEAD"]),
                "total": float(row["TOTAL_STORAGE"]),
                "bex": float(row["BOTTOM_OUTWARD_EXCHANGE"]),
                "bflux": float(row["BOTTOM_FLUX"]),
                "mass": float(row["MASS"]),
            }
        elif line.startswith("LAREBC2A2_NODE|"):
            row = fields(line.split("|", 1)[1])
            key = (row["HISTORY"], int(row["STEP"]))
            state_nodes[key][int(row["NODE"])] = {
                "z": float(row["Z"]),
                "h": float(row["H"]),
                "theta": float(row["THETA"]),
            }

    structure_ok = True
    if set(initial_meta) != set(EXPECTED_STEPS):
        structure_ok = False
    if set(initial_nodes) != set(EXPECTED_STEPS):
        structure_ok = False

    expected_keys = {
        (history, step)
        for history, nsteps in EXPECTED_STEPS.items()
        for step in range(1, nsteps + 1)
    }
    if set(state_meta) != expected_keys or set(state_nodes) != expected_keys:
        structure_ok = False

    histories = {}
    global_max_mass = 0.0
    global_max_sat_theta = 0.0
    global_max_interval_ledger = 0.0
    global_max_cumulative_ledger = 0.0
    all_geometry_ok = True

    for history, nsteps in EXPECTED_STEPS.items():
        try:
            H0, lower0 = diagnose_water_table(initial_nodes[history])
        except ValueError:
            all_geometry_ok = False
            raise
        sat_count0, sat_dev0 = saturated_audit(initial_nodes[history])
        global_max_sat_theta = max(global_max_sat_theta, sat_dev0)
        if sat_count0 < 1:
            all_geometry_ok = False

        prev_W = initial_meta[history]["total"]
        prev_H = H0
        prev_U = prev_W - THETA_S * (PROFILE_DEPTH_CM - prev_H)
        cumulative_residual = 0.0
        max_interval = 0.0
        max_sat = sat_dev0
        H_values = [H0]
        bottom_heads = []
        direction_signs = []
        prev_dH_sign = 0
        direction_changes = 0

        for step in range(1, nsteps + 1):
            key = (history, step)
            meta = state_meta[key]
            try:
                H, crossing = diagnose_water_table(state_nodes[key])
            except ValueError:
                all_geometry_ok = False
                raise
            sat_count, sat_dev = saturated_audit(state_nodes[key])
            if sat_count < 1:
                all_geometry_ok = False
            max_sat = max(max_sat, sat_dev)
            global_max_sat_theta = max(global_max_sat_theta, sat_dev)

            W = meta["total"]
            U = W - THETA_S * (PROFILE_DEPTH_CM - H)
            dH = H - prev_H
            dU = U - prev_U

            # Top flux is exactly zero in the preregistered A2 panel.
            # bottom outward exchange is positive downward/out of the soil column.
            interval_residual = dU + meta["bex"] - THETA_S * dH
            cumulative_residual += interval_residual
            max_interval = max(max_interval, abs(interval_residual))
            global_max_interval_ledger = max(global_max_interval_ledger, abs(interval_residual))
            global_max_cumulative_ledger = max(global_max_cumulative_ledger, abs(cumulative_residual))
            global_max_mass = max(global_max_mass, abs(meta["mass"]))

            sgn = 1 if dH > 0.0 else (-1 if dH < 0.0 else 0)
            if sgn != 0:
                if prev_dH_sign != 0 and sgn != prev_dH_sign:
                    direction_changes += 1
                prev_dH_sign = sgn
            direction_signs.append(sgn)
            H_values.append(H)
            bottom_heads.append(meta["bottom_head"])

            prev_W, prev_H, prev_U = W, H, U

        histories[history] = {
            "state_count": nsteps,
            "initial_H_cm": H0,
            "initial_crossing_lower_node": lower0,
            "minimum_H_cm": min(H_values),
            "maximum_H_cm": max(H_values),
            "final_H_cm": H_values[-1],
            "water_table_excursion_cm": max(H_values) - min(H_values),
            "direction_change_count": direction_changes,
            "minimum_saturated_node_count": min(
                saturated_audit(state_nodes[(history, step)])[0]
                for step in range(1, nsteps + 1)
            ),
            "max_saturated_theta_departure": max_sat,
            "max_abs_interval_moving_storage_ledger_cm": max_interval,
            "abs_cumulative_moving_storage_ledger_cm": abs(cumulative_residual),
            "bottom_head_min_cm": min(bottom_heads),
            "bottom_head_max_cm": max(bottom_heads),
        }

    hold = histories["WT_HOLD"]
    rise = histories["WT_RISE"]
    fall = histories["WT_FALL"]
    cycle = histories["WT_CYCLE"]

    behavior_ok = all([
        abs(hold["final_H_cm"] - 120.0) <= 1.0e-6,
        rise["minimum_H_cm"] < 119.0,
        fall["maximum_H_cm"] > 121.0,
        cycle["water_table_excursion_cm"] > 2.0,
        cycle["direction_change_count"] >= 1,
    ])

    qualified = all([
        raw == repeat,
        structure_ok,
        all_geometry_ok,
        behavior_ok,
        global_max_mass <= MASS_GATE_CM,
        global_max_sat_theta <= SAT_THETA_TOL,
        global_max_interval_ledger <= MASS_GATE_CM,
        global_max_cumulative_ledger <= 5.0 * MASS_GATE_CM,
        "LAREBC2A2_EXECUTION_COMPLETE=PASS" in raw,
    ])

    result = {
        "schema": "swap5.lare.bc2.a2.reference-geometry-result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-A2",
        "decision": (
            "BC2_REFERENCE_GEOMETRY_QUALIFIED"
            if qualified else
            "BC2_REFERENCE_GEOMETRY_NOT_YET_AUTHORITATIVE"
        ),
        "qualified": qualified,
        "repeat_stdout_bitwise_identity": raw == repeat,
        "structure_pass": structure_ok,
        "smooth_interior_geometry_pass": all_geometry_ok,
        "trajectory_behavior_pass": behavior_ok,
        "max_abs_reference_mass_residual_cm": global_max_mass,
        "max_saturated_node_theta_departure": global_max_sat_theta,
        "max_abs_interval_moving_storage_ledger_cm": global_max_interval_ledger,
        "max_abs_cumulative_moving_storage_ledger_cm": global_max_cumulative_ledger,
        "theta_s": THETA_S,
        "profile_depth_cm": PROFILE_DEPTH_CM,
        "histories": histories,
        "geometry_semantics": {
            "H_source": "strict interior zero-pressure crossing diagnosed from accepted full Reference profile",
            "bottom_head_used_as_H": False,
            "canonical_mode2_projection_policy_bypassed": False,
            "mode5_profile_crossing_observer": "same linear crossing geometry used only as research observation",
            "U_ref": "W_total - theta_s*(D-H)",
            "q_H_reference": "bottom outward exchange after saturated-zone theta_s audit",
        },
        "algebra_authority": algebra["decision"],
        "bc2_reduced_dynamics_authorized": qualified,
        "application_acceptance_adjudicated": False,
        "production_rom_authorized": False,
    }

    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": result["decision"],
        "max_mass": global_max_mass,
        "max_geometry_ledger": global_max_interval_ledger,
        "max_sat_theta_departure": global_max_sat_theta,
        "histories": histories,
    }, sort_keys=True))
    return 0 if qualified else 2


if __name__ == "__main__":
    raise SystemExit(main())
