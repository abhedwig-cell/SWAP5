#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

MATERIALS = ("B01", "B14")
HISTORIES = ("V01", "V02", "V03", "V04")
MEMBERS = ("U4", "U8", "R8", "R16")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--input-dir", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    assert pre["state"] == "PREREGISTERED_BEFORE_STAGE2_REDUCED_RESPONSE"

    cases = {}
    all_pass = True
    max_ledger = 0.0
    max_root_generic_corrector_delta = 0
    for material in MATERIALS:
        for history in HISTORIES:
            path = args.input_dir / f"{material}_{history}.json"
            raw = json.loads(path.read_text())
            assert raw["material"] == material and raw["history"] == history
            assert raw["scientific_firewall"]["feddes_evaluated"] is False
            assert raw["scientific_firewall"]["dynamic_root_feedback_implemented"] is False
            for member in MEMBERS:
                row = raw["cases"][member]
                key = f"{material}_{history}_{member}"
                cases[key] = row
                all_pass = all_pass and bool(row["pass"])
                for route in row["routes"].values():
                    max_ledger = max(max_ledger, float(route["max_abs_water_ledger_cm"]))
                max_root_generic_corrector_delta = max(
                    max_root_generic_corrector_delta,
                    abs(
                        int(row["routes"]["PRESCRIBED_ROOT"]["max_corrector_iterations"])
                        - int(row["routes"]["GENERIC_SINK"]["max_corrector_iterations"])
                    ),
                )

    expected = len(MATERIALS) * len(HISTORIES) * len(MEMBERS)
    if len(cases) != expected:
        raise SystemExit(f"Stage2 case count mismatch: {len(cases)} != {expected}")

    required_checks = (
        "fractions_nonnegative",
        "fraction_sum_within_arithmetic_guard",
        "sink_rate_within_arithmetic_guard",
        "cumulative_root_within_arithmetic_guard",
        "root_generic_bit_identity",
        "zero_sink_legacy_bit_identity",
        "root_ledger_pass",
        "generic_ledger_pass",
        "zero_root_ledger_pass",
        "legacy_ledger_pass",
    )
    check_failures = []
    for key, row in cases.items():
        for check in required_checks:
            if not row["checks"].get(check, False):
                check_failures.append({"case": key, "check": check})

    all_pass = all_pass and not check_failures and max_ledger <= float(
        pre["integrity_and_pass_rules"]["inherited_reduced_water_ledger_gate_cm"]
    )
    status = (
        "STAGE2_PRESCRIBED_SINK_HARNESS_EQUIVALENCE_QUALIFIED"
        if all_pass
        else "STAGE2_PRESCRIBED_SINK_HARNESS_EQUIVALENCE_NOT_QUALIFIED"
    )
    decision = (
        "STAGE3_DYNAMIC_FEEDBACK_MAY_BE_PREREGISTERED"
        if all_pass
        else "STOP_BEFORE_DYNAMIC_FEEDBACK"
    )

    out = {
        "schema": "swap5.rom_root.s2.result.v1",
        "workstream": "ROM-ROOT",
        "work_unit": "ROM-ROOT-S2",
        "status": status,
        "decision": decision,
        "case_count": len(cases),
        "all_32_cases_pass": all_pass,
        "maximum_abs_water_ledger_cm": max_ledger,
        "max_root_generic_corrector_iteration_difference": max_root_generic_corrector_delta,
        "check_failures": check_failures,
        "cases": cases,
        "interpretation": [
            "Stage 2 tests prescribed-sink aggregation and reduced hydraulic harness semantics only.",
            "Root and generic sink routes use the identical response-independent layer sink vector and must be bit-identical.",
            "The zero-sink control verifies that adding root-sink plumbing does not alter the pre-existing reduced hydraulic trajectory.",
            "No Feddes stress feedback is evaluated in Stage 2 and no hydrological fidelity claim follows from this result.",
        ],
        "scientific_firewall": {
            "reference_changed": False,
            "feddes_evaluated": False,
            "dynamic_root_feedback_implemented": False,
            "reduced_feedback_response_generated": False,
            "new_root_specific_state_selected": False,
            "new_partition_selected": False,
            "new_hydraulic_closure_selected": False,
            "application_acceptance_adjudicated": False,
            "performance_comparison_authorized": False,
            "production_rom_authorized": False,
        },
        "model_changed": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "status": status,
        "decision": decision,
        "case_count": len(cases),
        "maximum_abs_water_ledger_cm": max_ledger,
        "check_failures": check_failures,
    }, sort_keys=True))
    return 0 if all_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
