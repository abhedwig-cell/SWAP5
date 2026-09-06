from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any, Mapping, Sequence

SCHEMA_VERSION = "mp-workload-catalog-v1"
ALLOWED_STATUS = {
    "shadow-executable",
    "parameter-locked",
    "runtime-blocked",
    "policy-blocked",
    "template-blocked",
    "ready",
}
B12_ROW = "B12,0.01,0.529749,0.016562,1.090671,2.245895,179.6716,-4.493581,0"
B12_ROW_SHA256 = "8f6b214ba7894dd49be927c9384a80168f0ad05fabeb48b2f8d1330ef916e59e"
B12_PARAMETERS = {
    "ORES": 0.01,
    "OSAT": 0.529749,
    "ALFA": 0.016562,
    "NPAR": 1.090671,
    "KSATFIT": 2.245895,
    "KSATEXM": 179.6716,
    "LEXP": -4.493581,
    "H_ENPR": 0.0,
}


def _valid_reference_level(reference: object) -> bool:
    if reference in {"B0", "SWAP5-reference"}:
        return True
    return isinstance(reference, str) and re.fullmatch(r"B1\.\d+(?:p\d+)?", reference) is not None


def load_catalog(path: str | Path) -> dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def validate_catalog(catalog: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    if catalog.get("schema_version") != SCHEMA_VERSION:
        errors.append("unexpected schema_version")

    policy = catalog.get("reference_policy", {})
    if policy.get("immutable_legacy") != "B0":
        errors.append("reference_policy.immutable_legacy must be B0")
    corrected = policy.get("corrected_legacy")
    if not _valid_reference_level(corrected) or not str(corrected).startswith("B1."):
        errors.append("reference_policy.corrected_legacy must be an exact B1 snapshot")
    oracle_status = policy.get("corrected_legacy_oracle_status")
    if not isinstance(oracle_status, str) or not oracle_status:
        errors.append("reference_policy.corrected_legacy_oracle_status must be non-empty")
    if policy.get("swap5_reference") != "SWAP5-reference":
        errors.append("reference_policy.swap5_reference must be SWAP5-reference")

    workloads = catalog.get("workloads")
    if not isinstance(workloads, list) or not workloads:
        return errors + ["workloads must be a non-empty list"]

    ids: set[str] = set()
    families: set[str] = set()
    for index, workload in enumerate(workloads):
        where = f"workloads[{index}]"
        if not isinstance(workload, Mapping):
            errors.append(f"{where} must be an object")
            continue

        workload_id = workload.get("id")
        family = workload.get("family")
        status = workload.get("status")

        if not isinstance(workload_id, str) or not workload_id:
            errors.append(f"{where}.id must be non-empty")
        elif workload_id in ids:
            errors.append(f"duplicate workload id: {workload_id}")
        else:
            ids.add(workload_id)

        if not isinstance(family, str) or not family.startswith("MP-B"):
            errors.append(f"{where}.family must start with MP-B")
        else:
            families.add(family)

        if status not in ALLOWED_STATUS:
            errors.append(f"{where}.status is invalid: {status!r}")

        references = workload.get("reference_levels")
        if not isinstance(references, list) or not references:
            errors.append(f"{where}.reference_levels must be non-empty")
        else:
            unknown = sorted(
                reference
                for reference in references
                if not _valid_reference_level(reference)
            )
            if unknown:
                errors.append(
                    f"{where}.reference_levels contains unknown values: {unknown}"
                )

        measurements = workload.get("required_measurements")
        if not isinstance(measurements, list) or not measurements:
            errors.append(f"{where}.required_measurements must be non-empty")

    expected_families = {f"MP-B0{number}" for number in range(1, 7)}
    for required in sorted(expected_families - families):
        errors.append(f"missing benchmark family: {required}")

    b12 = next(
        (
            workload
            for workload in workloads
            if isinstance(workload, Mapping)
            and workload.get("id") == "MP-B04-B12-HYDRAULIC-STRESS"
        ),
        None,
    )
    if b12 is None:
        errors.append("missing MP-B04-B12-HYDRAULIC-STRESS")
    else:
        profile = b12.get("stress_profile", {})
        row = profile.get("source_row")
        if row != B12_ROW:
            errors.append("B12 source_row does not match locked Staringreeks 2018 row")
        if hashlib.sha256(str(row).encode("ascii")).hexdigest() != B12_ROW_SHA256:
            errors.append("B12 source_row SHA-256 mismatch")
        if profile.get("source_row_sha256_no_eol") != B12_ROW_SHA256:
            errors.append("B12 recorded source_row_sha256_no_eol mismatch")
        if profile.get("parameters") != B12_PARAMETERS:
            errors.append("B12 parameter map does not match locked source row")
        if b12.get("status") == "ready":
            errors.append("B12 workload cannot be ready without a complete executable fixture")

    return errors


def readiness_summary(catalog: Mapping[str, Any]) -> dict[str, Any]:
    workloads = catalog.get("workloads", [])
    status_counts: dict[str, int] = {}
    for workload in workloads:
        status = str(workload.get("status", "<missing>"))
        status_counts[status] = status_counts.get(status, 0) + 1
    return {
        "workload_count": len(workloads),
        "status_counts": dict(sorted(status_counts.items())),
        "ready_ids": [
            workload["id"]
            for workload in workloads
            if workload.get("status") in {"ready", "shadow-executable"}
        ],
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate SWAP5 MultiSWAP performance workload catalog"
    )
    parser.add_argument("catalog", type=Path)
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args(argv)

    catalog = load_catalog(args.catalog)
    errors = validate_catalog(catalog)
    if errors:
        print(json.dumps({"valid": False, "errors": errors}, indent=2))
        return 1

    payload: dict[str, Any] = {"valid": True}
    if args.summary:
        payload["summary"] = readiness_summary(catalog)
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
