from __future__ import annotations

import unittest

from dummy_head_management_complementarity import (
    HeadDependentManagementProblem,
    PhysicalStorageInfeasibleError,
)


class HeadManagementComplementarityTests(unittest.TestCase):
    def assert_closed(self, solution) -> None:
        self.assertAlmostEqual(solution.exchange_residual_m3, 0.0, places=11)
        self.assertAlmostEqual(solution.balance_residual_m, 0.0, places=11)

    def base(self, request: float, hmin: float) -> HeadDependentManagementProblem:
        return HeadDependentManagementProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=50.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
            requested_delivery_m3=request,
            management_min_level_m=hmin,
            datum_m=0.0,
        )

    def test_m1_full_regime_reproduces_fixed_delivery_solution(self) -> None:
        p = self.base(request=20.0, hmin=0.3)
        s = p.solve()
        fixed = p.fixed_delivery_problem(20.0)

        self.assertEqual(s.regime, "FULL")
        self.assertEqual(s.delivered_m3, 20.0)
        self.assertEqual(s.shortage_m3, 0.0)
        self.assertAlmostEqual(
            s.signed_exchange_m3,
            fixed.fixed_point_exchange_m3,
            places=12,
        )
        self.assertAlmostEqual(
            s.end_level_m,
            fixed.fixed_point_end_level_m,
            places=12,
        )
        self.assertGreater(s.end_level_m, 0.3)
        self.assert_closed(s)

    def test_m2_curtailed_regime_pins_min_level_and_closes_exactly(self) -> None:
        p = self.base(request=40.0, hmin=0.4)
        s = p.solve()

        self.assertEqual(s.regime, "CURTAILED")
        self.assertAlmostEqual(s.delivered_m3, 25.0, places=12)
        self.assertAlmostEqual(s.shortage_m3, 15.0, places=12)
        self.assertAlmostEqual(s.signed_exchange_m3, 35.0, places=12)
        self.assertAlmostEqual(s.end_level_m, 0.4, places=12)
        self.assert_closed(s)

    def test_m3_zero_regime_does_not_clip_physical_exchange(self) -> None:
        p = self.base(request=40.0, hmin=0.65)
        s = p.solve()
        zero = p.fixed_delivery_problem(0.0)

        self.assertEqual(s.regime, "ZERO")
        self.assertEqual(s.delivered_m3, 0.0)
        self.assertEqual(s.shortage_m3, 40.0)
        self.assertAlmostEqual(
            s.signed_exchange_m3,
            zero.fixed_point_exchange_m3,
            places=12,
        )
        self.assertAlmostEqual(s.signed_exchange_m3, 40.0, places=12)
        self.assertAlmostEqual(s.end_level_m, 0.6, places=12)
        self.assertLess(s.end_level_m, p.management_min_level_m)
        self.assert_closed(s)

    def test_m4_curtailment_feedback_increases_exchange_vs_unconstrained_full(self) -> None:
        p = self.base(request=40.0, hmin=0.4)
        constrained = p.solve()
        unconstrained = p.fixed_delivery_problem(40.0)

        self.assertEqual(constrained.regime, "CURTAILED")
        self.assertAlmostEqual(unconstrained.fixed_point_end_level_m, 0.28, places=12)
        self.assertAlmostEqual(unconstrained.fixed_point_exchange_m3, 32.0, places=12)

        self.assertGreater(
            constrained.end_level_m,
            unconstrained.fixed_point_end_level_m,
        )
        self.assertGreater(
            constrained.signed_exchange_m3,
            unconstrained.fixed_point_exchange_m3,
        )

        management_saved = 40.0 - constrained.delivered_m3
        extra_infiltration = (
            constrained.signed_exchange_m3
            - unconstrained.fixed_point_exchange_m3
        )
        extra_end_storage = p.basin_area_m2 * (
            constrained.end_level_m - unconstrained.fixed_point_end_level_m
        )
        self.assertAlmostEqual(
            management_saved,
            extra_infiltration + extra_end_storage,
            places=12,
        )

    def test_m5_full_curtailed_boundary_is_continuous(self) -> None:
        p = self.base(request=25.0, hmin=0.4)
        s = p.solve()

        self.assertEqual(s.regime, "FULL")
        self.assertAlmostEqual(s.delivered_m3, 25.0, places=12)
        self.assertAlmostEqual(s.end_level_m, 0.4, places=12)
        self.assertAlmostEqual(s.signed_exchange_m3, 35.0, places=12)

        self.assertAlmostEqual(
            p.delivery_for_end_level(p.management_min_level_m),
            25.0,
            places=12,
        )
        self.assertAlmostEqual(
            p.exchange_at_levels(p.management_min_level_m),
            s.signed_exchange_m3,
            places=12,
        )
        self.assert_closed(s)

    def test_m6_curtailed_zero_boundary_is_continuous(self) -> None:
        p = self.base(request=40.0, hmin=0.6)
        s = p.solve()

        self.assertEqual(s.regime, "ZERO")
        self.assertAlmostEqual(s.delivered_m3, 0.0, places=12)
        self.assertAlmostEqual(s.end_level_m, 0.6, places=12)
        self.assertAlmostEqual(s.signed_exchange_m3, 40.0, places=12)
        self.assertAlmostEqual(
            p.delivery_for_end_level(p.management_min_level_m),
            0.0,
            places=12,
        )
        self.assert_closed(s)

    def test_m7_physical_floor_violation_fails_closed(self) -> None:
        p = HeadDependentManagementProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=50.0,
            dt=1.0,
            start_level_m=0.1,
            groundwater_head_m=-10.0,
            requested_delivery_m3=0.0,
            management_min_level_m=0.0,
            datum_m=0.0,
        )

        with self.assertRaises(PhysicalStorageInfeasibleError):
            p.solve()

    def test_m8_dense_request_sweep_matches_independent_regime_formula(self) -> None:
        area = 100.0
        conductance = 50.0
        dt = 1.0
        h0 = 1.0
        hgw = 0.0
        lam = conductance * dt / (2.0 * area)

        def independent_end(delivery: float) -> float:
            return (
                (1.0 - lam) * h0
                + 2.0 * lam * hgw
                - delivery / area
            ) / (1.0 + lam)

        for hmin in (0.2, 0.4, 0.7):
            zero_end = independent_end(0.0)
            for request_i in range(1, 81):
                request = float(request_i)
                p = self.base(request=request, hmin=hmin)
                s = p.solve()
                full_end = independent_end(request)

                if full_end >= hmin - 1.0e-12:
                    expected = "FULL"
                    expected_delivery = request
                elif zero_end <= hmin + 1.0e-12:
                    expected = "ZERO"
                    expected_delivery = 0.0
                else:
                    expected = "CURTAILED"
                    expected_exchange = conductance * dt * (
                        0.5 * (h0 + hmin) - hgw
                    )
                    expected_delivery = area * (h0 - hmin) - expected_exchange

                self.assertEqual(
                    s.regime,
                    expected,
                    msg=f"hmin={hmin}, request={request}",
                )
                self.assertAlmostEqual(
                    s.delivered_m3,
                    expected_delivery,
                    places=10,
                    msg=f"hmin={hmin}, request={request}",
                )
                self.assert_closed(s)

    def test_invalid_problem_definition_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            HeadDependentManagementProblem(
                basin_area_m2=0.0,
                conductance_m2_per_time=1.0,
                dt=1.0,
                start_level_m=1.0,
                groundwater_head_m=0.0,
                requested_delivery_m3=1.0,
                management_min_level_m=0.0,
            )
        with self.assertRaises(ValueError):
            HeadDependentManagementProblem(
                basin_area_m2=1.0,
                conductance_m2_per_time=1.0,
                dt=1.0,
                start_level_m=1.0,
                groundwater_head_m=0.0,
                requested_delivery_m3=-1.0,
                management_min_level_m=0.0,
            )
        with self.assertRaises(ValueError):
            HeadDependentManagementProblem(
                basin_area_m2=1.0,
                conductance_m2_per_time=1.0,
                dt=1.0,
                start_level_m=0.0,
                groundwater_head_m=0.0,
                requested_delivery_m3=0.0,
                management_min_level_m=-0.1,
                datum_m=0.0,
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
