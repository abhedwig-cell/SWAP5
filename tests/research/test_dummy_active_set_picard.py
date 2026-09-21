from __future__ import annotations

import unittest

from dummy_active_set_picard import (
    ActiveSetPhysicalFloorError,
    ActiveSetPicardProblem,
)
from dummy_head_management_complementarity import HeadDependentManagementProblem


class ActiveSetPicardTests(unittest.TestCase):
    def problem(
        self,
        *,
        C: float = 50.0,
        dt: float = 1.0,
        hgw: float = 0.0,
        request: float = 40.0,
        hmin: float = 0.4,
    ) -> ActiveSetPicardProblem:
        return ActiveSetPicardProblem(
            HeadDependentManagementProblem(
                basin_area_m2=100.0,
                conductance_m2_per_time=C,
                dt=dt,
                start_level_m=1.0,
                groundwater_head_m=hgw,
                requested_delivery_m3=request,
                management_min_level_m=hmin,
                datum_m=0.0,
            )
        )

    def assert_oracle_fixed_point(self, p: ActiveSetPicardProblem) -> None:
        exact = p.oracle.solve()
        state = p.step(exact.signed_exchange_m3)
        self.assertAlmostEqual(
            state.next_exchange_m3,
            exact.signed_exchange_m3,
            places=11,
        )
        self.assertAlmostEqual(state.delivered_m3, exact.delivered_m3, places=11)
        self.assertAlmostEqual(
            state.provisional_end_level_m,
            exact.end_level_m,
            places=11,
        )
        self.assertAlmostEqual(state.balance_residual_m, 0.0, places=12)

    def test_a1_all_exact_management_regimes_are_active_set_fixed_points(self) -> None:
        full = self.problem(request=20.0, hmin=0.3)
        curtailed = self.problem(request=40.0, hmin=0.4)
        zero = self.problem(request=40.0, hmin=0.65)

        self.assertEqual(full.oracle.solve().regime, "FULL")
        self.assertEqual(curtailed.oracle.solve().regime, "CURTAILED")
        self.assertEqual(zero.oracle.solve().regime, "ZERO")

        for p in (full, curtailed, zero):
            self.assert_oracle_fixed_point(p)

    def test_a2_any_interior_curtailed_guess_maps_to_exact_curtailed_exchange(self) -> None:
        p = self.problem(request=40.0, hmin=0.4)
        exact = p.oracle.solve()
        self.assertEqual(exact.regime, "CURTAILED")
        self.assertAlmostEqual(exact.signed_exchange_m3, 35.0, places=12)

        for guess in (25.0, 35.0, 55.0):
            state = p.step(guess)
            self.assertEqual(state.provisional_regime, "CURTAILED")
            self.assertAlmostEqual(state.provisional_end_level_m, 0.4, places=12)
            self.assertAlmostEqual(
                state.next_exchange_m3,
                exact.signed_exchange_m3,
                places=12,
            )

    def test_a3_subcritical_non_switching_full_regime_retains_minus_lambda_error(self) -> None:
        p = self.problem(request=20.0, hmin=0.3)
        exact = p.oracle.solve()
        self.assertEqual(exact.regime, "FULL")
        self.assertAlmostEqual(p.coupling_stiffness, 0.25)

        guesses = p.exchange_guesses(5)
        errors = [value - exact.signed_exchange_m3 for value in guesses]

        for state in p.states(5):
            self.assertEqual(state.provisional_regime, "FULL")
        for left, right in zip(errors, errors[1:]):
            self.assertAlmostEqual(right / left, -0.25, places=11)

    def test_a4_preregistered_stiff_case_forms_full_curtailed_two_cycle(self) -> None:
        p = self.problem(
            C=300.0,
            dt=1.0,
            hgw=0.8,
            request=50.0,
            hmin=0.2,
        )
        exact = p.oracle.solve()

        self.assertAlmostEqual(p.coupling_stiffness, 1.5)
        self.assertEqual(exact.regime, "FULL")
        self.assertAlmostEqual(exact.delivered_m3, 50.0, places=12)
        self.assertAlmostEqual(exact.signed_exchange_m3, -6.0, places=12)
        self.assertAlmostEqual(exact.end_level_m, 0.56, places=12)

        guesses = p.exchange_guesses(3)
        expected = (60.0, -60.0, 75.0, -60.0)
        for observed, target in zip(guesses, expected):
            self.assertAlmostEqual(observed, target, places=11)
        regimes = tuple(state.provisional_regime for state in p.states(3))
        self.assertEqual(regimes, ("CURTAILED", "FULL", "CURTAILED"))

        self.assertNotIn(exact.signed_exchange_m3, guesses)

    def test_a5_nonconvergent_cycle_still_respects_management_bounds(self) -> None:
        p = self.problem(
            C=300.0,
            dt=1.0,
            hgw=0.8,
            request=50.0,
            hmin=0.2,
        )

        for state in p.states(8):
            self.assertGreaterEqual(state.delivered_m3, 0.0)
            self.assertLessEqual(state.delivered_m3, 50.0)
            self.assertGreaterEqual(state.provisional_end_level_m, 0.0)

    def test_a6_smaller_dt_converges_to_exact_oracle(self) -> None:
        p = self.problem(
            C=300.0,
            dt=0.2,
            hgw=0.8,
            request=50.0,
            hmin=0.2,
        )
        exact = p.oracle.solve()
        self.assertEqual(exact.regime, "FULL")
        self.assertAlmostEqual(p.coupling_stiffness, 0.3)

        guesses = p.exchange_guesses(8)
        errors = [value - exact.signed_exchange_m3 for value in guesses]

        for state in p.states(8):
            self.assertEqual(state.provisional_regime, "FULL")
        for left, right in zip(errors, errors[1:]):
            self.assertAlmostEqual(right / left, -0.3, places=10)
        self.assertLess(abs(errors[-1]), abs(errors[0]))

    def test_a7_cycle_states_are_locally_self_consistent_but_not_coupled_fixed_points(self) -> None:
        p = self.problem(
            C=300.0,
            dt=1.0,
            hgw=0.8,
            request=50.0,
            hmin=0.2,
        )
        states = p.states(3)

        for state in states:
            capacity = (
                p.oracle.basin_area_m2
                * (
                    p.oracle.start_level_m
                    - p.oracle.management_min_level_m
                )
                - state.exchange_guess_m3
            )
            expected_delivery = min(
                p.oracle.requested_delivery_m3,
                max(0.0, capacity),
            )
            self.assertAlmostEqual(
                state.delivered_m3,
                expected_delivery,
                places=12,
            )
            self.assertAlmostEqual(state.balance_residual_m, 0.0, places=12)

        self.assertNotAlmostEqual(
            states[0].next_exchange_m3,
            states[0].exchange_guess_m3,
            places=12,
        )
        self.assertNotAlmostEqual(
            states[1].next_exchange_m3,
            states[1].exchange_guess_m3,
            places=12,
        )

    def test_a8_provisional_physical_floor_crossing_fails_closed(self) -> None:
        p = self.problem(request=0.0, hmin=0.0)

        with self.assertRaises(ActiveSetPhysicalFloorError):
            p.step(150.0)

    def test_nonfinite_iteration_guess_is_rejected(self) -> None:
        p = self.problem()
        with self.assertRaises(ValueError):
            p.step(float("nan"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
