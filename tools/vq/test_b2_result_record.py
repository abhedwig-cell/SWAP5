from __future__ import annotations

import json
import math
import tempfile
import unittest
from pathlib import Path

from tools.vq.b2_result_record import assess_record

COMMIT = "a" * 40


def valid_record() -> dict:
    return {
        "schema_version": 1,
        "contract_id": "SWAP5-B2-reference-result-record-v1",
        "interval": {"t0": "2026-01-01T06:00:00", "t1": "2026-01-01T18:00:00", "time_basis": "UTC"},
        "endpoint_state": {
            "scope": "committed",
            "state_id": "state-t1",
            "variables": [
                {"variable_id": "soil.head", "value": [-100.0, -90.0], "unit": "cm"},
                {"variable_id": "surface.pond", "value": 0.0, "unit": "cm"},
            ],
        },
        "results": [
            {"result_id": "bottom.water_amount", "value": -0.25, "unit": "cm", "basis": "column_area", "aggregation": "interval_integral"},
            {"result_id": "transpiration.water_amount", "value": -0.30, "unit": "cm", "basis": "column_area", "aggregation": "interval_integral"},
        ],
        "mass_accounting": {
            "schema_version": 1,
            "component_id": "swap-column",
            "column_or_tile_id": "column-1",
            "interval": {"t0": "2026-01-01T06:00:00", "t1": "2026-01-01T18:00:00", "time_basis": "UTC"},
            "amount_unit": "cm",
            "area_basis": "column_area",
            "accounting_scope": "committed",
            "trial_id": None,
            "accepted_trial_id": "trial-1",
            "storage": {
                "start_total": 10.0,
                "end_total": 11.0,
                "components": [
                    {"term_id": "soil", "start_amount": 9.5, "end_amount": 10.5},
                    {"term_id": "surface", "start_amount": 0.5, "end_amount": 0.5},
                ],
            },
            "boundary_terms": [
                {"term_id": "precip", "interface_id": "atmosphere", "signed_amount": 1.0, "classification": "external"},
                {"term_id": "redistribution", "interface_id": "soil-internal", "signed_amount": 99.0, "classification": "internal_diagnostic"},
            ],
            "reported_residual": 0.0,
            "execution_class": "reference",
            "qualification_context": {
                "reference_mode": True,
                "tolerance_qualification_id": "mass-reference-1",
                "source_identity": COMMIT,
                "case_id": "fixture-1",
            },
            "diagnostics": {},
        },
        "transaction": {
            "accepted": True,
            "accepted_trial_id": "trial-1",
            "trial_count": 1,
            "retry_count": 0,
            "commit_count": 1,
            "rollback_count": 0,
            "rejected_trials_excluded_from_committed_totals": True,
        },
        "diagnostics": {
            "accepted": True,
            "execution_class": "reference",
            "retry_count": 0,
            "solver_iterations": 7,
            "solver_cost": 7.0,
            "fallback_used": False,
            "balance_residual": 0.0,
        },
        "provenance": {
            "implementation_commit": COMMIT,
            "numerical_policy": "reference",
            "result_contract_version": "v1",
            "case_id": "fixture-1",
        },
    }


class B2ResultRecordTests(unittest.TestCase):
    def write_record(self, root: Path, data: dict) -> Path:
        path = root / "result.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def test_valid_balanced_record_passes_and_recomputes_mass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = assess_record(self.write_record(root, valid_record()))
            self.assertTrue(result["valid_reference_result"])
            self.assertEqual(result["recomputed_mass_residual"], 0.0)
            self.assertFalse(result["mass_tolerance_applied"])

    def test_interval_mismatch_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data = valid_record()
            data["mass_accounting"]["interval"]["t1"] = "2026-01-02T00:00:00"
            result = assess_record(self.write_record(root, data))
            self.assertFalse(result["valid_reference_result"])
            self.assertIn("mass_interval_matches_result", result["failed_checks"])

    def test_duplicate_result_id_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data = valid_record()
            data["results"].append(dict(data["results"][0]))
            result = assess_record(self.write_record(root, data))
            self.assertFalse(result["valid_reference_result"])
            self.assertIn("result_ids_unique", result["failed_checks"])

    def test_retry_and_rollback_accounting_must_match_trials(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data = valid_record()
            data["transaction"].update({"trial_count": 3, "retry_count": 1, "rollback_count": 1})
            data["diagnostics"]["retry_count"] = 1
            result = assess_record(self.write_record(root, data))
            self.assertFalse(result["valid_reference_result"])
            self.assertIn("retry_count_matches_trials", result["failed_checks"])

    def test_accepted_trial_identity_must_match_mass_record(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data = valid_record()
            data["mass_accounting"]["accepted_trial_id"] = "trial-other"
            result = assess_record(self.write_record(root, data))
            self.assertFalse(result["valid_reference_result"])
            self.assertIn("mass_accepted_trial_matches", result["failed_checks"])

    def test_rejected_trials_may_not_contribute_to_committed_totals(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data = valid_record()
            data["transaction"]["rejected_trials_excluded_from_committed_totals"] = False
            result = assess_record(self.write_record(root, data))
            self.assertFalse(result["valid_reference_result"])
            self.assertIn("rejected_trials_excluded", result["failed_checks"])

    def test_nonfinite_physical_value_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data = valid_record()
            data["endpoint_state"]["variables"][0]["value"] = [math.nan]
            result = assess_record(self.write_record(root, data))
            self.assertFalse(result["valid_reference_result"])
            self.assertIn("endpoint_values_finite", result["failed_checks"])

    def test_diagnostic_residual_must_match_vq_recomputation(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data = valid_record()
            data["diagnostics"]["balance_residual"] = 1.0e-4
            result = assess_record(self.write_record(root, data))
            self.assertFalse(result["valid_reference_result"])
            self.assertIn("diagnostic_residual_matches_recomputed", result["failed_checks"])


if __name__ == "__main__":
    unittest.main()
