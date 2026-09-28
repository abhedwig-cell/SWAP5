#!/usr/bin/env python3
"""F-PE-BOFEK00 current-authority wet-regime correctness micro-gate.

No timestep policy is changed. This gate:
1. pins exact current source preimages for the two suspected mechanisms;
2. compares the current first-row head-boundary Jacobian term with an
   independent central finite-difference derivative on smooth ponded branches;
3. demonstrates dt-dependent branch selection before the analytical
   linear-runoff solve.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEADCALC = ROOT / "src/legacy/b1_10_port/headcalc.f90"
TOP = ROOT / "src/solver/mod_b110_dynamic_top_boundary_provider.f90"

HEAD_PREIMAGE = (
    "if (state%ftoph) fsi_ws%dfdh_main(1) = "
    "fsi_ws%dfdh_main(1) + state%kmean(1)/grid_disnod(1)"
)
BRANCH_PREIMAGE = "current_runoff = restricted_linear_runoff_depth(request%candidate_ponding_depth_cm, request)"
RUNOFF_GATE_PREIMAGE = "if (abs(current_runoff) < B110_DYN_TOP_RUNOFF_ZERO_CM) then"

K = 10.0
D = 1.0
DT = 0.01
RR = 0.1
POND_PREV = 0.02
Q0 = 20.0
PMAX = 0.05
H1 = -0.20

def h_surface_no_runoff(h1: float, dt: float = DT) -> float:
    p1 = K / D * dt
    return (POND_PREV + Q0 * dt - K * dt + p1 * h1) / (1.0 + p1)

def h_surface_linear_runoff(h1: float, dt: float = DT) -> float:
    p1 = K / D * dt
    a = dt / RR
    return (POND_PREV + Q0 * dt - K * dt + p1 * h1 + a * PMAX) / (1.0 + p1 + a)

def boundary_residual(h1: float, h_surface) -> float:
    hs = h_surface(h1)
    return -K * ((hs - h1) / D + 1.0)

def fd(fun, x: float, eps: float = 1.0e-7) -> float:
    return (fun(x + eps) - fun(x - eps)) / (2.0 * eps)

def relerr(a: float, b: float) -> float:
    return abs(a - b) / max(abs(a), abs(b), 1.0e-30)

def runoff_depth(candidate: float, dt: float) -> float:
    if candidate <= PMAX:
        return 0.0
    return dt / RR * (candidate - PMAX)

def analytical_active_defined(h1: float, dt: float) -> float:
    return h_surface_linear_runoff(h1, dt)

def main() -> int:
    head = HEADCALC.read_text(encoding="utf-8")
    top = TOP.read_text(encoding="utf-8")
    source = {
        "headcalc_preimage_present": HEAD_PREIMAGE in " ".join(head.split()),
        "candidate_runoff_preimage_present": BRANCH_PREIMAGE in top,
        "runoff_gate_preimage_present": RUNOFF_GATE_PREIMAGE in top,
    }
    # HEAD_PREIMAGE is normalized separately because source spacing is free-form.
    source["headcalc_preimage_present"] = (
        "if (state%ftoph) fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) + state%kmean(1)/grid_disnod(1)"
        in " ".join(head.split())
    )

    p1 = K / D * DT
    a = DT / RR

    fd_no = fd(lambda x: boundary_residual(x, h_surface_no_runoff), H1)
    expected_no = (K / D) / (1.0 + p1)

    fd_runoff = fd(lambda x: boundary_residual(x, h_surface_linear_runoff), H1)
    expected_runoff = (K / D) * (1.0 + a) / (1.0 + p1 + a)

    current_jacobian = K / D

    jacobian = {
        "parameters": {"K": K, "distance": D, "dt": DT, "runoff_resistance": RR},
        "no_runoff": {
            "fd": fd_no,
            "derived_correct": expected_no,
            "current_headcalc_term": current_jacobian,
            "fd_vs_correct_relerr": relerr(fd_no, expected_no),
            "fd_vs_current_relerr": relerr(fd_no, current_jacobian),
        },
        "active_linear_runoff": {
            "fd": fd_runoff,
            "derived_correct": expected_runoff,
            "current_headcalc_term": current_jacobian,
            "fd_vs_correct_relerr": relerr(fd_runoff, expected_runoff),
            "fd_vs_current_relerr": relerr(fd_runoff, current_jacobian),
        },
    }

    candidate = PMAX + 0.01
    dt_small = 1.0e-6
    dt_large = 1.0e-4
    zero_gate = 1.0e-6
    ro_small = runoff_depth(candidate, dt_small)
    ro_large = runoff_depth(candidate, dt_large)
    branch = {
        "candidate_ponding_cm": candidate,
        "ponding_max_cm": PMAX,
        "runoff_resistance_day": RR,
        "absolute_runoff_gate_cm": zero_gate,
        "dt_small_day": dt_small,
        "dt_large_day": dt_large,
        "runoff_small_cm": ro_small,
        "runoff_large_cm": ro_large,
        "small_selects_no_runoff": abs(ro_small) < zero_gate,
        "large_selects_analytical_runoff": abs(ro_large) >= zero_gate,
        "analytical_active_solution_small_dt_cm": analytical_active_defined(H1, dt_small),
        "analytical_active_solution_large_dt_cm": analytical_active_defined(H1, dt_large),
    }

    gates = {
        "source_preimages": all(source.values()),
        "fd_matches_derived_no_runoff": jacobian["no_runoff"]["fd_vs_correct_relerr"] <= 1.0e-7,
        "fd_matches_derived_active_runoff": jacobian["active_linear_runoff"]["fd_vs_correct_relerr"] <= 1.0e-7,
        "current_jacobian_fails_no_runoff": jacobian["no_runoff"]["fd_vs_current_relerr"] > 1.0e-4,
        "current_jacobian_fails_active_runoff": jacobian["active_linear_runoff"]["fd_vs_current_relerr"] > 1.0e-4,
        "dt_changes_branch": branch["small_selects_no_runoff"] and branch["large_selects_analytical_runoff"],
        "analytical_solution_exists_both": math.isfinite(branch["analytical_active_solution_small_dt_cm"]) and math.isfinite(branch["analytical_active_solution_large_dt_cm"]),
    }

    out = {
        "work_unit": "F-PE-BOFEK00",
        "classification": "DEFECT_CONFIRMED_CURRENT_REFERENCE" if all(gates.values()) else "GATE_FAILURE",
        "source": source,
        "jacobian": jacobian,
        "branch_selection": branch,
        "gates": gates,
        "policy_mutated": False,
    }
    print(json.dumps(out, indent=2, sort_keys=True))
    return 0 if all(gates.values()) else 2

if __name__ == "__main__":
    raise SystemExit(main())
