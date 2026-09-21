from __future__ import annotations

import unittest

from dummy_trapezoid_exchange_iteration import TrapezoidExchangeProblem


class TrapezoidExchangeIterationTests(unittest.TestCase):
    def test_t1_closed_form_fixed_point_satisfies_both_equations(self) -> None:
        p = TrapezoidExchangeProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=20.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
            managed_delivery_m3=20.0,
        )

        v = p.fixed_point_exchange_m3
        h1 = p.fixed_point_end_level_m

        self.assertAlmostEqual(p.exchange_equation_residual_m3(v), 0.0, places=12)
        self.assertAlmostEqual(
            p.water_balance_level_residual_m(v, h1), 0.0, places=12
        )
        self.assertAlmostEqual(v, 18.0 / 1.1, places=12)

    def test_t2_subcritical_lambda_converges_with_exact_error_ratio(self) -> None:
        p = TrapezoidExchangeProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=50.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
            managed_delivery_m3=10.0,
        )
        self.assertAlmostEqual(p.coupling_stiffness, 0.25)

        errors = p.error_sequence(5)
        for left, right in zip(errors, errors[1:]):
            self.assertNotEqual(left, 0.0)
            self.assertAlmostEqual(right / left, -0.25, places=12)
        self.assertLess(abs(errors[-1]), abs(errors[0]))

    def test_t3_lambda_one_is_equal_magnitude_two_cycle(self) -> None:
        p = TrapezoidExchangeProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=200.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
        )
        self.assertAlmostEqual(p.coupling_stiffness, 1.0)

        errors = p.error_sequence(4)
        for left, right in zip(errors, errors[1:]):
            self.assertAlmostEqual(right, -left, places=12)
            self.assertAlmostEqual(abs(right), abs(left), places=12)

    def test_t4_supercritical_lambda_grows_geometrically(self) -> None:
        p = TrapezoidExchangeProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=300.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
        )
        self.assertAlmostEqual(p.coupling_stiffness, 1.5)

        errors = p.error_sequence(4)
        for left, right in zip(errors, errors[1:]):
            self.assertAlmostEqual(right / left, -1.5, places=12)
        self.assertGreater(abs(errors[-1]), abs(errors[0]))

    def test_t5_one_corrector_improves_subcritical_explicit_estimate(self) -> None:
        p = TrapezoidExchangeProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=150.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
            managed_delivery_m3=10.0,
        )
        self.assertAlmostEqual(p.coupling_stiffness, 0.75)

        fixed = p.fixed_point_exchange_m3
        explicit_error = p.explicit_start_exchange_m3 - fixed
        corrector_error = p.one_corrector_exchange_m3 - fixed

        self.assertLess(abs(corrector_error), abs(explicit_error))
        self.assertAlmostEqual(
            corrector_error / explicit_error,
            -0.75,
            places=12,
        )
        self.assertNotAlmostEqual(corrector_error, 0.0, places=12)

    def test_t6_equal_lambda_has_same_normalized_error_propagation(self) -> None:
        p1 = TrapezoidExchangeProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=50.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
            managed_delivery_m3=10.0,
        )
        p2 = TrapezoidExchangeProblem(
            basin_area_m2=200.0,
            conductance_m2_per_time=100.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
            managed_delivery_m3=20.0,
        )
        self.assertAlmostEqual(p1.coupling_stiffness, p2.coupling_stiffness)

        e1 = p1.error_sequence(5)
        e2 = p2.error_sequence(5)
        n1 = [e / e1[0] for e in e1]
        n2 = [e / e2[0] for e in e2]
        for a, b in zip(n1, n2):
            self.assertAlmostEqual(a, b, places=12)

    def test_t7_delivery_shifts_fixed_point_not_error_factor(self) -> None:
        p0 = TrapezoidExchangeProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=50.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
            managed_delivery_m3=0.0,
        )
        p40 = TrapezoidExchangeProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=50.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
            managed_delivery_m3=40.0,
        )

        self.assertNotAlmostEqual(
            p0.fixed_point_exchange_m3,
            p40.fixed_point_exchange_m3,
            places=12,
        )
        self.assertAlmostEqual(p0.coupling_stiffness, p40.coupling_stiffness)

        for problem in (p0, p40):
            errors = problem.error_sequence(3)
            for left, right in zip(errors, errors[1:]):
                self.assertAlmostEqual(
                    right / left,
                    -problem.coupling_stiffness,
                    places=12,
                )

    def test_t8_timestep_reduction_restores_picard_convergence(self) -> None:
        unstable = TrapezoidExchangeProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=300.0,
            dt=1.0,
            start_level_m=1.0,
            groundwater_head_m=0.0,
        )
        stable = TrapezoidExchangeProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=300.0,
            dt=0.4,
            start_level_m=1.0,
            groundwater_head_m=0.0,
        )

        self.assertGreater(unstable.coupling_stiffness, 1.0)
        self.assertLess(stable.coupling_stiffness, 1.0)

        e_unstable = unstable.error_sequence(4)
        e_stable = stable.error_sequence(4)
        self.assertGreater(abs(e_unstable[-1]), abs(e_unstable[0]))
        self.assertLess(abs(e_stable[-1]), abs(e_stable[0]))

    def test_invalid_problem_definition_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            TrapezoidExchangeProblem(
                basin_area_m2=0.0,
                conductance_m2_per_time=1.0,
                dt=1.0,
                start_level_m=1.0,
                groundwater_head_m=0.0,
            )
        with self.assertRaises(ValueError):
            TrapezoidExchangeProblem(
                basin_area_m2=1.0,
                conductance_m2_per_time=-1.0,
                dt=1.0,
                start_level_m=1.0,
                groundwater_head_m=0.0,
            )
        with self.assertRaises(ValueError):
            TrapezoidExchangeProblem(
                basin_area_m2=1.0,
                conductance_m2_per_time=1.0,
                dt=0.0,
                start_level_m=1.0,
                groundwater_head_m=0.0,
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
