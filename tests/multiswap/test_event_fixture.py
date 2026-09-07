from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

from event_fixture import (
    FixtureContractError,
    build_fixture_from_reference_record,
    canonical_sha256,
    compare_observed_to_fixture,
    load_fixture,
    validate_fixture,
    write_fixture,
)


def digest(token: str) -> str:
    return canonical_sha256({"token": token})


def reference_record() -> dict:
    storage_start = 100.0
    rain = 3.0
    drainage = -1.0
    storage_end = 102.0
    return {
        "fixture_id": "mq-fixture-test-rain-001",
        "source": {
            "kind": "reference_run",
            "repository": "abhedwig-cell/SWAP5",
            "commit": "a" * 40,
            "reference_family": "synthetic-contract-test",
            "reference_snapshot": "TEST-REF-1",
            "case_id": "contract-case",
            "run_id": "reference-run-0001",
            "extractor_id": "fmq03-contract-test-extractor-v1",
            "extraction_mode": "reference_run_checkpoint",
            "source_artifacts": {
                "input_manifest": digest("input"),
                "reference_result": digest("result"),
            },
        },
        "event": {
            "kind": "infiltration",
            "checkpoint_t": 10.25,
            "t0": 10.25,
            "t1": 10.5,
            "time_basis": "model-days-since-origin",
            "metadata": {"note": "synthetic contract test, not a physics oracle"},
        },
        "parameters": {
            "mode": "reference",
            "id": "parameter-set-A",
            "sha256": digest("parameters"),
            "payload": None,
        },
        "committed_state": {
            "soil": {"h": [-100.0, -80.0], "theta": [0.25, 0.27]},
            "ponding": 0.0,
            "irrigation_cursor": 1,
        },
        "forcing": {
            "precipitation": [12.0],
            "potential_et": [1.5],
        },
        "numerical_config": {
            "policy": "reference",
            "mass_tolerance": 1.0e-10,
        },
        "expected_endpoint_state": {
            "soil": {"h": [-95.0, -79.0], "theta": [0.255, 0.272]},
            "ponding": 0.0,
            "irrigation_cursor": 1,
        },
        "endpoint_tolerance": {
            "abs": 1.0e-12,
            "rel": 1.0e-12,
            "overrides": {
                "state.soil.h[0]": {"abs": 1.0e-9, "rel": 0.0},
            },
        },
        "observables": {
            "bottom_flux": {"value": 0.125, "abs_tol": 1.0e-12, "rel_tol": 1.0e-12},
            "storage_end": {"value": storage_end, "abs_tol": 1.0e-12, "rel_tol": 0.0},
        },
        "diagnostics": {
            "accepted": True,
            "retries": 0,
            "newton_iterations": 7,
        },
        "mass_accounting": {
            "precision": "unrounded_internal",
            "hard_tolerance": 1.0e-10,
            "comparison_abs_tolerance": 1.0e-12,
            "storage_start": storage_start,
            "storage_end": storage_end,
            "boundary_terms": [
                {
                    "term_id": "precipitation",
                    "interface_id": "top",
                    "signed_amount": rain,
                    "classification": "external",
                },
                {
                    "term_id": "drainage",
                    "interface_id": "drain",
                    "signed_amount": drainage,
                    "classification": "external",
                },
                {
                    "term_id": "internal-transfer",
                    "interface_id": "soil-layer-1-2",
                    "signed_amount": 999.0,
                    "classification": "internal_diagnostic",
                },
            ],
            "reported_residual": 0.0,
        },
    }


def observed_from_fixture(fixture: dict) -> dict:
    mass = deepcopy(fixture["expected"]["mass_accounting"])
    return {
        "event": {
            "t0": fixture["event"]["t0"],
            "t1": fixture["event"]["t1"],
            "time_basis": fixture["event"]["time_basis"],
        },
        "endpoint_state": deepcopy(fixture["expected"]["endpoint_state"]["payload"]),
        "observables": {
            name: spec["value"] for name, spec in fixture["expected"]["observables"].items()
        },
        "diagnostics": deepcopy(fixture["expected"]["diagnostics"]),
        "mass_accounting": mass,
    }


class EventFixtureContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = build_fixture_from_reference_record(reference_record())

    def test_reference_record_builds_valid_fixture(self) -> None:
        validate_fixture(self.fixture)
        self.assertEqual(self.fixture["schema_version"], "mq-event-fixture-v1")
        self.assertEqual(self.fixture["source"]["extraction_mode"], "reference_run_checkpoint")

    def test_serialization_is_deterministic_and_roundtrips(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            first = Path(tmp) / "a.json"
            second = Path(tmp) / "b.json"
            write_fixture(first, self.fixture)
            write_fixture(second, deepcopy(self.fixture))
            self.assertEqual(first.read_bytes(), second.read_bytes())
            self.assertEqual(load_fixture(first), self.fixture)
            json.loads(first.read_text(encoding="utf-8"))

    def test_integrity_catches_payload_mutation(self) -> None:
        changed = deepcopy(self.fixture)
        changed["forcing"]["payload"]["precipitation"][0] += 1.0
        with self.assertRaisesRegex(FixtureContractError, "forcing.sha256"):
            validate_fixture(changed)

    def test_integrity_catches_provenance_mutation(self) -> None:
        changed = deepcopy(self.fixture)
        changed["source"]["case_id"] = "other-case"
        with self.assertRaisesRegex(FixtureContractError, "integrity"):
            validate_fixture(changed)

    def test_reference_source_requires_exact_commit_and_artifact_hashes(self) -> None:
        record = reference_record()
        record["source"]["commit"] = "main"
        with self.assertRaisesRegex(FixtureContractError, "40-character"):
            build_fixture_from_reference_record(record)
        record = reference_record()
        record["source"]["source_artifacts"] = {}
        with self.assertRaisesRegex(FixtureContractError, "at least one"):
            build_fixture_from_reference_record(record)

    def test_non_reference_extraction_is_rejected(self) -> None:
        record = reference_record()
        record["source"]["extraction_mode"] = "hand_edited"
        with self.assertRaisesRegex(FixtureContractError, "reference_run_checkpoint"):
            build_fixture_from_reference_record(record)

    def test_reconstructible_worker_or_solver_workspace_is_forbidden(self) -> None:
        record = reference_record()
        record["committed_state"]["worker_scratch"] = [1, 2, 3]
        with self.assertRaisesRegex(FixtureContractError, "forbidden"):
            build_fixture_from_reference_record(record)

    def test_reference_parameter_mode_does_not_duplicate_payload(self) -> None:
        self.assertIsNone(self.fixture["parameters"]["payload"])
        record = reference_record()
        record["parameters"]["payload"] = {"soil": "duplicated"}
        with self.assertRaisesRegex(FixtureContractError, "must not duplicate"):
            build_fixture_from_reference_record(record)

    def test_inline_parameter_set_is_hashed_and_allowed(self) -> None:
        record = reference_record()
        record["parameters"] = {
            "mode": "inline",
            "id": "inline-small-set",
            "sha256": "0" * 64,
            "payload": {"alpha": 1.25, "beta": 2},
        }
        fixture = build_fixture_from_reference_record(record)
        self.assertEqual(
            fixture["parameters"]["sha256"], canonical_sha256(record["parameters"]["payload"])
        )

    def test_checkpoint_must_be_exact_interval_start(self) -> None:
        record = reference_record()
        record["event"]["checkpoint_t"] = 10.0
        with self.assertRaisesRegex(FixtureContractError, "checkpoint_t"):
            build_fixture_from_reference_record(record)

    def test_rounded_legacy_balance_cannot_be_hard_mass_oracle(self) -> None:
        record = reference_record()
        record["mass_accounting"]["precision"] = "legacy_report_0.01cm"
        with self.assertRaisesRegex(FixtureContractError, "rounded legacy"):
            build_fixture_from_reference_record(record)

    def test_fixture_expected_mass_must_close(self) -> None:
        record = reference_record()
        record["mass_accounting"]["storage_end"] += 1.0e-5
        record["mass_accounting"]["reported_residual"] = 1.0e-5
        with self.assertRaisesRegex(FixtureContractError, "hard mass gate"):
            build_fixture_from_reference_record(record)

    def test_canonical_comparison_accepts_exact_observation(self) -> None:
        observed = observed_from_fixture(self.fixture)
        self.assertEqual(compare_observed_to_fixture(self.fixture, observed), [])

    def test_endpoint_numeric_tolerance_is_path_aware(self) -> None:
        observed = observed_from_fixture(self.fixture)
        observed["endpoint_state"]["soil"]["h"][0] += 5.0e-10
        self.assertEqual(compare_observed_to_fixture(self.fixture, observed), [])
        observed["endpoint_state"]["soil"]["h"][0] += 2.0e-9
        self.assertTrue(
            any("state.soil.h[0]" in item for item in compare_observed_to_fixture(self.fixture, observed))
        )

    def test_diagnostic_mismatch_is_exact(self) -> None:
        observed = observed_from_fixture(self.fixture)
        observed["diagnostics"]["retries"] = 1
        self.assertTrue(
            any("diagnostic retries" in item for item in compare_observed_to_fixture(self.fixture, observed))
        )

    def test_observed_mass_gate_cannot_be_relaxed_by_runtime(self) -> None:
        observed = observed_from_fixture(self.fixture)
        observed["mass_accounting"]["storage_end"] += 1.0e-6
        observed["mass_accounting"]["reported_residual"] = 1.0e-6
        observed["mass_accounting"]["hard_tolerance"] = 1.0
        differences = compare_observed_to_fixture(self.fixture, observed)
        self.assertTrue(any("hard mass gate" in item for item in differences), differences)

    def test_local_forcing_change_changes_fixture_identity(self) -> None:
        record_a = reference_record()
        record_b = reference_record()
        record_b["forcing"]["precipitation"][0] += 0.25
        fixture_a = build_fixture_from_reference_record(record_a)
        fixture_b = build_fixture_from_reference_record(record_b)
        self.assertNotEqual(fixture_a["forcing"]["sha256"], fixture_b["forcing"]["sha256"])
        self.assertNotEqual(fixture_a["integrity"], fixture_b["integrity"])


if __name__ == "__main__":
    unittest.main()
