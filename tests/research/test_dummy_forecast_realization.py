from __future__ import annotations

import unittest

from dummy_competing_claims import (
    PRIORITY_EXTERNAL_FIRST,
    PRIORITY_ROOT_FIRST,
)
from dummy_forecast_realization import (
    POLICY_PRIORITY_PRESERVING,
    POLICY_PROPORTIONAL,
    solve_forecast_realization,
)
from dummy_rootzone_demand import RootZoneConfig, RootZoneState
from dummy_three_store_internal_ledger import (
    ThreeStoreConfig,
    ThreeStoreState,
    total_three_store_water_m3,
)
from dummy_two_store_exchange import TwoStoreConfig, TwoStoreState


class ForecastRealizationTests(unittest.TestCase):
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
            dt=1.0,
            management_min_surface_head_m=0.4,
            surface_datum_m=0.0,
        )

    def state(self) -> ThreeStoreState:
        return ThreeStoreState(
            root=RootZoneState(40.0),
            water=TwoStoreState(1.0, 0.0),
        )

    def solve(
        self,
        *,
        forecast: float,
        priority: str,
        policy: str,
    ):
        return solve_forecast_realization(
            self.config(),
            self.state(),
            external_demand_m3=20.0,
            forecast_capacity_m3=forecast,
            priority=priority,
            realization_policy=policy,
        )

    def assert_closed(self, result) -> None:
        self.assertAlmostEqual(result.root_balance_residual_m3, 0.0, places=10)
        self.assertAlmostEqual(result.surface_balance_residual_m3, 0.0, places=10)
        self.assertAlmostEqual(result.groundwater_balance_residual_m3, 0.0, places=10)
        self.assertAlmostEqual(result.combined_balance_residual_m3, 0.0, places=10)

    def test_b1_canonical_root_first_priority_preserving(self) -> None:
        r = self.solve(
            forecast=60.0,
            priority=PRIORITY_ROOT_FIRST,
            policy=POLICY_PRIORITY_PRESERVING,
        )

        self.assertEqual(r.root_demand_m3, 40.0)
        self.assertEqual(r.external_demand_m3, 20.0)
        self.assertEqual(r.allocated.root_m3, 40.0)
        self.assertEqual(r.allocated.external_m3, 20.0)
        self.assertAlmostEqual(r.physical_supplied_total_m3, 32.0, places=12)
        self.assertAlmostEqual(r.supplied.root_m3, 32.0, places=12)
        self.assertAlmostEqual(r.supplied.external_m3, 0.0, places=12)
        self.assertAlmostEqual(r.realization_shortfall.root_m3, 8.0, places=12)
        self.assertAlmostEqual(r.realization_shortfall.external_m3, 20.0, places=12)
        self.assertAlmostEqual(r.exchange_volume_m3, 28.0, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 72.0, places=12)
        self.assertAlmostEqual(r.end.water.surface_head_m, 0.4, places=12)
        self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.28, places=12)
        self.assertAlmostEqual(r.next_root_request_m3, 8.0, places=12)
        self.assert_closed(r)

    def test_b2_canonical_external_first_priority_preserving(self) -> None:
        r = self.solve(
            forecast=60.0,
            priority=PRIORITY_EXTERNAL_FIRST,
            policy=POLICY_PRIORITY_PRESERVING,
        )

        self.assertEqual(r.allocated.external_m3, 20.0)
        self.assertEqual(r.allocated.root_m3, 40.0)
        self.assertAlmostEqual(r.physical_supplied_total_m3, 32.0, places=12)
        self.assertAlmostEqual(r.supplied.external_m3, 20.0, places=12)
        self.assertAlmostEqual(r.supplied.root_m3, 12.0, places=12)
        self.assertAlmostEqual(r.realization_shortfall.external_m3, 0.0, places=12)
        self.assertAlmostEqual(r.realization_shortfall.root_m3, 28.0, places=12)
        self.assertAlmostEqual(r.exchange_volume_m3, 28.0, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 52.0, places=12)
        self.assertAlmostEqual(r.next_root_request_m3, 28.0, places=12)
        self.assert_closed(r)

    def test_b3_canonical_proportional_policy_matches_preregistration(self) -> None:
        expected_root = 40.0 * 32.0 / 60.0
        expected_external = 20.0 * 32.0 / 60.0

        for priority in (PRIORITY_ROOT_FIRST, PRIORITY_EXTERNAL_FIRST):
            r = self.solve(
                forecast=60.0,
                priority=priority,
                policy=POLICY_PROPORTIONAL,
            )
            self.assertAlmostEqual(r.physical_supplied_total_m3, 32.0, places=12)
            self.assertAlmostEqual(r.supplied.root_m3, expected_root, places=11)
            self.assertAlmostEqual(r.supplied.external_m3, expected_external, places=11)
            self.assertAlmostEqual(
                r.end.root.storage_m3,
                40.0 + expected_root,
                places=11,
            )
            self.assertAlmostEqual(
                r.next_root_request_m3,
                80.0 - (40.0 + expected_root),
                places=11,
            )
            self.assertAlmostEqual(r.exchange_volume_m3, 28.0, places=12)
            self.assertAlmostEqual(r.end.water.surface_head_m, 0.4, places=12)
            self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.28, places=12)
            self.assert_closed(r)

    def test_b4_realization_policy_changes_recipient_state_not_physical_endpoint(self) -> None:
        p = self.solve(
            forecast=60.0,
            priority=PRIORITY_ROOT_FIRST,
            policy=POLICY_PRIORITY_PRESERVING,
        )
        q = self.solve(
            forecast=60.0,
            priority=PRIORITY_ROOT_FIRST,
            policy=POLICY_PROPORTIONAL,
        )

        self.assertAlmostEqual(
            p.physical_supplied_total_m3,
            q.physical_supplied_total_m3,
            places=12,
        )
        self.assertAlmostEqual(
            p.exchange_volume_m3,
            q.exchange_volume_m3,
            places=12,
        )
        self.assertEqual(p.end.water, q.end.water)
        self.assertNotAlmostEqual(
            p.supplied.root_m3,
            q.supplied.root_m3,
            places=9,
        )
        self.assertNotAlmostEqual(
            p.next_root_request_m3,
            q.next_root_request_m3,
            places=9,
        )

    def test_b5_underallocation_root_first_cannot_create_unallocated_supply(self) -> None:
        for policy in (POLICY_PRIORITY_PRESERVING, POLICY_PROPORTIONAL):
            r = self.solve(
                forecast=20.0,
                priority=PRIORITY_ROOT_FIRST,
                policy=policy,
            )
            self.assertEqual(r.allocated.root_m3, 20.0)
            self.assertEqual(r.allocated.external_m3, 0.0)
            self.assertAlmostEqual(r.physical_supplied_total_m3, 20.0, places=12)
            self.assertAlmostEqual(r.supplied.root_m3, 20.0, places=12)
            self.assertAlmostEqual(r.supplied.external_m3, 0.0, places=12)
            self.assertEqual(r.regime, "FULL")
            self.assertAlmostEqual(r.exchange_volume_m3, 30.0, places=12)
            self.assertAlmostEqual(r.end.water.surface_head_m, 0.5, places=12)
            self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.3, places=12)
            self.assert_closed(r)

    def test_b6_underallocation_external_first_cannot_create_unallocated_supply(self) -> None:
        for policy in (POLICY_PRIORITY_PRESERVING, POLICY_PROPORTIONAL):
            r = self.solve(
                forecast=20.0,
                priority=PRIORITY_EXTERNAL_FIRST,
                policy=policy,
            )
            self.assertEqual(r.allocated.external_m3, 20.0)
            self.assertEqual(r.allocated.root_m3, 0.0)
            self.assertAlmostEqual(r.physical_supplied_total_m3, 20.0, places=12)
            self.assertAlmostEqual(r.supplied.external_m3, 20.0, places=12)
            self.assertAlmostEqual(r.supplied.root_m3, 0.0, places=12)
            self.assertAlmostEqual(r.end.root.storage_m3, 40.0, places=12)
            self.assertAlmostEqual(r.next_root_request_m3, 40.0, places=12)
            self.assertAlmostEqual(r.exchange_volume_m3, 30.0, places=12)
            self.assert_closed(r)

    def test_b7_partial_forecast_root_first_policy_contrast(self) -> None:
        p = self.solve(
            forecast=45.0,
            priority=PRIORITY_ROOT_FIRST,
            policy=POLICY_PRIORITY_PRESERVING,
        )
        q = self.solve(
            forecast=45.0,
            priority=PRIORITY_ROOT_FIRST,
            policy=POLICY_PROPORTIONAL,
        )

        self.assertEqual(p.allocated.root_m3, 40.0)
        self.assertEqual(p.allocated.external_m3, 5.0)
        self.assertAlmostEqual(p.physical_supplied_total_m3, 32.0, places=12)
        self.assertAlmostEqual(p.supplied.root_m3, 32.0, places=12)
        self.assertAlmostEqual(p.supplied.external_m3, 0.0, places=12)

        self.assertAlmostEqual(q.supplied.root_m3, 40.0 * 32.0 / 45.0, places=11)
        self.assertAlmostEqual(q.supplied.external_m3, 5.0 * 32.0 / 45.0, places=11)
        self.assertEqual(p.end.water, q.end.water)
        self.assert_closed(p)
        self.assert_closed(q)

    def test_b8_partial_forecast_external_first_policy_contrast(self) -> None:
        p = self.solve(
            forecast=45.0,
            priority=PRIORITY_EXTERNAL_FIRST,
            policy=POLICY_PRIORITY_PRESERVING,
        )
        q = self.solve(
            forecast=45.0,
            priority=PRIORITY_EXTERNAL_FIRST,
            policy=POLICY_PROPORTIONAL,
        )

        self.assertEqual(p.allocated.external_m3, 20.0)
        self.assertEqual(p.allocated.root_m3, 25.0)
        self.assertAlmostEqual(p.supplied.external_m3, 20.0, places=12)
        self.assertAlmostEqual(p.supplied.root_m3, 12.0, places=12)

        self.assertAlmostEqual(q.supplied.external_m3, 20.0 * 32.0 / 45.0, places=11)
        self.assertAlmostEqual(q.supplied.root_m3, 25.0 * 32.0 / 45.0, places=11)
        self.assertEqual(p.end.water, q.end.water)
        self.assert_closed(p)
        self.assert_closed(q)

    def test_b9_exact_forecast_capacity_sweep_matches_piecewise_physics(self) -> None:
        for forecast in (0.0, 5.0, 20.0, 31.0, 32.0, 33.0, 40.0, 45.0, 60.0):
            r = self.solve(
                forecast=forecast,
                priority=PRIORITY_ROOT_FIRST,
                policy=POLICY_PRIORITY_PRESERVING,
            )
            allocated_total = min(forecast, 60.0)
            expected_supplied = min(allocated_total, 32.0)
            self.assertAlmostEqual(
                r.physical_supplied_total_m3,
                expected_supplied,
                places=10,
            )
            if allocated_total <= 32.0:
                expected_v = 100.0 / 3.0 - allocated_total / 6.0
                self.assertEqual(r.regime, "FULL")
                self.assertAlmostEqual(r.exchange_volume_m3, expected_v, places=10)
            else:
                self.assertEqual(r.regime, "CURTAILED")
                self.assertAlmostEqual(r.exchange_volume_m3, 28.0, places=10)
                self.assertAlmostEqual(r.end.water.surface_head_m, 0.4, places=10)
                self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.28, places=10)
            self.assert_closed(r)

    def test_b10_root_first_policy_divergence_begins_only_after_40(self) -> None:
        for forecast in (32.0, 33.0, 40.0):
            p = self.solve(
                forecast=forecast,
                priority=PRIORITY_ROOT_FIRST,
                policy=POLICY_PRIORITY_PRESERVING,
            )
            q = self.solve(
                forecast=forecast,
                priority=PRIORITY_ROOT_FIRST,
                policy=POLICY_PROPORTIONAL,
            )
            self.assertAlmostEqual(p.supplied.root_m3, q.supplied.root_m3, places=10)
            self.assertAlmostEqual(p.supplied.external_m3, q.supplied.external_m3, places=10)

        p45 = self.solve(
            forecast=45.0,
            priority=PRIORITY_ROOT_FIRST,
            policy=POLICY_PRIORITY_PRESERVING,
        )
        q45 = self.solve(
            forecast=45.0,
            priority=PRIORITY_ROOT_FIRST,
            policy=POLICY_PROPORTIONAL,
        )
        self.assertNotAlmostEqual(p45.supplied.external_m3, q45.supplied.external_m3, places=9)

    def test_b11_external_first_policy_divergence_begins_above_32(self) -> None:
        p32 = self.solve(
            forecast=32.0,
            priority=PRIORITY_EXTERNAL_FIRST,
            policy=POLICY_PRIORITY_PRESERVING,
        )
        q32 = self.solve(
            forecast=32.0,
            priority=PRIORITY_EXTERNAL_FIRST,
            policy=POLICY_PROPORTIONAL,
        )
        self.assertAlmostEqual(p32.supplied.root_m3, q32.supplied.root_m3, places=10)
        self.assertAlmostEqual(p32.supplied.external_m3, q32.supplied.external_m3, places=10)

        p33 = self.solve(
            forecast=33.0,
            priority=PRIORITY_EXTERNAL_FIRST,
            policy=POLICY_PRIORITY_PRESERVING,
        )
        q33 = self.solve(
            forecast=33.0,
            priority=PRIORITY_EXTERNAL_FIRST,
            policy=POLICY_PROPORTIONAL,
        )
        self.assertNotAlmostEqual(p33.supplied.root_m3, q33.supplied.root_m3, places=9)
        self.assertNotAlmostEqual(p33.supplied.external_m3, q33.supplied.external_m3, places=9)

    def test_b12_allocated_but_unsupplied_water_never_enters_state(self) -> None:
        r = self.solve(
            forecast=60.0,
            priority=PRIORITY_ROOT_FIRST,
            policy=POLICY_PRIORITY_PRESERVING,
        )
        self.assertEqual(r.allocated.root_m3, 40.0)
        self.assertEqual(r.allocated.external_m3, 20.0)
        self.assertAlmostEqual(r.supplied.root_m3, 32.0, places=12)
        self.assertAlmostEqual(r.supplied.external_m3, 0.0, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 40.0 + 32.0, places=12)

        initial_total = total_three_store_water_m3(self.config(), self.state())
        final_total = total_three_store_water_m3(self.config(), r.end)
        self.assertAlmostEqual(
            final_total - initial_total,
            -r.supplied.external_m3,
            places=10,
        )

    def test_b13_dense_bounds_and_ledgers_for_both_policies(self) -> None:
        for forecast in (0.0, 5.0, 20.0, 31.0, 32.0, 33.0, 40.0, 45.0, 60.0, 100.0):
            for priority in (PRIORITY_ROOT_FIRST, PRIORITY_EXTERNAL_FIRST):
                for policy in (POLICY_PRIORITY_PRESERVING, POLICY_PROPORTIONAL):
                    r = self.solve(
                        forecast=forecast,
                        priority=priority,
                        policy=policy,
                    )
                    self.assertGreaterEqual(r.allocated.root_m3, 0.0)
                    self.assertGreaterEqual(r.allocated.external_m3, 0.0)
                    self.assertLessEqual(r.allocated.root_m3, r.root_demand_m3 + 1.0e-10)
                    self.assertLessEqual(
                        r.allocated.external_m3,
                        r.external_demand_m3 + 1.0e-10,
                    )
                    self.assertGreaterEqual(r.supplied.root_m3, 0.0)
                    self.assertGreaterEqual(r.supplied.external_m3, 0.0)
                    self.assertLessEqual(
                        r.supplied.root_m3,
                        r.allocated.root_m3 + 1.0e-10,
                    )
                    self.assertLessEqual(
                        r.supplied.external_m3,
                        r.allocated.external_m3 + 1.0e-10,
                    )
                    self.assertAlmostEqual(
                        r.supplied.root_m3 + r.supplied.external_m3,
                        r.physical_supplied_total_m3,
                        places=9,
                    )
                    self.assert_closed(r)

    def test_b14_zero_forecast_allocates_no_management_but_physics_still_exchanges(self) -> None:
        for priority in (PRIORITY_ROOT_FIRST, PRIORITY_EXTERNAL_FIRST):
            for policy in (POLICY_PRIORITY_PRESERVING, POLICY_PROPORTIONAL):
                r = self.solve(
                    forecast=0.0,
                    priority=priority,
                    policy=policy,
                )
                self.assertEqual(r.allocated.total_m3, 0.0)
                self.assertEqual(r.supplied.total_m3, 0.0)
                self.assertAlmostEqual(r.end.root.storage_m3, 40.0, places=12)
                self.assertAlmostEqual(r.next_root_request_m3, 40.0, places=12)
                self.assertAlmostEqual(
                    r.exchange_volume_m3,
                    100.0 / 3.0,
                    places=10,
                )
                self.assertAlmostEqual(
                    r.end.water.surface_head_m,
                    2.0 / 3.0,
                    places=10,
                )
                self.assertAlmostEqual(
                    r.end.water.groundwater_head_m,
                    1.0 / 3.0,
                    places=10,
                )
                self.assert_closed(r)

    def test_b15_invalid_inputs_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            solve_forecast_realization(
                self.config(),
                self.state(),
                external_demand_m3=-1.0,
                forecast_capacity_m3=20.0,
                priority=PRIORITY_ROOT_FIRST,
                realization_policy=POLICY_PRIORITY_PRESERVING,
            )
        with self.assertRaises(ValueError):
            solve_forecast_realization(
                self.config(),
                self.state(),
                external_demand_m3=20.0,
                forecast_capacity_m3=-1.0,
                priority=PRIORITY_ROOT_FIRST,
                realization_policy=POLICY_PRIORITY_PRESERVING,
            )
        with self.assertRaises(ValueError):
            solve_forecast_realization(
                self.config(),
                self.state(),
                external_demand_m3=20.0,
                forecast_capacity_m3=20.0,
                priority="UNKNOWN",
                realization_policy=POLICY_PRIORITY_PRESERVING,
            )
        with self.assertRaises(ValueError):
            solve_forecast_realization(
                self.config(),
                self.state(),
                external_demand_m3=20.0,
                forecast_capacity_m3=20.0,
                priority=PRIORITY_ROOT_FIRST,
                realization_policy="UNKNOWN",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
