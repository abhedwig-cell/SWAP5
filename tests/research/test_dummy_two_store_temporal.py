from __future__ import annotations

import unittest

from dummy_temporal_partition import (
    TemporalCouplingConfig,
    continuous_one_event_reference,
    run_temporal_partition,
)
from dummy_two_store_exchange import TwoStoreConfig, TwoStoreState
from dummy_two_store_temporal import (
    TwoStoreTemporalConfig,
    continuous_two_store_event_reference,
    run_two_store_partition,
)


class TwoStoreTemporalMemoryTests(unittest.TestCase):
    def canonical(
        self,
        *,
        groundwater_storage_m2: float = 100.0,
    ) -> TwoStoreTemporalConfig:
        return TwoStoreTemporalConfig(
            stores=TwoStoreConfig(
                surface_storage_m2=100.0,
                groundwater_storage_m2=groundwater_storage_m2,
                conductance_m2_per_time=50.0,
            ),
            management_min_surface_head_m=0.4,
            request_rate_m3_per_time=40.0,
            surface_datum_m=0.0,
        )

    def start(self) -> TwoStoreState:
        return TwoStoreState(1.0, 0.0)

    def run_equal(self, n: int, *, groundwater_storage_m2: float = 100.0):
        return run_two_store_partition(
            self.canonical(
                groundwater_storage_m2=groundwater_storage_m2
            ),
            initial=self.start(),
            dts=[1.0 / n] * n,
        )

    def assert_run_closed(self, result) -> None:
        self.assertAlmostEqual(
            result.surface_balance_residual_m3, 0.0, places=8
        )
        self.assertAlmostEqual(
            result.groundwater_balance_residual_m3, 0.0, places=8
        )
        self.assertAlmostEqual(
            result.combined_balance_residual_m3, 0.0, places=8
        )
        for window in result.windows:
            self.assertAlmostEqual(
                window.surface_balance_residual_m3, 0.0, places=9
            )
            self.assertAlmostEqual(
                window.groundwater_balance_residual_m3, 0.0, places=9
            )
            self.assertAlmostEqual(
                window.combined_balance_residual_m3, 0.0, places=9
            )

    def test_m1_accepted_surface_and_groundwater_states_chain_exactly(self) -> None:
        result = run_two_store_partition(
            self.canonical(),
            initial=self.start(),
            dts=[0.2, 0.3, 0.5],
        )

        self.assertEqual(len(result.windows), 3)
        for left, right in zip(result.windows, result.windows[1:]):
            self.assertAlmostEqual(
                left.end.surface_head_m,
                right.start.surface_head_m,
                places=12,
            )
            self.assertAlmostEqual(
                left.end.groundwater_head_m,
                right.start.groundwater_head_m,
                places=12,
            )
        self.assert_run_closed(result)

    def test_m2_combined_storage_loss_equals_cumulative_management_delivery(self) -> None:
        for n in (1, 2, 4, 16, 64, 512):
            result = self.run_equal(n)
            self.assert_run_closed(result)

            A_s = self.canonical().stores.surface_storage_m2
            A_g = self.canonical().stores.groundwater_storage_m2
            initial_total = (
                A_s * result.initial.surface_head_m
                + A_g * result.initial.groundwater_head_m
            )
            final_total = (
                A_s * result.final.surface_head_m
                + A_g * result.final.groundwater_head_m
            )
            self.assertAlmostEqual(
                initial_total - final_total,
                result.cumulative_delivered_m3,
                places=8,
            )

    def test_m3_nonbinding_full_regime_matches_independent_mean_difference_recurrence(self) -> None:
        config = TwoStoreTemporalConfig(
            stores=TwoStoreConfig(
                surface_storage_m2=100.0,
                groundwater_storage_m2=200.0,
                conductance_m2_per_time=20.0,
            ),
            management_min_surface_head_m=0.0,
            request_rate_m3_per_time=5.0,
            surface_datum_m=-1.0,
        )
        initial = TwoStoreState(1.0, 0.2)
        n = 8
        dt = 1.0 / n

        result = run_two_store_partition(
            config,
            initial=initial,
            dts=[dt] * n,
        )
        self.assertTrue(all(w.regime == "FULL" for w in result.windows))

        A_s = config.stores.surface_storage_m2
        A_g = config.stores.groundwater_storage_m2
        A_sum = A_s + A_g
        C = config.stores.conductance_m2_per_time
        rate = config.request_rate_m3_per_time

        mean = (
            A_s * initial.surface_head_m
            + A_g * initial.groundwater_head_m
        ) / A_sum
        difference = initial.head_difference_m
        mu = 0.5 * C * dt * (1.0 / A_s + 1.0 / A_g)
        g = (1.0 - mu) / (1.0 + mu)

        for _ in range(n):
            mean -= rate * dt / A_sum
            difference = (
                g * difference
                - (rate * dt / A_s) / (1.0 + mu)
            )

        expected_surface = mean + (A_g / A_sum) * difference
        expected_groundwater = mean - (A_s / A_sum) * difference

        self.assertAlmostEqual(
            result.final.surface_head_m,
            expected_surface,
            places=11,
        )
        self.assertAlmostEqual(
            result.final.groundwater_head_m,
            expected_groundwater,
            places=11,
        )
        self.assert_run_closed(result)

    def test_m4_continuous_canonical_reference_matches_preregistered_values(self) -> None:
        ref = continuous_two_store_event_reference(
            self.canonical(),
            initial=self.start(),
            horizon=1.0,
        )

        self.assertAlmostEqual(
            ref.hit_time,
            0.909516342472789,
            places=12,
        )
        self.assertAlmostEqual(
            ref.cumulative_delivered_m3,
            36.38065369891156,
            places=11,
        )
        self.assertAlmostEqual(
            ref.final.surface_head_m,
            0.3929144878349753,
            places=11,
        )
        self.assertAlmostEqual(
            ref.final.groundwater_head_m,
            0.2432789751759090,
            places=11,
        )
        self.assertAlmostEqual(
            ref.cumulative_exchange_m3,
            24.32789751759091,
            places=10,
        )
        self.assertAlmostEqual(ref.surface_balance_residual_m3, 0.0, places=9)
        self.assertAlmostEqual(
            ref.groundwater_balance_residual_m3, 0.0, places=9
        )
        self.assertAlmostEqual(ref.combined_balance_residual_m3, 0.0, places=9)

    def test_m5_discrete_refinement_approaches_continuous_reference_overall(self) -> None:
        ref = continuous_two_store_event_reference(
            self.canonical(),
            initial=self.start(),
            horizon=1.0,
        )
        n16 = self.run_equal(16)
        n8192 = self.run_equal(8192)

        self.assertLess(
            abs(n8192.final.surface_head_m - ref.final.surface_head_m),
            abs(n16.final.surface_head_m - ref.final.surface_head_m),
        )
        self.assertLess(
            abs(n8192.final.groundwater_head_m - ref.final.groundwater_head_m),
            abs(n16.final.groundwater_head_m - ref.final.groundwater_head_m),
        )
        self.assertLess(
            abs(
                n8192.cumulative_delivered_m3
                - ref.cumulative_delivered_m3
            ),
            abs(
                n16.cumulative_delivered_m3
                - ref.cumulative_delivered_m3
            ),
        )
        self.assert_run_closed(n8192)

    def test_m6_finite_groundwater_memory_delays_shutoff_vs_fixed_head_reference(self) -> None:
        dynamic = continuous_two_store_event_reference(
            self.canonical(),
            initial=self.start(),
            horizon=1.0,
        )
        fixed = continuous_one_event_reference(
            TemporalCouplingConfig(
                basin_area_m2=100.0,
                conductance_m2_per_time=50.0,
                groundwater_head_m=0.0,
                management_min_level_m=0.4,
                request_rate_m3_per_time=40.0,
                datum_m=0.0,
            ),
            initial_level_m=1.0,
            horizon=1.0,
        )

        self.assertGreater(dynamic.hit_time, fixed.hit_time)
        self.assertGreater(
            dynamic.cumulative_delivered_m3,
            fixed.cumulative_delivered_m3,
        )
        self.assertGreater(dynamic.final.groundwater_head_m, 0.0)

    def test_m7_zero_management_windows_continue_reciprocal_physical_exchange(self) -> None:
        result = self.run_equal(16)
        zero_windows = [w for w in result.windows if w.regime == "ZERO"]

        self.assertTrue(zero_windows)
        self.assertLess(
            result.final.surface_head_m,
            self.canonical().management_min_surface_head_m,
        )
        self.assertGreater(
            result.final.groundwater_head_m,
            self.start().groundwater_head_m,
        )
        for window in zero_windows:
            self.assertEqual(window.delivered_m3, 0.0)
            self.assertNotEqual(window.exchange_volume_m3, 0.0)

    def test_m8_request_remains_exogenous_after_shortage(self) -> None:
        n = 16
        result = self.run_equal(n)
        expected_request = 40.0 / n

        self.assertTrue(any(w.shortage_m3 > 0.0 for w in result.windows))
        for window in result.windows:
            self.assertAlmostEqual(
                window.requested_m3,
                expected_request,
                places=12,
            )

    def test_m9_large_groundwater_storage_approaches_fixed_head_multiwindow_family(self) -> None:
        n = 64
        fixed = run_temporal_partition(
            TemporalCouplingConfig(
                basin_area_m2=100.0,
                conductance_m2_per_time=50.0,
                groundwater_head_m=0.0,
                management_min_level_m=0.4,
                request_rate_m3_per_time=40.0,
                datum_m=0.0,
            ),
            initial_level_m=1.0,
            dts=[1.0 / n] * n,
        )

        dynamic_100 = self.run_equal(n, groundwater_storage_m2=100.0)
        dynamic_1000 = self.run_equal(n, groundwater_storage_m2=1000.0)
        dynamic_large = self.run_equal(n, groundwater_storage_m2=1.0e6)

        delivery_errors = [
            abs(x.cumulative_delivered_m3 - fixed.cumulative_delivered_m3)
            for x in (dynamic_100, dynamic_1000, dynamic_large)
        ]
        surface_errors = [
            abs(x.final.surface_head_m - fixed.final_level_m)
            for x in (dynamic_100, dynamic_1000, dynamic_large)
        ]

        self.assertGreater(delivery_errors[0], delivery_errors[1])
        self.assertGreater(delivery_errors[1], delivery_errors[2])
        self.assertGreater(surface_errors[0], surface_errors[1])
        self.assertGreater(surface_errors[1], surface_errors[2])

    def test_m10_coarse_and_two_window_values_match_prequalification_expectations(self) -> None:
        one = self.run_equal(1)
        two = self.run_equal(2)

        self.assertEqual(tuple(w.regime for w in one.windows), ("CURTAILED",))
        self.assertAlmostEqual(one.cumulative_delivered_m3, 32.0, places=11)
        self.assertAlmostEqual(one.cumulative_exchange_m3, 28.0, places=11)
        self.assertAlmostEqual(one.final.surface_head_m, 0.4, places=11)
        self.assertAlmostEqual(one.final.groundwater_head_m, 0.28, places=11)

        self.assertEqual(
            tuple(w.regime for w in two.windows),
            ("FULL", "CURTAILED"),
        )
        self.assertAlmostEqual(
            two.cumulative_delivered_m3,
            34.666666666666664,
            places=10,
        )
        self.assertAlmostEqual(
            two.cumulative_exchange_m3,
            25.333333333333336,
            places=10,
        )
        self.assertAlmostEqual(two.final.surface_head_m, 0.4, places=11)
        self.assertAlmostEqual(
            two.final.groundwater_head_m,
            0.2533333333333333,
            places=11,
        )

    def test_invalid_temporal_reference_inputs_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            run_two_store_partition(
                self.canonical(),
                initial=self.start(),
                dts=[],
            )
        with self.assertRaises(ValueError):
            run_two_store_partition(
                self.canonical(),
                initial=self.start(),
                dts=[0.0],
            )
        with self.assertRaises(ValueError):
            continuous_two_store_event_reference(
                TwoStoreTemporalConfig(
                    stores=TwoStoreConfig(100.0, 100.0, 0.0),
                    management_min_surface_head_m=0.4,
                    request_rate_m3_per_time=40.0,
                ),
                initial=self.start(),
                horizon=1.0,
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
