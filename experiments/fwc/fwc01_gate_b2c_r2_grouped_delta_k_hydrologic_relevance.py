from __future__ import annotations

import json
import math
import sys
from decimal import Decimal, localcontext
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import fwc01_gate_b2a_physical_falling_slug_mass as b2a

CONTRACT = "F-FWC01_GATE_B2C_R2_GROUPED_DELTA_K_EQ18_HYDROLOGIC_RELEVANCE_PRECOMMIT.json"
FIXTURE = Path("integration/f-fwc/F-FWC01_GATE_B2A_MATERIAL_FIXTURE.json")
MATERIALS = ("B01", "B12", "O13", "O14")
BIN_COUNTS = (16, 64, 200)
BIN_FRACTIONS = (0.125, 0.5, 0.875, 1.0)
G_EFF_CM = (1.0, 10.0, 100.0)
HP_CM = (0.0, 1.0, 5.0)
Z_CM = (0.1, 1.0, 10.0, 100.0)
DT_DAYS = (1.0e-6, 1.0e-4, 1.0e-2)
FORWARD_LIMIT = 1.4210854715202004e-14
FRONT_ERROR_LIMIT_CM = 1.0e-6
WATER_ERROR_LIMIT_CM = 1.0e-8


def d(x: float) -> Decimal:
    return Decimal.from_float(float(x))


def decimal_eq18(theta_i: float, theta_d: float, k_i: float, k_d: float,
                 g: float, hp: float, z: float) -> Decimal:
    with localcontext() as ctx:
        ctx.prec = 80
        ti, td, ki, kd, gg, hh, zz = map(d, (theta_i, theta_d, k_i, k_d, g, hp, z))
        return (kd * (gg + hh) / zz + (kd - ki)) / (td - ti)


def grouped_eq18(theta_i: float, theta_d: float, k_i: float, k_d: float,
                 g: float, hp: float, z: float) -> float:
    delta_theta = theta_d - theta_i
    delta_k = k_d - k_i
    return (k_d * (g + hp) / z + delta_k) / delta_theta


def direct_eq18(theta_i: float, theta_d: float, k_i: float, k_d: float,
                g: float, hp: float, z: float) -> float:
    return (k_d * (g + hp) / z + k_d - k_i) / (theta_d - theta_i)


def normalized_error(value: float, ref: Decimal) -> float:
    with localcontext() as ctx:
        ctx.prec = 80
        err = abs(d(value) - ref)
        scale = max(Decimal(1), abs(ref))
        return float(err / scale)


def absolute_decimal_error(value: float, ref: Decimal) -> Decimal:
    with localcontext() as ctx:
        ctx.prec = 80
        return abs(d(value) - ref)


def bin_pair(nbins: int, fraction: float, row: dict) -> tuple[int, float, float, float, float]:
    j = min(nbins, max(1, int(round(fraction * nbins))))
    tr = float(row["theta_r"])
    ts = float(row["theta_s"])
    delta_theta = (ts - tr) / nbins
    theta_i = tr + (j - 1) * delta_theta
    theta_d = tr + j * delta_theta
    k_i = b2a.mvg_k_of_theta(theta_i, row)
    k_d = b2a.mvg_k_of_theta(theta_d, row)
    return j, theta_i, theta_d, k_i, k_d


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2c_r2_grouped_delta_k_hydrologic_relevance.py OUTPUT.json")
    out = Path(sys.argv[1])
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in fixture["rows"]}

    rows = []
    max_forward = 0.0
    max_front_error = 0.0
    max_water_error = 0.0
    grouped_forward_failures = 0
    front_effect_failures = 0
    water_effect_failures = 0
    nonfinite = 0
    negative_velocity = 0
    direct_forward_failures = 0
    direct_max_forward = 0.0
    worst = None

    for material in MATERIALS:
        row = by[material]
        for nbins in BIN_COUNTS:
            for fraction in BIN_FRACTIONS:
                j, theta_i, theta_d, k_i, k_d = bin_pair(nbins, fraction, row)
                delta_theta = theta_d - theta_i
                for g in G_EFF_CM:
                    for hp in HP_CM:
                        for z in Z_CM:
                            ref = decimal_eq18(theta_i, theta_d, k_i, k_d, g, hp, z)
                            grouped = grouped_eq18(theta_i, theta_d, k_i, k_d, g, hp, z)
                            direct = direct_eq18(theta_i, theta_d, k_i, k_d, g, hp, z)
                            eg = normalized_error(grouped, ref)
                            ed = normalized_error(direct, ref)
                            max_forward = max(max_forward, eg)
                            direct_max_forward = max(direct_max_forward, ed)
                            grouped_forward_failures += int(eg > FORWARD_LIMIT)
                            direct_forward_failures += int(ed > FORWARD_LIMIT)
                            if not (math.isfinite(grouped) and math.isfinite(direct)):
                                nonfinite += 1
                            if ref < 0:
                                negative_velocity += 1

                            abs_velocity_error = absolute_decimal_error(grouped, ref)
                            case_front_max = 0.0
                            case_water_max = 0.0
                            for dt in DT_DAYS:
                                with localcontext() as ctx:
                                    ctx.prec = 80
                                    front_err = float(abs_velocity_error * d(dt))
                                    water_err = float(abs_velocity_error * d(dt) * d(delta_theta))
                                case_front_max = max(case_front_max, front_err)
                                case_water_max = max(case_water_max, water_err)
                                max_front_error = max(max_front_error, front_err)
                                max_water_error = max(max_water_error, water_err)
                                front_effect_failures += int(front_err > FRONT_ERROR_LIMIT_CM)
                                water_effect_failures += int(water_err > WATER_ERROR_LIMIT_CM)

                            record = {
                                "material": material,
                                "theta_bin_count": nbins,
                                "bin_j": j,
                                "bin_fraction_request": fraction,
                                "theta_i": theta_i,
                                "theta_d": theta_d,
                                "delta_theta": delta_theta,
                                "K_i_cm_per_day": k_i,
                                "K_d_cm_per_day": k_d,
                                "delta_K_cm_per_day": k_d - k_i,
                                "G_eff_cm": g,
                                "ponding_head_cm": hp,
                                "front_depth_cm": z,
                                "grouped_velocity_cm_per_day": grouped,
                                "decimal80_velocity": str(ref),
                                "grouped_normalized_forward_error": eg,
                                "direct_normalized_forward_error_diagnostic": ed,
                                "max_front_displacement_error_cm": case_front_max,
                                "max_equivalent_water_depth_error_cm": case_water_max,
                            }
                            rows.append(record)
                            score = max(
                                eg / FORWARD_LIMIT if FORWARD_LIMIT else 0.0,
                                case_front_max / FRONT_ERROR_LIMIT_CM,
                                case_water_max / WATER_ERROR_LIMIT_CM,
                            )
                            if worst is None or score > worst[0]:
                                worst = (score, record)

    passed = (
        grouped_forward_failures == 0
        and front_effect_failures == 0
        and water_effect_failures == 0
        and nonfinite == 0
        and negative_velocity == 0
    )
    result = {
        "schema_version": 1,
        "workstream": "F-FWC",
        "work_unit": "F-FWC01",
        "gate": "B2C_R2_GROUPED_DELTA_K_EQ18_INDEPENDENT_HYDROLOGIC_RELEVANCE_QUALIFICATION",
        "contract": CONTRACT,
        "production_implementation": False,
        "case_count": len(rows),
        "materials": list(MATERIALS),
        "theta_bin_counts": list(BIN_COUNTS),
        "hydrologic_effect_dt_day": list(DT_DAYS),
        "grouped_delta_K": {
            "max_normalized_forward_error": max_forward,
            "cases_exceeding_forward_error_limit": grouped_forward_failures,
            "max_abs_front_displacement_error_cm": max_front_error,
            "front_effect_threshold_exceedance_count": front_effect_failures,
            "max_abs_equivalent_water_depth_error_cm": max_water_error,
            "water_effect_threshold_exceedance_count": water_effect_failures,
            "persistent_extra_state_bytes": 0,
        },
        "direct_association_negative_control": {
            "max_normalized_forward_error": direct_max_forward,
            "cases_exceeding_forward_error_limit": direct_forward_failures,
            "qualification_role": "diagnostic_only_B2C_R1_rejection_preserved"
        },
        "nonfinite_count": nonfinite,
        "negative_velocity_count": negative_velocity,
        "worst_grouped_case": worst[1] if worst else None,
        "rows": rows,
        "pass": passed,
        "decision": (
            "QUALIFIED_GROUPED_DELTA_K_EQ18_NUMERICAL_REPRESENTATION_READY_FOR_RESTRICTED_EXISTING_INFILTRATION_FRONT_ADVANCE_MASS_GATE"
            if passed else
            "GROUPED_DELTA_K_EQ18_REPRESENTATION_NOT_QUALIFIED_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims": [
            "No dry-bin creation or rainfall allocation qualification.",
            "No G_eff closure qualification.",
            "No front collision or merge qualification.",
            "No groundwater interaction qualification.",
            "No long-run hydraulic accuracy qualification."
        ]
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "pass": passed,
        "decision": result["decision"],
        "case_count": len(rows),
        "max_normalized_forward_error": max_forward,
        "max_abs_front_displacement_error_cm": max_front_error,
        "max_abs_equivalent_water_depth_error_cm": max_water_error,
        "direct_association_failure_count_diagnostic": direct_forward_failures,
        "nonfinite_count": nonfinite,
        "negative_velocity_count": negative_velocity,
    }, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
