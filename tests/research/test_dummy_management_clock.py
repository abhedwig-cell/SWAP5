from __future__ import annotations

import unittest

from dummy_competing_claims import (
    PRIORITY_EXTERNAL_FIRST,
    PRIORITY_ROOT_FIRST,
)
from dummy_management_clock import (
    run_management_clock,
    solve_clock_window,
)
from dummy_rootzone_demand import RootZoneConfig, RootZoneState
from dummy_three_store_internal_ledger import (
    ThreeStoreConfig,
    ThreeStoreState,
    total_three_store_water_m3,
)
from dummy_two_store_exchange import TwoStoreConfig, TwoStoreState


class ManagementClockTests(unittest.TestCase):
    def config(self) -> ThreeStoreConfig:
        return ThreeStoreConfig(
            root=RootZoneConfig(
                capacity_m3=100.0,
                target_m3=80.0,
            ),
            stores=TwoStoreConfig(
                surface_storage_m2=100.0,
                groundwater_storage_m2=100.0,
                conductance_m2_per_time=50.0,
            ),
            dt=0.5,
            management_min_surface_head_m=0.2,
            surface_datum_m=0.0,
        )

    def initial(self) -> ThreeStoreState:
        return ThreeStoreState(
            root=RootZoneState(40.0),
            water=TwoStoreState(1.0, 0.0),
        )

    def run_fast(self):
        return run_management_clock(
            self.config(),
            initial=self.initial(),
            priorities=(PRIORITY_ROOT_FIRST, PRIORITY_EXTERNAL_FIRST),
            root_claim_cap_m3=20.0,
            external_claim_m3=20.0,
        )

    def run_stale(self):
        return run_management_clock(
            self.config(),
            initial=self.initial(),
            priorities=(PRIORITY_ROOT_FIRST, PRIORITY_ROOT_FIRST),
            root_claim_cap_m3=20.0,
            external_claim_m3=20.0,
        )

    def assert_window_closed(self, result) -> None:
        self.assertAlmostEqual(result.root_balance_residual_m3, 0.0, places=10)
        self.assertAlmostEqual(result.surface_balance_residual_m3, 0.0, places=10)
        self.assertAlmostEqual(result.groundwater_balance_residual_m3, 0.0, places=10)
        self.assertAlmostEqual(result.combined_balance_residual_m3, 0.0, places=10)

    def test_c1_first_window_matches_preregistered_full_solution(self) -> None:
        r = solve_clock_window(
            self.config(),
            self.initial(),
            root_claim_cap_m3=20.0,
            external_claim_m3=20.0,
            priority=PRIORITY_ROOT_FIRST,
        )

        self.assertAlmostEqual(r.physical_root_deficit_m3, 40.0, places=12)
        self.assertAlmostEqual(r.scheduled_root_claim_m3, 20.0, places=12)
        self.assertAlmostEqual(r.external_claim_m3, 20.0, places=12)
        self.assertAlmostEqual(r.total_requested_m3, 40.0, places=12)
        self.assertEqual(r.regime, "FULL")
        self.assertAlmostEqual(r.total_realized_m3, 40.0, places=12)
        self.assertAlmostEqual(r.root_delivered_m3, 20.0, places=12)
        self.assertAlmostEqual(r.external_delivered_m3, 20.0, places=12)
        self.assertAlmostEqual(r.exchange_volume_m3, 16.0, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 60.0, places=12)
        self.assertAlmostEqual(r.end.water.surface_head_m, 0.44, places=12)
        self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.16, places=12)
        self.assertAlmostEqual(r.next_root_request_m3, 20.0, places=12)
        self.assert_window_closed(r)

    def test_c2_second_window_shared_physics_matches_preregistration(self) -> None:
        first = solve_clock_window(
            self.config(),
            self.initial(),
            root_claim_cap_m3=20.0,
            external_claim_m3=20.0,
            priority=PRIORITY_ROOT_FIRST,
        )
        second = solve_clock_window(
            self.config(),
            first.end,
            root_claim_cap_m3=20.0,
            external_claim_m3=20.0,
            priority=PRIORITY_EXTERNAL_FIRST,
        )

        self.assertAlmostEqual(second.physical_root_deficit_m3, 20.0, places=12)
        self.assertAlmostEqual(second.scheduled_root_claim_m3, 20.0, places=12)
        self.assertAlmostEqual(second.total_requested_m3, 40.0, places=12)
        self.assertEqual(second.regime, "CURTAILED")
        self.assertAlmostEqual(
            second.total_realized_m3,
            20.444444444444443,
            places=11,
        )
        self.assertAlmostEqual(
            second.exchange_volume_m3,
            3.555555555555556,
            places=11,
        )
        self.assertAlmostEqual(second.end.water.surface_head_m, 0.2, places=11)
        self.assertAlmostEqual(
            second.end.water.groundwater_head_m,
            0.19555555555555557,
            places=11,
        )
        self.assert_window_closed(second)

    def test_c3_fast_clock_matches_preregistered_outcome(self) -> None:
        r = self.run_fast()
        second = r.windows[1]

        self.assertEqual(second.priority, PRIORITY_EXTERNAL_FIRST)
        self.assertAlmostEqual(second.external_delivered_m3, 20.0, places=12)
        self.assertAlmostEqual(
            second.root_delivered_m3,
            0.44444444444444287,
            places=11,
        )
        self.assertAlmostEqual(
            r.final.root.storage_m3,
            60.44444444444444,
            places=11,
        )
        self.assertAlmostEqual(
            second.next_root_request_m3,
            19.555555555555557,
            places=11,
        )
        self.assertAlmostEqual(
            r.cumulative_external_delivered_m3,
            40.0,
            places=12,
        )
        self.assertAlmostEqual(r.combined_balance_residual_m3, 0.0, places=10)

    def test_c4_stale_clock_matches_preregistered_outcome(self) -> None:
        r = self.run_stale()
        second = r.windows[1]

        self.assertEqual(second.priority, PRIORITY_ROOT_FIRST)
        self.assertAlmostEqual(second.root_delivered_m3, 20.0, places=12)
        self.assertAlmostEqual(
            second.external_delivered_m3,
            0.44444444444444287,
            places=11,
        )
        self.assertAlmostEqual(r.final.root.storage_m3, 80.0, places=12)
        self.assertAlmostEqual(second.next_root_request_m3, 0.0, places=12)
        self.assertAlmostEqual(
            r.cumulative_external_delivered_m3,
            20.444444444444443,
            places=11,
        )
        self.assertAlmostEqual(r.combined_balance_residual_m3, 0.0, places=10)

    def test_c5_physical_water_trajectory_is_identical_between_clocks(self) -> None:
        fast = self.run_fast()
        stale = self.run_stale()

        self.assertEqual(len(fast.windows), len(stale.windows))
        for fw, sw in zip(fast.windows, stale.windows):
            self.assertAlmostEqual(
                fw.total_requested_m3,
                sw.total_requested_m3,
                places=12,
            )
            self.assertAlmostEqual(
                fw.total_realized_m3,
                sw.total_realized_m3,
                places=12,
            )
            self.assertAlmostEqual(
                fw.exchange_volume_m3,
                sw.exchange_volume_m3,
                places=12,
            )
            self.assertEqual(fw.end.water, sw.end.water)

        self.assertAlmostEqual(fast.final.water.surface_head_m, 0.2, places=11)
        self.assertAlmostEqual(stale.final.water.surface_head_m, 0.2, places=11)
        self.assertAlmostEqual(
            fast.final.water.groundwater_head_m,
            0.19555555555555557,
            places=11,
        )
        self.assertAlmostEqual(
            stale.final.water.groundwater_head_m,
            0.19555555555555557,
            places=11,
        )

    def test_c6_clock_difference_changes_root_memory_only_through_recipient_split(self) -> None:
        fast = self.run_fast()
        stale = self.run_stale()

        self.assertAlmostEqual(
            fast.cumulative_root_delivered_m3,
            20.444444444444443,
            places=11,
        )
        self.assertAlmostEqual(
            stale.cumulative_root_delivered_m3,
            40.0,
            places=12,
        )
        self.assertAlmostEqual(
            stale.final.root.storage_m3 - fast.final.root.storage_m3,
            stale.cumulative_root_delivered_m3
            - fast.cumulative_root_delivered_m3,
            places=10,
        )

    def test_c7_combined_storage_loss_equals_cumulative_external_delivery(self) -> None:
        c = self.config()
        initial_total = total_three_store_water_m3(c, self.initial())

        for r in (self.run_fast(), self.run_stale()):
            final_total = total_three_store_water_m3(c, r.final)
            self.assertAlmostEqual(
                final_total - initial_total,
                -r.cumulative_external_delivered_m3,
                places=10,
            )
            self.assertAlmostEqual(r.combined_balance_residual_m3, 0.0, places=10)

    def test_c8_conservation_cannot_select_management_clock(self) -> None:
        fast = self.run_fast()
        stale = self.run_stale()

        for w in fast.windows + stale.windows:
            self.assert_window_closed(w)

        self.assertAlmostEqual(fast.combined_balance_residual_m3, 0.0, places=10)
        self.assertAlmostEqual(stale.combined_balance_residual_m3, 0.0, places=10)
        self.assertNotAlmostEqual(
            fast.final.root.storage_m3,
            stale.final.root.storage_m3,
            places=9,
        )

    def test_c9_root_claim_cap_binds_only_first_window_in_canonical_case(self) -> None:
        r = self.run_fast()
        first, second = r.windows

        self.assertAlmostEqual(first.physical_root_deficit_m3, 40.0, places=12)
        self.assertAlmostEqual(first.scheduled_root_claim_m3, 20.0, places=12)
        self.assertAlmostEqual(second.physical_root_deficit_m3, 20.0, places=12)
        self.assertAlmostEqual(second.scheduled_root_claim_m3, 20.0, places=12)

    def test_c10_no_priority_event_reproduces_stale_schedule(self) -> None:
        a = self.run_stale()
        b = run_management_clock(
            self.config(),
            initial=self.initial(),
            priorities=[PRIORITY_ROOT_FIRST, PRIORITY_ROOT_FIRST],
            root_claim_cap_m3=20.0,
            external_claim_m3=20.0,
        )
        self.assertEqual(a, b)

    def test_c11_same_total_managed_realization_but_different_system_boundary_loss(self) -> None:
        fast = self.run_fast()
        stale = self.run_stale()

        self.assertAlmostEqual(
            sum(w.total_realized_m3 for w in fast.windows),
            sum(w.total_realized_m3 for w in stale.windows),
            places=12,
        )
        self.assertNotAlmostEqual(
            fast.cumulative_external_delivered_m3,
            stale.cumulative_external_delivered_m3,
            places=9,
        )

    def test_c12_invalid_inputs_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            run_management_clock(
                self.config(),
                initial=self.initial(),
                priorities=[],
                root_claim_cap_m3=20.0,
                external_claim_m3=20.0,
            )
        with self.assertRaises(ValueError):
            solve_clock_window(
                self.config(),
                self.initial(),
                root_claim_cap_m3=-1.0,
                external_claim_m3=20.0,
                priority=PRIORITY_ROOT_FIRST,
            )
        with self.assertRaises(ValueError):
            solve_clock_window(
                self.config(),
                self.initial(),
                root_claim_cap_m3=20.0,
                external_claim_m3=-1.0,
                priority=PRIORITY_ROOT_FIRST,
            )
        with self.assertRaises(ValueError):
            solve_clock_window(
                self.config(),
                self.initial(),
                root_claim_cap_m3=20.0,
                external_claim_m3=20.0,
                priority="UNKNOWN",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
