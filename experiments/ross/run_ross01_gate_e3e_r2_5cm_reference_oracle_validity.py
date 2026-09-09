from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import mpmath as mp
import numpy as np
from scipy.integrate import quad
from scipy.optimize import brentq

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3e_5cm_surface_boundary_face as e3e
import run_ross01_gate_e2c_bounded_local_face_solve as e2c

CONTRACT = "F-ROSS01_GATE_E3E_R2_5CM_REFERENCE_ORACLE_VALIDITY_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
LENGTH = 5.0
AGREE_TOL = 1.0e-9
LEGACY_FACE_THRESHOLD = 5.0e-4
GL_N = 256
BISECTION_STEPS = 80

WITNESSES = {
    "B01": [(0.7695052395319549,-1.8766271852337812e-9),(0.5,-0.01),(0.1,-1.0),(0.0,-100.0)],
    "B12": [(0.8837919082381909,-0.009962848502903649),(0.5,-0.01),(0.1,-1.0),(0.0,-100.0)],
    "O13": [(0.7833053261466696,-0.013722375623542532),(0.5,-0.01),(0.1,-1.0),(0.0,-100.0)],
    "O14": [(0.911544390759661,-3.724819842771122e-10),(0.5,-0.01),(0.1,-1.0),(0.0,-100.0)],
}

_XGL, _WGL = np.polynomial.legendre.leggauss(GL_N)


def physical_bracket(hs: float, ht: float, ksat: float) -> tuple[float, float]:
    if hs == 0.0 and ht == 0.0:
        return ksat, ksat
    if not (hs >= 0.0 and ht <= 0.0):
        raise ValueError(("outside_surface_to_unsat_scope", hs, ht))
    upper = ksat * (1.0 + (hs - ht) / LENGTH)
    lower = math.nextafter(ksat, math.inf)
    if not upper >= lower:
        upper = lower
    return lower, upper


def saturated_part(hs: float, q: float, ksat: float) -> float:
    if hs <= 0.0:
        return 0.0
    return (-hs) * ksat / (ksat - q)


def split_adaptive_path(hs: float, ht: float, q: float, ksat: float) -> float:
    sat = saturated_part(hs, q, ksat)
    if ht >= 0.0:
        return sat
    value, _ = quad(
        lambda h: e2c.c1.core.k_of_h(float(h)) / (e2c.c1.core.k_of_h(float(h)) - q),
        0.0,
        ht,
        epsabs=1.0e-12,
        epsrel=1.0e-12,
        limit=500,
        points=[0.0],
    )
    return sat + float(value)


def split_adaptive_q(hs: float, ht: float, ksat: float) -> float:
    if hs == 0.0 and ht == 0.0:
        return ksat
    if ht == 0.0:
        return ksat * (1.0 + hs / LENGTH)
    lo, hi = physical_bracket(hs, ht, ksat)
    f = lambda q: split_adaptive_path(hs, ht, q, ksat) - LENGTH
    flo = f(lo)
    fhi = f(hi)
    if fhi == 0.0:
        return hi
    if not (math.isfinite(flo) and math.isfinite(fhi) and flo * fhi <= 0.0):
        raise RuntimeError(("split_adaptive_bracket_failure", hs, ht, lo, hi, flo, fhi))
    return float(brentq(f, lo, hi, xtol=5.0e-14, rtol=1.0e-14, maxiter=200))


def gl_unsat_setup(ht: float):
    if ht >= 0.0:
        return np.empty(0), np.empty(0)
    mid = 0.5 * ht
    half = 0.5 * ht
    heads = mid + half * _XGL
    weights = half * _WGL
    kvals = np.asarray([e2c.c1.core.k_of_h(float(h)) for h in heads], dtype=np.float64)
    return kvals, weights


def split_fixed_gl_q(hs: float, ht: float, ksat: float) -> float:
    if hs == 0.0 and ht == 0.0:
        return ksat
    if ht == 0.0:
        return ksat * (1.0 + hs / LENGTH)
    kvals, weights = gl_unsat_setup(ht)
    lo, hi = physical_bracket(hs, ht, ksat)

    def residual(q: float) -> float:
        sat = saturated_part(hs, q, ksat)
        unsat = 0.0 if kvals.size == 0 else float(np.sum(weights * kvals / (kvals - q)))
        return sat + unsat - LENGTH

    flo = residual(lo)
    fhi = residual(hi)
    if fhi == 0.0:
        return hi
    if not (math.isfinite(flo) and math.isfinite(fhi) and flo * fhi <= 0.0):
        raise RuntimeError(("split_gl_bracket_failure", hs, ht, lo, hi, flo, fhi))
    for _ in range(BISECTION_STEPS):
        mid = 0.5 * (lo + hi)
        fm = residual(mid)
        if flo * fm <= 0.0:
            hi = mid
            fhi = fm
        else:
            lo = mid
            flo = fm
    return 0.5 * (lo + hi)


def mp_k(h, row):
    h = mp.mpf(h)
    ks = mp.mpf(str(row["ksatfit_cm_per_day"]))
    if h >= 0:
        return ks
    alpha = mp.mpf(str(row["alpha_per_cm"]))
    n = mp.mpf(str(row["n"]))
    m = 1 - 1/n
    lam = mp.mpf(str(row["lambda"]))
    se = (1 + abs(alpha*h)**n) ** (-m)
    term = (1 - se ** (1/m)) ** m
    return ks * se**lam * (1-term)**2


def mpmath80_q(hs: float, ht: float, row: dict) -> float:
    mp.mp.dps = 80
    hsmp = mp.mpf(str(hs)); htmp = mp.mpf(str(ht))
    ks = mp.mpf(str(row["ksatfit_cm_per_day"]))
    L = mp.mpf("5")
    if hsmp == 0 and htmp == 0:
        return float(ks)
    if htmp == 0:
        return float(ks * (1 + hsmp/L))
    lo = ks * (1 + mp.mpf("1e-40"))
    hi = ks * (1 + (hsmp-htmp)/L)

    def residual(q):
        sat = mp.mpf("0") if hsmp <= 0 else (-hsmp) * ks / (ks-q)
        unsat = mp.mpf("0") if htmp >= 0 else mp.quad(lambda h: mp_k(h,row)/(mp_k(h,row)-q), [mp.mpf("0"), htmp])
        return sat + unsat - L

    flo = residual(lo); fhi = residual(hi)
    if fhi == 0:
        return float(hi)
    if flo*fhi > 0:
        raise RuntimeError(("mpmath_bracket_failure", hs, ht, str(flo), str(fhi)))
    for _ in range(120):
        mid = (lo+hi)/2
        fm = residual(mid)
        if flo*fm <= 0:
            hi = mid; fhi = fm
        else:
            lo = mid; flo = fm
    return float((lo+hi)/2)


def summarize(material: str, row: dict) -> dict:
    e3e.configure_5cm(row)
    ksat = float(e2c.c1.core.KSAT)
    probes = e3e.build_probes(material)
    rows = []
    unresolved = 0
    nonfinite = 0
    wrong_sign = 0
    for p in probes:
        hs = float(p["h_surface"]); ht = float(p["h_top_node"])
        try:
            legacy = float(e2c.c1.core.steady_q(hs, ht))
            adaptive = split_adaptive_q(hs, ht, ksat)
            fixed = split_fixed_gl_q(hs, ht, ksat)
        except Exception as exc:
            rows.append({"probe_id":p["id"],"error":repr(exc),"h_surface":hs,"h_top_node":ht})
            unresolved += 1
            continue
        if not all(math.isfinite(x) for x in (legacy,adaptive,fixed)):
            nonfinite += 1
            continue
        wrong_sign += int(math.copysign(1.0,adaptive) != math.copysign(1.0,fixed))
        rows.append({
            "probe_id": p["id"], "probe_set": p["probe_set"], "family": p["family"],
            "h_surface": hs, "h_top_node": ht,
            "legacy_q": legacy, "split_adaptive_q": adaptive, "split_fixed_gl_q": fixed,
            "adaptive_vs_fixed_abs_over_ksat": abs(adaptive-fixed)/ksat,
            "legacy_vs_adaptive_abs_over_ksat": abs(legacy-adaptive)/ksat,
        })

    valid = [r for r in rows if "split_adaptive_q" in r]
    af = [r["adaptive_vs_fixed_abs_over_ksat"] for r in valid]
    la = sorted(r["legacy_vs_adaptive_abs_over_ksat"] for r in valid)
    witnesses = []
    for hs, ht in WITNESSES[material]:
        adaptive = split_adaptive_q(hs, ht, ksat)
        fixed = split_fixed_gl_q(hs, ht, ksat)
        mpq = mpmath80_q(hs, ht, row)
        witnesses.append({
            "h_surface": hs, "h_top_node": ht,
            "split_adaptive_q": adaptive, "split_fixed_gl_q": fixed, "mpmath80_q": mpq,
            "adaptive_vs_mpmath_abs_over_ksat": abs(adaptive-mpq)/ksat,
            "fixed_vs_mpmath_abs_over_ksat": abs(fixed-mpq)/ksat,
        })

    max_af = max(af, default=math.inf)
    max_amp = max(w["adaptive_vs_mpmath_abs_over_ksat"] for w in witnesses)
    max_fmp = max(w["fixed_vs_mpmath_abs_over_ksat"] for w in witnesses)
    tests = {
        "adaptive_vs_fixed": max_af <= AGREE_TOL,
        "adaptive_vs_mpmath80_witness": max_amp <= AGREE_TOL,
        "fixed_vs_mpmath80_witness": max_fmp <= AGREE_TOL,
        "wrong_sign_count": wrong_sign == 0,
        "nonfinite_count": nonfinite == 0,
        "unresolved_count": unresolved == 0,
    }
    return {
        "material": material,
        "probe_count": len(probes),
        "valid_probe_count": len(valid),
        "unresolved_count": unresolved,
        "nonfinite_count": nonfinite,
        "wrong_sign_count_between_independent_oracles": wrong_sign,
        "max_split_adaptive_vs_fixed_abs_over_ksat": max_af,
        "max_split_adaptive_vs_mpmath80_witness_abs_over_ksat": max_amp,
        "max_split_fixed_gl_vs_mpmath80_witness_abs_over_ksat": max_fmp,
        "legacy_max_abs_over_ksat": max(la, default=math.inf),
        "legacy_p99_abs_over_ksat": la[int(0.99*(len(la)-1))] if la else math.inf,
        "legacy_count_exceeding_5e_4": sum(x > LEGACY_FACE_THRESHOLD for x in la),
        "legacy_worst_probe": max(valid, key=lambda r:r["legacy_vs_adaptive_abs_over_ksat"]) if valid else None,
        "witnesses": witnesses,
        "tests": tests,
        "pass": all(tests.values()),
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3e_r2_5cm_reference_oracle_validity.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(f"material must be one of {MATERIALS}")
    catalog=json.loads(CATALOG.read_text(encoding="utf-8"))
    row=next(r for r in catalog["rows"] if r["sfu"]==material)
    result=summarize(material,row)
    result.update({
        "schema_version":1,
        "workstream":"F-ROSS",
        "work_unit":"F-ROSS01",
        "gate":"E3E_R2_5CM_SURFACE_TO_UNSAT_REFERENCE_ORACLE_VALIDITY",
        "contract":CONTRACT,
        "production_implementation":False,
        "qualification_target":"REFERENCE_ORACLE_ONLY",
        "decision": (
            "QUALIFIED_SPLIT_H0_5CM_REFERENCE_ORACLE_READY_FOR_INDEPENDENT_BOUNDARY_FACE_REQUALIFICATION"
            if result["pass"] else "5CM_REFERENCE_ORACLE_NOT_YET_QUALIFIED_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims":[
            "No Ross candidate qualification follows from this oracle gate.",
            "The prior 5 cm candidate FAIL remains preserved until independent requalification.",
            "No surface-process, ponding, runoff, runtime or MultiSWAP admission follows."
        ]
    })
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps({
        "material":material,"pass":result["pass"],"decision":result["decision"],
        "max_adaptive_vs_fixed":result["max_split_adaptive_vs_fixed_abs_over_ksat"],
        "max_adaptive_vs_mp":result["max_split_adaptive_vs_mpmath80_witness_abs_over_ksat"],
        "legacy_max":result["legacy_max_abs_over_ksat"],
        "legacy_count_exceeding_5e_4":result["legacy_count_exceeding_5e_4"],
        "legacy_worst":result["legacy_worst_probe"],
    },sort_keys=True),flush=True)
    if not result["pass"]:
        raise SystemExit(1)


if __name__=="__main__":
    main()
