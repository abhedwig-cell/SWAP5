from __future__ import annotations

import hashlib
import json
import math
import sys
import warnings
from pathlib import Path

import numpy as np
from scipy.integrate import IntegrationWarning, quad

import run_ross01_gate_c1r_characterization_v4 as v4
import run_ross01_gate_c2b_henpr_svg2006_bridge as hydro
import run_ross01_gate_c2b_state_coordinate_conditioning as coord0
import run_ross01_gate_c2b_state_coordinate_r1 as coordr1

N = 241
STRESS_MATERIALS = ("B10", "O12", "O13", "B05", "O14", "O05", "B12")
CATALOG_PATH = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
SEAMS = (-40.0, -4.0)

base = v4.base
core = base.c1.core
ORIGINAL_BUILD_PROBES = base.build_probes

CURRENT_ROW = None
CURRENT_C = None


def seed_for_material(name: str) -> int:
    return int(hashlib.sha256(("F-ROSS01-C2B-FACE-CHAR:" + name).encode()).hexdigest()[:8], 16)


def configure_core_c2b(row: dict) -> None:
    global CURRENT_ROW, CURRENT_C
    CURRENT_ROW = row
    CURRENT_C = coord0.constants(row)
    core.THETA_R = float(row["theta_r"])
    core.THETA_S = float(row["theta_s"])
    core.ALPHA = float(row["alpha_per_cm"])
    core.NPAR = float(row["n"])
    core.MPAR = 1.0 - 1.0 / core.NPAR
    core.KSAT = float(row["ksatfit_cm_per_day"])
    core.LAMBDA = float(row["lambda"])
    core.LENGTH_CM = base.LENGTH_CM
    core.H_MIN = base.H_MIN
    core.H_MAX = base.H_MAX
    core.S_MIN = c2b_s_of_h(base.H_MIN)
    core.S_MAX = c2b_s_of_h(base.H_MAX)


def c2b_s_of_h(h: float) -> float:
    if CURRENT_C is None:
        raise RuntimeError("C2B material is not configured")
    return float(CURRENT_C["s_of_h"](h))


def c2b_k_of_h(h: float) -> float:
    if CURRENT_ROW is None or CURRENT_C is None:
        raise RuntimeError("C2B material is not configured")
    return float(hydro.k_candidate(h, CURRENT_ROW, CURRENT_C))


def path_length_for_q_split(h_above: float, h_below: float, q: float) -> float:
    dh = h_below - h_above
    power = 8

    def transformed(t: float) -> float:
        if t == 0.0:
            return 0.0
        tp = t**power
        h = h_above + dh * tp
        jac = dh * power * t ** (power - 1)
        k = c2b_k_of_h(h)
        return jac * k / (k - q)

    cuts = [0.0, 1.0]
    low = min(h_above, h_below)
    high = max(h_above, h_below)
    if dh != 0.0:
        for seam in SEAMS:
            if low < seam < high:
                ratio = (seam - h_above) / dh
                if 0.0 < ratio < 1.0:
                    cuts.append(ratio ** (1.0 / power))
    cuts = sorted(set(cuts))
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
                limit=160,
            )
            total += value
    return total


def hydro_mobility_split(h_above: float) -> float:
    h_below = h_above + base.LENGTH_CM
    cuts = [h_above]
    low = min(h_above, h_below)
    high = max(h_above, h_below)
    for seam in SEAMS:
        if low < seam < high:
            cuts.append(seam)
    cuts.append(h_below)
    cuts = sorted(cuts) if h_below >= h_above else sorted(cuts, reverse=True)
    total = 0.0
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", IntegrationWarning)
        for left, right in zip(cuts[:-1], cuts[1:]):
            value, _ = quad(
                lambda h: 1.0 / c2b_k_of_h(h),
                left,
                right,
                epsabs=2.0e-10,
                epsrel=2.0e-10,
                limit=160,
            )
            total += value
    return 1.0 / total


def state_to_u_c2b(s: float) -> float:
    if CURRENT_C is None:
        raise RuntimeError("C2B material is not configured")
    u, _ = coordr1.state_to_u_r1(float(s), CURRENT_C)
    if not (0.0 <= u <= 4.0 and math.isfinite(u)):
        raise ValueError("qualified C2B S-to-u mapping returned invalid coordinate")
    return float(u)


def state_to_head_c2b(s: float) -> tuple[float, float]:
    u = state_to_u_c2b(s)
    return u, v4.u_to_head(u)


def build_probes_c2b(name: str):
    probes = list(ORIGINAL_BUILD_PROBES(name))
    # Explicitly stress the C2B conductivity derivative joins. These are
    # characterization probes and do not become a future holdout.
    offsets = (0.001, 0.01, 0.1, 0.5, 2.0)
    for seam in SEAMS:
        for da in offsets:
            for db in offsets:
                for sa_sign, sb_sign in ((-1.0, -1.0), (1.0, 1.0), (-1.0, 1.0), (1.0, -1.0)):
                    ha = seam + sa_sign * da
                    hb = seam + sb_sign * db
                    if base.H_MIN <= ha <= base.H_MAX and base.H_MIN <= hb <= base.H_MAX:
                        probes.append((c2b_s_of_h(ha), c2b_s_of_h(hb), f"c2b_join_{int(abs(seam))}"))
        if base.H_MIN <= seam <= base.H_MAX:
            s = c2b_s_of_h(seam)
            probes.append((s, s, f"c2b_join_equal_{int(abs(seam))}"))
    return probes


# Install the unchanged C2B physical closure and the independently qualified
# state-coordinate mapping into the existing C1R face-table harness.
core.s_of_h = c2b_s_of_h
core.k_of_h = c2b_k_of_h
core.path_length_for_q = path_length_for_q_split
core.hydro_mobility = hydro_mobility_split
base.c1.configure_core = configure_core_c2b
base.seed_for_material = seed_for_material
base.build_probes = build_probes_c2b
v4.state_to_u = state_to_u_c2b
v4.state_to_head = state_to_head_c2b


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_c2b_face_table_characterization.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in STRESS_MATERIALS:
        raise SystemExit(f"material must be one of {STRESS_MATERIALS}")

    catalog = json.loads(CATALOG_PATH.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    row = by_name[material]
    result = base.run_material(row, N)

    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2B_HENPR_SVG2006_N241_STEADY_FACE_CHARACTERIZATION",
        "contract": "F-ROSS01_GATE_C2B_FACE_TABLE_CHARACTERIZATION_CONTRACT.json",
        "material": material,
        "candidate": {
            "N": N,
            "storage": "float32_log_mobility",
            "coordinate": "uniform_u_log10_negative_head_0_to_4",
            "state_mapping": "C2B_STATE_COORDINATE_R1",
            "head_envelope_cm": [base.H_MIN, base.H_MAX],
            "shared_table_plus_metadata_bytes": 4 * N * N + base.FIXED_METADATA_BYTES,
        },
        "physical_closure": "SWAP5_HENPR_SVG2006_LOGK_BRIDGE_V1",
        "oracle_quadrature_seams_cm": list(SEAMS),
        "ksatfit_cm_per_day": float(row["ksatfit_cm_per_day"]),
        "ksatexm_cm_per_day": float(row["ksatexm_cm_per_day"]),
        "ksatexm_over_ksatfit": float(row["ksatexm_cm_per_day"]) / float(row["ksatfit_cm_per_day"]),
        "result": result,
        "pass": bool(result["pass"]),
        "decision": "C2B_FACE_CHARACTERIZATION_MATERIAL_PASS" if result["pass"] else "C2B_FACE_CHARACTERIZATION_MATERIAL_FAIL",
        "science_guard": "Face representability only; no empirical hydraulic validation of the Class B closure.",
        "scope_guard": "Characterization only; no 36-material holdout, transient, groundwater or production claim."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": material,
        "pass": evidence["pass"],
        "max_hybrid_metric": result.get("max_hybrid_metric"),
        "p99_hybrid_metric": result.get("p99_hybrid_metric"),
        "max_abs_error_over_ksatfit": result.get("max_abs_error_over_ksatfit"),
        "wrong_sign_count": result.get("wrong_sign_count"),
        "near_zero_violation_count": result.get("near_zero_violation_count"),
        "failed_metrics": result.get("failed_metrics", []),
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if evidence["pass"] else 1)


if __name__ == "__main__":
    main()
