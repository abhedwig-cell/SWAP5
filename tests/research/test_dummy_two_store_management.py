from __future__ import annotations

import unittest

from dummy_head_management_complementarity import HeadDependentManagementProblem
from dummy_two_store_exchange import TwoStoreConfig, TwoStoreState, total_storage_m3
from dummy_two_store_management import (
    TwoStoreManagementProblem,
    TwoStorePhysicalInfeasibleError,
)


class TwoStoreManagementTests(unittest.TestCase):
    def problem(
        self,
        *,
        A_g: float = 100.0,
        request: float = 40.0,
        hmin: float = 0.4,
        C: float = 50.0,
        dt: float = 1.0,
        h_s0: float = 1.0,
        h_g0: float = 0.0,
        datum: float = 0.0,
    ) -> TwoStoreManagementProblem:
        return TwoStoreManagementProblem(
            config=TwoStoreConfig(
                surface_storage_m2=100.0,
                groundwater_storage_m2=A_g,
                conductance_m2_per_time=C,
            ),
            start=TwoStoreState(h_s0, h_g0),
            dt=dt,
            requested_m3=request,
            management_min_surface_head_m=hmin,
            surface_datum_m=datum,
        )

    def assert_closed(self, solution) -> None:
        self.assertAlmostEqual(solution.surface_balance_residual_m3, 0.0, places=10)
        self.assertAlmostEqual(
            solution.groundwater_balance_residual_m3, 0.0, places=10
        )
        self.assertAlmostEqual(solution.exchange_residual_m3, 0.0, places=10)
        self.assertAlmostEqual(solution.combined_ledger_residual_m3, 0.0, places=10)

    def test_d1_fixed_delivery_closes_reciprocal_equations(self) -> None:
        p = self.problem()
        fixed = p.fixed_delivery(20.0)

        self.assertAlmostEqual(fixed.exchange_volume_m3, 30.0, places=12)
        self.assertAlmostEqual(fixed.end.surface_head_m, 0.5, places=12)
        self.assertAlmostEqual(fixed.end.groundwater_head_m, 0.3, places=12)
        self.assert_closed(fixed)

    def test_d2_canonical_dynamic_groundwater_case_is_exact(self) -> None:
        s = self.problem().solve()

        self.assertEqual(s.regime, "CURTAILED")
        self.assertAlmostEqual(s.delivered_m3, 32.0, places=12)
        self.assertAlmostEqual(s.shortage_m3, 8.0, places=12)
        self.assertAlmostEqual(s.exchange_volume_m3, 28.0, places=12)
        self.assertAlmostEqual(s.end.surface_head_m, 0.4, places=12)
        self.assertAlmostEqual(s.end.groundwater_head_m, 0.28, places=12)
        self.assert_closed(s)

    def test_d3_combined_storage_loss_equals_management_delivery(self) -> None:
        p = self.problem()
        s = p.solve()
        initial = total_storage_m3(p.config, p.start)
        final = total_storage_m3(p.config, s.end)

        self.assertAlmostEqual(initial - final, s.delivered_m3, places=11)
        self.assertAlmostEqual(
            p.config.surface_storage_m2
            * (p.start.surface_head_m - s.end.surface_head_m),
            s.delivered_m3 + s.exchange_volume_m3,
            places=11,
        )
        self.assertAlmostEqual(
            p.config.groundwater_storage_m2
            * (s.end.groundwater_head_m - p.start.groundwater_head_m),
            s.exchange_volume_m3,
            places=11,
        )

    def test_d4_dynamic_groundwater_response_changes_management_vs_fixed_head(self) -> None:
        dynamic = self.problem().solve()
        fixed = HeadDependentManagementProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=50.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
            requested_delivery_m3=40.0,
            management_min_level_m=0.4,
            datum_m=0.0,
        ).solve()

        self.assertAlmostEqual(fixed.delivered_m3, 25.0, places=12)
        self.assertAlmostEqual(fixed.signed_exchange_m3, 35.0, places=12)
        self.assertGreater(dynamic.delivered_m3, fixed.delivered_m3)
        self.assertLess(dynamic.exchange_volume_m3, fixed.signed_exchange_m3)
        self.assertGreater(dynamic.end.groundwater_head_m, 0.0)

    def test_d5_groundwater_storage_family_moves_monotonically_to_fixed_head_limit(self) -> None:
        capacities = (20.0, 50.0, 100.0, 200.0, 1000.0, 1.0e6)
        solutions = [self.problem(A_g=A_g).solve() for A_g in capacities]
        deliveries = [s.delivered_m3 for s in solutions]
        exchanges = [s.exchange_volume_m3 for s in solutions]
        groundwater_rises = [s.end.groundwater_head_m for s in solutions]

        self.assertEqual(solutions[0].regime, "FULL")
        self.assertAlmostEqual(deliveries[0], 40.0, places=12)

        for left, right in zip(deliveries, deliveries[1:]):
            self.assertGreaterEqual(left, right)
        for left, right in zip(exchanges, exchanges[1:]):
            self.assertLessEqual(left, right)
        for left, right in zip(groundwater_rises, groundwater_rises[1:]):
            self.assertGreaterEqual(left, right)

    def test_d6_large_groundwater_storage_recovers_d5_fixed_head_limit(self) -> None:
        dynamic = self.problem(A_g=1.0e12).solve()
        fixed = HeadDependentManagementProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=50.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
            requested_delivery_m3=40.0,
            management_min_level_m=0.4,
            datum_m=0.0,
        ).solve()

        self.assertEqual(dynamic.regime, fixed.regime)
        self.assertAlmostEqual(dynamic.delivered_m3, fixed.delivered_m3, places=8)
        self.assertAlmostEqual(
            dynamic.exchange_volume_m3,
            fixed.signed_exchange_m3,
            places=8,
        )
        self.assertAlmostEqual(dynamic.end.surface_head_m, fixed.end_level_m, places=10)
        self.assertAlmostEqual(dynamic.end.groundwater_head_m, 0.0, places=9)

    def test_d7_full_and_zero_regimes_close_with_dynamic_groundwater(self) -> None:
        full = self.problem(request=20.0, hmin=0.4).solve()
        zero = self.problem(request=40.0, hmin=0.7).solve()

        self.assertEqual(full.regime, "FULL")
        self.assertAlmostEqual(full.delivered_m3, 20.0, places=12)
        self.assertEqual(zero.regime, "ZERO")
        self.assertAlmostEqual(zero.delivered_m3, 0.0, places=12)
        self.assertAlmostEqual(zero.end.surface_head_m, 2.0 / 3.0, places=12)
        self.assertAlmostEqual(zero.end.groundwater_head_m, 1.0 / 3.0, places=12)
        self.assert_closed(full)
        self.assert_closed(zero)

    def test_d8_active_set_boundaries_are_continuous(self) -> None:
        full_boundary = self.problem(request=32.0, hmin=0.4).solve()
        self.assertEqual(full_boundary.regime, "FULL")
        self.assertAlmostEqual(full_boundary.delivered_m3, 32.0, places=12)
        self.assertAlmostEqual(full_boundary.exchange_volume_m3, 28.0, places=12)
        self.assertAlmostEqual(full_boundary.end.surface_head_m, 0.4, places=12)

        zero_trial = self.problem(request=40.0, hmin=2.0 / 3.0).solve()
        self.assertEqual(zero_trial.regime, "ZERO")
        self.assertAlmostEqual(zero_trial.delivered_m3, 0.0, places=12)
        self.assertAlmostEqual(zero_trial.end.surface_head_m, 2.0 / 3.0, places=12)

    def test_d9_zero_withdrawal_surface_floor_violation_fails_closed(self) -> None:
        p = self.problem(
            request=0.0,
            hmin=0.0,
            C=50.0,
            h_s0=0.1,
            h_g0=-10.0,
            datum=0.0,
        )

        with self.assertRaises(TwoStorePhysicalInfeasibleError):
            p.solve()

    def test_invalid_management_inputs_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            self.problem(request=-1.0)
        with self.assertRaises(ValueError):
            self.problem(dt=0.0)
        with self.assertRaises(ValueError):
            self.problem(hmin=-0.1, datum=0.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
