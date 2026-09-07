from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
STATUS_PATH = HERE / "fmq04d_canonical_interface_status.json"
EXPECTED_CANONICAL_COMMIT = "539b8c1b942d5c2dc8f97b8b7f400b2c3a1da0aa"

CRITICAL_REAL_PHYSICAL_CAPABILITIES = (
    "concrete_b1_10_physical_adapter",
    "b1_10_committed_continuation_state_capture",
    "real_b1_10_short_interval_continuation",
    "full_unrounded_accepted_interval_mass_accounting",
    "mass_accounting_boundary_term_detail_for_fmq_fixture",
    "deterministic_real_b1_10_endpoint_replay",
)

ALREADY_MATERIALIZED_CONTRACT_CAPABILITIES = (
    "generic_t0_t1_interval",
    "externally_atomic_requested_interval",
    "private_working_state_for_internal_substeps",
    "separate_forcing_numerical_config_result_contracts",
    "worker_scratch_excluded_from_persistent_state_contract",
    "exact_b1_10_physical_preimage_qualified",
)


class TestFMQ04dCanonicalInterfaceStatus(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.status = json.loads(STATUS_PATH.read_text(encoding="utf-8"))

    def test_qualification_only_boundary(self) -> None:
        self.assertEqual(self.status["workstream"], "F-MQ")
        self.assertEqual(self.status["work_unit"], "F-MQ04d")
        self.assertFalse(self.status["production_code_change_allowed"])

    def test_exact_canonical_source_pin(self) -> None:
        source = self.status["canonical_source"]
        self.assertEqual(source["branch"], "integration/f-ci-canonical")
        self.assertEqual(source["commit"], EXPECTED_CANONICAL_COMMIT)
        self.assertEqual(source["reference_snapshot"], "B1.10")
        self.assertRegex(source["commit"], r"^[0-9a-f]{40}$")
        self.assertRegex(source["source_manifest_sha256"], r"^[0-9a-f]{64}$")
        self.assertTrue(source["evidence"])
        self.assertIn("integration/f-ci/F-CI05_STATUS.json", source["evidence"])
        self.assertIn("integration/f-ci/F-CI05_B1_10_PHYSICAL_SEAM.json", source["evidence"])
        for digest in source["evidence"].values():
            self.assertRegex(digest, r"^[0-9a-f]{40}$")

    def test_materialized_contract_capabilities_are_recorded(self) -> None:
        caps = self.status["capabilities"]
        for name in ALREADY_MATERIALIZED_CONTRACT_CAPABILITIES:
            self.assertIs(caps[name], True, name)

    def test_missing_real_physical_capabilities_block_admission(self) -> None:
        caps = self.status["capabilities"]
        missing = [name for name in CRITICAL_REAL_PHYSICAL_CAPABILITIES if not caps[name]]
        self.assertTrue(missing)
        self.assertFalse(self.status["fixture_admission_allowed"])
        self.assertEqual(
            self.status["status"],
            "INTERFACE_NEEDED_CANONICAL_PHYSICAL_CONTINUATION",
        )

    def test_no_false_ready_state_is_representable(self) -> None:
        caps = self.status["capabilities"]
        physical_ready = all(caps[name] for name in CRITICAL_REAL_PHYSICAL_CAPABILITIES)
        self.assertEqual(self.status["fixture_admission_allowed"], physical_ready)

    def test_interface_contract_is_complete_enough_for_handoff(self) -> None:
        contract = self.status["required_interface_contract"]
        self.assertEqual(
            set(contract),
            {
                "physical_adapter",
                "committed_state",
                "forcing",
                "result",
                "mass",
                "transactionality",
                "time",
            },
        )
        self.assertEqual(self.status["dependency"], "F-CI/F-KT")
        self.assertGreaterEqual(len(self.status["unblock_conditions"]), 5)


if __name__ == "__main__":
    unittest.main(verbosity=2)
