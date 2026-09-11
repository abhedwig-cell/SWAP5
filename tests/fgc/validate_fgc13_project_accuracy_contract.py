#!/usr/bin/env python3
import argparse
import json
import math
import sys
from pathlib import Path

SCHEMA_ID = "SWAP5_PROJECT_ACCURACY_CONTRACT_EVIDENCE_V1"
QOI_MAP = {"GROUNDWATER_HEAD": 1, "GROUNDWATER_DRAWDOWN": 2}
GOVERNANCE_STATUSES = {
    "REGULATOR_APPROVED",
    "CONTRACTUALLY_APPROVED",
    "PROJECT_GOVERNANCE_APPROVED",
    "FORMALLY_ADOPTED",
}
APPLICATION_SEMANTICS = {
    "MAX_ABSOLUTE_PREDICTION_ERROR",
    "OTHER_EXPLICIT_NUMERICAL_PREDICTION_ERROR_LIMIT",
}
ATTESTATIONS = {
    "not_physical_impact_threshold_only",
    "not_calibration_metric_only",
    "not_model_generated_uncertainty_only",
    "not_monitoring_trigger_only",
    "not_swap_numerical_behavior",
    "not_model_timestep_schedule",
}


class PacketError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


def reject(code, message):
    raise PacketError(code, message)


def require_object(value, path):
    if not isinstance(value, dict):
        reject("TYPE_ERROR", f"{path} must be an object")
    return value


def require_exact_keys(obj, required, path):
    obj = require_object(obj, path)
    keys = set(obj)
    required = set(required)
    missing = sorted(required - keys)
    extra = sorted(keys - required)
    if missing:
        reject("MISSING_FIELD", f"{path} missing {missing}")
    if extra:
        reject("UNKNOWN_FIELD", f"{path} contains unknown fields {extra}")


def require_string(value, path):
    if not isinstance(value, str) or not value.strip():
        reject("INVALID_STRING", f"{path} must be a non-empty string")
    return value


def require_true(value, code, path):
    if value is not True:
        reject(code, f"{path} must be true")


def require_positive_int(value, path):
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        reject("INVALID_POSITIVE_INTEGER", f"{path} must be a positive integer")
    return value


def require_positive_finite(value, code, path):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        reject(code, f"{path} must be numeric")
    numeric = float(value)
    if not math.isfinite(numeric) or numeric <= 0.0:
        reject(code, f"{path} must be positive and finite")
    return numeric


def require_sha256_digest(value, path):
    digest = require_string(value, path)
    if len(digest) != 64 or any(ch not in "0123456789abcdef" for ch in digest):
        reject("INVALID_SOURCE_DIGEST", f"{path} must be 64 lowercase hexadecimal characters")
    return digest


def validate_provenance(value, expected_claim_type, expected_basis_kind, path):
    keys = {
        "provenance_id",
        "claim_id",
        "issuer",
        "document_title",
        "document_version",
        "clause",
        "locator",
        "governance_status",
        "claim_type",
        "evidence_basis_kind",
        "source_digest_sha256",
        "external_to_swap_numerical_behavior",
    }
    require_exact_keys(value, keys, path)
    provenance_id = require_positive_int(value["provenance_id"], f"{path}.provenance_id")
    claim_id = require_string(value["claim_id"], f"{path}.claim_id")
    for key in ("issuer", "document_title", "document_version", "clause", "locator"):
        require_string(value[key], f"{path}.{key}")
    if value["governance_status"] not in GOVERNANCE_STATUSES:
        reject("UNAPPROVED_GOVERNANCE_STATUS", f"{path}.governance_status is not an admitted external status")
    if value["claim_type"] != expected_claim_type:
        reject("CLAIM_TYPE_MISMATCH", f"{path}.claim_type must be {expected_claim_type}")
    if value["evidence_basis_kind"] != expected_basis_kind:
        reject(
            "EVIDENCE_BASIS_FORBIDDEN_OR_MISMATCH",
            f"{path}.evidence_basis_kind must be {expected_basis_kind}",
        )
    require_sha256_digest(value["source_digest_sha256"], f"{path}.source_digest_sha256")
    require_true(
        value["external_to_swap_numerical_behavior"],
        "SWAP_DERIVED_POLICY_FORBIDDEN",
        f"{path}.external_to_swap_numerical_behavior",
    )
    return provenance_id, claim_id


def validate_packet(packet):
    top_keys = {
        "schema_id",
        "packet_id",
        "packet_version",
        "project",
        "application_requirement",
        "temporal_policy",
        "forbidden_substitution_attestations",
        "canonical_mapping",
    }
    require_exact_keys(packet, top_keys, "packet")
    if packet["schema_id"] != SCHEMA_ID:
        reject("SCHEMA_ID_MISMATCH", "packet.schema_id is not the F-GC13 v1 schema")
    require_string(packet["packet_id"], "packet.packet_id")
    require_positive_int(packet["packet_version"], "packet.packet_version")

    project_keys = {
        "project_id",
        "name",
        "jurisdiction",
        "decision_context",
        "qoi_kind",
        "spatial_scope",
        "time_horizon",
    }
    project = packet["project"]
    require_exact_keys(project, project_keys, "packet.project")
    for key in ("project_id", "name", "jurisdiction", "decision_context", "spatial_scope", "time_horizon"):
        require_string(project[key], f"packet.project.{key}")
    if project["qoi_kind"] not in QOI_MAP:
        reject("UNSUPPORTED_QOI", "qoi_kind must be GROUNDWATER_HEAD or GROUNDWATER_DRAWDOWN")

    app_keys = {"available", "externally_qualified", "value_cm", "requirement_semantics", "provenance"}
    app = packet["application_requirement"]
    require_exact_keys(app, app_keys, "packet.application_requirement")
    require_true(app["available"], "H_APP_NOT_AVAILABLE", "packet.application_requirement.available")
    require_true(
        app["externally_qualified"],
        "H_APP_NOT_EXTERNALLY_QUALIFIED",
        "packet.application_requirement.externally_qualified",
    )
    h_app_cm = require_positive_finite(app["value_cm"], "INVALID_H_APP", "packet.application_requirement.value_cm")
    if app["requirement_semantics"] not in APPLICATION_SEMANTICS:
        reject("INVALID_H_APP_SEMANTICS", "application requirement is not an explicit numerical prediction-error limit")
    if app["provenance"] is None:
        reject("MISSING_APPLICATION_PROVENANCE", "application provenance is required")
    app_provenance_id, app_claim_id = validate_provenance(
        app["provenance"],
        "APPLICATION_PREDICTION_ACCURACY_REQUIREMENT",
        "EXPLICIT_NUMERICAL_PREDICTION_ERROR_ACCEPTANCE_RULE",
        "packet.application_requirement.provenance",
    )

    temporal_keys = {
        "available",
        "externally_qualified",
        "mode",
        "allocation_fraction",
        "direct_budget_cm",
        "provenance",
    }
    temporal = packet["temporal_policy"]
    require_exact_keys(temporal, temporal_keys, "packet.temporal_policy")
    require_true(temporal["available"], "TEMPORAL_POLICY_NOT_AVAILABLE", "packet.temporal_policy.available")
    require_true(
        temporal["externally_qualified"],
        "TEMPORAL_POLICY_NOT_EXTERNALLY_QUALIFIED",
        "packet.temporal_policy.externally_qualified",
    )
    if temporal["provenance"] is None:
        reject("MISSING_TEMPORAL_PROVENANCE", "temporal provenance is required")

    mode = temporal["mode"]
    if mode == "FRACTION_OF_APPLICATION_REQUIREMENT":
        a_temporal = require_positive_finite(
            temporal["allocation_fraction"],
            "INVALID_TEMPORAL_FRACTION",
            "packet.temporal_policy.allocation_fraction",
        )
        if a_temporal > 1.0:
            reject("INVALID_TEMPORAL_FRACTION", "allocation_fraction must be <= 1")
        if temporal["direct_budget_cm"] is not None:
            reject("AMBIGUOUS_TEMPORAL_POLICY", "fraction mode must not also carry a direct budget")
        expected_claim_type = "TEMPORAL_ERROR_ALLOCATION_FRACTION"
        expected_basis_kind = "EXPLICIT_TEMPORAL_ALLOCATION_RULE"
        temporal_budget_cm = h_app_cm * a_temporal
    elif mode == "DIRECT_HEAD_ERROR_BUDGET_CM":
        if temporal["allocation_fraction"] is not None:
            reject("AMBIGUOUS_TEMPORAL_POLICY", "direct-budget mode must not also carry an allocation fraction")
        direct_budget_cm = require_positive_finite(
            temporal["direct_budget_cm"],
            "INVALID_DIRECT_TEMPORAL_BUDGET",
            "packet.temporal_policy.direct_budget_cm",
        )
        if direct_budget_cm > h_app_cm:
            reject("DIRECT_TEMPORAL_BUDGET_EXCEEDS_H_APP", "direct temporal budget may not exceed H_app")
        a_temporal = direct_budget_cm / h_app_cm
        temporal_budget_cm = direct_budget_cm
        expected_claim_type = "DIRECT_TEMPORAL_HEAD_ERROR_BUDGET"
        expected_basis_kind = "EXPLICIT_DIRECT_TEMPORAL_ERROR_BUDGET_RULE"
    else:
        reject("UNSUPPORTED_TEMPORAL_POLICY_MODE", "unsupported temporal policy mode")

    if not math.isfinite(a_temporal) or a_temporal <= 0.0 or a_temporal > 1.0:
        reject("INVALID_CANONICAL_TEMPORAL_FRACTION", "derived canonical A_temporal is outside (0,1]")
    if not math.isfinite(temporal_budget_cm) or temporal_budget_cm <= 0.0:
        reject("INVALID_TEMPORAL_BUDGET", "derived temporal budget is not positive and finite")

    temporal_provenance_id, temporal_claim_id = validate_provenance(
        temporal["provenance"],
        expected_claim_type,
        expected_basis_kind,
        "packet.temporal_policy.provenance",
    )
    if app_claim_id == temporal_claim_id:
        reject("CLAIM_ID_REUSE_FORBIDDEN", "application and temporal governance require distinct claim identities")
    if app_provenance_id == temporal_provenance_id:
        reject("PROVENANCE_ID_REUSE_FORBIDDEN", "application and temporal governance require distinct provenance ids")

    attestations = packet["forbidden_substitution_attestations"]
    require_exact_keys(attestations, ATTESTATIONS, "packet.forbidden_substitution_attestations")
    for key in sorted(ATTESTATIONS):
        require_true(attestations[key], "FORBIDDEN_SUBSTITUTION_NOT_EXCLUDED", f"packet.forbidden_substitution_attestations.{key}")

    mapping_keys = {
        "contract_id",
        "contract_version",
        "application_provenance_id",
        "temporal_allocation_provenance_id",
    }
    mapping = packet["canonical_mapping"]
    require_exact_keys(mapping, mapping_keys, "packet.canonical_mapping")
    contract_id = require_positive_int(mapping["contract_id"], "packet.canonical_mapping.contract_id")
    contract_version = require_positive_int(mapping["contract_version"], "packet.canonical_mapping.contract_version")
    application_mapping_id = require_positive_int(
        mapping["application_provenance_id"], "packet.canonical_mapping.application_provenance_id"
    )
    temporal_mapping_id = require_positive_int(
        mapping["temporal_allocation_provenance_id"], "packet.canonical_mapping.temporal_allocation_provenance_id"
    )
    if application_mapping_id != app_provenance_id:
        reject("APPLICATION_PROVENANCE_MAPPING_MISMATCH", "canonical application provenance id does not match evidence")
    if temporal_mapping_id != temporal_provenance_id:
        reject("TEMPORAL_PROVENANCE_MAPPING_MISMATCH", "canonical temporal provenance id does not match evidence")

    return {
        "contract_id": contract_id,
        "contract_version": contract_version,
        "qoi_kind": project["qoi_kind"],
        "qoi_kind_value": QOI_MAP[project["qoi_kind"]],
        "h_app_available": True,
        "h_app_cm": h_app_cm,
        "h_app_externally_qualified": True,
        "application_provenance_id": app_provenance_id,
        "a_temporal_available": True,
        "a_temporal": a_temporal,
        "a_temporal_externally_qualified": True,
        "temporal_allocation_provenance_id": temporal_provenance_id,
        "model_temporal_indicator_budget_cm": temporal_budget_cm,
        "source_policy_mode": mode,
    }


def load_json(path):
    with Path(path).open(encoding="utf-8") as handle:
        return json.load(handle)


def apply_mutation(packet, dotted_path, value):
    target = packet
    parts = dotted_path.split(".")
    for part in parts[:-1]:
        target = target[part]
    target[parts[-1]] = value


def run_rejection_matrix(matrix_path, fixtures_dir):
    matrix = load_json(matrix_path)
    failures = 0
    for case in matrix["cases"]:
        packet = load_json(Path(fixtures_dir) / case["base_fixture"])
        for mutation in case["mutations"]:
            apply_mutation(packet, mutation["path"], mutation["value"])
        try:
            validate_packet(packet)
        except PacketError as exc:
            if exc.code != case["expected_code"]:
                print(
                    f"FGC13_REJECTION_CASE_FAIL={case['id']} expected={case['expected_code']} actual={exc.code}",
                    file=sys.stderr,
                )
                failures += 1
            else:
                print(f"FGC13_REJECTION_CASE_PASS={case['id']}:{exc.code}")
        else:
            print(f"FGC13_REJECTION_CASE_FAIL={case['id']} unexpectedly accepted", file=sys.stderr)
            failures += 1
    if failures:
        raise SystemExit(1)
    print(f"FGC13_REJECTION_MATRIX=PASS:{len(matrix['cases'])}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("packet", nargs="?")
    parser.add_argument("--rejection-matrix")
    parser.add_argument("--fixtures-dir")
    args = parser.parse_args()

    if args.rejection_matrix:
        if not args.fixtures_dir:
            parser.error("--fixtures-dir is required with --rejection-matrix")
        run_rejection_matrix(args.rejection_matrix, args.fixtures_dir)
        return
    if not args.packet:
        parser.error("packet is required")

    try:
        mapping = validate_packet(load_json(args.packet))
    except PacketError as exc:
        print(f"FGC13_PACKET_DECISION=REJECT:{exc.code}", file=sys.stderr)
        print(exc.message, file=sys.stderr)
        raise SystemExit(2)

    print("FGC13_PACKET_DECISION=ACCEPT")
    print(json.dumps(mapping, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
