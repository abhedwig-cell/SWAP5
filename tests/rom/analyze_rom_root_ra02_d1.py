#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import struct
from pathlib import Path

EPS = 2.220446049250313e-16
OBS_DT = 0.0008

ROUTES = {
    "R512_T32": {"nodes": 512, "rooted_nodes": 256, "output_factor": 32},
    "R1024_T32": {"nodes": 1024, "rooted_nodes": 512, "output_factor": 32},
    "R2048_T32": {"nodes": 2048, "rooted_nodes": 1024, "output_factor": 32},
    "R2048_T16": {"nodes": 2048, "rooted_nodes": 1024, "output_factor": 16},
    "R2048_T8": {"nodes": 2048, "rooted_nodes": 1024, "output_factor": 8},
}
SPACE_PAIRS = [("R512_T32", "R1024_T32"), ("R1024_T32", "R2048_T32")]
TIME_PAIRS = [("R2048_T8", "R2048_T16"), ("R2048_T16", "R2048_T32")]
CASES = ("V01", "V02", "V03", "V04")
PTRA = {"V01": 0.60, "V02": 0.30, "V03": 0.60, "V04": 0.30}
MATERIAL = {
    "B01": {"theta_r": 0.02, "theta_s": 0.427494, "alpha": 0.021659, "n": 1.734737},
    "B14": {"theta_r": 0.01, "theta_s": 0.416774, "alpha": 0.00541, "n": 1.301528},
}


def parse_marker(line: str, prefix: str) -> dict[str, str] | None:
    if not line.startswith(prefix + "|"):
        return None
    out: dict[str, str] = {}
    for item in line.rstrip("\n").split("|")[1:]:
        if "=" not in item:
            continue
        k, v = item.split("=", 1)
        out[k] = v
    return out


def f64_bits(x: float) -> int:
    return struct.unpack(">Q", struct.pack(">d", x))[0]


def ulp_distance(a: float, b: float) -> int:
    if math.isnan(a) or math.isnan(b):
        raise ValueError("NaN")
    if a < 0.0 or b < 0.0:
        # Root-response fields are non-negative by contract.
        raise ValueError("ULP helper expects non-negative values")
    return abs(f64_bits(a) - f64_bits(b))


def gamma(k: int) -> float:
    x = k * EPS
    if x >= 1.0:
        raise ValueError("gamma undefined")
    return x / (1.0 - x)


def h_from_se(material: str, se: float) -> float:
    p = MATERIAL[material]
    n = p["n"]
    m = 1.0 - 1.0 / n
    return -((se ** (-1.0 / m) - 1.0) ** (1.0 / n)) / p["alpha"]


def se_from_h(material: str, h: float) -> float:
    p = MATERIAL[material]
    n = p["n"]
    m = 1.0 - 1.0 / n
    return (1.0 + (p["alpha"] * abs(h)) ** n) ** (-m)


def critical_se(material: str, ptra: float) -> float:
    h3l = h_from_se(material, 0.35)
    h3h = h_from_se(material, 0.55)
    if ptra < 0.10:
        h3 = h3l
    elif ptra <= 0.50:
        h3 = h3h + ((0.50 - ptra) / (0.50 - 0.10)) * (h3l - h3h)
    else:
        h3 = h3h
    return se_from_h(material, h3)


def theta_to_se(material: str, theta: float) -> float:
    p = MATERIAL[material]
    return (theta - p["theta_r"]) / (p["theta_s"] - p["theta_r"])


def parse_route(path: Path) -> dict:
    roots: dict[tuple[str, int], dict[str, float]] = {}
    profiles: dict[tuple[str, int, int], float] = {}
    for line in path.read_text(errors="replace").splitlines():
        m = parse_marker(line, "LAREDYN0R_ROOT")
        if m is not None:
            case = m["CASE"]
            obs = int(m["OBS_STEP"])
            roots[(case, obs)] = {
                "ACTUAL_RATE": float(m["ACTUAL_RATE"]),
                "ACTUAL_FRACTION": float(m["ACTUAL_FRACTION"]),
                "RAW_CUMULATIVE_ROOT": float(m["CUMULATIVE_ROOT"]),
                "PTRA": float(m["PTRA"]),
            }
            continue
        m = parse_marker(line, "LAREDYN0R_PROFILE")
        if m is not None:
            profiles[(m["CASE"], int(m["OBS_STEP"]), int(m["BIN"]))] = float(m["THETA"])
    expected_root = len(CASES) * 1024
    expected_profile = len(CASES) * 1024 * 16
    if len(roots) != expected_root:
        raise SystemExit(f"{path}: root records {len(roots)} != {expected_root}")
    if len(profiles) != expected_profile:
        raise SystemExit(f"{path}: profile records {len(profiles)} != {expected_profile}")
    for case in CASES:
        running = 0.0
        for obs in range(1, 1025):
            if (case, obs) not in roots:
                raise SystemExit(f"{path}: missing root {case} {obs}")
            running += roots[(case, obs)]["ACTUAL_RATE"] * OBS_DT
            # Match the frozen RA01 uncertainty authority. The raw marker is
            # segment-local on reconstructed R2048_T32 logs and is retained
            # above only as provenance, not as route-global cumulative state.
            roots[(case, obs)]["CUMULATIVE_ROOT"] = running
            for b in range(1, 17):
                if (case, obs, b) not in profiles:
                    raise SystemExit(f"{path}: missing profile {case} {obs} {b}")
    return {"roots": roots, "profiles": profiles}


def pair_summary(material: str, a_name: str, b_name: str, a: dict, b: dict) -> dict:
    field_stats = {}
    for field in ("ACTUAL_RATE", "ACTUAL_FRACTION", "CUMULATIVE_ROOT"):
        diffs = []
        ulps = []
        exact = 0
        for case in CASES:
            for obs in range(1, 1025):
                av = a["roots"][(case, obs)][field]
                bv = b["roots"][(case, obs)][field]
                d = av - bv
                diffs.append(d)
                if f64_bits(av) == f64_bits(bv):
                    exact += 1
                ulps.append(ulp_distance(av, bv))
        field_stats[field] = {
            "records": len(diffs),
            "exact_bit_equal": exact,
            "nonexact": len(diffs) - exact,
            "rmse": math.sqrt(math.fsum(d*d for d in diffs) / len(diffs)),
            "max_abs": max(abs(d) for d in diffs),
            "max_ulp": max(ulps),
        }

    round_exceeds = 0
    max_round_ratio = 0.0
    full_potential_status_disagreements = 0
    root_examples = []
    for case in CASES:
        bound = (
            gamma(ROUTES[a_name]["rooted_nodes"])
            + gamma(ROUTES[a_name]["output_factor"])
            + gamma(ROUTES[b_name]["rooted_nodes"])
            + gamma(ROUTES[b_name]["output_factor"])
        ) * PTRA[case]
        for obs in range(1, 1025):
            ar = a["roots"][(case, obs)]["ACTUAL_RATE"]
            br = b["roots"][(case, obs)]["ACTUAL_RATE"]
            delta = abs(ar - br)
            ratio = delta / bound if bound > 0 else math.inf
            max_round_ratio = max(max_round_ratio, ratio)
            if delta > bound:
                round_exceeds += 1
                if len(root_examples) < 12:
                    root_examples.append({"case": case, "obs": obs, "delta": delta, "reference_bound": bound})
            af = a["roots"][(case, obs)]["ACTUAL_FRACTION"]
            bf = b["roots"][(case, obs)]["ACTUAL_FRACTION"]
            if (af == 1.0) != (bf == 1.0):
                full_potential_status_disagreements += 1

    threshold_straddles = []
    rooted_bins = range(1, 9)
    for case in CASES:
        thresholds = {"h4": 0.08, "h3": critical_se(material, PTRA[case])}
        for obs in range(1, 1025):
            for bin_id in rooted_bins:
                ase = theta_to_se(material, a["profiles"][(case, obs, bin_id)])
                bse = theta_to_se(material, b["profiles"][(case, obs, bin_id)])
                for label, threshold in thresholds.items():
                    da = ase - threshold
                    db = bse - threshold
                    if da == 0.0 or db == 0.0 or da * db < 0.0:
                        if len(threshold_straddles) < 40:
                            threshold_straddles.append({
                                "case": case,
                                "obs": obs,
                                "bin": bin_id,
                                "threshold": label,
                                "threshold_Se": threshold,
                                "left_Se_proxy": ase,
                                "right_Se_proxy": bse,
                            })

    return {
        "left": a_name,
        "right": b_name,
        "fields": field_stats,
        "actual_rate_roundoff_reference_exceed_count": round_exceeds,
        "actual_rate_max_fraction_of_roundoff_reference": max_round_ratio,
        "roundoff_reference_exceed_examples": root_examples,
        "exact_full_potential_status_disagreements": full_potential_status_disagreements,
        "bin_mean_threshold_straddle_count_lower_bound": len(threshold_straddles),
        "bin_mean_threshold_straddle_examples": threshold_straddles,
        "note": "Threshold count is exact only when <=40; examples are capped at 40. Workflow classification uses an uncapped recomputation.",
    }


def exact_threshold_count(material: str, a_name: str, b_name: str, a: dict, b: dict) -> int:
    count = 0
    for case in CASES:
        thresholds = (0.08, critical_se(material, PTRA[case]))
        for obs in range(1, 1025):
            for bin_id in range(1, 9):
                ase = theta_to_se(material, a["profiles"][(case, obs, bin_id)])
                bse = theta_to_se(material, b["profiles"][(case, obs, bin_id)])
                for threshold in thresholds:
                    da = ase - threshold
                    db = bse - threshold
                    if da == 0.0 or db == 0.0 or da * db < 0.0:
                        count += 1
    return count


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence-dir", required=True, type=Path)
    ap.add_argument("--prereg", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()

    prereg = json.loads(args.prereg.read_text())
    if prereg["state"] != "PREREGISTERED_BEFORE_RA02_D1_ANALYSIS":
        raise SystemExit("unexpected preregistration state")

    data = {}
    for material in ("B01", "B14"):
        data[material] = {}
        for route in ROUTES:
            path = args.evidence_dir / f"{material}_{route}_o0.txt"
            if not path.is_file():
                raise SystemExit(f"missing RA01 route file {path}")
            data[material][route] = parse_route(path)

    materials = {}
    any_threshold = False
    any_round_exceed = False
    for material in ("B01", "B14"):
        summaries = []
        for pair_class, pairs in (("space", SPACE_PAIRS), ("time", TIME_PAIRS)):
            for a_name, b_name in pairs:
                s = pair_summary(material, a_name, b_name, data[material][a_name], data[material][b_name])
                s["pair_class"] = pair_class
                exact_count = exact_threshold_count(material, a_name, b_name, data[material][a_name], data[material][b_name])
                s["bin_mean_threshold_straddle_count"] = exact_count
                any_threshold = any_threshold or exact_count > 0
                any_round_exceed = any_round_exceed or s["actual_rate_roundoff_reference_exceed_count"] > 0
                summaries.append(s)

        response_ranges = {}
        for case in CASES:
            vals = []
            for route in ROUTES:
                for obs in range(1, 1025):
                    vals.append(data[material][route]["roots"][(case, obs)]["ACTUAL_FRACTION"])
            response_ranges[case] = {
                "min_actual_fraction": min(vals),
                "max_actual_fraction": max(vals),
                "critical_h3_Se": critical_se(material, PTRA[case]),
                "h4_Se": 0.08,
            }

        materials[material] = {
            "comparisons": summaries,
            "response_ranges": response_ranges,
        }

    supports_floor = (not any_threshold) and (not any_round_exceed)
    result = {
        "schema": "swap5.rom_root.ra02_d1.result.v1",
        "workstream": "ROM-ROOT",
        "work_unit": "ROM-ROOT-RA02-D1",
        "status": "DIAGNOSTIC_COMPLETE_NO_REFERENCE_POLICY_DECISION",
        "authority": {
            "ra01_workflow_run": 35819870854,
            "ra01_evidence_artifact_id": 10733930641,
            "preregistration": str(args.prereg),
        },
        "materials": materials,
        "classifications": {
            "AVAILABLE_OUTPUT_SUPPORTS_NUMERICAL_FLOOR": supports_floor,
            "THRESHOLD_EFFECT_PLAUSIBLE_AT_BIN_SCALE": any_threshold,
            "ROOT_RATE_EXCEEDS_AGGREGATION_ROUNDOFF_REFERENCE": any_round_exceed,
            "NODE_LEVEL_ADJUDICATION_UNAVAILABLE": True,
            "REFERENCE_AUTHORITY_CHANGE": False,
        },
        "bounded_interpretation": (
            "The persisted RA01 outputs can diagnose aggregate response and 10-cm bin-mean threshold proximity, "
            "but cannot prove node-level Feddes-regime identity because node-level pressure heads and reduction factors were not persisted."
        ),
        "scientific_firewall": {
            "new_simulation_executed": False,
            "reference_qualified": False,
            "stage2_authorized": False,
            "stage3_authorized": False,
            "reduced_candidate_response_generated": False,
            "uncertainty_gate_changed": False,
            "production_change_authorized": False,
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": result["status"], "classifications": result["classifications"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
