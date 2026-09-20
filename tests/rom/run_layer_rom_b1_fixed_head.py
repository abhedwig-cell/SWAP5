#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import pathlib
import sys
from typing import Any


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_module(name: str, path: pathlib.Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def metric_vector(row: dict[str, Any]) -> dict[str, float | int]:
    return {
        "total_storage_rmse_cm": float(row["total_storage_error_cm"]["rmse"]),
        "cumulative_bottom_rmse_cm": float(row["cumulative_bottom_exchange_error_cm"]["rmse"]),
        "terminal_bottom_flux_rmse_cm_per_day": float(row["terminal_bottom_flux_error_cm_per_day"]["rmse"]),
        "bottom_flux_sign_error_count": int(row["bottom_flux_sign_error_count"]),
        "mapped_R16_cell_theta_rmse": float(row["mapped_R16_cell_theta_error"]["rmse"]),
    }


def vector_close(a: dict[str, Any], b: dict[str, Any], tol: float) -> bool:
    for key in (
        "total_storage_error_cm",
        "cumulative_bottom_exchange_error_cm",
        "terminal_bottom_flux_error_cm_per_day",
        "mapped_R16_cell_theta_error",
    ):
        if abs(float(a[key]["rmse"]) - float(b[key]["rmse"])) > tol:
            return False
    return int(a["bottom_flux_sign_error_count"]) == int(b["bottom_flux_sign_error_count"])


def min_dimension(rows: list[dict[str, Any]], key: str) -> int | None:
    dims = [int(row["dimension"]) for row in rows if row["status"] == "QUALIFIED" and bool(row[key])]
    return min(dims) if dims else None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-dir", required=True, type=pathlib.Path)
    ap.add_argument("--r16", required=True, type=pathlib.Path)
    ap.add_argument("--r2", required=True, type=pathlib.Path)
    ap.add_argument("--c4r-result", required=True, type=pathlib.Path)
    ap.add_argument("--fmc-result", required=True, type=pathlib.Path)
    ap.add_argument("--fmc-reproduction", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    if pre["phase"] != "PREREGISTERED_BEFORE_LAYER_LADDER_FIXED_HEAD_REPLAY":
        raise SystemExit("wrong B1 preregistration phase")

    expected = pre["blind_reference_reuse"]
    checks = {
        "R16": (sha256(args.r16), expected["R16_sha256"]),
        "R2": (sha256(args.r2), expected["R2_sha256"]),
        "C4R_RESULT": (sha256(args.c4r_result), expected["C4R_result_sha256"]),
    }
    drift = {k: {"got": got, "expected": exp} for k, (got, exp) in checks.items() if got != exp}
    if drift:
        raise SystemExit(f"immutable C4R evidence drift: {drift}")

    c4r = load_module("layer_b1_c4r_source", args.source_dir / "analyze_lare_bc2_c4r_blind.py")
    persisted = json.loads(args.c4r_result.read_text())
    fmc_raw = json.loads(args.fmc_result.read_text())
    fmc_repro = json.loads(args.fmc_reproduction.read_text())
    if persisted["decision"] != "C4R_BLIND_PROFILE_FRONTIER_REPLICATED":
        raise SystemExit("unexpected C4R decision")
    if not persisted["blind_validation"] or not persisted["integrity"]["pass"]:
        raise SystemExit("C4R blind/integrity authority missing")
    if not fmc_repro["pass"] or not fmc_raw["integrity"]["pass"]:
        raise SystemExit("FMC comparator reproduction/integrity missing")

    r16 = c4r.parse_d13(args.r16)
    r2 = c4r.parse_d13(args.r2)
    if r16["n"] != 16 or r2["n"] != 2:
        raise SystemExit("C4R geometry mismatch")

    # Reconstruct the frozen R2 comparator independently from raw immutable traces.
    r2cmp = c4r.r2_metrics(r2, r16)
    persisted_r2 = persisted["comparators"]["R2"]["pooled"]
    if not vector_close(r2cmp["pooled"], persisted_r2, 1.0e-12):
        raise SystemExit("B1 failed to reproduce persisted C4R R2 vector")

    # Bind the FMC vector through the raw result and the persisted C4R synthesis.
    fmc = {
        "total_storage_error_cm": fmc_raw["FMC"]["pooled"]["total_storage_error_cm"],
        "cumulative_bottom_exchange_error_cm": fmc_raw["FMC"]["pooled"]["cumulative_bottom_exchange_error_cm"],
        "terminal_bottom_flux_error_cm_per_day": fmc_raw["FMC"]["pooled"]["terminal_bottom_flux_error_cm_per_day"],
        "mapped_R16_cell_theta_error": fmc_raw["FMC"]["pooled"]["R16_cell_theta_error"],
        "bottom_flux_sign_error_count": fmc_raw["FMC"]["pooled"]["bottom_flux_sign_error_count"],
    }
    persisted_fmc = persisted["comparators"]["FMC_GW200"]["pooled"]
    if not vector_close(fmc, persisted_fmc, 1.0e-12):
        raise SystemExit("B1 failed to reproduce persisted C4R FMC vector")

    tol = float(pre["relative_frontiers"]["numerical_equality_tolerance"])
    attempted: list[dict[str, Any]] = []
    persisted_by_id = {row["id"]: row for row in persisted["lare_members"]}

    for spec in pre["layer_ladder"]:
        member = {
            "id": spec["id"].replace("L", "R", 1),
            "dimension": int(spec["dimension"]),
            "boundaries_cm": [float(v) for v in spec["boundaries_cm"]],
        }
        # Keep B1 labels L2/L3/L4/L6 while using the inherited C4R runner semantics.
        raw = c4r.run_member(member, r16)
        raw["id"] = spec["id"]
        raw["role"] = spec["role"]
        raw["crosses_R2_GW"] = (
            raw["status"] == "QUALIFIED"
            and c4r.crosses_gw(raw, r2cmp["pooled"], tol)
        )
        raw["crosses_FMC_GW"] = (
            raw["status"] == "QUALIFIED"
            and c4r.crosses_gw(raw, fmc, tol)
        )
        raw["crosses_R2_PROFILE"] = (
            raw["status"] == "QUALIFIED"
            and c4r.crosses_profile(raw, r2cmp["pooled"], tol)
        )
        raw["crosses_FMC_PROFILE"] = (
            raw["status"] == "QUALIFIED"
            and c4r.crosses_profile(raw, fmc, tol)
        )

        source_id = member["id"]
        if source_id in persisted_by_id:
            source = persisted_by_id[source_id]
            reproduced = (
                raw["status"] == source["status"]
                and (
                    raw["status"] != "QUALIFIED"
                    or vector_close(raw["pooled"], source["pooled"], 1.0e-12)
                )
            )
            raw["C4R_member_reproduction_pass"] = reproduced
            if not reproduced:
                raise SystemExit(f"B1 failed C4R member reproduction for {source_id}")
        else:
            raw["C4R_member_reproduction_pass"] = None
        attempted.append(raw)

    if len(attempted) != 4:
        raise SystemExit("B1 did not attempt all four frozen members")

    qualified = [row for row in attempted if row["status"] == "QUALIFIED"]
    max_ledger = max([float(row["max_abs_water_ledger_cm"]) for row in qualified] or [0.0])
    hard_integrity = (
        max_ledger <= float(pre["integrity_gates"]["maximum_water_ledger_cm"])
        and all(row["status"] in {"QUALIFIED", "OUTSIDE_QUALIFIED_DOMAIN", "NUMERICAL_BLOCKED"} for row in attempted)
        and all(row.get("C4R_member_reproduction_pass") is not False for row in attempted)
    )

    minima = {
        "R2_GW": min_dimension(attempted, "crosses_R2_GW"),
        "FMC_GW": min_dimension(attempted, "crosses_FMC_GW"),
        "R2_PROFILE": min_dimension(attempted, "crosses_R2_PROFILE"),
        "FMC_PROFILE": min_dimension(attempted, "crosses_FMC_PROFILE"),
    }

    if not hard_integrity:
        decision = "B1_EXECUTION_OR_AUTHORITY_BLOCKED"
    elif minima["R2_GW"] == 4 and minima["FMC_GW"] == 4:
        decision = "B1_DIMENSION4_GW_FRONTIER_REPLICATED"
    elif (
        (minima["R2_GW"] is not None and minima["R2_GW"] < 4)
        or (minima["FMC_GW"] is not None and minima["FMC_GW"] < 4)
    ):
        decision = "B1_LOWER_DIMENSION_GW_FRONTIER"
    else:
        decision = "B1_HIGHER_DIMENSION_REQUIRED_FOR_GW_FRONTIER"

    decomposition = {}
    for row in attempted:
        d = int(row["dimension"])
        if row["status"] != "QUALIFIED":
            decomposition[row["id"]] = {"status": row["status"]}
            continue
        co = persisted_by_id.get(f"R{d}")
        if co is None:
            decomposition[row["id"]] = {
                "status": "NO_SAME_PARTITION_CORICHARDS_IN_PERSISTED_C4R_FOR_THIS_PARTITION"
            }
            continue
        # C4R's same-partition CoRichards is available for R3/R4/R6.
        cor_name = f"COR_R{d}"
        decomposition[row["id"]] = {
            "same_partition_CoRichards_reference": cor_name,
            "note": "Numerical discretization vector is bound in C4T; B1 does not rerun CoRichards.",
        }

    out = {
        "schema": "swap5.layer-rom.phase-b1.result.v1",
        "workstream": "F-ROM-LAYER",
        "work_unit": "LAYER-ROM-B1",
        "decision": decision,
        "authority": {
            "preregistration": str(args.prereg),
            "C4R_workflow_run": expected["workflow_run"],
            "C4R_artifact_id": expected["artifact_id"],
            "C4R_artifact_digest": expected["artifact_digest"],
            "selective_source": {
                "C4R_analyzer_blob": "7b2a35a8cf134011247a625ad6e327c4f500baa2",
                "BC1_runner_blob": "33a68fc51d5c1905b9f377e2d14626aeebe27f98",
                "role": "EXACT_RESEARCH_SOURCE_REUSE_NO_WHOLESALE_BRANCH_MERGE",
            },
        },
        "integrity": {
            "pass": hard_integrity,
            "all_four_members_attempted": len(attempted) == 4,
            "qualified_member_count": len(qualified),
            "maximum_water_ledger_cm": max_ledger,
            "R2_raw_reproduction_pass": True,
            "FMC_raw_reproduction_pass": True,
            "C4R_existing_member_reproduction_pass": all(
                row.get("C4R_member_reproduction_pass") is not False for row in attempted
            ),
        },
        "comparators": {
            "R2": metric_vector(r2cmp["pooled"]),
            "FMC_GW200": metric_vector(fmc),
        },
        "members": attempted,
        "frontiers": {
            "minimum_dimension": minima,
            "crossing_members": {
                key: [row["id"] for row in attempted if row["status"] == "QUALIFIED" and row[key]]
                for key in (
                    "crosses_R2_GW",
                    "crosses_FMC_GW",
                    "crosses_R2_PROFILE",
                    "crosses_FMC_PROFILE",
                )
            },
        },
        "error_decomposition_note": decomposition,
        "interpretation": [
            "B1 replays one frozen active-lower-zone ladder on one blind fixed-zero-head workload; only L2 is new relative to the inherited C4R LARE ladder.",
            "A comparator-relative frontier is a componentwise relative statement, not an application-acceptance threshold.",
            "A1 state-information sufficiency and B1 propagated closure fidelity remain distinct: L3 may separate bounded Reference futures while failing the fixed-head response frontier.",
            "PROFILE and GW frontiers remain separate; no scalar score combines them.",
            "No performance measurement, moving-water-table semantics or production coupling is introduced.",
        ],
        "application_acceptance_adjudicated": False,
        "performance_measurement_performed": False,
        "speed_claim_authorized": False,
        "moving_water_table_authorized": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": decision,
        "integrity": out["integrity"],
        "frontiers": out["frontiers"],
        "members": {
            row["id"]: {
                "status": row["status"],
                "pooled": None if row["pooled"] is None else metric_vector(row["pooled"]),
                "crosses_R2_GW": row["crosses_R2_GW"],
                "crosses_FMC_GW": row["crosses_FMC_GW"],
                "crosses_R2_PROFILE": row["crosses_R2_PROFILE"],
                "crosses_FMC_PROFILE": row["crosses_FMC_PROFILE"],
            }
            for row in attempted
        },
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
