from __future__ import annotations

import bisect
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_mfp_c1_candidates import HermiteMFPTable

# B1b changes representation quality only. All physical equations, oracle,
# materials, face lengths, head/gradient envelopes, face-error thresholds and
# fail-closed rules remain those of B1. The ratio density remains hierarchical.
core.AsinhMFPTable = HermiteMFPTable
core.MASTER_NX = 33
core.VIEW_NX = (17, 33)

EPS = (1.0e-3, 2.0e-4, 4.0e-5, 8.0e-6, 1.6e-6)


def tolerant_bracket(axis, x):
    """Clamp only floating-point endpoint roundoff, never physical extrapolation."""
    lo, hi = axis[0], axis[-1]
    tol_lo = 8.0 * math.ulp(lo)
    tol_hi = 8.0 * math.ulp(hi)
    if x < lo:
        if lo - x <= tol_lo:
            x = lo
        else:
            raise ValueError(("axis_out_of_range", x, lo, hi))
    elif x > hi:
        if x - hi <= tol_hi:
            x = hi
        else:
            raise ValueError(("axis_out_of_range", x, lo, hi))
    if x >= hi:
        return len(axis)-2, len(axis)-1
    i = bisect.bisect_right(axis, x)-1
    return max(0, i), min(len(axis)-1, i+1)


core.bracket = tolerant_bracket


def asymptotic_continuity_test(view):
    rows=[]
    finite=True
    final_ratios=[]
    initial_over=0
    for h in (-1.0e5, -100.0, -1.0, -0.01, -0.001, 0.0, 0.001, 0.01, 1.0, 10.0, 100.0):
        for g0 in (0.0,1.0):
            def q(g):
                return view.flux(h,h+g*view.length)
            q0=q(g0)
            distances=[]
            for e in EPS:
                distances.append(max(abs(q(g0-e)-q0),abs(q(g0+e)-q0)))
            ratios=[]
            for a,b in zip(distances[:-1],distances[1:]):
                ratios.append(0.0 if a<1.0e-14 and b<1.0e-14 else b/max(a,1.0e-300))
            finite=finite and all(math.isfinite(v) for v in distances+ratios+[q0])
            if ratios[0]>0.35:
                initial_over+=1
            final_ratios.append(ratios[-1])
            rows.append({"h_u":h,"g":g0,"epsilons":list(EPS),
                         "distances":distances,"consecutive_ratios":ratios,
                         "initial_ratio":ratios[0],"final_ratio":ratios[-1]})
    maximum=max(final_ratios)
    return {"pass":finite and maximum<=0.35,
            "finite":finite,
            "expected_linear_refinement_ratio":0.2,
            "initial_rows_over_0p35":initial_over,
            "final_rows_over_0p35":sum(r>0.35 for r in final_ratios),
            "maximum_final_ratio":maximum,
            "threshold":0.35,"rows":rows}

core.continuity_test = asymptotic_continuity_test

if __name__ == "__main__":
    core.main()
