#!/usr/bin/env python3
from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from tools.vq import fvq01_admission as gate


class Fvq01AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.matrix = json.loads(gate.MATRIX.read_text(encoding="utf-8"))
        cls.inventory = json.loads(gate.INVENTORY.read_text(encoding="utf-8"))

    def test_current_matrix_semantics_pass(self) -> None:
        checks = gate.validate_matrix(self.matrix)
        self.assertTrue(all(checks.values()), checks)

    def test_current_inventory_semantics_pass(self) -> None:
        checks = gate.validate_inventory(self.inventory)
        self.assertTrue(all(checks.values()), checks)

    def test_blocked_claim_cannot_be_promoted_by_metadata_only(self) -> None:
        matrix = copy.deepcopy(self.matrix)
        claim = next(item for item in matrix["claims"] if item["claim_id"] == "FVQ-C08")
        claim["claim_qualified"] = True
        claim["test_pass"] = "PASS"
        checks = gate.validate_matrix(matrix)
        self.assertFalse(checks["blocked_never_qualified"])

    def test_testdouble_cannot_qualify_real_warm_start_physics(self) -> None:
        matrix = copy.deepcopy(self.matrix)
        claim = next(item for item in matrix["claims"] if item["claim_id"] == "FVQ-C09")
        claim["claim_qualified"] = True
        claim["implementation_exists"] = True
        claim["test_executable"] = True
        claim["test_pass"] = "PASS"
        checks = gate.validate_matrix(matrix)
        self.assertFalse(checks["blocked_never_qualified"])
        self.assertFalse(checks["testdouble_not_physics"])

    def test_stale_b2_candidate_is_not_directly_reusable(self) -> None:
        inventory = copy.deepcopy(self.inventory)
        asset = next(item for item in inventory["assets"] if item["asset_id"] == "FVQ-A06")
        self.assertEqual(asset["classification"], "REBASE_REQUIRED")

    def test_historical_testdouble_evidence_is_historical_only(self) -> None:
        inventory = copy.deepcopy(self.inventory)
        asset = next(item for item in inventory["assets"] if item["asset_id"] == "FVQ-A16")
        self.assertEqual(asset["classification"], "HISTORICAL_ONLY")

    def test_every_qualified_claim_has_real_execution_evidence(self) -> None:
        checks = gate.validate_matrix(self.matrix)
        self.assertTrue(checks["qualified_requires_execution_evidence"], checks)

    def test_no_production_src_changed_on_fvq_branch(self) -> None:
        checks = gate.check_source_provenance()
        self.assertTrue(checks["fvq_changes_no_production_src"], checks)


if __name__ == "__main__":
    unittest.main()
