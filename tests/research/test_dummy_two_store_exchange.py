from __future__ import annotations

import math
import unittest

from dummy_two_store_exchange import (
    TwoStoreConfig,
    TwoStoreState,
    continuous_exchange_volume_m3,
    continuous_state,
    total_storage_m3,
    trapezoid_run,
    trapezoid_step,
    weighted_equilibrium_head_m,
)


class TwoStoreExchangeTests(unittest.TestCase):
    def canonical(self, C: float = 150.0) -> TwoStoreConfig:
        return TwoStoreConfig(
            surface_storage_m2=100.0,
            groundwater_storage_m2=100.0,
            conductance_m2_per_time=C,
        )

    def start(self) -> TwoStoreState:
        return TwoStoreState(surface_head_m=1.0, groundwater_head_m=0.0)

    def test_g1_exchange_is_exactly_reciprocal_between_stores(self) -> None:
        step = trapezoid_step(self.canonical(), self.start(), dt=1.0)

        self.assertAlmostEqual(
            step.surface_storage_change_m3,
            -step.exchange_volume_m3,
            places=12,
        )
        self.assertAlmostEqual(
            step.groundwater_storage_change_m3,
            step.exchange_volume_m3,
            places=12,
        )
        self.assertAlmostEqual(step.total_storage_residual_m3, 0.0, places=12)

    def test_g2_total_storage_is_invariant_continuous_and_discrete(self) -> None:
        config = TwoStoreConfig(
            surface_storage_m2=80.0,
            groundwater_storage_m2=320.0,
            conductance_m2_per_time=70.0,
        )
        start = TwoStoreState(1.2, -0.1)
        initial = total_storage_m3(config, start)

        for dt in (0.0, 0.1, 1.0, 10.0):
            end = continuous_state(config, start, dt=dt)
            self.assertAlmostEqual(total_storage_m3(config, end), initial, places=11)

        steps = trapezoid_run(config, start, dts=[0.2, 0.3, 0.5, 1.0])
        for step in steps:
            self.assertAlmostEqual(step.total_storage_residual_m3, 0.0, places=11)
        self.assertAlmostEqual(
            total_storage_m3(config, steps[-1].end),
            initial,
            places=11,
        )

    def test_g3_continuous_oracle_preserves_equilibrium_and_head_order(self) -> None:
        config = self.canonical()
        start = self.start()
        equilibrium = weighted_equilibrium_head_m(config, start)
        previous_difference = start.head_difference_m

        for dt in (0.1, 0.5, 1.0, 2.0):
            end = continuous_state(config, start, dt=dt)
            self.assertAlmostEqual(
                weighted_equilibrium_head_m(config, end),
                equilibrium,
                places=12,
            )
            self.assertGreater(end.head_difference_m, 0.0)
            self.assertLess(end.head_difference_m, previous_difference)
            self.assertAlmostEqual(
                end.head_difference_m,
                math.exp(-3.0 * dt),
                places=12,
            )

    def test_g4_trapezoid_closed_form_satisfies_both_storage_and_exchange_equations(self) -> None:
        step = trapezoid_step(self.canonical(), self.start(), dt=1.0)

        self.assertAlmostEqual(step.exchange_volume_m3, 60.0, places=12)
        self.assertAlmostEqual(step.end.surface_head_m, 0.4, places=12)
        self.assertAlmostEqual(step.end.groundwater_head_m, 0.6, places=12)
        self.assertAlmostEqual(step.exchange_equation_residual_m3, 0.0, places=12)
        self.assertAlmostEqual(step.total_storage_residual_m3, 0.0, places=12)

    def test_g5_head_difference_amplification_matches_formula_with_unequal_storage(self) -> None:
        config = TwoStoreConfig(
            surface_storage_m2=100.0,
            groundwater_storage_m2=300.0,
            conductance_m2_per_time=120.0,
        )
        start = TwoStoreState(1.1, 0.2)
        step = trapezoid_step(config, start, dt=0.75)

        observed = step.end.head_difference_m / start.head_difference_m
        expected_mu = (
            0.5
            * config.conductance_m2_per_time
            * 0.75
            * (
                1.0 / config.surface_storage_m2
                + 1.0 / config.groundwater_storage_m2
            )
        )
        expected_g = (1.0 - expected_mu) / (1.0 + expected_mu)

        self.assertAlmostEqual(step.mu, expected_mu, places=12)
        self.assertAlmostEqual(step.amplification, expected_g, places=12)
        self.assertAlmostEqual(observed, expected_g, places=12)

    def test_g6_mu_regimes_control_discrete_head_ordering(self) -> None:
        subcritical = trapezoid_step(self.canonical(C=50.0), self.start(), dt=1.0)
        critical = trapezoid_step(self.canonical(C=100.0), self.start(), dt=1.0)
        supercritical = trapezoid_step(self.canonical(C=150.0), self.start(), dt=1.0)

        self.assertAlmostEqual(subcritical.mu, 0.5)
        self.assertGreater(subcritical.end.head_difference_m, 0.0)

        self.assertAlmostEqual(critical.mu, 1.0)
        self.assertAlmostEqual(critical.end.head_difference_m, 0.0, places=12)

        self.assertAlmostEqual(supercritical.mu, 1.5)
        self.assertLess(supercritical.end.head_difference_m, 0.0)

    def test_g7_stiff_repeated_steps_alternate_head_order_with_decaying_difference(self) -> None:
        config = self.canonical(C=150.0)
        steps = trapezoid_run(config, self.start(), dts=[1.0] * 5)
        differences = [self.start().head_difference_m] + [
            step.end.head_difference_m for step in steps
        ]
        expected = (1.0, -0.2, 0.04, -0.008, 0.0016, -0.00032)

        for observed, target in zip(differences, expected):
            self.assertAlmostEqual(observed, target, places=11)

        initial_storage = total_storage_m3(config, self.start())
        for step in steps:
            self.assertAlmostEqual(
                total_storage_m3(config, step.end),
                initial_storage,
                places=11,
            )

    def test_g8_partitioning_stiff_horizon_removes_reversal_and_approaches_continuous(self) -> None:
        config = self.canonical(C=150.0)
        start = self.start()
        exact = continuous_state(config, start, dt=1.0)

        one = trapezoid_run(config, start, dts=[1.0])[-1].end
        four_steps = trapezoid_run(config, start, dts=[0.25] * 4)
        sixteen_steps = trapezoid_run(config, start, dts=[1.0 / 16.0] * 16)
        four = four_steps[-1].end
        sixteen = sixteen_steps[-1].end

        self.assertLess(one.head_difference_m, 0.0)
        self.assertTrue(
            all(step.end.head_difference_m > 0.0 for step in four_steps)
        )
        self.assertTrue(
            all(step.end.head_difference_m > 0.0 for step in sixteen_steps)
        )

        error_one = abs(one.surface_head_m - exact.surface_head_m)
        error_four = abs(four.surface_head_m - exact.surface_head_m)
        error_sixteen = abs(sixteen.surface_head_m - exact.surface_head_m)
        self.assertLess(error_four, error_one)
        self.assertLess(error_sixteen, error_four)

        exact_exchange = continuous_exchange_volume_m3(config, start, dt=1.0)
        discrete_exchange = sum(step.exchange_volume_m3 for step in sixteen_steps)
        self.assertLess(
            abs(discrete_exchange - exact_exchange),
            abs(60.0 - exact_exchange),
        )

    def test_invalid_two_store_inputs_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            TwoStoreConfig(0.0, 100.0, 1.0)
        with self.assertRaises(ValueError):
            TwoStoreConfig(100.0, 0.0, 1.0)
        with self.assertRaises(ValueError):
            TwoStoreConfig(100.0, 100.0, -1.0)
        with self.assertRaises(ValueError):
            trapezoid_step(self.canonical(), self.start(), dt=0.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
