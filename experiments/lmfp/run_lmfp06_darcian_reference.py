from __future__ import annotations

import json
import math
import random

from run_lmfp02_testbench import B110Material
from run_lmfp03_column import ExtendedMFPTable, heterogeneous_face_flux, homogeneous_face_flux


def material(code: int) -> B110Material:
    vals = [0.0] * 24
    if code == 1:
        tr, ts, ks, alpha, lamb, nn = 0.045, 0.430, 20.0, 0.040, 0.50, 1.80
    elif code == 2:
        tr, ts, ks, alpha, lamb, nn = 0.080, 0.500, 0.20, 0.010, 0.50, 1.30
    else:
        raise ValueError(code)
    mm = 1.0 - 1.0 / nn
    vals[0] = tr
    vals[1] = ts
    vals[2] = ks
    vals[3] = alpha
    vals[4] = lamb
    vals[5] = nn
    vals[6] = mm
    vals[7] = alpha
    vals[8] = 0.0
    vals[9] = ks
    vals[10] = 0.999
    vals[11] = 0.99 * ks
    vals[21] = -1.0e6
    vals[22] = 1.0e-12
    return B110Material.from_input(vals)


SAND = material(1)
CLAY = material(2)
TABLES = {
    1: ExtendedMFPTable(SAND, n=2049, pf_max=8.0, pf_min=-4.0),
    2: ExtendedMFPTable(CLAY, n=2049, pf_max=8.0, pf_min=-4.0),
}
MATERIALS = {1: SAND, 2: CLAY}


def _rhs(mat: B110Material, h: float, q: float) -> float:
    """dh/dz for z positive downward and q positive downward."""
    k = max(mat.conductivity(h), 1.0e-14)
    return 1.0 - q / k


def _rk4(mat: B110Material, h: float, q: float, step: float) -> float:
    k1 = _rhs(mat, h, q)
    k2 = _rhs(mat, h + 0.5 * step * k1, q)
    k3 = _rhs(mat, h + 0.5 * step * k2, q)
    k4 = _rhs(mat, h + step * k3, q)
    return h + (step / 6.0) * (k1 + 2.0 * k2 + 2.0 * k3 + k4)


def integrate_segment(mat: B110Material, h0: float, q: float, length: float,
                      atol: float = 1.0e-9, rtol: float = 2.0e-9,
                      max_steps: int = 200000) -> tuple[float, int]:
    if length < 0.0:
        raise ValueError("length must be nonnegative")
    if length == 0.0:
        return h0, 0
    z = 0.0
    h = h0
    step = min(length, max(length / 16.0, 1.0e-6))
    accepted = 0
    while z < length:
        if accepted > max_steps:
            raise RuntimeError("steady Darcy segment exceeded max_steps")
        step = min(step, length - z)
        try:
            one = _rk4(mat, h, q, step)
            half = _rk4(mat, h, q, 0.5 * step)
            two = _rk4(mat, half, q, 0.5 * step)
        except (OverflowError, ValueError):
            step *= 0.25
            if step < 1.0e-12 * max(1.0, length):
                raise RuntimeError("steady Darcy segment integration underflow")
            continue
        if not (math.isfinite(one) and math.isfinite(two)) or abs(two) > 1.0e13:
            step *= 0.25
            if step < 1.0e-12 * max(1.0, length):
                raise RuntimeError("steady Darcy segment diverged")
            continue
        err = abs(two - one) / 15.0
        tol = atol + rtol * max(1.0, abs(h), abs(two))
        if err <= tol:
            h = two + (two - one) / 15.0
            z += step
            accepted += 1
            fac = 2.0 if err == 0.0 else min(2.0, max(0.5, 0.9 * (tol / err) ** 0.2))
            step *= fac
        else:
            step *= max(0.1, 0.9 * (tol / err) ** 0.2)
            if step < 1.0e-12 * max(1.0, length):
                raise RuntimeError("steady Darcy segment accuracy underflow")
    return h, accepted


def end_head_for_flux(mat_u: B110Material, mat_l: B110Material,
                      h_top: float, q: float, len_u: float, len_l: float) -> tuple[float, float, int]:
    h_int, n1 = integrate_segment(mat_u, h_top, q, len_u)
    h_end, n2 = integrate_segment(mat_l, h_int, q, len_l)
    return h_end, h_int, n1 + n2


def solve_steady_flux(mat_u: B110Material, mat_l: B110Material,
                      h_top: float, h_bottom: float, len_u: float, len_l: float,
                      flux_atol: float = 1.0e-11, head_atol: float = 2.0e-8,
                      max_iter: int = 100) -> tuple[float, float, int, int, float]:
    """Independent steady local Darcy BVP solved by shooting on conservative q.

    The oracle does not call a LayeredMFP face routine or conductivity mean.
    Pressure head is continuous at the material interface and the same flux is
    integrated through both material segments.
    """
    total = len_u + len_l
    if total <= 0.0:
        raise ValueError("positive total distance required")

    def residual(q: float):
        try:
            h_end, h_int, steps = end_head_for_flux(mat_u, mat_l, h_top, q, len_u, len_l)
            return h_end - h_bottom, h_int, steps
        except RuntimeError:
            return (-math.inf if q > 0.0 else math.inf), math.nan, 0

    kscale = max(mat_u.conductivity(0.0), mat_l.conductivity(0.0),
                 mat_u.conductivity(h_top), mat_l.conductivity(h_bottom), 1.0e-8)
    grad_scale = 1.0 + abs(h_top - h_bottom) / total
    span = max(kscale * grad_scale, 1.0e-7)
    lo, hi = -span, span
    flo, _, _ = residual(lo)
    fhi, _, _ = residual(hi)
    expansions = 0
    while not (flo >= 0.0 and fhi <= 0.0) and expansions < 32:
        span *= 2.0
        lo, hi = -span, span
        flo, _, _ = residual(lo)
        fhi, _, _ = residual(hi)
        expansions += 1
    if not (flo >= 0.0 and fhi <= 0.0):
        raise RuntimeError(("steady Darcy flux not bracketed", h_top, h_bottom, len_u, len_l, flo, fhi))

    total_steps = 0
    best_h_int = math.nan
    for iteration in range(1, max_iter + 1):
        mid = 0.5 * (lo + hi)
        fm, h_int, steps = residual(mid)
        total_steps += steps
        if math.isfinite(h_int):
            best_h_int = h_int
        qtol = flux_atol + 1.0e-10 * max(1.0, abs(mid))
        if abs(fm) <= head_atol or (hi - lo) <= 2.0 * qtol:
            return mid, best_h_int, iteration, total_steps, fm
        if fm > 0.0:
            lo = mid
            flo = fm
        else:
            hi = mid
            fhi = fm
    mid = 0.5 * (lo + hi)
    fm, h_int, steps = residual(mid)
    total_steps += steps
    return mid, h_int, max_iter, total_steps, fm


def arithmetic_flux(mat_u, mat_l, h_u, h_l, len_u, len_l):
    total = len_u + len_l
    k = 0.5 * (mat_u.conductivity(h_u) + mat_l.conductivity(h_l))
    return k * (1.0 + (h_u - h_l) / total)


def harmonic_flux(mat_u, mat_l, h_u, h_l, len_u, len_l):
    total = len_u + len_l
    ku = mat_u.conductivity(h_u)
    kl = mat_l.conductivity(h_l)
    keff = total / (len_u / ku + len_l / kl)
    return keff * (1.0 + (h_u - h_l) / total)


def mfp_flux(code_u, code_l, h_u, h_l, len_u, len_l):
    if code_u == code_l:
        return homogeneous_face_flux(TABLES[code_u], h_u, h_l, len_u + len_l), math.nan, 0
    q, h_i, it, residual = heterogeneous_face_flux(
        TABLES[code_u], TABLES[code_l], h_u, h_l, len_u, len_l,
        tolerance=1.0e-11, max_iterations=80)
    if abs(residual) > 1.0e-8 * max(1.0, abs(q)):
        raise RuntimeError("MFP equal-flux residual too large")
    return q, h_i, it


def relerr(q, ref, floor=1.0e-8):
    return abs(q - ref) / max(abs(ref), floor)


def run() -> dict:
    ev = {
        "work_unit": "F-LMFP06",
        "oracle": "independent adaptive-RK4 steady Darcy shooting BVP",
        "sign_convention": "z and q positive downward; q=K(h)*(1-dh/dz)",
        "tests": {},
    }

    sanity = []
    for code in (1, 2):
        mat = MATERIALS[code]
        for h in (-300.0, -90.0, -20.0, -2.0):
            q, hi, it, steps, res = solve_steady_flux(mat, mat, h, h, 5.0, 5.0)
            expected = mat.conductivity(h)
            sanity.append({"code": code, "kind": "equal_head", "h": h, "q": q,
                           "expected": expected, "abs_error": abs(q-expected),
                           "interface_head": hi, "iterations": it, "ode_steps": steps,
                           "head_residual": res})
            hbot = h + 10.0
            q0, hi0, it0, steps0, res0 = solve_steady_flux(mat, mat, h, hbot, 4.0, 6.0)
            sanity.append({"code": code, "kind": "hydrostatic", "h_top": h, "h_bottom": hbot,
                           "q": q0, "expected": 0.0, "abs_error": abs(q0),
                           "interface_head": hi0, "expected_interface": h+4.0,
                           "iterations": it0, "ode_steps": steps0, "head_residual": res0})
    max_equal = max(x["abs_error"] for x in sanity if x["kind"] == "equal_head")
    max_hydro = max(x["abs_error"] for x in sanity if x["kind"] == "hydrostatic")
    max_hydro_hi = max(abs(x["interface_head"]-x["expected_interface"])
                       for x in sanity if x["kind"] == "hydrostatic")
    ev["tests"]["oracle_analytic_sanity"] = {
        "pass": max_equal < 5.0e-8 and max_hydro < 5.0e-9 and max_hydro_hi < 2.0e-6,
        "max_equal_head_flux_abs_error": max_equal,
        "max_hydrostatic_flux_abs_error": max_hydro,
        "max_hydrostatic_interface_head_abs_error": max_hydro_hi,
        "cases": sanity,
    }

    local = []
    for orient in ((1, 2), (2, 1)):
        for total in (20.0, 10.0, 5.0, 2.5, 1.25, 0.625, 0.3125):
            hu = -90.0 - total
            hl = -90.0 + total
            lu = ll = 0.5 * total
            qref, href_i, it, steps, res = solve_steady_flux(
                MATERIALS[orient[0]], MATERIALS[orient[1]], hu, hl, lu, ll)
            qmfp, hmfp_i, mit = mfp_flux(orient[0], orient[1], hu, hl, lu, ll)
            qa = arithmetic_flux(MATERIALS[orient[0]], MATERIALS[orient[1]], hu, hl, lu, ll)
            qh = harmonic_flux(MATERIALS[orient[0]], MATERIALS[orient[1]], hu, hl, lu, ll)
            local.append({"orientation": f"{orient[0]}->{orient[1]}", "distance": total,
                          "q_ref": qref, "q_mfp": qmfp, "q_arithmetic": qa, "q_harmonic": qh,
                          "mfp_rel_error": relerr(qmfp,qref), "arithmetic_rel_error": relerr(qa,qref),
                          "harmonic_rel_error": relerr(qh,qref), "oracle_interface_head": href_i,
                          "mfp_interface_head": hmfp_i, "oracle_iterations": it,
                          "oracle_ode_steps": steps, "mfp_iterations": mit, "head_residual": res})
    finest = [x for x in local if x["distance"] == 0.3125]
    ev["tests"]["heterogeneous_local_limit"] = {
        "pass": all(x["mfp_rel_error"] < 0.01 for x in finest)
                and all(x["harmonic_rel_error"] < 0.01 for x in finest)
                and all(x["arithmetic_rel_error"] > 0.25 for x in finest),
        "finest_cases": finest,
        "all_cases": local,
    }

    rng = random.Random(43106)
    rows = []
    failures = 0
    max_oracle_iterations = 0
    max_ode_steps = 0
    sign_mismatch = {"mfp": 0, "arithmetic": 0, "harmonic": 0}
    for _ in range(240):
        cu, cl = rng.choice(((1,1),(2,2),(1,2),(2,1)))
        hu = -10.0 ** rng.uniform(0.0, 2.7)
        hl = -10.0 ** rng.uniform(0.0, 2.7)
        lu = 10.0 ** rng.uniform(-0.2, 1.1)
        ll = 10.0 ** rng.uniform(-0.2, 1.1)
        try:
            qref, href_i, it, steps, res = solve_steady_flux(
                MATERIALS[cu], MATERIALS[cl], hu, hl, lu, ll)
            qmfp, hmfp_i, mit = mfp_flux(cu, cl, hu, hl, lu, ll)
            qa = arithmetic_flux(MATERIALS[cu], MATERIALS[cl], hu, hl, lu, ll)
            qh = harmonic_flux(MATERIALS[cu], MATERIALS[cl], hu, hl, lu, ll)
        except Exception as exc:
            failures += 1
            rows.append({"failed": True, "codes": [cu,cl], "heads": [hu,hl], "lengths": [lu,ll],
                         "error": type(exc).__name__ + ":" + str(exc)})
            continue
        max_oracle_iterations = max(max_oracle_iterations, it)
        max_ode_steps = max(max_ode_steps, steps)
        for name, q in (("mfp",qmfp),("arithmetic",qa),("harmonic",qh)):
            if abs(qref) > 1.0e-7 and q*qref < 0.0:
                sign_mismatch[name] += 1
        rows.append({"failed": False, "codes": [cu,cl], "heads": [hu,hl], "lengths": [lu,ll],
                     "q_ref": qref, "q_mfp": qmfp, "q_arithmetic": qa, "q_harmonic": qh,
                     "mfp_rel_error": relerr(qmfp,qref), "arithmetic_rel_error": relerr(qa,qref),
                     "harmonic_rel_error": relerr(qh,qref), "oracle_interface_head": href_i,
                     "mfp_interface_head": hmfp_i, "oracle_iterations": it,
                     "oracle_ode_steps": steps, "mfp_iterations": mit, "head_residual": res})

    valid = [x for x in rows if not x["failed"] and abs(x["q_ref"]) > 1.0e-7]
    def summary(key):
        vals = sorted(x[key] for x in valid)
        return {"median": vals[len(vals)//2], "p90": vals[min(len(vals)-1, int(0.9*len(vals)))],
                "maximum": vals[-1]}
    ev["tests"]["bounded_reference_matrix"] = {
        "pass": failures == 0 and sign_mismatch["mfp"] == 0,
        "cases": len(rows), "valid_relative_error_cases": len(valid), "failures": failures,
        "sign_mismatch": sign_mismatch,
        "max_oracle_root_iterations": max_oracle_iterations,
        "max_accumulated_ode_steps_per_root": max_ode_steps,
        "mfp_error": summary("mfp_rel_error"),
        "arithmetic_error": summary("arithmetic_rel_error"),
        "harmonic_error": summary("harmonic_rel_error"),
        "rows": rows,
    }

    repro = []
    for cu, cl, hu, hl, lu, ll in [
        (1,2,-150,-50,10,10), (2,1,-150,-50,10,10),
        (1,2,-300,-30,3,7), (2,1,-30,-300,7,3),
        (1,1,-200,-60,8,12), (2,2,-200,-60,8,12),
    ]:
        q1, _, _, _, _ = solve_steady_flux(MATERIALS[cu], MATERIALS[cl], hu, hl, lu, ll)
        q2, _, _, _, _ = solve_steady_flux(MATERIALS[cu], MATERIALS[cl], hu, hl, lu, ll,
                                            flux_atol=2.5e-12, head_atol=5.0e-9)
        repro.append({"case":[cu,cl,hu,hl,lu,ll], "q_default":q1, "q_tight":q2,
                      "abs_difference":abs(q1-q2)})
    max_repro = max(x["abs_difference"] for x in repro)
    ev["tests"]["oracle_tolerance_reproducibility"] = {
        "pass": max_repro < 2.0e-7,
        "max_abs_flux_difference": max_repro,
        "cases": repro,
    }

    ev["structural_pass"] = all(t["pass"] for t in ev["tests"].values())
    return ev


def main():
    out = run()
    print(json.dumps(out, indent=2, sort_keys=True))
    if not out["structural_pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
