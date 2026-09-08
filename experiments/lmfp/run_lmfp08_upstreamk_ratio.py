from __future__ import annotations

import bisect
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp08_physics_informed_correction as core
from run_lmfp08_logk_candidate import oracle_kdar

X_AXIS = list(core.X_AXIS)
G_AXIS = list(core.G_AXIS)
_SHARED_TABLES = {}


def bracket(axis, x):
    if x < axis[0] or x > axis[-1]:
        raise ValueError(("axis_out_of_range", x, axis[0], axis[-1]))
    if x == axis[-1]:
        return len(axis)-2, len(axis)-1
    i = bisect.bisect_right(axis, x)-1
    return max(0, i), min(len(axis)-1, i+1)


class UpstreamKLogRatioTable:
    """Positive Darcian conductance correction around exact upper-node K.

    Define g=(h_lower-h_upper)/L and K_DAR by q_D=(1-g)K_DAR.
    Store R=log(K_DAR/K(h_upper)). Runtime evaluates

        q=(1-g) K(h_upper) exp(R_interp).

    The complete g=0 table row is analytically R=0, so equal-head gravity flow
    is exact and continuous for every h inside the x envelope. At g=1 the
    hydraulic-gradient factor makes q exactly and continuously zero. Positive
    conductance and flow direction are structural rather than post-hoc checks.
    """

    def __init__(self, code, length, x_axis=X_AXIS, g_axis=G_AXIS):
        self.code = int(code)
        self.length = float(length)
        self.x_axis = list(x_axis)
        self.g_axis = list(g_axis)
        self.log_ratio = []
        mat = core.MATERIAL_BY_CODE[self.code]
        for x in self.x_axis:
            h_u = -10.0**x
            ku = mat.conductivity(h_u)
            if not math.isfinite(ku) or ku <= 0.0:
                raise RuntimeError(("nonpositive upper K", self.code, h_u, ku))
            row = []
            for g in self.g_axis:
                if abs(g) <= 1.0e-14:
                    row.append(0.0)
                else:
                    kd = oracle_kdar(self.code, h_u, g, self.length)
                    ratio = kd / ku
                    if not math.isfinite(ratio) or ratio <= 0.0:
                        raise RuntimeError(("nonpositive K_DAR/K_upper", self.code,
                                            self.length, h_u, g, kd, ku, ratio))
                    row.append(math.log(ratio))
            self.log_ratio.append(row)

    def ratio(self, h_u, g):
        if h_u >= 0.0:
            raise ValueError(("upper_head_not_unsaturated", h_u))
        x = math.log10(-h_u)
        i0, i1 = bracket(self.x_axis, x)
        j0, j1 = bracket(self.g_axis, g)
        x0, x1 = self.x_axis[i0], self.x_axis[i1]
        g0, g1 = self.g_axis[j0], self.g_axis[j1]
        tx = 0.0 if x1 == x0 else (x-x0)/(x1-x0)
        tg = 0.0 if g1 == g0 else (g-g0)/(g1-g0)
        a00 = self.log_ratio[i0][j0]
        a10 = self.log_ratio[i1][j0]
        a11 = self.log_ratio[i1][j1]
        a01 = self.log_ratio[i0][j1]
        a = ((1-tx)*(1-tg)*a00 + tx*(1-tg)*a10 +
             tx*tg*a11 + (1-tx)*tg*a01)
        return math.exp(a)

    def flux(self, h_u, h_l):
        g = (h_l-h_u)/self.length
        ku = core.MATERIAL_BY_CODE[self.code].conductivity(h_u)
        return (1.0-g) * ku * self.ratio(h_u, g)


class UpstreamKRatioCache:
    def __init__(self):
        self.tables = {}
        self.build_count = 0
        self.transient_calls = 0
        self.coverage_misses = 0

    def table(self, code, length):
        key = (int(code), round(float(length), 12))
        if key not in _SHARED_TABLES:
            _SHARED_TABLES[key] = UpstreamKLogRatioTable(code, length)
        if key not in self.tables:
            self.tables[key] = _SHARED_TABLES[key]
            self.build_count += 1
        return self.tables[key]

    def flux(self, code, h_u, h_l, length):
        self.transient_calls += 1
        try:
            return self.table(code, length).flux(h_u, h_l)
        except ValueError as exc:
            self.coverage_misses += 1
            raise RuntimeError("upstreamk_ratio_coverage:"+str(exc)) from exc

    def diagnostics(self):
        n = len(X_AXIS)*len(G_AXIS)
        return {
            "table_builds": self.build_count,
            "values_per_table": n,
            "table_values_total": self.build_count*n,
            "bytes_double_values_before_metadata": self.build_count*n*8,
            "transient_face_calls": self.transient_calls,
            "coverage_misses": self.coverage_misses,
            "upper_head_envelope_cm": [-10.0**X_AXIS[-1], -10.0**X_AXIS[0]],
            "gradient_envelope": [G_AXIS[0], G_AXIS[-1]],
            "coordinates": "x=log10(-h_upper), g=(h_lower-h_upper)/L",
            "stored_quantity": "R=log(K_DAR/K(h_upper))",
            "flux_structure": "q=(1-g)*K(h_upper)*exp(R)",
        }


def continuity_refinement():
    cache = UpstreamKRatioCache()
    rows = []
    ratios = []
    finite = True
    eps_large = 1.0e-3
    eps_small = 2.0e-4
    for code in (1, 2):
        for length in (10.0, 20.0):
            tab = cache.table(code, length)
            for h_u in (-200.0, -80.0, -20.0):
                for g0 in (0.0, 1.0):
                    q0 = tab.flux(h_u, h_u+g0*length)
                    qlm = tab.flux(h_u, h_u+(g0-eps_large)*length)
                    qlp = tab.flux(h_u, h_u+(g0+eps_large)*length)
                    qsm = tab.flux(h_u, h_u+(g0-eps_small)*length)
                    qsp = tab.flux(h_u, h_u+(g0+eps_small)*length)
                    large = max(abs(qlm-q0), abs(qlp-q0))
                    small = max(abs(qsm-q0), abs(qsp-q0))
                    ratio = 0.0 if large < 1.0e-14 and small < 1.0e-14 else small/max(large,1.0e-300)
                    vals = (q0, qlm, qlp, qsm, qsp, ratio)
                    finite = finite and all(math.isfinite(v) for v in vals)
                    ratios.append(ratio)
                    rows.append({
                        "code": code, "length": length, "h_upper": h_u, "g": g0,
                        "eps_large": eps_large, "eps_small": eps_small,
                        "q_center": q0, "large_max_distance": large,
                        "small_max_distance": small, "small_over_large": ratio,
                    })
    # eps shrinks by factor five. A continuous locally Lipschitz closure should
    # shrink the center distance approximately linearly. 0.35 leaves substantial
    # room for one-sided slope differences while rejecting a non-vanishing jump.
    passed = finite and max(ratios) <= 0.35
    return {
        "pass": passed,
        "finite": finite,
        "epsilon_ratio": eps_small/eps_large,
        "maximum_small_over_large": max(ratios),
        "threshold": 0.35,
        "response_tangent_admitted": False,
        "rows": rows,
        "cache": cache.diagnostics(),
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_lmfp08_upstreamk_ratio.py FULLRICHARDS_OUTPUT EVIDENCE_JSON")
    core.CorrectionCache = UpstreamKRatioCache
    identities = core.identity_tests()
    face = core.face_validation()
    response = core.response_diagnostics()
    continuity = continuity_refinement()
    transient = core.transient_matrix(Path(sys.argv[1]))
    structural = (identities["pass"] and face["pass"] and response["pass"] and
                  continuity["pass"] and transient["pass"])
    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP08",
        "candidate": "UPSTREAM_K_NORMALIZED_LOG_DARCIAN_RATIO_HOMOGENEOUS_FACE",
        "heterogeneous_faces": "current MFP equal-flux interface retained unchanged",
        "representation": {
            "formula": "q=(1-g)*K(h_upper)*exp(interp(R)); R=log(K_DAR/K(h_upper))",
            "g": "(h_lower-h_upper)/face_distance",
            "x_axis_points": len(X_AXIS),
            "g_axis_points": len(G_AXIS),
            "values_per_material_geometry_class": len(X_AXIS)*len(G_AXIS),
            "bytes_per_class_before_metadata": len(X_AXIS)*len(G_AXIS)*8,
            "equal_head_identity": "entire g=0 row has R=0, giving q=K(h_upper) without point branch",
            "hydrostatic_identity": "factor (1-g) gives q=0 continuously at g=1",
            "positive_effective_conductivity": True,
            "flow_direction_fixed_by_total_hydraulic_gradient": True,
            "runtime_extrapolation": False,
        },
        "tests": {
            "exact_identities": identities,
            "face_oracle_validation": face,
            "response_diagnostics_legacy": response,
            "strict_response_continuity_refinement": continuity,
            "transient_matrix": transient,
        },
        "structural_pass": structural,
        "interpretation": {
            "production_admission": "none",
            "response_tangent_admission": "none; continuity only",
            "lookup_ownership": "immutable shared hydraulic parameter data",
            "solver_policy": "explicit LayeredMFP physical model configuration only",
            "motivation": "removes the near-g=0 MFP-table secant discontinuity exposed after the first log-ratio gate",
        },
    }
    Path(sys.argv[2]).write_text(json.dumps(evidence, indent=2, sort_keys=True)+"\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if structural else 1)


if __name__ == "__main__":
    main()
