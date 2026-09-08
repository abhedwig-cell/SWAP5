from __future__ import annotations

import json
import math
import random

from run_lmfp02_testbench import adaptive_simpson
from run_lmfp06_darcian_reference import MATERIALS, TABLES, solve_steady_flux
from run_lmfp03_column import homogeneous_face_flux


def integrated_mean(mat, h_u: float, h_l: float) -> float:
    scale = max(1.0, abs(h_u), abs(h_l))
    if abs(h_l - h_u) <= 1.0e-12 * scale:
        return mat.conductivity(0.5 * (h_u + h_l))
    val, _ = adaptive_simpson(mat.conductivity, h_u, h_l, atol=1.0e-12, rtol=2.0e-10)
    return val / (h_l - h_u)


def szymkiewicz_2009_kdar(mat, h_u: float, h_l: float, dz: float) -> tuple[float, str, dict]:
    """Approximate Darcian mean from Szymkiewicz (2009), homogeneous vertical block.

    This is a literature-formula control only. It is not claimed to reproduce
    SWAP 4.3.1 SWKMEAN=7 tables byte-for-byte or to cover material interfaces.

    Sign convention follows the paper: z positive downward, dh=h_L-h_U.
    Discrete q = K_DAR * (1 - dh/dz).
    """
    if dz <= 0.0:
        raise ValueError("dz must be positive")
    dh = h_l - h_u
    ratio = dh / dz
    gravity_factor = 1.0 - ratio
    ku = mat.conductivity(h_u)

    if abs(gravity_factor) <= 1.0e-13:
        # Hydrostatic pressure-head gradient. q is zero for any finite K_AV.
        return integrated_mean(mat, h_u, h_l), "hydrostatic", {
            "dh_over_dz": ratio, "gravity_factor": gravity_factor
        }

    if ratio <= 0.0:
        # Downward flow, infiltration into drier soil.
        kint = integrated_mean(mat, h_u, h_l)
        kup = ku / gravity_factor
        kdar = max(kint, kup)
        return kdar, "downward_dry", {
            "dh_over_dz": ratio, "gravity_factor": gravity_factor,
            "K_INT": kint, "K_U_over_G": kup,
        }

    if ratio < 1.0:
        # Downward flow, drainage or infiltration near a water table.
        kup = ku / gravity_factor
        h_probe = h_l - (dh * dh) / dz
        kprobe = mat.conductivity(h_probe)
        kdar = min(kup, kprobe)
        return kdar, "downward_wet", {
            "dh_over_dz": ratio, "gravity_factor": gravity_factor,
            "K_U_over_G": kup, "h_probe": h_probe, "K_probe": kprobe,
        }

    # Upward capillary flow. Approximate the steady profile by two zones.
    h_r = h_l - dz
    k1 = integrated_mean(mat, h_u, h_r)
    k2 = mat.conductivity(h_r)
    r = k2 / max(k1, 1.0e-300)
    a = r - 1.0
    if abs(a) < 1.0e-10:
        delta = (dh - dz) * dz / dh
    else:
        discr = dh * dh + 4.0 * a * (dh - dz) * dz
        if discr < 0.0 and discr > -1.0e-12 * max(1.0, dh * dh):
            discr = 0.0
        if discr < 0.0:
            raise RuntimeError(("negative Szymkiewicz discriminant", discr, h_u, h_l, dz, k1, k2))
        delta = (-dh + math.sqrt(discr)) / (2.0 * a)
    delta = min(dz, max(0.0, delta))
    denom = (dz - delta) * k1 + delta * k2
    if denom <= 0.0:
        raise RuntimeError("nonpositive Szymkiewicz series denominator")
    kdar = dz * k1 * k2 / denom
    return kdar, "upward_capillary", {
        "dh_over_dz": ratio, "gravity_factor": gravity_factor,
        "h_R": h_r, "K_AV_1": k1, "K_AV_2": k2,
        "K2_over_K1": r, "delta_z": delta,
    }


def szymkiewicz_2009_flux(mat, h_u: float, h_l: float, dz: float):
    kdar, regime, detail = szymkiewicz_2009_kdar(mat, h_u, h_l, dz)
    q = kdar * (1.0 - (h_l - h_u) / dz)
    return q, kdar, regime, detail


def relerr(q, ref, floor=1.0e-8):
    return abs(q - ref) / max(abs(ref), floor)


def percentile(vals, p):
    vals = sorted(vals)
    if not vals:
        return math.nan
    return vals[min(len(vals)-1, int(p * len(vals)))]


def run():
    evidence = {
        "work_unit": "F-LMFP06",
        "control": "SZYMKIEWICZ_2009_HOMOGENEOUS_VERTICAL_DARCIAN_APPROXIMATION",
        "swkmean7_reproduced": False,
        "scope": "homogeneous material faces only",
        "tests": {},
    }

    # Exact/limiting sanity cases that do not depend on the independent BVP.
    sanity = []
    for code in (1, 2):
        mat = MATERIALS[code]
        for h in (-300.0, -90.0, -20.0, -2.0):
            q, kd, regime, detail = szymkiewicz_2009_flux(mat, h, h, 10.0)
            sanity.append({"code":code, "kind":"equal_head", "h":h, "q":q,
                           "expected":mat.conductivity(h), "abs_error":abs(q-mat.conductivity(h)),
                           "regime":regime, "K_DAR":kd, "detail":detail})
            q0, kd0, regime0, detail0 = szymkiewicz_2009_flux(mat, h, h+10.0, 10.0)
            sanity.append({"code":code, "kind":"hydrostatic", "h_top":h, "h_bottom":h+10.0,
                           "q":q0, "expected":0.0, "abs_error":abs(q0),
                           "regime":regime0, "K_DAR":kd0, "detail":detail0})
    evidence["tests"]["analytic_sanity"] = {
        "pass": max(x["abs_error"] for x in sanity) < 1.0e-10,
        "max_abs_error": max(x["abs_error"] for x in sanity),
        "cases": sanity,
    }

    # Cases where the first independent oracle sweep exposed the largest MFP errors.
    stress = [
        (1, -183.9188, -3.05775, 11.37460),
        (1, -54.12, -1.82, 8.0),
        (1, -300.0, -5.0, 12.0),
        (1, -200.0, -20.0, 10.0),
        (2, -200.0, -20.0, 10.0),
        (2, -30.0, -300.0, 10.0),
    ]
    stress_rows = []
    for code, hu, hl, dz in stress:
        mat = MATERIALS[code]
        qref, _, _, _, _ = solve_steady_flux(mat, mat, hu, hl, 0.5*dz, 0.5*dz)
        qmfp = homogeneous_face_flux(TABLES[code], hu, hl, dz)
        qsz, kd, regime, detail = szymkiewicz_2009_flux(mat, hu, hl, dz)
        stress_rows.append({"code":code,"h_upper":hu,"h_lower":hl,"dz":dz,
                            "q_ref":qref,"q_mfp":qmfp,"q_szym2009":qsz,
                            "mfp_rel_error":relerr(qmfp,qref),
                            "szym2009_rel_error":relerr(qsz,qref),
                            "regime":regime,"K_DAR":kd,"detail":detail})
    evidence["tests"]["targeted_strong_gradient_control"] = {
        "pass": sum(x["szym2009_rel_error"] < x["mfp_rel_error"] for x in stress_rows) >= 4,
        "cases_better_than_mfp": sum(x["szym2009_rel_error"] < x["mfp_rel_error"] for x in stress_rows),
        "cases": stress_rows,
    }

    rng = random.Random(4310609)
    rows = []
    failures = 0
    sign_mismatch = 0
    for _ in range(260):
        code = rng.choice((1,2))
        hu = -10.0 ** rng.uniform(0.0, 2.7)
        hl = -10.0 ** rng.uniform(0.0, 2.7)
        dz = 10.0 ** rng.uniform(0.1, 1.4)
        mat = MATERIALS[code]
        try:
            qref, _, _, _, _ = solve_steady_flux(mat, mat, hu, hl, 0.5*dz, 0.5*dz)
            qmfp = homogeneous_face_flux(TABLES[code], hu, hl, dz)
            qsz, kd, regime, detail = szymkiewicz_2009_flux(mat, hu, hl, dz)
        except Exception as exc:
            failures += 1
            rows.append({"failed":True,"code":code,"heads":[hu,hl],"dz":dz,
                         "error":type(exc).__name__+":"+str(exc)})
            continue
        if abs(qref) > 1.0e-7 and qsz*qref < 0.0:
            sign_mismatch += 1
        rows.append({"failed":False,"code":code,"heads":[hu,hl],"dz":dz,
                     "gradient_factor":1.0-(hl-hu)/dz,
                     "q_ref":qref,"q_mfp":qmfp,"q_szym2009":qsz,
                     "mfp_rel_error":relerr(qmfp,qref),
                     "szym2009_rel_error":relerr(qsz,qref),
                     "regime":regime,"K_DAR":kd,"detail":detail})

    valid = [r for r in rows if not r["failed"] and abs(r["q_ref"]) > 1.0e-7]
    mfp = [r["mfp_rel_error"] for r in valid]
    szy = [r["szym2009_rel_error"] for r in valid]
    by_regime = {}
    for regime in sorted({r["regime"] for r in valid}):
        rr = [r for r in valid if r["regime"] == regime]
        by_regime[regime] = {
            "n":len(rr),
            "mfp_median":percentile([r["mfp_rel_error"] for r in rr],0.5),
            "mfp_p90":percentile([r["mfp_rel_error"] for r in rr],0.9),
            "szym2009_median":percentile([r["szym2009_rel_error"] for r in rr],0.5),
            "szym2009_p90":percentile([r["szym2009_rel_error"] for r in rr],0.9),
        }
    evidence["tests"]["homogeneous_oracle_matrix"] = {
        "pass": failures == 0 and sign_mismatch == 0 and percentile(szy,0.9) < percentile(mfp,0.9),
        "cases":len(rows),"valid_relative_error_cases":len(valid),"failures":failures,
        "sign_mismatch":sign_mismatch,
        "mfp_error":{"median":percentile(mfp,0.5),"p90":percentile(mfp,0.9),"maximum":max(mfp)},
        "szym2009_error":{"median":percentile(szy,0.5),"p90":percentile(szy,0.9),"maximum":max(szy)},
        "fraction_szym2009_better_than_mfp":sum(s<m for s,m in zip(szy,mfp))/len(valid),
        "by_regime":by_regime,
        "rows":rows,
    }

    evidence["structural_pass"] = all(v["pass"] for v in evidence["tests"].values())
    return evidence


def main():
    ev = run()
    print(json.dumps(ev, indent=2, sort_keys=True))
    if not ev["structural_pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
