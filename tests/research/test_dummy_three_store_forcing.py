from __future__ import annotations

import unittest

from dummy_rootzone_demand import RootZoneConfig, RootZoneInfeasibleLossError, RootZoneState
from dummy_three_store_forcing import (
    ThreeStoreRootForcing,
    run_forced_three_store_sequence,
    solve_forced_three_store_window,
)
from dummy_three_store_internal_ledger import (
    ThreeStoreConfig,
    ThreeStoreState,
    solve_three_store_window,
    total_three_store_water_m3,
)
from dummy_two_store_exchange import TwoStoreConfig, TwoStoreState


class ThreeStoreForcingMemoryTests(unittest.TestCase):
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

    def test_f1_rain_erases_next_demand_despite_current_shortage(self) -> None:
        c = self.config()
        start = self.state(root=40.0)
        r = solve_forced_three_store_window(
            c,
            start,
            ThreeStoreRootForcing(rainfall_m3=20.0),
        )

        self.assertEqual(r.request_m3, 40.0)
        self.assertEqual(r.regime, "CURTAILED")
        self.assertAlmostEqual(r.delivered_m3, 32.0, places=12)
        self.assertAlmostEqual(r.shortage_m3, 8.0, places=12)
        self.assertAlmostEqual(r.exchange_volume_m3, 28.0, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 92.0, places=12)
        self.assertAlmostEqual(r.end.water.surface_head_m, 0.4, places=12)
        self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.28, places=12)
        self.assertAlmostEqual(r.next_request_m3, 0.0, places=12)
        self.assertAlmostEqual(r.drainage_m3, 0.0, places=12)
        self.assertAlmostEqual(
            total_three_store_water_m3(c, r.end)
            - total_three_store_water_m3(c, start),
            20.0,
            places=12,
        )
        self.assert_closed(r)

    def test_f2_root_loss_amplifies_next_deficit_beyond_current_shortage(self) -> None:
        r = solve_forced_three_store_window(
            self.config(),
            self.state(root=40.0),
            ThreeStoreRootForcing(prescribed_loss_m3=10.0),
        )

        self.assertEqual(r.request_m3, 40.0)
        self.assertAlmostEqual(r.delivered_m3, 32.0, places=12)
        self.assertAlmostEqual(r.shortage_m3, 8.0, places=12)
        self.assertAlmostEqual(r.exchange_volume_m3, 28.0, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 62.0, places=12)
        self.assertAlmostEqual(r.next_request_m3, 18.0, places=12)
        self.assertAlmostEqual(r.drainage_m3, 0.0, places=12)
        self.assert_closed(r)

    def test_f3_capacity_excess_is_explicit_external_drainage(self) -> None:
        c = self.config(target=90.0, hmin=0.0)
        start = self.state(root=90.0)
        r = solve_forced_three_store_window(
            c,
            start,
            ThreeStoreRootForcing(
                rainfall_m3=25.0,
                prescribed_loss_m3=5.0,
            ),
        )

        self.assertEqual(r.request_m3, 0.0)
        self.assertEqual(r.delivered_m3, 0.0)
        self.assertEqual(r.shortage_m3, 0.0)
        self.assertAlmostEqual(r.end.root.storage_m3, 100.0, places=12)
        self.assertAlmostEqual(r.drainage_m3, 10.0, places=12)
        self.assertAlmostEqual(r.next_request_m3, 0.0, places=12)
        self.assertAlmostEqual(
            total_three_store_water_m3(c, r.end)
            - total_three_store_water_m3(c, start),
            10.0,
            places=12,
        )
        self.assert_closed(r)

    def test_f4_zero_root_forcing_reproduces_qualified_d13_window(self) -> None:
        c = self.config()
        start = self.state(root=40.0)

        base = solve_three_store_window(c, start)
        forced = solve_forced_three_store_window(
            c,
            start,
            ThreeStoreRootForcing(),
        )

        self.assertEqual(forced.request_m3, base.request_m3)
        self.assertEqual(forced.regime, base.regime)
        self.assertAlmostEqual(forced.delivered_m3, base.delivered_m3, places=12)
        self.assertAlmostEqual(forced.shortage_m3, base.shortage_m3, places=12)
        self.assertAlmostEqual(
            forced.exchange_volume_m3,
            base.exchange_volume_m3,
            places=12,
        )
        self.assertEqual(forced.end, base.end)
        self.assertAlmostEqual(
            forced.next_request_m3,
            base.next_request_m3,
            places=12,
        )
        self.assert_closed(forced)

    def test_f5_same_window_water_solution_is_independent_of_postdecision_root_forcing(self) -> None:
        c = self.config()
        start = self.state(root=40.0)

        cases = [
            ThreeStoreRootForcing(),
            ThreeStoreRootForcing(rainfall_m3=20.0),
            ThreeStoreRootForcing(prescribed_loss_m3=10.0),
            ThreeStoreRootForcing(rainfall_m3=5.0, prescribed_loss_m3=7.0),
        ]
        results = [
            solve_forced_three_store_window(c, start, forcing)
            for forcing in cases
        ]

        reference = results[0]
        for result in results[1:]:
            self.assertEqual(result.request_m3, reference.request_m3)
            self.assertEqual(result.regime, reference.regime)
            self.assertAlmostEqual(
                result.delivered_m3,
                reference.delivered_m3,
                places=12,
            )
            self.assertAlmostEqual(
                result.shortage_m3,
                reference.shortage_m3,
                places=12,
            )
            self.assertAlmostEqual(
                result.exchange_volume_m3,
                reference.exchange_volume_m3,
                places=12,
            )
            self.assertEqual(result.end.water, reference.end.water)

    def test_f6_same_current_shortage_can_map_to_zero_equal_or_larger_next_request(self) -> None:
        c = self.config()
        start = self.state(root=40.0)

        rain = solve_forced_three_store_window(
            c, start, ThreeStoreRootForcing(rainfall_m3=20.0)
        )
        neutral = solve_forced_three_store_window(
            c, start, ThreeStoreRootForcing()
        )
        loss = solve_forced_three_store_window(
            c, start, ThreeStoreRootForcing(prescribed_loss_m3=10.0)
        )

        self.assertAlmostEqual(rain.shortage_m3, 8.0, places=12)
        self.assertAlmostEqual(neutral.shortage_m3, 8.0, places=12)
        self.assertAlmostEqual(loss.shortage_m3, 8.0, places=12)

        self.assertAlmostEqual(rain.next_request_m3, 0.0, places=12)
        self.assertAlmostEqual(neutral.next_request_m3, 8.0, places=12)
        self.assertAlmostEqual(loss.next_request_m3, 18.0, places=12)

    def test_f7_multiwindow_combined_ledger_retains_only_external_root_terms(self) -> None:
        c = self.config()
        result = run_forced_three_store_sequence(
            c,
            initial=self.state(root=40.0),
            forcings=[
                ThreeStoreRootForcing(rainfall_m3=20.0),
                ThreeStoreRootForcing(prescribed_loss_m3=10.0),
                ThreeStoreRootForcing(prescribed_loss_m3=10.0),
            ],
        )

        for window in result.windows:
            self.assert_closed(window)
        self.assert_closed(result)

        expected_change = (
            result.cumulative_rainfall_m3
            - result.cumulative_prescribed_loss_m3
            - result.cumulative_drainage_m3
        )
        actual_change = (
            total_three_store_water_m3(c, result.final)
            - total_three_store_water_m3(c, result.initial)
        )
        self.assertAlmostEqual(actual_change, expected_change, places=10)

    def test_f8_identical_committed_state_and_forcing_imply_identical_future_problem(self) -> None:
        c = self.config()
        forcing = ThreeStoreRootForcing(
            rainfall_m3=3.0,
            prescribed_loss_m3=2.0,
        )
        a = solve_forced_three_store_window(
            c,
            self.state(root=72.0, hs=0.4, hg=0.28),
            forcing,
        )
        b = solve_forced_three_store_window(
            c,
            ThreeStoreState(
                root=RootZoneState(72.0),
                water=TwoStoreState(0.4, 0.28),
            ),
            forcing,
        )

        self.assertEqual(a.request_m3, b.request_m3)
        self.assertEqual(a.regime, b.regime)
        self.assertAlmostEqual(a.delivered_m3, b.delivered_m3, places=12)
        self.assertAlmostEqual(
            a.exchange_volume_m3,
            b.exchange_volume_m3,
            places=12,
        )
        self.assertEqual(a.end, b.end)
        self.assertEqual(a.next_request_m3, b.next_request_m3)

    def test_f9_dense_forcing_grid_preserves_combined_ledger(self) -> None:
        c = self.config()
        start = self.state(root=40.0)

        for rainfall in (0.0, 5.0, 20.0):
            for loss in (0.0, 5.0, 10.0):
                result = solve_forced_three_store_window(
                    c,
                    start,
                    ThreeStoreRootForcing(
                        rainfall_m3=rainfall,
                        prescribed_loss_m3=loss,
                    ),
                )
                expected = rainfall - loss - result.drainage_m3
                actual = (
                    total_three_store_water_m3(c, result.end)
                    - total_three_store_water_m3(c, start)
                )
                self.assertAlmostEqual(actual, expected, places=10)
                self.assert_closed(result)

    def test_f10_external_root_forcing_does_not_change_transfer_sign_convention(self) -> None:
        c = self.config(hmin=0.0)
        start = self.state(root=80.0, hs=0.2, hg=0.8)
        r = solve_forced_three_store_window(
            c,
            start,
            ThreeStoreRootForcing(rainfall_m3=5.0),
        )

        self.assertEqual(r.request_m3, 0.0)
        self.assertAlmostEqual(r.exchange_volume_m3, -20.0, places=12)
        self.assertAlmostEqual(r.end.water.surface_head_m, 0.4, places=12)
        self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.6, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 85.0, places=12)
        self.assert_closed(r)

    def test_f11_infeasible_root_loss_fails_closed_without_borrowing_from_other_stores(self) -> None:
        c = self.config(hmin=0.4)
        start = self.state(root=10.0, hs=0.5, hg=0.0)
        snapshot = start

        with self.assertRaises(RootZoneInfeasibleLossError):
            solve_forced_three_store_window(
                c,
                start,
                ThreeStoreRootForcing(prescribed_loss_m3=11.0),
            )

        self.assertEqual(start, snapshot)

    def test_f12_invalid_forcing_and_empty_sequence_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            ThreeStoreRootForcing(rainfall_m3=-1.0)
        with self.assertRaises(ValueError):
            ThreeStoreRootForcing(prescribed_loss_m3=-1.0)
        with self.assertRaises(ValueError):
            run_forced_three_store_sequence(
                self.config(),
                initial=self.state(root=40.0),
                forcings=[],
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
