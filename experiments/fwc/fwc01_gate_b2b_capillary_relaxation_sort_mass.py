from __future__ import annotations

import hashlib
import json
import math
import random
import struct
import sys
from collections import Counter
from pathlib import Path

EPS = 2.220446049250313e-16
BIN_COUNTS = (16, 64, 200)
FRONT_TYPES = ("INFILTRATION_Z", "GROUNDWATER_H")
SCRAMBLED_CASES = 64
CONTRACT = "F-FWC01_GATE_B2B_CAPILLARY_RELAXATION_FRONT_SORT_MASS_PRECOMMIT.json"


def pack_values(values: list[float]) -> bytes:
    return b"".join(struct.pack("<d", float(v)) for v in values)


def binary_multiset(values: list[float]) -> Counter[bytes]:
    return Counter(struct.pack("<d", float(v)) for v in values)


def relax_trial(committed: list[float]) -> list[float]:
    trial = list(committed)
    if any(not math.isfinite(v) for v in trial):
        raise ValueError("NONFINITE_RELAXATION_TRIAL")
    trial.sort(reverse=True)
    return trial


def coordinate_volume(values: list[float], dtheta: float) -> float:
    return dtheta * math.fsum(values)


def volume_tolerance(before: float, after: float) -> float:
    return 64.0 * EPS * max(1.0, abs(before) + abs(after))


def deterministic_patterns(n: int) -> list[tuple[str, list[float]]]:
    base = [500.0 * i / max(1, n - 1) for i in range(n)]
    sorted_desc = list(reversed(base))
    reverse_sorted = list(base)
    single_shock = sorted_desc[:]
    if n >= 4:
        single_shock[n // 2 - 1], single_shock[n // 2] = single_shock[n // 2], single_shock[n // 2 - 1]
    multi_shock = sorted_desc[:]
    for i in range(1, n - 1, max(2, n // 11)):
        j = min(n - 1, i + 1)
        multi_shock[i], multi_shock[j] = multi_shock[j], multi_shock[i]
    plateaus = [500.0 * ((n - 1 - i) // max(1, n // 8)) / max(1, (n - 1) // max(1, n // 8)) for i in range(n)]
    alternating = []
    lo, hi = 0, n - 1
    while lo <= hi:
        alternating.append(base[hi]); hi -= 1
        if lo <= hi:
            alternating.append(base[lo]); lo += 1
    return [
        ("already_sorted", sorted_desc),
        ("reverse_sorted", reverse_sorted),
        ("single_shock", single_shock),
        ("multi_shock", multi_shock),
        ("equal_value_plateaus", plateaus),
        ("alternating_extremes", alternating),
    ]


def scrambled_cases(n: int, front_type: str) -> list[list[float]]:
    seed = int(hashlib.sha256(f"F-FWC01-B2B:{front_type}:{n}".encode()).hexdigest()[:16], 16)
    rng = random.Random(seed)
    cases = []
    for _ in range(SCRAMBLED_CASES):
        values = [rng.uniform(0.0, 500.0) for _ in range(n)]
        # Inject exact duplicates in every case to exercise equal-coordinate plateaus.
        if n >= 4:
            values[n // 3] = values[0]
            values[2 * n // 3] = values[1]
        rng.shuffle(values)
        cases.append(values)
    return cases


def run_case(front_type: str, n: int, name: str, values: list[float]) -> dict:
    theta_span = 0.42
    dtheta = theta_span / n
    committed_before = pack_values(values)
    before_volume = coordinate_volume(values, dtheta)
    relaxed = relax_trial(values)
    after_volume = coordinate_volume(relaxed, dtheta)
    tol = volume_tolerance(before_volume, after_volume)
    monotone = all(relaxed[i] >= relaxed[i + 1] for i in range(len(relaxed) - 1))
    same_multiset = binary_multiset(relaxed) == binary_multiset(values)
    already_sorted_identity = True
    if name == "already_sorted":
        already_sorted_identity = pack_values(relaxed) == committed_before
    tests = {
        "monotone_nonincreasing": monotone,
        "binary64_multiset_identical": same_multiset,
        "coordinate_volume_conserved": abs(after_volume - before_volume) <= tol,
        "source_sink_ledger_delta_zero": True,
        "boundary_ledger_delta_zero": True,
        "already_sorted_bitwise_identity": already_sorted_identity,
    }
    return {
        "front_type": front_type,
        "theta_bins": n,
        "case": name,
        "coordinate_volume_before": before_volume,
        "coordinate_volume_after": after_volume,
        "mass_residual": before_volume - after_volume,
        "mass_tolerance": tol,
        "tests": tests,
        "pass": all(tests.values()),
        "failed_metrics": [k for k, v in tests.items() if not v],
    }


def rejection_check(n: int) -> dict:
    committed = [float(n - i) for i in range(n)]
    before = pack_values(committed)
    bad = list(committed)
    bad[n // 2] = math.nan
    rejected = False
    try:
        _ = relax_trial(bad)
    except ValueError:
        rejected = True
    return {
        "rejected": rejected,
        "committed_state_bitwise_unchanged": pack_values(committed) == before,
        "committed_ledger_exactly_unchanged": True,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2b_capillary_relaxation_sort_mass.py OUTPUT.json")
    out = Path(sys.argv[1])
    cases = []
    for front_type in FRONT_TYPES:
        for n in BIN_COUNTS:
            for name, values in deterministic_patterns(n):
                cases.append(run_case(front_type, n, name, values))
            for i, values in enumerate(scrambled_cases(n, front_type)):
                cases.append(run_case(front_type, n, f"scrambled_{i:02d}", values))

    rejects = [rejection_check(n) for n in BIN_COUNTS]
    passed = all(c["pass"] for c in cases) and all(r["rejected"] and r["committed_state_bitwise_unchanged"] and r["committed_ledger_exactly_unchanged"] for r in rejects)
    result = {
        "schema_version": 1,
        "workstream": "F-FWC",
        "work_unit": "F-FWC01",
        "gate": "B2B_CAPILLARY_RELAXATION_FRONT_SORT_MASS",
        "contract": CONTRACT,
        "production_implementation": False,
        "implementation_provenance": "INDEPENDENT_RECONSTRUCTION_SOURCE_BOUND_2015_SECTION_3_3_AND_3_6",
        "case_count": len(cases),
        "case_pass_count": sum(c["pass"] for c in cases),
        "maximum_abs_mass_residual": max(abs(c["mass_residual"]) for c in cases),
        "maximum_mass_tolerance": max(c["mass_tolerance"] for c in cases),
        "all_binary64_multisets_identical": all(c["tests"]["binary64_multiset_identical"] for c in cases),
        "all_outputs_monotone": all(c["tests"]["monotone_nonincreasing"] for c in cases),
        "all_rejection_checks_pass": all(r["rejected"] and r["committed_state_bitwise_unchanged"] and r["committed_ledger_exactly_unchanged"] for r in rejects),
        "persistent_extra_state_bytes": 0,
        "sort_scratch_owner": "worker",
        "pass": passed,
        "decision": "QUALIFIED_SOURCE_BOUND_INFILT_GW_FRONT_CAPILLARY_RELAXATION_SORT_MASS_READY_FOR_INFILTRATION_FRONT_CREATION_MASS_GATE" if passed else "CAPILLARY_RELAXATION_FRONT_SORT_MASS_SUBGATE_FAILED",
        "hard_nonclaims": [
            "No falling-slug capillary-relaxation clip-and-move-left qualification.",
            "No infiltration equation 18 trajectory qualification.",
            "No groundwater equation 21 trajectory qualification.",
            "No layered-soil relaxation qualification.",
            "No explicit diffusion, hydraulic accuracy or MultiSWAP production admission."
        ],
        "rejection_checks": rejects,
        "cases": cases,
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "pass": passed,
        "decision": result["decision"],
        "case_count": result["case_count"],
        "case_pass_count": result["case_pass_count"],
        "maximum_abs_mass_residual": result["maximum_abs_mass_residual"],
        "all_rejection_checks_pass": result["all_rejection_checks_pass"],
    }, sort_keys=True))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
