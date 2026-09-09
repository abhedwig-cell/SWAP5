from __future__ import annotations

import hashlib
import json
import math
import random
import sys
from decimal import Decimal, localcontext
from pathlib import Path

CONTRACT = "F-FWC01_GATE_B2C_R1_HIGH_PRECISION_EQ18_REPRESENTATION_PRECOMMIT.json"
EPS = 2.220446049250313e-16
LIMIT = 64.0 * EPS
RANDOM_CASES = 4096


def d(x: float) -> Decimal:
    return Decimal.from_float(float(x))


def decimal_eq18(theta_i: float, theta_d: float, k_i: float, k_d: float, g: float, hp: float, z: float) -> Decimal:
    with localcontext() as ctx:
        ctx.prec = 80
        ti, td, ki, kd, gg, hh, zz = map(d, (theta_i, theta_d, k_i, k_d, g, hp, z))
        return (kd * (gg + hh) / zz + kd - ki) / (td - ti)


def direct(theta_i: float, theta_d: float, k_i: float, k_d: float, g: float, hp: float, z: float) -> float:
    return (k_d * (g + hp) / z + k_d - k_i) / (theta_d - theta_i)


def cached(theta_i: float, theta_d: float, k_i: float, k_d: float, g: float, hp: float, z: float) -> float:
    dt = theta_d - theta_i
    dk = k_d - k_i
    return (k_d * (g + hp) / z + dk) / dt


def norm_error(value: float, ref: Decimal) -> float:
    with localcontext() as ctx:
        ctx.prec = 80
        err = abs(d(value) - ref)
        scale = max(Decimal(1), abs(ref))
        return float(err / scale)


def rel_mismatch(actual: float, nominal: float) -> float:
    return abs(actual - nominal) / max(abs(nominal), 1.0e-300)


def build_cases() -> list[dict]:
    seed = int(hashlib.sha256(b"F-FWC01-B2C-R1-ENDPOINT-SEMANTICS").hexdigest()[:16], 16)
    rng = random.Random(seed)
    rows: list[dict] = []
    for i in range(RANDOM_CASES):
        nominal_dt = 10.0 ** rng.uniform(-8.0, math.log10(0.8))
        theta_i = rng.uniform(0.0, max(0.0, 0.95 - nominal_dt))
        theta_d = theta_i + nominal_dt
        if not theta_d > theta_i:
            continue
        k_i = rng.uniform(0.0, 1000.0)
        nominal_dk = 10.0 ** rng.uniform(-10.0, 3.0)
        k_d = k_i + nominal_dk
        g = rng.uniform(0.0, 1000.0)
        hp = rng.uniform(0.0, 50.0)
        z = 10.0 ** rng.uniform(-8.0, 8.0)
        rows.append({
            "id": f"random_{i:04d}", "theta_i": theta_i, "theta_d": theta_d,
            "k_i": k_i, "k_d": k_d, "g": g, "hp": hp, "z": z,
            "nominal_dt": nominal_dt, "nominal_dk": nominal_dk,
        })
    rows.extend([
        {"id":"green_ampt", "theta_i":0.0, "theta_d":0.37, "k_i":0.0, "k_d":12.5, "g":83.0, "hp":4.0, "z":27.0, "nominal_dt":0.37, "nominal_dk":12.5},
        {"id":"zero_capillary", "theta_i":0.11, "theta_d":0.31, "k_i":2.0, "k_d":9.0, "g":0.0, "hp":0.0, "z":50.0, "nominal_dt":0.20, "nominal_dk":7.0},
        {"id":"equal_K_capillary", "theta_i":0.15, "theta_d":0.45, "k_i":5.0, "k_d":5.0, "g":100.0, "hp":2.0, "z":10.0, "nominal_dt":0.30, "nominal_dk":0.0},
    ])
    return rows


def decimal_limit_residuals() -> dict:
    with localcontext() as ctx:
        ctx.prec = 80
        ti, td, ki, kd, gg, hp, z = map(Decimal, ("0", "0.37", "0", "12.5", "83", "4", "27"))
        v = (kd*(gg+hp)/z + kd-ki)/(td-ti)
        infiltration = (td-ti)*v
        f = (td-ti)*z
        ga = kd * (Decimal(1) + (td-ti)*(gg+hp)/f)
        ga_res = infiltration-ga
        ti2, td2, ki2, kd2, z2 = map(Decimal, ("0.11", "0.31", "2", "9", "50"))
        v2 = (kd2*Decimal(0)/z2 + kd2-ki2)/(td2-ti2)
        fd = (kd2-ki2)/(td2-ti2)
        fd_res = v2-fd
    return {
        "green_ampt_decimal80_residual": str(ga_res),
        "zero_capillary_decimal80_residual": str(fd_res),
        "green_ampt_exact_zero": ga_res == 0,
        "zero_capillary_exact_zero": fd_res == 0,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2c_r1_decimal80_eq18_representation.py OUTPUT.json")
    out = Path(sys.argv[1])
    cases = build_cases()
    direct_errors: list[float] = []
    cached_errors: list[float] = []
    dt_mismatch: list[float] = []
    dk_mismatch: list[float] = []
    direct_fail = 0
    cached_fail = 0
    worst_direct = None
    worst_cached = None
    for row in cases:
        ref = decimal_eq18(row["theta_i"], row["theta_d"], row["k_i"], row["k_d"], row["g"], row["hp"], row["z"])
        vd = direct(row["theta_i"], row["theta_d"], row["k_i"], row["k_d"], row["g"], row["hp"], row["z"])
        vc = cached(row["theta_i"], row["theta_d"], row["k_i"], row["k_d"], row["g"], row["hp"], row["z"])
        ed = norm_error(vd, ref)
        ec = norm_error(vc, ref)
        direct_errors.append(ed); cached_errors.append(ec)
        direct_fail += int(ed > LIMIT); cached_fail += int(ec > LIMIT)
        if worst_direct is None or ed > worst_direct[0]: worst_direct = (ed, row["id"], vd, str(ref))
        if worst_cached is None or ec > worst_cached[0]: worst_cached = (ec, row["id"], vc, str(ref))
        if row["nominal_dt"] != 0.0:
            dt_mismatch.append(rel_mismatch(row["theta_d"]-row["theta_i"], row["nominal_dt"]))
        if row["nominal_dk"] != 0.0:
            dk_mismatch.append(rel_mismatch(row["k_d"]-row["k_i"], row["nominal_dk"]))

    def p99(xs: list[float]) -> float:
        s = sorted(xs); return s[int(0.99*(len(s)-1))]

    limits = decimal_limit_residuals()
    passed = direct_fail == 0 and cached_fail == 0 and limits["green_ampt_exact_zero"] and limits["zero_capillary_exact_zero"]
    result = {
        "schema_version":1, "workstream":"F-FWC", "work_unit":"F-FWC01",
        "gate":"B2C_R1_HIGH_PRECISION_EQ18_NUMERICAL_REPRESENTATION_CHARACTERIZATION",
        "contract":CONTRACT, "production_implementation":False,
        "decimal_precision_digits":80, "case_count":len(cases), "metric_limit":LIMIT,
        "direct_endpoint_eq18":{
            "max_normalized_forward_error":max(direct_errors), "p99_normalized_forward_error":p99(direct_errors),
            "cases_exceeding_limit":direct_fail, "worst_case":{"id":worst_direct[1],"error":worst_direct[0],"binary64":worst_direct[2],"decimal80":worst_direct[3]}
        },
        "precomputed_binary64_deltas_eq18":{
            "max_normalized_forward_error":max(cached_errors), "p99_normalized_forward_error":p99(cached_errors),
            "cases_exceeding_limit":cached_fail, "worst_case":{"id":worst_cached[1],"error":worst_cached[0],"binary64":worst_cached[2],"decimal80":worst_cached[3]},
            "dynamic_state_bytes":0, "possible_storage_role":"immutable_shared_parameter_cache"
        },
        "synthetic_endpoint_construction_diagnostic":{
            "max_relative_nominal_delta_theta_mismatch":max(dt_mismatch), "p99_relative_nominal_delta_theta_mismatch":p99(dt_mismatch),
            "max_relative_nominal_delta_K_mismatch":max(dk_mismatch), "p99_relative_nominal_delta_K_mismatch":p99(dk_mismatch)
        },
        "decimal80_limit_identities":limits,
        "pass":passed,
        "decision":"QUALIFIED_EQ18_BINARY64_ENDPOINT_SEMANTICS_READY_FOR_RESTRICTED_EXISTING_FRONT_ADVANCE_MASS_GATE" if passed else "EQ18_BINARY64_REPRESENTATION_NOT_QUALIFIED_NUMERICAL_POLICY_RESEARCH_REQUIRED",
        "hard_nonclaims":["No dry-bin creation or rainfall allocation qualification.","No G_eff closure qualification.","No front merge or groundwater interaction qualification."]
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    print(json.dumps({"pass":passed,"decision":result["decision"],"case_count":len(cases),"direct_max":max(direct_errors),"direct_fail":direct_fail,"cached_max":max(cached_errors),"cached_fail":cached_fail,"max_dt_nominal_mismatch":max(dt_mismatch),"max_dk_nominal_mismatch":max(dk_mismatch),**limits}, sort_keys=True))
    if not passed: raise SystemExit(1)

if __name__ == "__main__": main()
