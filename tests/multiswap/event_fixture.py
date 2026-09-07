from __future__ import annotations

from copy import deepcopy
from hashlib import sha256
import json
import math
from pathlib import Path
import re
from typing import Any, Mapping

SCHEMA_VERSION = "mq-event-fixture-v1"
EXTRACTION_MODE = "reference_run_checkpoint"
ALLOWED_MASS_PRECISION = {"unrounded_internal", "synthetic_exact"}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")

TOP_LEVEL_KEYS = {
    "schema_version",
    "fixture_id",
    "source",
    "event",
    "parameters",
    "committed_state",
    "forcing",
    "numerical_config",
    "expected",
    "integrity",
}
SOURCE_KEYS = {
    "kind",
    "repository",
    "commit",
    "reference_family",
    "reference_snapshot",
    "case_id",
    "run_id",
    "extractor_id",
    "extraction_mode",
    "source_artifacts",
}
EVENT_KEYS = {"kind", "checkpoint_t", "t0", "t1", "time_basis", "metadata"}
PARAMETER_KEYS = {"mode", "id", "sha256", "payload"}
PAYLOAD_KEYS = {"payload", "sha256"}
EXPECTED_KEYS = {"endpoint_state", "observables", "diagnostics", "mass_accounting"}
ENDPOINT_KEYS = {"payload", "sha256", "tolerance"}
TOLERANCE_KEYS = {"abs", "rel", "overrides"}
OBSERVABLE_KEYS = {"value", "abs_tol", "rel_tol"}
MASS_KEYS = {
    "precision",
    "hard_tolerance",
    "comparison_abs_tolerance",
    "storage_start",
    "storage_end",
    "boundary_terms",
    "reported_residual",
}
BOUNDARY_KEYS = {"term_id", "interface_id", "signed_amount", "classification"}

FORBIDDEN_STATE_KEYS = {
    "worker_scratch",
    "worker_context",
    "jacobian",
    "jacobian_matrix",
    "newton_vector",
    "residual_workspace",
    "linear_solver_workspace",
    "constitutive_cache",
    "temporary_solver_state",
}


class FixtureContractError(ValueError):
    pass


def _canonical_bytes(value: Any) -> bytes:
    try:
        text = json.dumps(
            value,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        )
    except (TypeError, ValueError) as exc:
        raise FixtureContractError(f"value is not canonical-JSON serializable: {exc}") from exc
    return text.encode("utf-8")


def canonical_sha256(value: Any) -> str:
    return sha256(_canonical_bytes(value)).hexdigest()


def _require_exact_keys(mapping: Mapping[str, Any], expected: set[str], label: str) -> None:
    actual = set(mapping)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise FixtureContractError(f"{label} keys mismatch missing={missing} extra={extra}")


def _require_nonempty_text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise FixtureContractError(f"{label} must be non-empty text")
    return value


def _require_sha(value: Any, label: str) -> str:
    if not isinstance(value, str) or SHA256_RE.fullmatch(value) is None:
        raise FixtureContractError(f"{label} must be a lowercase SHA-256 hex digest")
    return value


def _require_finite_number(value: Any, label: str, *, nonnegative: bool = False) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise FixtureContractError(f"{label} must be numeric")
    result = float(value)
    if not math.isfinite(result):
        raise FixtureContractError(f"{label} must be finite")
    if nonnegative and result < 0.0:
        raise FixtureContractError(f"{label} must be nonnegative")
    return result


def _seal_payload(payload: Any) -> dict[str, Any]:
    return {"payload": deepcopy(payload), "sha256": canonical_sha256(payload)}


def _validate_payload_block(block: Mapping[str, Any], label: str) -> None:
    _require_exact_keys(block, PAYLOAD_KEYS, label)
    expected = canonical_sha256(block["payload"])
    observed = _require_sha(block["sha256"], f"{label}.sha256")
    if observed != expected:
        raise FixtureContractError(f"{label}.sha256 does not match canonical payload")


def _validate_parameter_block(block: Mapping[str, Any]) -> None:
    _require_exact_keys(block, PARAMETER_KEYS, "parameters")
    mode = block["mode"]
    if mode not in {"reference", "inline"}:
        raise FixtureContractError("parameters.mode must be reference or inline")
    _require_nonempty_text(block["id"], "parameters.id")
    _require_sha(block["sha256"], "parameters.sha256")
    if mode == "reference":
        if block["payload"] is not None:
            raise FixtureContractError("reference parameters must not duplicate immutable payload")
    else:
        if block["payload"] is None:
            raise FixtureContractError("inline parameters require payload")
        if canonical_sha256(block["payload"]) != block["sha256"]:
            raise FixtureContractError("inline parameters.sha256 does not match payload")


def _find_forbidden_state_key(value: Any, path: str = "committed_state.payload") -> str | None:
    if isinstance(value, Mapping):
        for key, child in value.items():
            key_text = str(key).lower()
            if key_text in FORBIDDEN_STATE_KEYS:
                return f"{path}.{key}"
            found = _find_forbidden_state_key(child, f"{path}.{key}")
            if found:
                return found
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found = _find_forbidden_state_key(child, f"{path}[{index}]")
            if found:
                return found
    return None


def _validate_source(source: Mapping[str, Any]) -> None:
    _require_exact_keys(source, SOURCE_KEYS, "source")
    if source["kind"] != "reference_run":
        raise FixtureContractError("source.kind must be reference_run")
    for key in (
        "repository",
        "reference_family",
        "reference_snapshot",
        "case_id",
        "run_id",
        "extractor_id",
    ):
        _require_nonempty_text(source[key], f"source.{key}")
    commit = source["commit"]
    if not isinstance(commit, str) or COMMIT_RE.fullmatch(commit) is None:
        raise FixtureContractError("source.commit must be an exact 40-character lowercase commit SHA")
    if source["extraction_mode"] != EXTRACTION_MODE:
        raise FixtureContractError(f"source.extraction_mode must be {EXTRACTION_MODE}")
    artifacts = source["source_artifacts"]
    if not isinstance(artifacts, Mapping) or not artifacts:
        raise FixtureContractError("source.source_artifacts must contain at least one pinned artifact hash")
    for name, digest in artifacts.items():
        _require_nonempty_text(name, "source.source_artifacts key")
        _require_sha(digest, f"source.source_artifacts.{name}")


def _validate_event(event: Mapping[str, Any]) -> None:
    _require_exact_keys(event, EVENT_KEYS, "event")
    _require_nonempty_text(event["kind"], "event.kind")
    _require_nonempty_text(event["time_basis"], "event.time_basis")
    if event["checkpoint_t"] != event["t0"]:
        raise FixtureContractError("event.checkpoint_t must equal event.t0")
    if isinstance(event["t0"], (int, float)) and isinstance(event["t1"], (int, float)):
        if isinstance(event["t0"], bool) or isinstance(event["t1"], bool):
            raise FixtureContractError("event times may not be boolean")
        if float(event["t1"]) <= float(event["t0"]):
            raise FixtureContractError("event.t1 must be greater than event.t0")
    elif not isinstance(event["t0"], str) or not isinstance(event["t1"], str):
        raise FixtureContractError("event t0/t1 must both be numeric or both be strings")
    if not isinstance(event["metadata"], Mapping):
        raise FixtureContractError("event.metadata must be an object")


def mass_residual(mass: Mapping[str, Any]) -> float:
    storage_start = _require_finite_number(mass["storage_start"], "mass.storage_start")
    storage_end = _require_finite_number(mass["storage_end"], "mass.storage_end")
    external_total = 0.0
    for term in mass["boundary_terms"]:
        if term["classification"] == "external":
            external_total += _require_finite_number(term["signed_amount"], "boundary.signed_amount")
    return storage_end - storage_start - external_total


def _validate_mass_accounting(mass: Mapping[str, Any], label: str = "mass_accounting") -> float:
    _require_exact_keys(mass, MASS_KEYS, label)
    if mass["precision"] not in ALLOWED_MASS_PRECISION:
        raise FixtureContractError(
            f"{label}.precision must be one of {sorted(ALLOWED_MASS_PRECISION)}; rounded legacy reports are not a hard oracle"
        )
    hard_tolerance = _require_finite_number(
        mass["hard_tolerance"], f"{label}.hard_tolerance", nonnegative=True
    )
    _require_finite_number(
        mass["comparison_abs_tolerance"],
        f"{label}.comparison_abs_tolerance",
        nonnegative=True,
    )
    terms = mass["boundary_terms"]
    if not isinstance(terms, list):
        raise FixtureContractError(f"{label}.boundary_terms must be an array")
    seen: set[tuple[str, str]] = set()
    for index, term in enumerate(terms):
        if not isinstance(term, Mapping):
            raise FixtureContractError(f"{label}.boundary_terms[{index}] must be an object")
        _require_exact_keys(term, BOUNDARY_KEYS, f"{label}.boundary_terms[{index}]")
        term_id = _require_nonempty_text(term["term_id"], f"{label}.boundary_terms[{index}].term_id")
        interface_id = _require_nonempty_text(
            term["interface_id"], f"{label}.boundary_terms[{index}].interface_id"
        )
        if (term_id, interface_id) in seen:
            raise FixtureContractError(f"duplicate mass boundary term {(term_id, interface_id)}")
        seen.add((term_id, interface_id))
        _require_finite_number(term["signed_amount"], f"{label}.boundary_terms[{index}].signed_amount")
        if term["classification"] not in {"external", "internal_diagnostic"}:
            raise FixtureContractError(
                f"{label}.boundary_terms[{index}].classification invalid"
            )
    residual = mass_residual(mass)
    reported = mass["reported_residual"]
    if reported is not None:
        reported_value = _require_finite_number(reported, f"{label}.reported_residual")
        if abs(reported_value - residual) > max(hard_tolerance, 1.0e-15):
            raise FixtureContractError(f"{label}.reported_residual disagrees with normalized accounting")
    if abs(residual) > hard_tolerance:
        raise FixtureContractError(
            f"{label} violates hard mass gate residual={residual:.17g} tolerance={hard_tolerance:.17g}"
        )
    return residual


def _validate_endpoint(endpoint: Mapping[str, Any]) -> None:
    _require_exact_keys(endpoint, ENDPOINT_KEYS, "expected.endpoint_state")
    digest = _require_sha(endpoint["sha256"], "expected.endpoint_state.sha256")
    if digest != canonical_sha256(endpoint["payload"]):
        raise FixtureContractError("expected.endpoint_state.sha256 does not match payload")
    tolerance = endpoint["tolerance"]
    if not isinstance(tolerance, Mapping):
        raise FixtureContractError("expected.endpoint_state.tolerance must be an object")
    _require_exact_keys(tolerance, TOLERANCE_KEYS, "expected.endpoint_state.tolerance")
    _require_finite_number(tolerance["abs"], "endpoint tolerance abs", nonnegative=True)
    _require_finite_number(tolerance["rel"], "endpoint tolerance rel", nonnegative=True)
    overrides = tolerance["overrides"]
    if not isinstance(overrides, Mapping):
        raise FixtureContractError("endpoint tolerance overrides must be an object")
    for path, spec in overrides.items():
        _require_nonempty_text(path, "endpoint tolerance override path")
        if not isinstance(spec, Mapping):
            raise FixtureContractError(f"endpoint tolerance override {path} must be an object")
        _require_exact_keys(spec, {"abs", "rel"}, f"endpoint tolerance override {path}")
        _require_finite_number(spec["abs"], f"endpoint override {path}.abs", nonnegative=True)
        _require_finite_number(spec["rel"], f"endpoint override {path}.rel", nonnegative=True)


def _validate_observables(observables: Mapping[str, Any]) -> None:
    for name, spec in observables.items():
        _require_nonempty_text(name, "observable name")
        if not isinstance(spec, Mapping):
            raise FixtureContractError(f"observable {name} must be an object")
        _require_exact_keys(spec, OBSERVABLE_KEYS, f"observable {name}")
        _require_finite_number(spec["value"], f"observable {name}.value")
        _require_finite_number(spec["abs_tol"], f"observable {name}.abs_tol", nonnegative=True)
        _require_finite_number(spec["rel_tol"], f"observable {name}.rel_tol", nonnegative=True)


def _fixture_without_integrity(fixture: Mapping[str, Any]) -> dict[str, Any]:
    payload = deepcopy(dict(fixture))
    payload.pop("integrity", None)
    return payload


def validate_fixture(fixture: Mapping[str, Any]) -> None:
    if not isinstance(fixture, Mapping):
        raise FixtureContractError("fixture must be an object")
    _require_exact_keys(fixture, TOP_LEVEL_KEYS, "fixture")
    if fixture["schema_version"] != SCHEMA_VERSION:
        raise FixtureContractError(f"schema_version must be {SCHEMA_VERSION}")
    _require_nonempty_text(fixture["fixture_id"], "fixture_id")
    _validate_source(fixture["source"])
    _validate_event(fixture["event"])
    _validate_parameter_block(fixture["parameters"])
    _validate_payload_block(fixture["committed_state"], "committed_state")
    forbidden = _find_forbidden_state_key(fixture["committed_state"]["payload"])
    if forbidden:
        raise FixtureContractError(f"reconstructible solver/worker workspace is forbidden in fixture state: {forbidden}")
    _validate_payload_block(fixture["forcing"], "forcing")
    _validate_payload_block(fixture["numerical_config"], "numerical_config")

    expected = fixture["expected"]
    if not isinstance(expected, Mapping):
        raise FixtureContractError("expected must be an object")
    _require_exact_keys(expected, EXPECTED_KEYS, "expected")
    _validate_endpoint(expected["endpoint_state"])
    if not isinstance(expected["observables"], Mapping):
        raise FixtureContractError("expected.observables must be an object")
    _validate_observables(expected["observables"])
    if not isinstance(expected["diagnostics"], Mapping):
        raise FixtureContractError("expected.diagnostics must be an object")
    _canonical_bytes(expected["diagnostics"])
    _validate_mass_accounting(expected["mass_accounting"], "expected.mass_accounting")

    integrity = _require_sha(fixture["integrity"], "integrity")
    expected_integrity = canonical_sha256(_fixture_without_integrity(fixture))
    if integrity != expected_integrity:
        raise FixtureContractError("fixture integrity hash does not match canonical content")


def build_fixture_from_reference_record(record: Mapping[str, Any]) -> dict[str, Any]:
    required = {
        "fixture_id",
        "source",
        "event",
        "parameters",
        "committed_state",
        "forcing",
        "numerical_config",
        "expected_endpoint_state",
        "endpoint_tolerance",
        "observables",
        "diagnostics",
        "mass_accounting",
    }
    _require_exact_keys(record, required, "reference record")
    source = deepcopy(record["source"])
    _validate_source(source)

    parameters = deepcopy(record["parameters"])
    if parameters["mode"] == "inline":
        parameters["sha256"] = canonical_sha256(parameters["payload"])
    _validate_parameter_block(parameters)

    endpoint_payload = deepcopy(record["expected_endpoint_state"])
    fixture = {
        "schema_version": SCHEMA_VERSION,
        "fixture_id": record["fixture_id"],
        "source": source,
        "event": deepcopy(record["event"]),
        "parameters": parameters,
        "committed_state": _seal_payload(record["committed_state"]),
        "forcing": _seal_payload(record["forcing"]),
        "numerical_config": _seal_payload(record["numerical_config"]),
        "expected": {
            "endpoint_state": {
                "payload": endpoint_payload,
                "sha256": canonical_sha256(endpoint_payload),
                "tolerance": deepcopy(record["endpoint_tolerance"]),
            },
            "observables": deepcopy(record["observables"]),
            "diagnostics": deepcopy(record["diagnostics"]),
            "mass_accounting": deepcopy(record["mass_accounting"]),
        },
        "integrity": "0" * 64,
    }
    fixture["integrity"] = canonical_sha256(_fixture_without_integrity(fixture))
    validate_fixture(fixture)
    return fixture


def write_fixture(path: Path, fixture: Mapping[str, Any]) -> None:
    validate_fixture(fixture)
    text = json.dumps(fixture, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n"
    path.write_text(text, encoding="utf-8")


def load_fixture(path: Path) -> dict[str, Any]:
    fixture = json.loads(path.read_text(encoding="utf-8"))
    validate_fixture(fixture)
    return fixture


def _numeric_equal(expected: float, observed: float, abs_tol: float, rel_tol: float) -> bool:
    if not math.isfinite(expected) or not math.isfinite(observed):
        return False
    limit = max(abs_tol, rel_tol * max(abs(expected), abs(observed)))
    return abs(expected - observed) <= limit


def _compare_state(
    expected: Any,
    observed: Any,
    *,
    path: str,
    default_abs: float,
    default_rel: float,
    overrides: Mapping[str, Mapping[str, float]],
    differences: list[str],
) -> None:
    spec = overrides.get(path)
    abs_tol = default_abs if spec is None else float(spec["abs"])
    rel_tol = default_rel if spec is None else float(spec["rel"])

    if isinstance(expected, Mapping):
        if not isinstance(observed, Mapping):
            differences.append(f"{path}: expected object")
            return
        if set(expected) != set(observed):
            differences.append(
                f"{path}: key mismatch missing={sorted(set(expected)-set(observed))} extra={sorted(set(observed)-set(expected))}"
            )
            return
        for key in sorted(expected):
            child_path = f"{path}.{key}" if path else str(key)
            _compare_state(
                expected[key],
                observed[key],
                path=child_path,
                default_abs=default_abs,
                default_rel=default_rel,
                overrides=overrides,
                differences=differences,
            )
        return

    if isinstance(expected, list):
        if not isinstance(observed, list):
            differences.append(f"{path}: expected array")
            return
        if len(expected) != len(observed):
            differences.append(f"{path}: length {len(observed)} != {len(expected)}")
            return
        for index, (exp_item, obs_item) in enumerate(zip(expected, observed)):
            _compare_state(
                exp_item,
                obs_item,
                path=f"{path}[{index}]",
                default_abs=default_abs,
                default_rel=default_rel,
                overrides=overrides,
                differences=differences,
            )
        return

    if isinstance(expected, (int, float)) and not isinstance(expected, bool):
        if isinstance(observed, bool) or not isinstance(observed, (int, float)):
            differences.append(f"{path}: expected numeric")
            return
        if not _numeric_equal(float(expected), float(observed), abs_tol, rel_tol):
            differences.append(
                f"{path}: observed={observed!r} expected={expected!r} abs_tol={abs_tol} rel_tol={rel_tol}"
            )
        return

    if observed != expected:
        differences.append(f"{path}: observed={observed!r} expected={expected!r}")


def compare_observed_to_fixture(fixture: Mapping[str, Any], observed: Mapping[str, Any]) -> list[str]:
    validate_fixture(fixture)
    required_observed = {"event", "endpoint_state", "observables", "diagnostics", "mass_accounting"}
    if set(observed) != required_observed:
        return [
            f"observed keys mismatch missing={sorted(required_observed-set(observed))} extra={sorted(set(observed)-required_observed)}"
        ]

    differences: list[str] = []
    expected_event = fixture["event"]
    if observed["event"] != {
        "t0": expected_event["t0"],
        "t1": expected_event["t1"],
        "time_basis": expected_event["time_basis"],
    }:
        differences.append("event interval/time_basis differs from fixture")

    endpoint = fixture["expected"]["endpoint_state"]
    tolerance = endpoint["tolerance"]
    _compare_state(
        endpoint["payload"],
        observed["endpoint_state"],
        path="state",
        default_abs=float(tolerance["abs"]),
        default_rel=float(tolerance["rel"]),
        overrides=tolerance["overrides"],
        differences=differences,
    )

    expected_observables = fixture["expected"]["observables"]
    observed_observables = observed["observables"]
    if not isinstance(observed_observables, Mapping):
        differences.append("observables: expected object")
    else:
        for name, spec in expected_observables.items():
            if name not in observed_observables:
                differences.append(f"observable {name}: missing")
                continue
            value = observed_observables[name]
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                differences.append(f"observable {name}: nonnumeric")
                continue
            if not _numeric_equal(
                float(spec["value"]),
                float(value),
                float(spec["abs_tol"]),
                float(spec["rel_tol"]),
            ):
                differences.append(
                    f"observable {name}: observed={value!r} expected={spec['value']!r}"
                )

    expected_diagnostics = fixture["expected"]["diagnostics"]
    observed_diagnostics = observed["diagnostics"]
    if not isinstance(observed_diagnostics, Mapping):
        differences.append("diagnostics: expected object")
    else:
        for key, expected_value in expected_diagnostics.items():
            if key not in observed_diagnostics:
                differences.append(f"diagnostic {key}: missing")
            elif observed_diagnostics[key] != expected_value:
                differences.append(
                    f"diagnostic {key}: observed={observed_diagnostics[key]!r} expected={expected_value!r}"
                )

    observed_mass = observed["mass_accounting"]
    if not isinstance(observed_mass, Mapping):
        differences.append("mass_accounting: expected object")
        return differences
    try:
        observed_mass_copy = deepcopy(dict(observed_mass))
        expected_mass = fixture["expected"]["mass_accounting"]
        observed_mass_copy["hard_tolerance"] = expected_mass["hard_tolerance"]
        observed_mass_copy["comparison_abs_tolerance"] = expected_mass["comparison_abs_tolerance"]
        _validate_mass_accounting(observed_mass_copy, "observed.mass_accounting")
    except FixtureContractError as exc:
        differences.append(str(exc))
        return differences

    expected_mass = fixture["expected"]["mass_accounting"]
    comparison_tol = float(expected_mass["comparison_abs_tolerance"])
    for key in ("storage_start", "storage_end"):
        if abs(float(observed_mass[key]) - float(expected_mass[key])) > comparison_tol:
            differences.append(
                f"mass {key}: observed={observed_mass[key]!r} expected={expected_mass[key]!r}"
            )

    expected_terms = {
        (term["term_id"], term["interface_id"], term["classification"]): float(term["signed_amount"])
        for term in expected_mass["boundary_terms"]
    }
    observed_terms = {
        (term["term_id"], term["interface_id"], term["classification"]): float(term["signed_amount"])
        for term in observed_mass["boundary_terms"]
    }
    if set(expected_terms) != set(observed_terms):
        differences.append("mass boundary term identity set differs")
    else:
        for identity, expected_amount in expected_terms.items():
            if abs(observed_terms[identity] - expected_amount) > comparison_tol:
                differences.append(
                    f"mass boundary {identity}: observed={observed_terms[identity]!r} expected={expected_amount!r}"
                )
    return differences
