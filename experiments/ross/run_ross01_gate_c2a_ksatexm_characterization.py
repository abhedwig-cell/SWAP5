from __future__ import annotations

import hashlib
import json
import math
import sys
import warnings
from pathlib import Path

import numpy as np
from scipy.integrate import IntegrationWarning, quad
from scipy.stats import qmc

import run_ross01_gate_c1r_characterization_v4 as v4

N = 241
H_THR = -2.0
LOG10 = math.log(10.0)
CATALOG_PATH = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
STRESS_MATERIALS = ("B10", "O12", "O13", "B05", "O14", "O05")

core = v4.base.c1.core
ORIGINAL_CONFIGURE = v4.base.c1.configure_core
BASE_MVG_K_OF_H = core.k_of_h

KSATEXM = math.nan
S_THR = math.nan
K_THR = math.nan


def seed_for_material(name: str) -> int:
    return int(hashlib.sha256(("F-ROSS01-C2A-KSATEXM-CHAR:" + name).encode()).hexdigest()[:8], 16)


def configure_core_ksatexm(row):
    global KSATEXM, S_THR, K_THR
    ORIGINAL_CONFIGURE(row)
    if float(row["h_enpr_cm"]) != 0.0:
        raise ValueError("C2A frozen catalog requires H_ENPR=0")
    KSATEXM = float(row["ksatexm_cm_per_day"])
    if not KSATEXM > core.KSAT:
        raise ValueError("SWAP 4.3.1 activates KSATEXM only when KSATEXM > KSATFIT")
    S_THR = core.s_of_h(H_THR)
    K_THR = BASE_MVG_K_OF_H(H_THR)
    if not K_THR < KSATEXM:
        raise ValueError("SWAP 4.3.1 readswap validation requires K_thr < KSATEXM")


def k_of_h_ksatexm(h: float) -> float:
    s = core.s_of_h(h)
    if s > S_THR:
        fraction = (s - S_THR) / (1.0 - S_THR)
        return fraction * KSATEXM + (1.0 - fraction) * K_THR
    return BASE_MVG_K_OF_H(h)


def path_length_for_q_split_at_ksatexm_seam(h_above: float, h_below: float, q: float) -> float:
    dh = h_below - h_above
    power = 8

    def transformed(t: float) -> float:
        if t == 0.0:
            return 0.0
        tp = t**power
        h = h_above + dh * tp
        jac = dh * power * t ** (power - 1)
        k = k_of_h_ksatexm(h)
        return jac * k / (k - q)

    cuts = [0.0, 1.0]
    low = min(h_above, h_below)
    high = max(h_above, h_below)
    if low < H_THR < high:
        ratio = (H_THR - h_above) / dh
        if 0.0 < ratio < 1.0:
            cuts.insert(1, ratio ** (1.0 / power))

    total = 0.0
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", IntegrationWarning)
        for left, right in zip(cuts[:-1], cuts[1:]):
            value, _ = quad(
                transformed,
                left,
                right,
                epsabs=2.0e-10,
                epsrel=2.0e-10,
                limit=120,
            )
            total += value
    return total


def state_pair_from_heads(h_above: float, h_below: float):
    return float(core.s_of_h(h_above)), float(core.s_of_h(h_below))


def build_probes(name: str):
    probes = []
    seed = seed_for_material(name)

    ordinary_s = qmc.Sobol(d=2, scramble=True, seed=seed).random_base2(m=9)
    for a, b in ordinary_s:
        sa = core.S_MIN + (core.S_MAX - core.S_MIN) * float(a)
        sb = core.S_MIN + (core.S_MAX - core.S_MIN) * float(b)
        probes.append((float(sa), float(sb), "ordinary_state"))

    ordinary_u = qmc.Sobol(d=2, scramble=True, seed=seed ^ 0xA5A5A5A5).random_base2(m=9)
    for a, b in ordinary_u:
        ua = 4.0 * float(a)
        ub = 4.0 * float(b)
        probes.append((*state_pair_from_heads(-(10.0**ua), -(10.0**ub)), "ordinary_coordinate"))

    # Dedicated wet-end and h=-2 cm seam probes. These are characterization only.
    wet_heads = -np.geomspace(1.0, 2.0, 64)
    for ha in wet_heads:
        for hb in (-1.0, -1.25, -1.5, -1.75, -2.0):
            probes.append((*state_pair_from_heads(float(ha), float(hb)), "wet_extension"))

    for delta_a in (-0.75, -0.25, -0.05, -0.005, 0.005, 0.05, 0.25, 0.75):
        for delta_b in (-0.75, -0.25, -0.05, -0.005, 0.005, 0.05, 0.25, 0.75):
            ha = H_THR + delta_a
            hb = H_THR + delta_b
            if v4.base.H_MIN <= ha <= v4.base.H_MAX and v4.base.H_MIN <= hb <= v4.base.H_MAX:
                probes.append((*state_pair_from_heads(ha, hb), "threshold_cross"))

    for h in -np.geomspace(1.0, 10000.0, 64):
        probes.append((*state_pair_from_heads(float(h), float(h)), "equal_head"))

    for h_above in -np.geomspace(11.0, 10000.0, 64):
        h_below = float(h_above) + v4.base.LENGTH_CM
        probes.append((*state_pair_from_heads(float(h_above), h_below), "hydrostatic"))

    # Concentrate near-hydrostatic paths around the wet-end path that crosses h=-2.
    for h_above in list(-np.geomspace(11.0, 30.0, 32)) + list(-np.geomspace(31.0, 10000.0, 32)):
        for epsilon in (-0.25, 0.25):
            h_below = float(h_above) + v4.base.LENGTH_CM + epsilon
            if v4.base.H_MIN <= h_below <= v4.base.H_MAX:
                probes.append((*state_pair_from_heads(float(h_above), h_below), "near_hydrostatic"))

    for ha, hb in (
        (-2.0, -2.0), (-2.0, -1.0), (-1.0, -2.0),
        (-2.000001, -1.999999), (-1.999999, -2.000001),
        (-11.0, -1.0), (-11.25, -1.0), (-10.75, -1.0),
        (v4.base.H_MIN, v4.base.H_MIN), (v4.base.H_MAX, v4.base.H_MAX),
        (v4.base.H_MIN, v4.base.H_MAX), (v4.base.H_MAX, v4.base.H_MIN),
    ):
        probes.append((*state_pair_from_heads(ha, hb), "edge"))

    return probes


def source_checks(row) -> dict:
    left = k_of_h_ksatexm(H_THR - 1.0e-9)
    at = k_of_h_ksatexm(H_THR)
    right = k_of_h_ksatexm(H_THR + 1.0e-9)
    wet = k_of_h_ksatexm(0.0)
    samples = [k_of_h_ksatexm(float(h)) for h in np.linspace(H_THR, 0.0, 257)]
    checks = {
        "h_enpr_zero": float(row["h_enpr_cm"]) == 0.0,
        "ksatexm_gt_ksatfit": KSATEXM > core.KSAT,
        "k_thr_lt_ksatexm": K_THR < KSATEXM,
        "threshold_exact_base_branch": at == K_THR,
        "threshold_continuity": max(abs(left - at), abs(right - at)) <= 1.0e-7 * max(core.KSAT, 1.0),
        "wet_limit_equals_ksatexm": abs(wet - KSATEXM) <= 2.0e-14 * max(1.0, KSATEXM),
        "extension_monotone": all(b >= a for a, b in zip(samples[:-1], samples[1:])),
    }
    return {
        "h_thr_cm": H_THR,
        "s_thr": S_THR,
        "k_thr_cm_per_day": K_THR,
        "k_thr_over_ksatfit": K_THR / core.KSAT,
        "ksatexm_cm_per_day": KSATEXM,
        "ksatexm_over_ksatfit": KSATEXM / core.KSAT,
        "checks": checks,
        "pass": all(checks.values()),
    }


# Install the source-bound physical law and the seam-aware independent oracle.
core.k_of_h = k_of_h_ksatexm
core.path_length_for_q = path_length_for_q_split_at_ksatexm_seam
v4.base.c1.configure_core = configure_core_ksatexm
v4.base.build_probes = build_probes
v4.base.seed_for_material = seed_for_material


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_c2a_ksatexm_characterization.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in STRESS_MATERIALS:
        raise SystemExit(f"material must be one of {STRESS_MATERIALS}")
    catalog = json.loads(CATALOG_PATH.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    row = by_name[material]

    result = v4.base.run_material(row, N)
    # run_material has already configured the core for this row.
    src = source_checks(row)
    result["source_checks"] = src
    result["ksatexm_enabled"] = True
    result["h_enpr_enabled"] = False
    result["characterization_probe_set"] = "FRESH_C2A_KSATEXM_CHARACTERIZATION"
    result["oracle_seam_split_at_h_cm"] = H_THR
    if not src["pass"]:
        result["pass"] = False
        result.setdefault("failed_metrics", []).append("source_semantics_checks")

    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2A_KSATEXM_CHARACTERIZATION",
        "material": material,
        "candidate": {
            "N": N,
            "storage": "float32_log_mobility",
            "coordinate": "u=log10(-h/cm) on [0,4]",
            "head_envelope_cm": [v4.base.H_MIN, v4.base.H_MAX],
            "shared_table_plus_metadata_bytes": 4 * N * N + v4.base.FIXED_METADATA_BYTES,
        },
        "result": result,
        "pass": bool(result["pass"]),
        "decision": "C2A_CHARACTERIZATION_MATERIAL_PASS" if result["pass"] else "C2A_CHARACTERIZATION_MATERIAL_FAIL",
        "scope_limit": "Characterization only; no 36-material KSATEXM qualification claim and no h>-1 cm claim."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": material,
        "pass": evidence["pass"],
        "max_hybrid_metric": result.get("max_hybrid_metric"),
        "p99_hybrid_metric": result.get("p99_hybrid_metric"),
        "max_abs_error_over_ksatfit": result.get("max_abs_error_over_ksatfit"),
        "failed_metrics": result.get("failed_metrics", []),
        "s_thr": src["s_thr"],
        "ksatexm_over_ksatfit": src["ksatexm_over_ksatfit"],
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if evidence["pass"] else 1)


if __name__ == "__main__":
    main()
