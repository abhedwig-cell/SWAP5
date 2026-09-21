from __future__ import annotations

import unittest

from dummy_rootzone_demand import RootZoneConfig, RootZoneState
from dummy_three_store_internal_ledger import (
    ThreeStoreConfig,
    ThreeStoreState,
    run_three_store_sequence,
    solve_three_store_window,
    total_three_store_water_m3,
)
from dummy_two_store_exchange import TwoStoreConfig, TwoStoreState
from dummy_two_store_management import TwoStorePhysicalInfeasibleError


class ThreeStoreInternalLedgerTests(unittest.TestCase):
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

    def test_t1_canonical_curtailed_case_matches_preregistration(self) -> None:
        c = self.config()
        start = self.state(root=40.0)
        r = solve_three_store_window(c, start)

        self.assertEqual(r.request_m3, 40.0)
        self.assertEqual(r.regime, "CURTAILED")
        self.assertAlmostEqual(r.delivered_m3, 32.0, places=12)
        self.assertAlmostEqual(r.shortage_m3, 8.0, places=12)
        self.assertAlmostEqual(r.exchange_volume_m3, 28.0, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 72.0, places=12)
        self.assertAlmostEqual(r.end.water.surface_head_m, 0.4, places=12)
        self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.28, places=12)
        self.assertAlmostEqual(r.next_request_m3, 8.0, places=12)
        self.assertAlmostEqual(
            total_three_store_water_m3(c, start),
            140.0,
            places=12,
        )
        self.assertAlmostEqual(
            total_three_store_water_m3(c, r.end),
            140.0,
            places=12,
        )
        self.assert_closed(r)

    def test_t2_preregistered_full_case(self) -> None:
        r = solve_three_store_window(
            self.config(),
            self.state(root=70.0),
        )

        self.assertEqual(r.request_m3, 10.0)
        self.assertEqual(r.regime, "FULL")
        self.assertAlmostEqual(r.delivered_m3, 10.0, places=12)
        self.assertAlmostEqual(r.shortage_m3, 0.0, places=12)
        self.assertAlmostEqual(
            r.exchange_volume_m3,
            31.666666666666668,
            places=11,
        )
        self.assertAlmostEqual(r.end.root.storage_m3, 80.0, places=12)
        self.assertAlmostEqual(
            r.end.water.surface_head_m,
            0.5833333333333333,
            places=11,
        )
        self.assertAlmostEqual(
            r.end.water.groundwater_head_m,
            0.31666666666666665,
            places=11,
        )
        self.assertAlmostEqual(r.next_request_m3, 0.0, places=12)
        self.assert_closed(r)

    def test_t3_preregistered_zero_case(self) -> None:
        r = solve_three_store_window(
            self.config(),
            self.state(root=60.0, hs=0.5, hg=0.0),
        )

        self.assertEqual(r.request_m3, 20.0)
        self.assertEqual(r.regime, "ZERO")
        self.assertAlmostEqual(r.delivered_m3, 0.0, places=12)
        self.assertAlmostEqual(r.shortage_m3, 20.0, places=12)
        self.assertAlmostEqual(
            r.exchange_volume_m3,
            16.666666666666668,
            places=11,
        )
        self.assertAlmostEqual(r.end.root.storage_m3, 60.0, places=12)
        self.assertAlmostEqual(
            r.end.water.surface_head_m,
            0.3333333333333333,
            places=11,
        )
        self.assertAlmostEqual(
            r.end.water.groundwater_head_m,
            0.16666666666666669,
            places=11,
        )
        self.assertAlmostEqual(r.next_request_m3, 20.0, places=12)
        self.assert_closed(r)

    def test_t4_reverse_groundwater_to_surface_exchange_closes_same_ledger(self) -> None:
        r = solve_three_store_window(
            self.config(hmin=0.0),
            self.state(root=80.0, hs=0.2, hg=0.8),
        )

        self.assertEqual(r.request_m3, 0.0)
        self.assertEqual(r.regime, "FULL")
        self.assertAlmostEqual(r.delivered_m3, 0.0, places=12)
        self.assertAlmostEqual(r.exchange_volume_m3, -20.0, places=12)
        self.assertAlmostEqual(r.end.root.storage_m3, 80.0, places=12)
        self.assertAlmostEqual(r.end.water.surface_head_m, 0.4, places=12)
        self.assertAlmostEqual(r.end.water.groundwater_head_m, 0.6, places=12)
        self.assertAlmostEqual(r.next_request_m3, 0.0, places=12)
        self.assert_closed(r)

    def test_t5_canonical_second_window_has_zero_management_and_continued_exchange(self) -> None:
        result = run_three_store_sequence(
            self.config(),
            initial=self.state(root=40.0),
            steps=2,
        )
        first, second = result.windows

        self.assertEqual(first.regime, "CURTAILED")
        self.assertAlmostEqual(first.delivered_m3, 32.0, places=12)

        self.assertEqual(second.request_m3, 8.0)
        self.assertEqual(second.regime, "ZERO")
        self.assertAlmostEqual(second.delivered_m3, 0.0, places=12)
        self.assertAlmostEqual(second.shortage_m3, 8.0, places=12)
        self.assertAlmostEqual(second.exchange_volume_m3, 4.0, places=12)
        self.assertAlmostEqual(second.end.root.storage_m3, 72.0, places=12)
        self.assertAlmostEqual(
            second.end.water.surface_head_m, 0.36, places=12
        )
        self.assertAlmostEqual(
            second.end.water.groundwater_head_m, 0.32, places=12
        )
        self.assertAlmostEqual(second.next_request_m3, 8.0, places=12)
        self.assert_closed(first)
        self.assert_closed(second)
        self.assert_closed(result)

    def test_t6_irrigation_and_exchange_cancel_from_combined_ledger_over_regimes(self) -> None:
        cases = (
            (self.config(), self.state(root=40.0)),
            (self.config(), self.state(root=70.0)),
            (self.config(), self.state(root=60.0, hs=0.5, hg=0.0)),
            (self.config(hmin=0.0), self.state(root=80.0, hs=0.2, hg=0.8)),
        )

        for c, start in cases:
            result = solve_three_store_window(c, start)
            self.assertAlmostEqual(
                total_three_store_water_m3(c, result.end),
                total_three_store_water_m3(c, start),
                places=10,
            )
            self.assert_closed(result)

    def test_t7_no_forcing_next_root_deficit_equals_current_shortage(self) -> None:
        for root_storage in (40.0, 60.0, 70.0, 80.0):
            r = solve_three_store_window(
                self.config(),
                self.state(root=root_storage),
            )
            self.assertAlmostEqual(
                r.next_request_m3,
                r.shortage_m3,
                places=10,
            )

    def test_t8_identical_committed_state_implies_identical_future_solution(self) -> None:
        c = self.config()
        state_a = self.state(root=72.0, hs=0.4, hg=0.28)
        state_b = ThreeStoreState(
            root=RootZoneState(72.0),
            water=TwoStoreState(0.4, 0.28),
        )

        a = solve_three_store_window(c, state_a)
        b = solve_three_store_window(c, state_b)

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

    def test_t9_same_window_delivery_does_not_generate_second_request(self) -> None:
        r = solve_three_store_window(
            self.config(),
            self.state(root=40.0),
        )

        self.assertEqual(r.request_m3, 40.0)
        self.assertEqual(r.delivered_m3, 32.0)
        self.assertEqual(r.next_request_m3, 8.0)
        self.assertEqual(r.shortage_m3, 8.0)

    def test_t10_underlying_physical_infeasibility_fails_without_state_mutation(self) -> None:
        c = self.config(hmin=0.0)
        start = self.state(root=80.0, hs=0.1, hg=-10.0)
        snapshot = start

        with self.assertRaises(TwoStorePhysicalInfeasibleError):
            solve_three_store_window(c, start)

        self.assertEqual(start, snapshot)

    def test_t11_dense_state_grid_preserves_internal_transfer_identity(self) -> None:
        for root_storage in (40.0, 60.0, 70.0, 80.0):
            for surface_head in (0.6, 1.0):
                for groundwater_head in (0.0, 0.4, 0.8):
                    c = self.config(hmin=0.2)
                    start = self.state(
                        root=root_storage,
                        hs=surface_head,
                        hg=groundwater_head,
                    )
                    result = solve_three_store_window(c, start)

                    self.assertGreaterEqual(result.delivered_m3, 0.0)
                    self.assertLessEqual(result.delivered_m3, result.request_m3)
                    self.assertAlmostEqual(
                        total_three_store_water_m3(c, result.end),
                        total_three_store_water_m3(c, start),
                        places=9,
                    )
                    self.assert_closed(result)

    def test_t12_invalid_inputs_and_sequence_length_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            ThreeStoreConfig(
                root=RootZoneConfig(100.0, 80.0),
                stores=TwoStoreConfig(100.0, 100.0, 50.0),
                dt=0.0,
                management_min_surface_head_m=0.4,
            )
        with self.assertRaises(ValueError):
            run_three_store_sequence(
                self.config(),
                initial=self.state(root=40.0),
                steps=0,
            )
        with self.assertRaises(ValueError):
            solve_three_store_window(
                self.config(),
                self.state(root=101.0),
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
