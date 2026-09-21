from __future__ import annotations

import unittest

from dummy_competing_claims import (
    PRIORITY_EXTERNAL_FIRST,
    PRIORITY_ROOT_FIRST,
    solve_competing_claims,
)
from dummy_rootzone_demand import RootZoneConfig, RootZoneState
from dummy_three_store_internal_ledger import (
    ThreeStoreConfig,
    ThreeStoreState,
    solve_three_store_window,
    total_three_store_water_m3,
)
from dummy_two_store_exchange import TwoStoreConfig, TwoStoreState


class CompetingClaimsTests(unittest.TestCase):
    def config(
        self,
        *,
        target: float = 80.0,
        hmin: float = 0.4,
        C: float = 50.0,
        dt: float = 1.0,
        datum: float = 0.0,
    ) -> ThreeStoreConfig:
        return ThreeStoreConfig(
            root=RootZoneConfig(
                capacity_m3=100.0,
                target_m3=target,
            ),
            stores=TwoStoreConfig(
                surface_storage_m2=100.0,
                groundwater_storage_m2=100.0,
                conductance_m2_per_time=C,
            ),
            dt=dt,
            management_min_surface_head_m=hmin,
            surface_datum_m=datum,
        )

    def state(
        self,
        *,
        root: float,
        hs: float = 1.0,
        hg: float = 0.0,
    ) -> ThreeStoreState:
        return ThreeStoreState(
            root=RootZoneState(root),
            water=TwoStoreState(hs, hg),
        )

    def assert_closed(self, result) -> None:
        self.assertAlmostEqual(
            result.root_balance_residual_m3, 0.0, places=10
        )
        self.assertAlmostEqual(
            result.surface_balance_residual_m3, 0.0, places=10
        )
        self.assertAlmostEqual(
            result.groundwater_balance_residual_m3, 0.0, places=10
        )
        self.assertAlmostEqual(
            result.combined_balance_residual_m3, 0.0, places=10
        )

    def test_p1_canonical_root_priority_matches_preregistration(self) -> None:
        r = solve_competing_claims(
            self.config(),
            self.state(root=40.0),
            external_request_m3=20.0,
            priority=PRIORITY_ROOT_FIRST,
        )

        self.assertEqual(r.root_request_m3, 40.0)
        self.assertEqual(r.external_request_m3, 20.0)
        self.assertEqual(r.total_requested_m3, 60.0)
        self.assertEqual(r.regime, "CURTAILED")
        self.assertAlmostEqual(r.total_realized_m3, 32.0, places=12)
        self.assertAlmostEqual(r.root_delivered_m3, 32.0, places=12)
        self.assertAlmostEqual(r.external_delivered_m3, 0.0, places=12)
        self.assertAlmostEqual(r.root_shortage_m3, 8.0, places=12)
        self.assertAlmostEqual(r.external_shortage_m3, 20.0, places=12)
        self.assertAlmostEqual(r.exchange_volume_m3, 28.0, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 72.0, places=12)
        self.assertAlmostEqual(r.end.water.surface_head_m, 0.4, places=12)
        self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.28, places=12)
        self.assertAlmostEqual(r.next_root_request_m3, 8.0, places=12)
        self.assert_closed(r)

    def test_p2_canonical_external_priority_matches_preregistration(self) -> None:
        r = solve_competing_claims(
            self.config(),
            self.state(root=40.0),
            external_request_m3=20.0,
            priority=PRIORITY_EXTERNAL_FIRST,
        )

        self.assertAlmostEqual(r.total_realized_m3, 32.0, places=12)
        self.assertAlmostEqual(r.external_delivered_m3, 20.0, places=12)
        self.assertAlmostEqual(r.root_delivered_m3, 12.0, places=12)
        self.assertAlmostEqual(r.external_shortage_m3, 0.0, places=12)
        self.assertAlmostEqual(r.root_shortage_m3, 28.0, places=12)
        self.assertAlmostEqual(r.exchange_volume_m3, 28.0, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 52.0, places=12)
        self.assertAlmostEqual(r.end.water.surface_head_m, 0.4, places=12)
        self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.28, places=12)
        self.assertAlmostEqual(r.next_root_request_m3, 28.0, places=12)
        self.assert_closed(r)

    def test_p3_priority_reversal_changes_split_not_physical_endpoint(self) -> None:
        c = self.config()
        start = self.state(root=40.0)

        root_first = solve_competing_claims(
            c,
            start,
            external_request_m3=20.0,
            priority=PRIORITY_ROOT_FIRST,
        )
        external_first = solve_competing_claims(
            c,
            start,
            external_request_m3=20.0,
            priority=PRIORITY_EXTERNAL_FIRST,
        )

        self.assertAlmostEqual(
            root_first.total_realized_m3,
            external_first.total_realized_m3,
            places=12,
        )
        self.assertAlmostEqual(
            root_first.exchange_volume_m3,
            external_first.exchange_volume_m3,
            places=12,
        )
        self.assertEqual(root_first.end.water, external_first.end.water)
        self.assertNotEqual(
            root_first.root_delivered_m3,
            external_first.root_delivered_m3,
        )
        self.assertNotEqual(
            root_first.external_delivered_m3,
            external_first.external_delivered_m3,
        )

    def test_p4_priority_changes_combined_system_loss_only_through_external_delivery(self) -> None:
        c = self.config()
        start = self.state(root=40.0)
        initial = total_three_store_water_m3(c, start)

        root_first = solve_competing_claims(
            c, start, external_request_m3=20.0, priority=PRIORITY_ROOT_FIRST
        )
        external_first = solve_competing_claims(
            c, start, external_request_m3=20.0, priority=PRIORITY_EXTERNAL_FIRST
        )

        self.assertAlmostEqual(
            total_three_store_water_m3(c, root_first.end) - initial,
            -root_first.external_delivered_m3,
            places=10,
        )
        self.assertAlmostEqual(
            total_three_store_water_m3(c, external_first.end) - initial,
            -external_first.external_delivered_m3,
            places=10,
        )
        self.assertAlmostEqual(
            total_three_store_water_m3(c, root_first.end) - initial,
            0.0,
            places=10,
        )
        self.assertAlmostEqual(
            total_three_store_water_m3(c, external_first.end) - initial,
            -20.0,
            places=10,
        )

    def test_p5_capacity_between_high_request_and_total_matches_matrix(self) -> None:
        c = self.config()
        start = self.state(root=60.0)

        root_first = solve_competing_claims(
            c, start, external_request_m3=30.0, priority=PRIORITY_ROOT_FIRST
        )
        external_first = solve_competing_claims(
            c, start, external_request_m3=30.0, priority=PRIORITY_EXTERNAL_FIRST
        )

        self.assertAlmostEqual(root_first.total_realized_m3, 32.0, places=12)
        self.assertAlmostEqual(root_first.root_delivered_m3, 20.0, places=12)
        self.assertAlmostEqual(root_first.external_delivered_m3, 12.0, places=12)
        self.assertAlmostEqual(root_first.next_root_request_m3, 0.0, places=12)

        self.assertAlmostEqual(external_first.total_realized_m3, 32.0, places=12)
        self.assertAlmostEqual(external_first.external_delivered_m3, 30.0, places=12)
        self.assertAlmostEqual(external_first.root_delivered_m3, 2.0, places=12)
        self.assertAlmostEqual(external_first.next_root_request_m3, 18.0, places=12)

        self.assertEqual(root_first.end.water, external_first.end.water)
        self.assert_closed(root_first)
        self.assert_closed(external_first)

    def test_p6_when_all_claims_are_realizable_priority_is_irrelevant(self) -> None:
        c = self.config()
        start = self.state(root=70.0)

        root_first = solve_competing_claims(
            c, start, external_request_m3=5.0, priority=PRIORITY_ROOT_FIRST
        )
        external_first = solve_competing_claims(
            c, start, external_request_m3=5.0, priority=PRIORITY_EXTERNAL_FIRST
        )

        for r in (root_first, external_first):
            self.assertEqual(r.regime, "FULL")
            self.assertAlmostEqual(r.total_realized_m3, 15.0, places=12)
            self.assertAlmostEqual(r.root_delivered_m3, 10.0, places=12)
            self.assertAlmostEqual(r.external_delivered_m3, 5.0, places=12)
            self.assertAlmostEqual(r.root_shortage_m3, 0.0, places=12)
            self.assertAlmostEqual(r.external_shortage_m3, 0.0, places=12)
            self.assertAlmostEqual(r.next_root_request_m3, 0.0, places=12)
            self.assert_closed(r)
        self.assertEqual(root_first.end, external_first.end)

    def test_p7_reverse_exchange_scarcity_root_priority_matches_matrix(self) -> None:
        r = solve_competing_claims(
            self.config(hmin=0.0),
            self.state(root=40.0, hs=0.2, hg=0.8),
            external_request_m3=20.0,
            priority=PRIORITY_ROOT_FIRST,
        )

        self.assertEqual(r.regime, "CURTAILED")
        self.assertAlmostEqual(r.total_realized_m3, 48.0, places=12)
        self.assertAlmostEqual(r.exchange_volume_m3, -28.0, places=12)
        self.assertAlmostEqual(r.root_delivered_m3, 40.0, places=12)
        self.assertAlmostEqual(r.external_delivered_m3, 8.0, places=12)
        self.assertAlmostEqual(r.root_shortage_m3, 0.0, places=12)
        self.assertAlmostEqual(r.external_shortage_m3, 12.0, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 80.0, places=12)
        self.assertAlmostEqual(r.end.water.surface_head_m, 0.0, places=12)
        self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.52, places=12)
        self.assertAlmostEqual(r.next_root_request_m3, 0.0, places=12)
        self.assert_closed(r)

    def test_p8_reverse_exchange_scarcity_external_priority_preserves_physics(self) -> None:
        c = self.config(hmin=0.0)
        start = self.state(root=40.0, hs=0.2, hg=0.8)

        root_first = solve_competing_claims(
            c, start, external_request_m3=20.0, priority=PRIORITY_ROOT_FIRST
        )
        external_first = solve_competing_claims(
            c, start, external_request_m3=20.0, priority=PRIORITY_EXTERNAL_FIRST
        )

        self.assertAlmostEqual(external_first.total_realized_m3, 48.0, places=12)
        self.assertAlmostEqual(external_first.exchange_volume_m3, -28.0, places=12)
        self.assertAlmostEqual(external_first.external_delivered_m3, 20.0, places=12)
        self.assertAlmostEqual(external_first.root_delivered_m3, 28.0, places=12)
        self.assertAlmostEqual(external_first.root_shortage_m3, 12.0, places=12)
        self.assertAlmostEqual(external_first.next_root_request_m3, 12.0, places=12)
        self.assertEqual(root_first.end.water, external_first.end.water)
        self.assert_closed(external_first)

    def test_p9_realized_claims_respect_bounds_and_sum_to_exact_capacity(self) -> None:
        for root_storage in (40.0, 60.0, 70.0, 80.0):
            for external_request in (0.0, 5.0, 20.0, 30.0):
                for priority in (PRIORITY_ROOT_FIRST, PRIORITY_EXTERNAL_FIRST):
                    r = solve_competing_claims(
                        self.config(),
                        self.state(root=root_storage),
                        external_request_m3=external_request,
                        priority=priority,
                    )
                    self.assertGreaterEqual(r.root_delivered_m3, 0.0)
                    self.assertGreaterEqual(r.external_delivered_m3, 0.0)
                    self.assertLessEqual(
                        r.root_delivered_m3,
                        r.root_request_m3 + 1.0e-10,
                    )
                    self.assertLessEqual(
                        r.external_delivered_m3,
                        r.external_request_m3 + 1.0e-10,
                    )
                    self.assertAlmostEqual(
                        r.root_delivered_m3 + r.external_delivered_m3,
                        r.total_realized_m3,
                        places=10,
                    )
                    self.assert_closed(r)

    def test_p10_root_memory_tracks_accepted_root_delivery_not_external_shortage(self) -> None:
        c = self.config()
        start = self.state(root=40.0)

        root_first = solve_competing_claims(
            c, start, external_request_m3=20.0, priority=PRIORITY_ROOT_FIRST
        )
        external_first = solve_competing_claims(
            c, start, external_request_m3=20.0, priority=PRIORITY_EXTERNAL_FIRST
        )

        self.assertAlmostEqual(
            root_first.next_root_request_m3,
            root_first.root_shortage_m3,
            places=12,
        )
        self.assertAlmostEqual(
            external_first.next_root_request_m3,
            external_first.root_shortage_m3,
            places=12,
        )
        self.assertNotEqual(
            root_first.external_shortage_m3,
            root_first.next_root_request_m3,
        )

    def test_p11_zero_external_demand_reduces_to_d13_root_only_case(self) -> None:
        c = self.config()
        start = self.state(root=40.0)
        base = solve_three_store_window(c, start)

        for priority in (PRIORITY_ROOT_FIRST, PRIORITY_EXTERNAL_FIRST):
            r = solve_competing_claims(
                c,
                start,
                external_request_m3=0.0,
                priority=priority,
            )
            self.assertAlmostEqual(r.root_request_m3, base.request_m3, places=12)
            self.assertAlmostEqual(r.root_delivered_m3, base.delivered_m3, places=12)
            self.assertAlmostEqual(r.external_delivered_m3, 0.0, places=12)
            self.assertAlmostEqual(
                r.exchange_volume_m3,
                base.exchange_volume_m3,
                places=12,
            )
            self.assertEqual(r.end, base.end)
            self.assertAlmostEqual(
                r.next_root_request_m3,
                base.next_request_m3,
                places=12,
            )

    def test_p12_invalid_external_request_and_priority_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            solve_competing_claims(
                self.config(),
                self.state(root=40.0),
                external_request_m3=-1.0,
                priority=PRIORITY_ROOT_FIRST,
            )
        with self.assertRaises(ValueError):
            solve_competing_claims(
                self.config(),
                self.state(root=40.0),
                external_request_m3=20.0,
                priority="UNKNOWN",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
