#!/usr/bin/env python3
import argparse
import json
import math
from pathlib import Path
import struct

MASK64 = (1 << 64) - 1


def parse(path: Path, prefix: str):
    out = {}
    for raw in path.read_text().splitlines():
        if not raw.startswith(prefix):
            continue
        if "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        out[key[len(prefix):]] = value.strip()
    return out


def f64_from_signed_bits(text: str) -> float:
    u = int(text) & MASK64
    return struct.unpack(">d", u.to_bytes(8, "big"))[0]


def signed_bits(value: float) -> int:
    u = int.from_bytes(struct.pack(">d", value), "big")
    return u if u < (1 << 63) else u - (1 << 64)


def require(cond, message):
    if not cond:
        raise AssertionError(message)


def scientific_compare(candidate, oracle):
    keys = ["ACTIVE_NODES", "POND_BITS", "GWL_BITS", "TOP_FLUX_BITS", "BOTTOM_FLUX_BITS",
            "ENDPOINT_STORAGE_BITS", "SOLVER_STATUS", "SOLVER_ROUTE", "NONLINEAR_ITERATIONS",
            "JACOBIAN_BUILDS", "LINEAR_SOLVES", "BACKTRACKING_ATTEMPTS", "INTERNAL_RETRIES",
            "ALT_SOLVER_CALLS"]
    n = int(candidate["ACTIVE_NODES"])
    require(int(oracle["ACTIVE_NODES"]) == n, "active node count differs")
    keys += [f"HEAD_BITS_{i}" for i in range(1, n + 1)]
    keys += [f"THETA_BITS_{i}" for i in range(1, n + 1)]
    keys += [f"QSSDI_BITS_{i}" for i in range(1, n + 1)]
    keys += [f"QROT_BITS_{i}" for i in range(1, n + 1)]
    for level in (1, 2):
        keys += [f"QDRA_BITS_{level}_{i}" for i in range(1, n + 1)]
    comparisons = []
    for key in keys:
        require(key in candidate, f"candidate missing scientific quantity {key}")
        require(key in oracle, f"oracle missing scientific quantity {key}")
        same = candidate[key] == oracle[key]
        comparisons.append({
            "quantity": key,
            "criterion": "EXACT_TEXT_IDENTITY_FOR_INTEGER_OR_ROUTE; BITWISE_IEEE_REAL64_FOR_BITS_FIELDS",
            "candidate": candidate[key],
            "oracle": oracle[key],
            "observed_difference": 0.0 if same else None,
            "tolerance": None,
            "tolerance_provenance": None,
            "pass": same,
        })
        require(same, f"scientific identity mismatch {key}: candidate={candidate[key]} oracle={oracle[key]}")
    return comparisons


def independent_mass(candidate, oracle):
    require(candidate.get("MASS_COMPLETE") == "1", "authoritative mass complete=false")
    require(candidate.get("MISSING_MASK") == "0", "authoritative missing mass mask != 0")
    required = ["STORAGE_START_BITS", "STORAGE_END_BITS", "TOTAL_IN_BITS", "TOTAL_OUT_BITS", "RESIDUAL_BITS"]
    for key in required:
        require(key in candidate, f"candidate missing mass field {key}")
    storage_start = f64_from_signed_bits(candidate["STORAGE_START_BITS"])
    storage_end = f64_from_signed_bits(candidate["STORAGE_END_BITS"])
    total_in = f64_from_signed_bits(candidate["TOTAL_IN_BITS"])
    total_out = f64_from_signed_bits(candidate["TOTAL_OUT_BITS"])
    authoritative = f64_from_signed_bits(candidate["RESIDUAL_BITS"])
    for label, value in [("storage_start", storage_start), ("storage_end", storage_end),
                         ("total_in", total_in), ("total_out", total_out), ("residual", authoritative)]:
        require(math.isfinite(value), f"non-finite mass field {label}")

    require(candidate["STORAGE_START_BITS"] == oracle["INITIAL_STORAGE_BITS"],
            "authoritative initial storage differs from independently constructed reference state")
    require(candidate["STORAGE_END_BITS"] == oracle["ENDPOINT_STORAGE_BITS"],
            "authoritative final storage differs from independent reference endpoint")

    duration = 0.5
    top = f64_from_signed_bits(oracle["TOP_FLUX_BITS"])
    bottom = f64_from_signed_bits(oracle["BOTTOM_FLUX_BITS"])
    n = int(oracle["ACTIVE_NODES"])
    independent_in = max(0.0, -top) * duration + max(0.0, bottom) * duration
    independent_out = max(0.0, top) * duration + max(0.0, -bottom) * duration
    for i in range(1, n + 1):
        amount = f64_from_signed_bits(oracle[f"QSSDI_BITS_{i}"]) * duration
        if amount >= 0.0:
            independent_in += amount
        else:
            independent_out -= amount
    for level in (1, 2):
        for i in range(1, n + 1):
            amount = f64_from_signed_bits(oracle[f"QDRA_BITS_{level}_{i}"]) * duration
            if amount >= 0.0:
                independent_out += amount
            else:
                independent_in -= amount

    require(signed_bits(independent_in) == int(candidate["TOTAL_IN_BITS"]),
            "independently recomputed total_in not bitwise identical")
    require(signed_bits(independent_out) == int(candidate["TOTAL_OUT_BITS"]),
            "independently recomputed total_out not bitwise identical")

    closure = storage_start + independent_in - independent_out - storage_end
    authoritative_form = storage_end - storage_start - (independent_in - independent_out)
    require(closure == 0.0, f"independent closure is nonzero: {closure.hex()}")
    require(authoritative_form == authoritative,
            f"authoritative residual mismatch recomputed={authoritative_form.hex()} kernel={authoritative.hex()}")
    require(authoritative == 0.0, f"authoritative residual nonzero: {authoritative.hex()}")

    return {
        "complete": True,
        "missing_contribution_mask": 0,
        "storage_start": {"value_hex": storage_start.hex(), "bits": int(candidate["STORAGE_START_BITS"])},
        "storage_end": {"value_hex": storage_end.hex(), "bits": int(candidate["STORAGE_END_BITS"])},
        "total_in": {"value_hex": total_in.hex(), "bits": int(candidate["TOTAL_IN_BITS"])},
        "total_out": {"value_hex": total_out.hex(), "bits": int(candidate["TOTAL_OUT_BITS"])},
        "authoritative_residual": {"value_hex": authoritative.hex(), "bits": int(candidate["RESIDUAL_BITS"])},
        "independent_total_in": {"value_hex": independent_in.hex(), "bits": signed_bits(independent_in)},
        "independent_total_out": {"value_hex": independent_out.hex(), "bits": signed_bits(independent_out)},
        "independent_closure_initial_plus_in_minus_out_minus_final": closure.hex(),
        "independent_fkt08_authoritative_form": authoritative_form.hex(),
        "criterion": "EXACT_IEEE_BINARY64_IDENTITY_AND_EXACT_ZERO; NO_NEW_TOLERANCE",
        "pass": True,
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--candidate-o0-a1", type=Path, required=True)
    p.add_argument("--candidate-o0-a2", type=Path, required=True)
    p.add_argument("--candidate-o2", type=Path, required=True)
    p.add_argument("--oracle-o0-a1", type=Path, required=True)
    p.add_argument("--oracle-o0-a2", type=Path, required=True)
    p.add_argument("--oracle-o2", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()

    c0a = parse(a.candidate_o0_a1, "VQ14_CAND_")
    c0b = parse(a.candidate_o0_a2, "VQ14_CAND_")
    c2 = parse(a.candidate_o2, "VQ14_CAND_")
    o0a = parse(a.oracle_o0_a1, "VQ14_ORACLE_")
    o0b = parse(a.oracle_o0_a2, "VQ14_ORACLE_")
    o2 = parse(a.oracle_o2, "VQ14_ORACLE_")

    require(c0a == c0b, "O0 candidate cross-run repeatability mismatch")
    require(o0a == o0b, "O0 oracle cross-run repeatability mismatch")
    comp_o0 = scientific_compare(c0a, o0a)
    comp_o2 = scientific_compare(c2, o2)
    comp_candidate_opt = scientific_compare(c0a, o2)  # oracle O2 is already identical reference route
    require({k: v for k, v in c0a.items() if not k.startswith("MASS_") and k not in {
        "STORAGE_START_BITS", "STORAGE_END_BITS", "TOTAL_IN_BITS", "TOTAL_OUT_BITS", "RESIDUAL_BITS",
        "ACCEPTED_TRANSACTIONS", "MISSING_MASK"}} ==
            {k: v for k, v in c2.items() if not k.startswith("MASS_") and k not in {
        "STORAGE_START_BITS", "STORAGE_END_BITS", "TOTAL_IN_BITS", "TOTAL_OUT_BITS", "RESIDUAL_BITS",
        "ACCEPTED_TRANSACTIONS", "MISSING_MASK"}}, "candidate O0/O2 scientific diagnostics differ")
    mass_o0 = independent_mass(c0a, o0a)
    mass_o2 = independent_mass(c2, o2)
    require({k: c0a[k] for k in ["MASS_COMPLETE", "MISSING_MASK", "STORAGE_START_BITS", "STORAGE_END_BITS",
                                   "TOTAL_IN_BITS", "TOTAL_OUT_BITS", "RESIDUAL_BITS"]} ==
            {k: c2[k] for k in ["MASS_COMPLETE", "MISSING_MASK", "STORAGE_START_BITS", "STORAGE_END_BITS",
                                  "TOTAL_IN_BITS", "TOTAL_OUT_BITS", "RESIDUAL_BITS"]},
            "candidate O0/O2 authoritative mass differs")

    result = {
        "schema_version": 1,
        "criterion": "EXACT_BITWISE_IDENTITY_NO_NEW_SCIENTIFIC_TOLERANCE",
        "o0_candidate_vs_corrected_b110_bound_reference": comp_o0,
        "o2_candidate_vs_corrected_b110_bound_reference": comp_o2,
        "candidate_o0_vs_reference_o2_cross_optimizer_check": comp_candidate_opt,
        "maximum_observed_scientific_difference": 0.0,
        "mass_o0": mass_o0,
        "mass_o2": mass_o2,
        "repeatability": {
            "candidate_o0_a_b_a": "PASS_EXACT",
            "reference_o0_a_b_a": "PASS_EXACT"
        },
        "pass": True
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print("VQ14_EXACT_REFERENCE_COMPARISON PASS")
    print("VQ14_INDEPENDENT_AUTHORITATIVE_MASS PASS")
    print("VQ14_REPEATABILITY PASS")

if __name__ == "__main__":
    main()
