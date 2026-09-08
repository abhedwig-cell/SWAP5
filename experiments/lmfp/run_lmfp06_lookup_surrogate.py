from __future__ import annotations

import bisect
import json
import math
import random

from run_lmfp06_darcian_reference import MATERIALS, solve_steady_flux


HEAD_AXIS = [
    -1.0, -1.5, -2.3, -3.5, -5.3, -8.0, -12.0, -18.0,
    -27.0, -41.0, -62.0, -94.0, -142.0, -214.0, -323.0, -500.0,
]


def gravity_factor(h_u, h_l, length):
    return 1.0 + (h_u - h_l) / length


def oracle_kdar(code_u, code_l, h_u, h_l, len_u, len_l):
    mat_u = MATERIALS[code_u]
    mat_l = MATERIALS[code_l]
    total = len_u + len_l
    g = gravity_factor(h_u, h_l, total)
    if abs(g) > 1.0e-7:
        q, _, _, _, _ = solve_steady_flux(mat_u, mat_l, h_u, h_l, len_u, len_l)
        k = q / g
        if not math.isfinite(k) or k <= 0.0:
            raise RuntimeError(("nonpositive oracle K_DAR", code_u, code_l, h_u, h_l, q, g, k))
        return k

    # At exactly hydrostatic pressure-head gradient q=0 and K_DAR is not
    # identifiable from q/G. Estimate the continuous limiting value symmetrically.
    eps = max(1.0e-5, 2.0e-5 * total)
    vals = []
    for sign in (-1.0, 1.0):
        hl = h_l + sign * eps
        gg = gravity_factor(h_u, hl, total)
        q, _, _, _, _ = solve_steady_flux(mat_u, mat_l, h_u, hl, len_u, len_l)
        vals.append(q / gg)
    k = 0.5 * (vals[0] + vals[1])
    if not math.isfinite(k) or k <= 0.0:
        raise RuntimeError(("invalid hydrostatic-limit K_DAR", vals, k))
    return k


class DarcianLookup:
    """Diagnostic immutable K_DAR(h_upper,h_lower) table for one fixed face.

    This mirrors the mathematical shape of the historical SWKMEAN=7 runtime
    lookup, but the values are generated independently from the F-LMFP06 steady
    Darcy oracle. It is not a reconstruction of a missing legacy .unf table.
    """

    def __init__(self, code_u, code_l, len_u, len_l, axis=HEAD_AXIS):
        self.code_u = code_u
        self.code_l = code_l
        self.len_u = float(len_u)
        self.len_l = float(len_l)
        self.axis = list(axis)
        if any(self.axis[i] <= self.axis[i+1] for i in range(len(self.axis)-1)):
            raise ValueError("head axis must be strictly decreasing from wet to dry")
        self.values = []
        for hu in self.axis:
            row = []
            for hl in self.axis:
                row.append(oracle_kdar(code_u, code_l, hu, hl, self.len_u, self.len_l))
            self.values.append(row)

    def _bracket(self, h):
        # Work on the negated ascending coordinate for simple bisect.
        x = -h
        xs = [-v for v in self.axis]
        if x <= xs[0]:
            return 0, 1
        if x >= xs[-1]:
            return len(xs)-2, len(xs)-1
        j = bisect.bisect_right(xs, x) - 1
        return j, j+1

    def kdar(self, h_u, h_l):
        i0, i1 = self._bracket(h_u)
        j0, j1 = self._bracket(h_l)
        hu0, hu1 = self.axis[i0], self.axis[i1]
        hl0, hl1 = self.axis[j0], self.axis[j1]
        tu = (h_u - hu0) / (hu1 - hu0)
        tl = (h_l - hl0) / (hl1 - hl0)
        k00 = self.values[i0][j0]
        k10 = self.values[i1][j0]
        k11 = self.values[i1][j1]
        k01 = self.values[i0][j1]
        return ((1-tu)*(1-tl)*k00 + tu*(1-tl)*k10 +
                tu*tl*k11 + (1-tu)*tl*k01)

    def flux(self, h_u, h_l):
        total = self.len_u + self.len_l
        return self.kdar(h_u, h_l) * gravity_factor(h_u, h_l, total)


def relerr(q, ref, floor=1.0e-8):
    return abs(q-ref) / max(abs(ref), floor)


def percentile(vals, p):
    vals = sorted(vals)
    return vals[min(len(vals)-1, int(p*len(vals)))]


def run():
    faces = [
        ("sand_sand", 1, 1, 5.0, 5.0),
        ("sand_clay", 1, 2, 5.0, 5.0),
    ]
    evidence = {
        "work_unit":"F-LMFP06",
        "surrogate":"ORACLE_DERIVED_BILINEAR_DARCIAN_LOOKUP",
        "legacy_swkmean7_table_reproduced":False,
        "head_axis":HEAD_AXIS,
        "faces":{},
    }
    rng = random.Random(4310610)
    all_pass = True

    for name, cu, cl, lu, ll in faces:
        table = DarcianLookup(cu, cl, lu, ll)
        rows = []
        failures = 0
        sign_mismatch = 0
        for _ in range(100):
            # Sample uniformly in log(-h), but remain inside the interpolation envelope.
            hu = -10.0 ** rng.uniform(0.02, math.log10(480.0))
            hl = -10.0 ** rng.uniform(0.02, math.log10(480.0))
            try:
                qref, _, _, _, _ = solve_steady_flux(MATERIALS[cu], MATERIALS[cl], hu, hl, lu, ll)
                qtab = table.flux(hu, hl)
            except Exception as exc:
                failures += 1
                rows.append({"failed":True,"heads":[hu,hl],"error":type(exc).__name__+":"+str(exc)})
                continue
            if abs(qref) > 1.0e-7 and qref*qtab < 0.0:
                sign_mismatch += 1
            rows.append({"failed":False,"heads":[hu,hl],"q_ref":qref,"q_lookup":qtab,
                         "rel_error":relerr(qtab,qref),
                         "gravity_factor":gravity_factor(hu,hl,lu+ll)})
        valid = [r for r in rows if not r["failed"] and abs(r["q_ref"]) > 1.0e-7]
        errs = [r["rel_error"] for r in valid]
        stats = {
            "table_shape":[len(HEAD_AXIS),len(HEAD_AXIS)],
            "table_values":len(HEAD_AXIS)**2,
            "validation_cases":len(rows),
            "valid_relative_error_cases":len(valid),
            "failures":failures,
            "sign_mismatch":sign_mismatch,
            "error":{"median":percentile(errs,0.5),"p90":percentile(errs,0.9),"maximum":max(errs)},
            "rows":rows,
        }
        # This is an experimental feasibility gate, not a production accuracy limit.
        stats["pass"] = failures == 0 and sign_mismatch == 0 and stats["error"]["p90"] < 0.25
        all_pass = all_pass and stats["pass"]
        evidence["faces"][name] = stats

    evidence["structural_pass"] = all_pass
    return evidence


def main():
    ev = run()
    print(json.dumps(ev, indent=2, sort_keys=True))
    if not ev["structural_pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
