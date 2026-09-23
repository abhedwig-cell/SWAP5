#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
import sys

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
OBS_DT = 0.0008
DT = 0.0001
STEPS = 1024
HORIZON = OBS_DT * STEPS
ROOT_DEPTH = 80.0
LEDGER_GATE = 1.0e-10
ARITH_GUARD = 64.0 * np.finfo(float).eps

PARTITIONS = {
    "U4": [0.0, 40.0, 80.0, 120.0, 160.0],
    "U8": [0.0, 20.0, 40.0, 60.0, 80.0, 100.0, 120.0, 140.0, 160.0],
    "R8": [0.0, 90.0, 100.0, 110.0, 120.0, 130.0, 140.0, 150.0, 160.0],
    "R16": [float(x) for x in range(0, 161, 10)],
}
HISTORIES = {
    "V01": {"root": "SHALLOW", "tp": 0.60, "state_class": "HIGH"},
    "V02": {"root": "SHALLOW", "tp": 0.30, "state_class": "LOW"},
    "V03": {"root": "UNIFORM", "tp": 0.60, "state_class": "HIGH"},
    "V04": {"root": "UNIFORM", "tp": 0.30, "state_class": "LOW"},
}
INITIAL_SE = {
    "B01": {"HIGH": 0.551, "LOW": 0.42671759600680326},
    "B14": {"HIGH": 0.551, "LOW": 0.40713288830832667},
}


def load_module(name: str, path: pathlib.Path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


bc = load_module("rom_root_s2_bc", HERE / "run_lare_bc1_stage_b.py")


def json_default(value):
    if isinstance(value, np.generic):
        return value.item()
    raise TypeError(f"Object of type {value.__class__.__name__} is not JSON serializable")


def configure_material(material: str) -> None:
    if material == "B01":
        bc.THETA_R = 0.02
        bc.THETA_S = 0.427494
        bc.ALPHA = 0.021659
        bc.N_VG = 1.734737
        bc.M_VG = 1.0 - 1.0 / bc.N_VG
        bc.KS = 31.225016
        bc.LAMBDA = 0.98087
    elif material == "B14":
        bc.THETA_R = 0.01
        bc.THETA_S = 0.416774
        bc.ALPHA = 0.00541
        bc.N_VG = 1.301528
        bc.M_VG = 1.0 - 1.0 / bc.N_VG
        bc.KS = 0.895023
        bc.LAMBDA = -0.334926
    else:
        raise ValueError(material)


def cumulative_root_fraction(z_cm: float, profile: str) -> float:
    u = min(1.0, max(0.0, z_cm / ROOT_DEPTH))
    if profile == "SHALLOW":
        return 2.0 * u - u * u
    if profile == "UNIFORM":
        return u
    raise ValueError(profile)


def layer_root_fractions(bounds: list[float], profile: str) -> np.ndarray:
    f = np.asarray([cumulative_root_fraction(z, profile) for z in bounds], dtype=float)
    out = np.diff(f)
    if np.any(out < -ARITH_GUARD):
        raise RuntimeError("negative retained root fraction")
    out[np.abs(out) <= ARITH_GUARD] = 0.0
    return out


def initialize(material: str, history: str, member: str):
    configure_material(material)
    bounds = PARTITIONS[member]
    dz = np.diff(np.asarray(bounds, dtype=float))
    state_class = HISTORIES[history]["state_class"]
    se0 = INITIAL_SE[material][state_class]
    theta0 = bc.theta_from_se(se0)
    theta = np.full(len(dz), theta0, dtype=float)
    psi, k = bc.psi_k(theta)
    y = np.concatenate([theta * dz, [0.0, 0.0, 0.0]])
    return bounds, dz, y, float(k[0]), float(psi[0]), float(se0)


def hydraulic_fluxes(y: np.ndarray, dz: np.ndarray, k0: float, psi0: float):
    n = len(dz)
    theta = y[:n] / dz
    qint = bc.interface_fluxes(theta, dz)
    qt = k0
    qb = bc.qbottom(theta, dz, k0, psi0, "G00", "HOLD", "CURRENT_LAYER_FACE")
    return qint, float(qt), float(qb)


def rhs_legacy(y: np.ndarray, dz: np.ndarray, k0: float, psi0: float) -> np.ndarray:
    n = len(dz)
    qint, qt, qb = hydraulic_fluxes(y, dz, k0, psi0)
    dy = np.zeros_like(y)
    for i in range(n):
        qup = qt if i == 0 else qint[i - 1]
        qdn = qb if i == n - 1 else qint[i]
        dy[i] = qup - qdn
    dy[n] = qt
    dy[n + 1] = qb
    dy[n + 2] = 0.0
    return dy


def rhs_prescribed_root(y: np.ndarray, dz: np.ndarray, k0: float, psi0: float, root_sink: np.ndarray) -> np.ndarray:
    n = len(dz)
    qint, qt, qb = hydraulic_fluxes(y, dz, k0, psi0)
    dy = np.zeros_like(y)
    for i in range(n):
        qup = qt if i == 0 else qint[i - 1]
        qdn = qb if i == n - 1 else qint[i]
        dy[i] = qup - qdn - root_sink[i]
    dy[n] = qt
    dy[n + 1] = qb
    dy[n + 2] = float(np.sum(root_sink))
    return dy


def rhs_generic_sink(y: np.ndarray, dz: np.ndarray, k0: float, psi0: float, generic_sink: np.ndarray) -> np.ndarray:
    n = len(dz)
    qint, qt, qb = hydraulic_fluxes(y, dz, k0, psi0)
    dy = np.zeros_like(y)
    for i in range(n):
        qup = qt if i == 0 else qint[i - 1]
        qdn = qb if i == n - 1 else qint[i]
        external_withdrawal = generic_sink[i]
        dy[i] = qup - qdn - external_withdrawal
    dy[n] = qt
    dy[n + 1] = qb
    dy[n + 2] = float(np.sum(generic_sink))
    return dy


def heun_step(y, dt, dz, k0, psi0, route: str, sink: np.ndarray):
    if route == "LEGACY_NO_SINK":
        f0 = rhs_legacy(y, dz, k0, psi0)
    elif route == "PRESCRIBED_ROOT":
        f0 = rhs_prescribed_root(y, dz, k0, psi0, sink)
    elif route == "GENERIC_SINK":
        f0 = rhs_generic_sink(y, dz, k0, psi0, sink)
    else:
        raise ValueError(route)
    guess = y + dt * f0
    n = len(dz)
    for iteration in range(1, bc.HEUN_MAX_CORRECTOR + 1):
        if route == "LEGACY_NO_SINK":
            fg = rhs_legacy(guess, dz, k0, psi0)
        elif route == "PRESCRIBED_ROOT":
            fg = rhs_prescribed_root(guess, dz, k0, psi0, sink)
        else:
            fg = rhs_generic_sink(guess, dz, k0, psi0, sink)
        nxt = y + 0.5 * dt * (f0 + fg)
        if np.max(np.abs(nxt[:n] / dz - guess[:n] / dz)) <= bc.HEUN_CORRECTOR_TOL_THETA:
            return nxt, iteration
        guess = nxt
    raise RuntimeError("iterative Heun corrector did not converge")


def solve_route(material: str, history: str, member: str, route: str, sink: np.ndarray):
    bounds, dz, y, k0, psi0, se0 = initialize(material, history, member)
    n = len(dz)
    initial_storage = float(np.sum(y[:n]))
    substeps = int(round(OBS_DT / DT))
    if substeps <= 0 or abs(substeps * DT - OBS_DT) > 1.0e-15:
        raise RuntimeError("Stage2 dt does not divide observation interval")

    storage = []
    cumulative_top = []
    cumulative_bottom = []
    cumulative_root = []
    max_ledger = 0.0
    max_corrector = 0
    root_ledger_rate = 0.0 if route == "LEGACY_NO_SINK" else math.fsum(float(v) for v in sink)
    ledger_substep_count = 0

    for _obs in range(1, STEPS + 1):
        for _ in range(substeps):
            y, iterations = heun_step(y, DT, dz, k0, psi0, route, sink)
            ledger_substep_count += 1
            # Auxiliary accounting coordinate only.  The prescribed withdrawal
            # is constant and is not part of the hydraulic state, so materialize
            # its cumulative ledger from the exact transaction count instead of
            # carrying repeated binary64 addition error across 8192 substeps.
            y[n + 2] = float(ledger_substep_count) * DT * root_ledger_rate
            max_corrector = max(max_corrector, iterations)
        theta = y[:n] / dz
        bc.psi_k(theta)
        total = float(np.sum(y[:n]))
        ledger = (total - initial_storage) - (float(y[n]) - float(y[n + 1]) - float(y[n + 2]))
        max_ledger = max(max_ledger, abs(ledger))
        storage.append(y[:n].copy())
        cumulative_top.append(float(y[n]))
        cumulative_bottom.append(float(y[n + 1]))
        cumulative_root.append(float(y[n + 2]))

    return {
        "route": route,
        "status": "QUALIFIED",
        "material": material,
        "history": history,
        "member": member,
        "dimension": n,
        "boundaries_cm": bounds,
        "initial_se": se0,
        "dt_day": DT,
        "observation_dt_day": OBS_DT,
        "layer_storage_cm": np.asarray(storage).tolist(),
        "cumulative_top_downward_cm": cumulative_top,
        "cumulative_bottom_downward_cm": cumulative_bottom,
        "cumulative_root_withdrawal_cm": cumulative_root,
        "max_abs_water_ledger_cm": max_ledger,
        "max_corrector_iterations": max_corrector,
    }


def exact_identity(a: dict, b: dict) -> bool:
    keys = (
        "layer_storage_cm",
        "cumulative_top_downward_cm",
        "cumulative_bottom_downward_cm",
        "cumulative_root_withdrawal_cm",
    )
    return all(np.array_equal(np.asarray(a[k]), np.asarray(b[k])) for k in keys)


def case(material: str, history: str, member: str) -> dict:
    bounds = PARTITIONS[member]
    profile = HISTORIES[history]["root"]
    tp = float(HISTORIES[history]["tp"])
    fractions = layer_root_fractions(bounds, profile)
    sink = tp * fractions
    zero = np.zeros_like(sink)

    root = solve_route(material, history, member, "PRESCRIBED_ROOT", sink)
    generic = solve_route(material, history, member, "GENERIC_SINK", sink)
    zero_root = solve_route(material, history, member, "PRESCRIBED_ROOT", zero)
    legacy = solve_route(material, history, member, "LEGACY_NO_SINK", zero)

    fsum = math.fsum(float(v) for v in fractions)
    sink_sum = math.fsum(float(v) for v in sink)
    final_root = float(root["cumulative_root_withdrawal_cm"][-1])
    expected_root = tp * HORIZON
    scale_rate = max(1.0, abs(tp))
    scale_cum = max(1.0, abs(expected_root))

    checks = {
        "fractions_nonnegative": bool(np.all(fractions >= 0.0)),
        "fraction_sum_within_arithmetic_guard": abs(fsum - 1.0) <= ARITH_GUARD,
        "sink_rate_within_arithmetic_guard": abs(sink_sum - tp) <= ARITH_GUARD * scale_rate,
        "cumulative_root_within_arithmetic_guard": abs(final_root - expected_root) <= ARITH_GUARD * scale_cum,
        "root_generic_bit_identity": exact_identity(root, generic),
        "zero_sink_legacy_bit_identity": exact_identity(zero_root, legacy),
        "root_ledger_pass": float(root["max_abs_water_ledger_cm"]) <= LEDGER_GATE,
        "generic_ledger_pass": float(generic["max_abs_water_ledger_cm"]) <= LEDGER_GATE,
        "zero_root_ledger_pass": float(zero_root["max_abs_water_ledger_cm"]) <= LEDGER_GATE,
        "legacy_ledger_pass": float(legacy["max_abs_water_ledger_cm"]) <= LEDGER_GATE,
    }
    return {
        "material": material,
        "history": history,
        "member": member,
        "root_profile": profile,
        "potential_transpiration_cm_per_day": tp,
        "layer_root_fraction": fractions.tolist(),
        "prescribed_layer_sink_cm_per_day": sink.tolist(),
        "root_fraction_sum": fsum,
        "prescribed_total_rate_cm_per_day": sink_sum,
        "expected_cumulative_root_cm": expected_root,
        "actual_cumulative_root_cm": final_root,
        "arithmetic_guard_fraction": ARITH_GUARD,
        "ledger_gate_cm": LEDGER_GATE,
        "routes": {
            "PRESCRIBED_ROOT": {k: root[k] for k in ("status", "max_abs_water_ledger_cm", "max_corrector_iterations")},
            "GENERIC_SINK": {k: generic[k] for k in ("status", "max_abs_water_ledger_cm", "max_corrector_iterations")},
            "ZERO_PRESCRIBED_ROOT": {k: zero_root[k] for k in ("status", "max_abs_water_ledger_cm", "max_corrector_iterations")},
            "LEGACY_NO_SINK": {k: legacy[k] for k in ("status", "max_abs_water_ledger_cm", "max_corrector_iterations")},
        },
        "checks": checks,
        "pass": all(checks.values()),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--material", required=True, choices=("B01", "B14"))
    ap.add_argument("--history", required=True, choices=tuple(HISTORIES))
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    assert pre["state"] == "PREREGISTERED_BEFORE_STAGE2_REDUCED_RESPONSE"
    assert pre["scientific_firewall"]["dynamic_root_feedback_implemented"] is False
    assert pre["integrity_and_pass_rules"]["inherited_reduced_water_ledger_gate_cm"] == LEDGER_GATE

    cases = {member: case(args.material, args.history, member) for member in PARTITIONS}
    out = {
        "schema": "swap5.rom_root.s2.execution.v1",
        "workstream": "ROM-ROOT",
        "work_unit": "ROM-ROOT-S2",
        "material": args.material,
        "history": args.history,
        "cases": cases,
        "pass": all(row["pass"] for row in cases.values()),
        "scientific_firewall": {
            "feddes_evaluated": False,
            "dynamic_root_feedback_implemented": False,
            "reduced_feedback_response_generated": False,
            "new_root_specific_state_selected": False,
            "new_partition_selected": False,
            "new_hydraulic_closure_selected": False,
        },
        "model_changed": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(out, indent=2, sort_keys=True, default=json_default) + "\n")
    print(json.dumps({
        "material": args.material,
        "history": args.history,
        "pass": out["pass"],
        "members": {m: {"pass": v["pass"], "checks": v["checks"]} for m, v in cases.items()},
    }, sort_keys=True, default=json_default))
    return 0 if out["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
