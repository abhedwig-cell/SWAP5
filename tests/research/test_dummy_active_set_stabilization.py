from __future__ import annotations

import unittest
from unittest.mock import patch

from dummy_active_set_picard import ActiveSetPicardProblem
from dummy_active_set_stabilization import (
    UnderRelaxedActiveSet,
    direct_active_set_solve,
)
from dummy_head_management_complementarity import (
    HeadDependentManagementProblem,
    PhysicalStorageInfeasibleError,
)


class ActiveSetStabilizationTests(unittest.TestCase):
    def make_problem(
        self,
        *,
        C: float = 50.0,
        dt: float = 1.0,
        hgw: float = 0.0,
        request: float = 40.0,
        hmin: float = 0.4,
        h0: float = 1.0,
        datum: float = 0.0,
    ) -> HeadDependentManagementProblem:
        return HeadDependentManagementProblem(
            basin_area_m2=100.0,
            conductance_m2_per_time=C,
            dt=dt,
            start_level_m=h0,
            groundwater_head_m=hgw,
            requested_delivery_m3=request,
            management_min_level_m=hmin,
            datum_m=datum,
        )

    def test_s1_fixed_full_and_zero_error_ratio_matches_relaxed_formula(self) -> None:
        cases = (
            self.make_problem(request=20.0, hmin=0.3),
            self.make_problem(request=40.0, hmin=0.65),
        )

        for oracle_problem in cases:
            exact = oracle_problem.solve()
            active = ActiveSetPicardProblem(oracle_problem)
            relaxed = UnderRelaxedActiveSet(active, omega=0.5)
            q = relaxed.fixed_full_zero_error_factor

            guesses = relaxed.exchange_sequence(5)
            errors = [g - exact.signed_exchange_m3 for g in guesses]
            states = relaxed.states(5)

            self.assertIn(exact.regime, ("FULL", "ZERO"))
            for state in states:
                self.assertEqual(state.provisional_regime, exact.regime)
            for left, right in zip(errors, errors[1:]):
                self.assertNotAlmostEqual(left, 0.0, places=14)
                self.assertAlmostEqual(right / left, q, places=11)

    def test_s2_curtailed_error_ratio_is_one_minus_omega(self) -> None:
        oracle_problem = self.make_problem(request=40.0, hmin=0.4)
        exact = oracle_problem.solve()
        active = ActiveSetPicardProblem(oracle_problem)
        relaxed = UnderRelaxedActiveSet(active, omega=0.4)

        self.assertEqual(exact.regime, "CURTAILED")
        guesses = relaxed.exchange_sequence(5, initial_exchange_m3=50.0)
        errors = [g - exact.signed_exchange_m3 for g in guesses]

        for state in relaxed.states(5, initial_exchange_m3=50.0):
            self.assertEqual(state.provisional_regime, "CURTAILED")
        for left, right in zip(errors, errors[1:]):
            self.assertAlmostEqual(
                right / left,
                relaxed.curtailed_error_factor,
                places=11,
            )

    def test_s3_omega_star_resolves_preregistered_stiff_case_in_two_updates(self) -> None:
        oracle_problem = self.make_problem(
            C=300.0,
            dt=1.0,
            hgw=0.8,
            request=50.0,
            hmin=0.2,
        )
        exact = oracle_problem.solve()
        active = ActiveSetPicardProblem(oracle_problem)
        omega_star = 1.0 / (1.0 + active.coupling_stiffness)
        relaxed = UnderRelaxedActiveSet(active, omega=omega_star)

        self.assertAlmostEqual(omega_star, 0.4, places=12)
        observed = relaxed.exchange_sequence(3)
        expected = (60.0, 12.0, -6.0, -6.0)
        for value, target in zip(observed, expected):
            self.assertAlmostEqual(value, target, places=10)

        regimes = tuple(state.provisional_regime for state in relaxed.states(3))
        self.assertEqual(regimes, ("CURTAILED", "FULL", "FULL"))
        self.assertAlmostEqual(observed[-1], exact.signed_exchange_m3, places=10)

    def test_s4_strict_relaxation_boundary_has_two_cycle(self) -> None:
        oracle_problem = self.make_problem(
            C=300.0,
            dt=1.0,
            hgw=0.8,
            request=50.0,
            hmin=0.2,
        )
        active = ActiveSetPicardProblem(oracle_problem)
        relaxed = UnderRelaxedActiveSet(active, omega=0.8)

        self.assertAlmostEqual(relaxed.fixed_full_zero_error_factor, -1.0)
        observed = relaxed.exchange_sequence(4)
        expected = (60.0, -36.0, 24.0, -36.0, 24.0)
        for value, target in zip(observed, expected):
            self.assertAlmostEqual(value, target, places=10)

        exact = oracle_problem.solve().signed_exchange_m3
        self.assertAlmostEqual(abs(observed[1] - exact), 30.0, places=10)
        self.assertAlmostEqual(abs(observed[2] - exact), 30.0, places=10)

    def test_s5_omega_half_converges_after_regime_identification(self) -> None:
        oracle_problem = self.make_problem(
            C=300.0,
            dt=1.0,
            hgw=0.8,
            request=50.0,
            hmin=0.2,
        )
        exact = oracle_problem.solve()
        active = ActiveSetPicardProblem(oracle_problem)
        relaxed = UnderRelaxedActiveSet(active, omega=0.5)

        guesses = relaxed.exchange_sequence(8)
        states = relaxed.states(8)
        self.assertEqual(states[0].provisional_regime, "CURTAILED")
        for state in states[1:]:
            self.assertEqual(state.provisional_regime, "FULL")

        errors = [g - exact.signed_exchange_m3 for g in guesses]
        self.assertAlmostEqual(relaxed.fixed_full_zero_error_factor, -0.25)
        for left, right in zip(errors[1:], errors[2:]):
            self.assertAlmostEqual(right / left, -0.25, places=10)
        self.assertLess(abs(errors[-1]), abs(errors[1]))

    def test_s6_direct_active_set_matches_oracle_on_dense_feasible_grid(self) -> None:
        parameter_sets = []
        for C in (0.0, 50.0, 100.0):
            for dt in (0.25, 0.5, 1.0):
                for hgw in (0.0, 0.3, 0.8):
                    for hmin in (0.2, 0.4, 0.7):
                        for request in (0.0, 20.0, 50.0, 80.0):
                            parameter_sets.append(
                                self.make_problem(
                                    C=C,
                                    dt=dt,
                                    hgw=hgw,
                                    request=request,
                                    hmin=hmin,
                                )
                            )

        expected = [p.solve() for p in parameter_sets]

        with patch.object(
            HeadDependentManagementProblem,
            "solve",
            side_effect=AssertionError("direct solver must not call oracle.solve()"),
        ):
            observed = [direct_active_set_solve(p) for p in parameter_sets]

        self.assertEqual(len(observed), len(expected))
        for direct, oracle in zip(observed, expected):
            self.assertEqual(direct.regime, oracle.regime)
            self.assertAlmostEqual(
                direct.delivered_m3, oracle.delivered_m3, places=10
            )
            self.assertAlmostEqual(
                direct.signed_exchange_m3,
                oracle.signed_exchange_m3,
                places=10,
            )
            self.assertAlmostEqual(direct.end_level_m, oracle.end_level_m, places=10)
            self.assertAlmostEqual(direct.exchange_residual_m3, 0.0, places=10)
            self.assertAlmostEqual(direct.balance_residual_m, 0.0, places=10)

    def test_s7_direct_active_set_matches_fail_closed_physical_classification(self) -> None:
        p = self.make_problem(
            C=50.0,
            dt=1.0,
            hgw=-10.0,
            request=0.0,
            hmin=0.0,
            h0=0.1,
            datum=0.0,
        )

        with self.assertRaises(PhysicalStorageInfeasibleError):
            p.solve()
        with self.assertRaises(PhysicalStorageInfeasibleError):
            direct_active_set_solve(p)

    def test_s8_omega_star_annihilates_fixed_regime_error_for_multiple_lambda(self) -> None:
        for C in (50.0, 150.0, 300.0):
            oracle_problem = self.make_problem(
                C=C,
                dt=1.0,
                hgw=0.8,
                request=50.0,
                hmin=0.2,
            )
            exact = oracle_problem.solve()
            self.assertEqual(exact.regime, "FULL")

            active = ActiveSetPicardProblem(oracle_problem)
            omega_star = 1.0 / (1.0 + active.coupling_stiffness)
            relaxed = UnderRelaxedActiveSet(active, omega=omega_star)

            initial = exact.signed_exchange_m3 + 5.0
            raw = active.step(initial)
            self.assertEqual(raw.provisional_regime, "FULL")
            corrected = relaxed.step(initial).relaxed_next_exchange_m3
            self.assertAlmostEqual(
                corrected,
                exact.signed_exchange_m3,
                places=10,
            )

    def test_invalid_relaxation_is_rejected(self) -> None:
        active = ActiveSetPicardProblem(self.make_problem())
        for omega in (0.0, -0.1, 1.1, float("nan")):
            with self.assertRaises(ValueError):
                UnderRelaxedActiveSet(active, omega=omega)


if __name__ == "__main__":
    unittest.main(verbosity=2)
