from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FLUX_PATH = ROOT / "docs/publication/evidence/PUB_GC_E4_RAW_FLUX_POINTS.json"
HEAD_PATH = ROOT / "docs/publication/evidence/PUB_GC_E4_RAW_HEAD_SCANS.json"
SOURCE_PATH = ROOT / "src/runtime/mod_modflow6_swap_predictor_response.f90"
CELL_PATH = ROOT / "src/runtime/mod_modflow6_multiswap_cell_response.f90"

BASELINE = "B3"
FRACTIONS = (0.001, 0.003, 0.01)
U_A = 0.0002665743709457589
DT_DAY = 0.001
H_START_M = -0.71499716161412
Q_U_BASELINE = -0.00007573810169146028
PARTIAL_SLOPE = U_A / DT_DAY
REL_E4_MATCH_TOL = 1.0e-6


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def walk(obj):
    if isinstance(obj, list):
        for item in obj:
            yield from walk(item)
    elif isinstance(obj, dict):
        yield obj
        for item in obj.values():
            if isinstance(item, (dict, list)):
                yield from walk(item)


def load_flux_records() -> list[dict]:
    raw = json.loads(FLUX_PATH.read_text(encoding="utf-8"))
    return [
        item for item in walk(raw)
        if item.get("schema") == "pub-gc-e4-flux-point-v2"
        and item.get("baseline_id") == BASELINE
    ]


def load_head_scan() -> dict:
    raw = json.loads(HEAD_PATH.read_text(encoding="utf-8"))
    matches = [
        item for item in walk(raw)
        if item.get("schema") == "pub-gc-e4-head-scan-v1"
        and item.get("baseline_id") == BASELINE
    ]
    require(len(matches) == 1, f"expected one B3 head scan, got {len(matches)}")
    return matches[0]


def q_u_point(record: dict) -> float:
    u_point = float(record["u_A_point"])
    h_end_m = float(record["h_end_m"])
    qbot = float(record["qbot_cm_per_day"])
    return u_point * ((h_end_m - H_START_M) * 100.0) / DT_DAY - qbot


def main() -> None:
    source = SOURCE_PATH.read_text(encoding="utf-8")
    cell = CELL_PATH.read_text(encoding="utf-8")
    require(
        "u = duration_day / dh_bot_end_cm_per_qbot_cm_per_day" in source,
        "production u definition drifted",
    )
    require(
        "q_u_cm_per_day = u * delta_h_bot_cm / duration_day - q_bot_predictor_cm_per_day" in source,
        "production q_u definition drifted",
    )
    require(
        "cell%dq_u_dh_per_s = u_total / duration_s" in cell,
        "production cell slope drifted",
    )

    scan = load_head_scan()
    predictor = scan["predictor"]
    require(math.isclose(float(scan["u_A"]), U_A, rel_tol=0.0, abs_tol=1.0e-18), "B3 u_A drift")
    require(math.isclose(float(scan["window_day"]), DT_DAY, rel_tol=0.0, abs_tol=1.0e-18), "B3 dt drift")
    require(math.isclose(float(predictor["h_start_m"]), H_START_M, rel_tol=0.0, abs_tol=1.0e-15), "B3 h_start drift")
    require(math.isclose(float(predictor["q_u_cm_per_day"]), Q_U_BASELINE, rel_tol=0.0, abs_tol=1.0e-15), "B3 q_u drift")

    reconstructed_baseline = (
        U_A
        * ((float(predictor["h_end_m"]) - H_START_M) * 100.0)
        / DT_DAY
        - float(predictor["q_bot_predictor_cm_per_day"])
    )
    require(
        math.isclose(reconstructed_baseline, Q_U_BASELINE, rel_tol=0.0, abs_tol=1.0e-15),
        "baseline historical q_u reconstruction",
    )

    records = load_flux_records()
    rows: list[dict] = []
    for fraction in FRACTIONS:
        minus = next(
            (
                r for r in records
                if math.isclose(float(r.get("fraction", -1.0)), fraction, rel_tol=0.0, abs_tol=1.0e-15)
                and r.get("side") == "minus"
                and bool(r.get("ready"))
            ),
            None,
        )
        plus = next(
            (
                r for r in records
                if math.isclose(float(r.get("fraction", -1.0)), fraction, rel_tol=0.0, abs_tol=1.0e-15)
                and r.get("side") == "plus"
                and bool(r.get("ready"))
            ),
            None,
        )
        require(minus is not None and plus is not None, f"missing B3 E4 pair at fraction {fraction}")

        h_minus = float(minus["h_end_m"])
        h_plus = float(plus["h_end_m"])
        q_minus = float(minus["qbot_cm_per_day"])
        q_plus = float(plus["qbot_cm_per_day"])
        q_u_minus = q_u_point(minus)
        q_u_plus = q_u_point(plus)

        delta_h_cm = (h_plus - h_minus) * 100.0
        require(delta_h_cm != 0.0, f"zero head signal at fraction {fraction}")

        u_fd = (q_plus - q_minus) * DT_DAY / delta_h_cm
        total_slope = (q_u_plus - q_u_minus) / delta_h_cm
        total_to_partial = total_slope / PARTIAL_SLOPE

        # If u is frozen at the baseline value, the full q_u change along the
        # predictor family is exactly the competition between +u/dt and dqbot/dH.
        frozen_q_u_minus = U_A * ((h_minus - H_START_M) * 100.0) / DT_DAY - q_minus
        frozen_q_u_plus = U_A * ((h_plus - H_START_M) * 100.0) / DT_DAY - q_plus
        frozen_total_slope = (frozen_q_u_plus - frozen_q_u_minus) / delta_h_cm
        analytic_frozen_slope = (U_A - u_fd) / DT_DAY
        require(
            math.isclose(
                frozen_total_slope,
                analytic_frozen_slope,
                rel_tol=0.0,
                abs_tol=5.0e-12,
            ),
            f"frozen-u cancellation identity at fraction {fraction}",
        )

        e4_relative_match = abs(U_A - u_fd) / max(abs(U_A), abs(u_fd))
        require(
            e4_relative_match <= REL_E4_MATCH_TOL,
            f"selected fraction left already-qualified E4 predictor plateau: {fraction}",
        )

        row = {
            "fraction": fraction,
            "u_fd": u_fd,
            "e4_relative_u_match": e4_relative_match,
            "production_partial_slope_per_day": PARTIAL_SLOPE,
            "frozen_total_slope_per_day": frozen_total_slope,
            "frozen_to_partial_ratio": frozen_total_slope / PARTIAL_SLOPE,
            "pointwise_total_slope_per_day": total_slope,
            "pointwise_total_to_partial_ratio": total_to_partial,
            "q_u_minus_cm_per_day": q_u_minus,
            "q_u_plus_cm_per_day": q_u_plus,
        }
        rows.append(row)
        print("GC_MAP07_ROW=" + json.dumps(row, sort_keys=True, separators=(",", ":")))

    max_frozen_ratio = max(abs(float(r["frozen_to_partial_ratio"])) for r in rows)
    max_pointwise_ratio = max(abs(float(r["pointwise_total_to_partial_ratio"])) for r in rows)
    print(f"GC_MAP07_PRODUCTION_PARTIAL_SLOPE_PER_DAY={PARTIAL_SLOPE:.17g}")
    print(f"GC_MAP07_MAX_ABS_FROZEN_TOTAL_TO_PARTIAL_RATIO={max_frozen_ratio:.17g}")
    print(f"GC_MAP07_MAX_ABS_POINTWISE_TOTAL_TO_PARTIAL_RATIO={max_pointwise_ratio:.17g}")
    print("GC_MAP07_PRODUCTION_FORMULA_AUTHORITY=PASS")
    print("GC_MAP07_HISTORICAL_QU_RECONSTRUCTION=PASS")
    print("GC_MAP07_PREDICTOR_FAMILY_CANCELLATION_IDENTITY=PASS")
    print("GC_MAP07_E4_PLATEAU_AUTHORITY_PRESERVED=PASS")
    print("GC_MAP07_DIAGNOSTIC_GATE=PASS")


if __name__ == "__main__":
    main()
