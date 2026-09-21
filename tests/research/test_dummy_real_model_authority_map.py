from __future__ import annotations

import copy
from pathlib import Path
import unittest

from dummy_real_model_authority_map import (
    index_rows,
    load_authority_map,
    validate_authority_map,
)


ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "integration/research/RIBASIM_DUMMY_18_AUTHORITY_MAP.json"


class RealModelAuthorityMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.data = load_authority_map(MAP_PATH)
        cls.rows = index_rows(cls.data)

    def test_a1_current_map_validates_cleanly(self) -> None:
        self.assertEqual(validate_authority_map(self.data), [])

    def test_a2_required_unresolved_rows_remain_unresolved(self) -> None:
        for row_id in self.data["required_unresolved_ids"]:
            self.assertEqual(self.rows[row_id]["status"], "UNRESOLVED")
            self.assertFalse(self.rows[row_id]["substitution_allowed"])
            self.assertTrue(self.rows[row_id]["blocker"])

    def test_a3_ready_stages_use_only_bound_rows(self) -> None:
        for stage in self.data["substitution_stages"]:
            if stage["state"] != "READY_RESTRICTED":
                continue
            for row_id in stage["requirements"]:
                self.assertEqual(self.rows[row_id]["status"], "BOUND")

    def test_a4_blocked_stages_have_nonbound_blockers(self) -> None:
        for stage in self.data["substitution_stages"]:
            if stage["state"] != "BLOCKED":
                continue
            self.assertTrue(stage["blockers"])
            for row_id in stage["blockers"]:
                self.assertNotEqual(self.rows[row_id]["status"], "BOUND")

    def test_a5_ribasim_demand_allocated_supplied_are_distinct(self) -> None:
        demand = self.rows["ribasim.user_demand.demand"]
        allocated = self.rows["ribasim.user_demand.allocated"]
        supplied = self.rows["ribasim.user_demand.supplied"]

        self.assertEqual(demand["class"], "MANAGEMENT_DECISION")
        self.assertEqual(allocated["class"], "MANAGEMENT_DECISION")
        self.assertEqual(supplied["class"], "TRANSFER")
        self.assertIn("lag", supplied["time_support"])

    def test_a6_ribasim_hmin_and_routing_are_explicit_non_equivalences(self) -> None:
        self.assertEqual(
            self.rows["ribasim.user_demand.min_level"]["status"],
            "NON_EQUIVALENT",
        )
        self.assertEqual(
            self.rows["ribasim.routing.linear_surrogate"]["status"],
            "NON_EQUIVALENT",
        )

    def test_a7_modflow_head_and_flux_bound_but_storage_unresolved(self) -> None:
        self.assertEqual(self.rows["modflow.head"]["status"], "BOUND")
        self.assertEqual(
            self.rows["modflow.interface.riv_drn_exchange"]["status"],
            "BOUND",
        )
        self.assertEqual(
            self.rows["modflow.storage.aggregate"]["status"],
            "UNRESOLVED",
        )

    def test_a8_swap_event_state_known_but_external_realization_unresolved(self) -> None:
        self.assertEqual(
            self.rows["swap.irrigation.management_state"]["status"],
            "BOUND",
        )
        self.assertEqual(
            self.rows["swap.irrigation.partial_supply_policy"]["status"],
            "UNRESOLVED",
        )
        self.assertEqual(
            self.rows["swap.irrigation.atomic_transaction"]["status"],
            "UNRESOLVED",
        )

    def test_a9_canopy_and_net_soil_are_bound_but_gross_external_supply_is_not(self) -> None:
        self.assertEqual(
            self.rows["swap.rutter.canopy_storage"]["status"],
            "BOUND",
        )
        self.assertEqual(
            self.rows["swap.rutter.net_soil_irrigation"]["status"],
            "BOUND",
        )
        self.assertEqual(
            self.rows["swap.irrigation.gross_source_withdrawal"]["status"],
            "UNRESOLVED",
        )

    def test_a10_storage_partition_drainage_and_product_registration_stay_open(self) -> None:
        for row_id in (
            "swap_modflow.storage_partition",
            "swap.drainage.ownership",
            "coupler.product_registration",
        ):
            self.assertEqual(self.rows[row_id]["status"], "UNRESOLVED")

    def test_a11_source_pins_are_exactly_present(self) -> None:
        pins = self.data["pins"]
        self.assertEqual(
            pins["swap5_canonical"],
            "integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5",
        )
        self.assertEqual(
            pins["ribasim"],
            "Deltares/Ribasim@f965a3266a4685bf10f3458aaa1855d09fa45a7a",
        )

    def test_a12_required_unresolved_cannot_be_silently_promoted(self) -> None:
        data = copy.deepcopy(self.data)
        row = next(
            x for x in data["rows"]
            if x["id"] == "swap_modflow.storage_partition"
        )
        row["status"] = "BOUND"
        row["substitution_allowed"] = True
        row.pop("blocker", None)

        errors = validate_authority_map(data)
        self.assertTrue(
            any(
                "required unresolved row promoted" in error
                for error in errors
            )
        )

    def test_a13_ready_stage_cannot_depend_on_unresolved_row(self) -> None:
        data = copy.deepcopy(self.data)
        stage = next(
            x for x in data["substitution_stages"]
            if x["id"] == "stage2.modflow_full_storage"
        )
        stage["state"] = "READY_RESTRICTED"
        stage.pop("blockers", None)

        errors = validate_authority_map(data)
        self.assertTrue(
            any("READY stage depends on non-BOUND" in error for error in errors)
        )

    def test_a14_non_equivalent_row_requires_adapter(self) -> None:
        data = copy.deepcopy(self.data)
        row = next(
            x for x in data["rows"]
            if x["id"] == "swap.root_storage.bucket"
        )
        row.pop("adaptation_required", None)

        errors = validate_authority_map(data)
        self.assertTrue(
            any(
                "NON_EQUIVALENT row requires adaptation_required" in error
                for error in errors
            )
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
