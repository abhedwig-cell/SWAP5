from __future__ import annotations

import math
import unittest

from dummy_temporal_partition import (
    TemporalCouplingConfig,
    continuous_one_event_reference,
    run_temporal_partition,
)


class TemporalPartitionTests(unittest.TestCase):
    def canonical(self) -> TemporalCouplingConfig:
        return TemporalCouplingConfig(
            basin_area_m2=100.0,
            conductance_m2_per_time=50.0,
            groundwater_head_m=0.0,
            management_min_level_m=0.4,
            request_rate_m3_per_time=40.0,
            datum_m=0.0,
        )

    def run_equal(self, n: int):
        return run_temporal_partition(
            self.canonical(),
            initial_level_m=1.0,
            dts=[1.0 / n] * n,
        )

    def test_p1_multiwindow_state_chain_and_balance_close(self) -> None:
        result = run_temporal_partition(
            self.canonical(),
            initial_level_m=1.0,
            dts=[0.2, 0.3, 0.5],
        )

        self.assertEqual(len(result.windows), 3)
        for left, right in zip(result.windows, result.windows[1:]):
            self.assertAlmostEqual(
                left.end_level_m,
                right.start_level_m,
                places=12,
            )
        for window in result.windows:
            self.assertAlmostEqual(
                window.window_balance_residual_m3,
                0.0,
                places=10,
            )
        self.assertAlmostEqual(
            result.cumulative_balance_residual_m3,
            0.0,
            places=10,
        )

    def test_p2_nonbinding_full_regime_matches_closed_trapezoid_recurrence(self) -> None:
        config = TemporalCouplingConfig(
            basin_area_m2=100.0,
            conductance_m2_per_time=20.0,
            groundwater_head_m=0.2,
            management_min_level_m=0.0,
            request_rate_m3_per_time=10.0,
            datum_m=0.0,
        )
        h0 = 1.0
        horizon = 1.0
        h_eq = (
            config.groundwater_head_m
            - config.request_rate_m3_per_time
            / config.conductance_m2_per_time
        )

        for n in (1, 4, 16, 64):
            dt = horizon / n
            k = config.conductance_m2_per_time * dt / config.basin_area_m2
            g = (1.0 - 0.5 * k) / (1.0 + 0.5 * k)
            expected = h_eq + (g ** n) * (h0 - h_eq)

            result = run_temporal_partition(
                config,
                initial_level_m=h0,
                dts=[dt] * n,
            )
            self.assertTrue(all(w.regime == "FULL" for w in result.windows))
            self.assertAlmostEqual(result.final_level_m, expected, places=11)

    def test_p3_canonical_one_and_two_window_results_match_preregistration(self) -> None:
        one = self.run_equal(1)
        two = self.run_equal(2)

        self.assertEqual(tuple(w.regime for w in one.windows), ("CURTAILED",))
        self.assertAlmostEqual(one.cumulative_delivered_m3, 25.0, places=11)
        self.assertAlmostEqual(
            one.cumulative_signed_exchange_m3, 35.0, places=11
        )
        self.assertAlmostEqual(one.final_level_m, 0.4, places=11)

        self.assertEqual(
            tuple(w.regime for w in two.windows),
            ("FULL", "CURTAILED"),
        )
        self.assertAlmostEqual(two.cumulative_delivered_m3, 27.5, places=11)
        self.assertAlmostEqual(
            two.cumulative_signed_exchange_m3, 32.5, places=11
        )
        self.assertAlmostEqual(two.final_level_m, 0.4, places=11)

    def test_continuous_canonical_event_reference_matches_closed_form(self) -> None:
        config = self.canonical()
        ref = continuous_one_event_reference(
            config,
            initial_level_m=1.0,
            horizon=1.0,
        )

        expected_hit = 2.0 * math.log(1.5)
        expected_delivery = 40.0 * expected_hit
        expected_level = 0.4 * math.exp(
            -0.5 * (1.0 - expected_hit)
        )
        expected_exchange = 100.0 * (1.0 - expected_level) - expected_delivery

        self.assertAlmostEqual(ref.hit_time, expected_hit, places=12)
        self.assertAlmostEqual(
            ref.cumulative_delivered_m3,
            expected_delivery,
            places=12,
        )
        self.assertAlmostEqual(ref.final_level_m, expected_level, places=12)
        self.assertAlmostEqual(
            ref.cumulative_signed_exchange_m3,
            expected_exchange,
            places=12,
        )

    def test_p4_uniform_refinement_has_event_grid_jitter_but_fine_case_is_closer(self) -> None:
        ref = continuous_one_event_reference(
            self.canonical(),
            initial_level_m=1.0,
            horizon=1.0,
        )
        n16 = self.run_equal(16)
        n64 = self.run_equal(64)
        n128 = self.run_equal(128)
        n8192 = self.run_equal(8192)

        h_error_16 = abs(n16.final_level_m - ref.final_level_m)
        h_error_64 = abs(n64.final_level_m - ref.final_level_m)
        h_error_128 = abs(n128.final_level_m - ref.final_level_m)
        h_error_8192 = abs(n8192.final_level_m - ref.final_level_m)

        u_error_16 = abs(
            n16.cumulative_delivered_m3 - ref.cumulative_delivered_m3
        )
        u_error_8192 = abs(
            n8192.cumulative_delivered_m3 - ref.cumulative_delivered_m3
        )

        self.assertGreater(h_error_128, h_error_64)
        self.assertLess(h_error_8192, h_error_16)
        self.assertLess(u_error_8192, u_error_16)

    def test_p5_coarse_window_underdelivers_and_ends_at_threshold_vs_continuous(self) -> None:
        coarse = self.run_equal(1)
        ref = continuous_one_event_reference(
            self.canonical(),
            initial_level_m=1.0,
            horizon=1.0,
        )

        self.assertLess(
            coarse.cumulative_delivered_m3,
            ref.cumulative_delivered_m3,
        )
        self.assertGreater(coarse.final_level_m, ref.final_level_m)
        self.assertAlmostEqual(coarse.final_level_m, 0.4, places=12)
        self.assertLess(ref.final_level_m, 0.4)

    def test_p6_zero_management_window_can_move_level_below_management_threshold(self) -> None:
        result = self.run_equal(4)

        self.assertEqual(
            tuple(w.regime for w in result.windows),
            ("FULL", "FULL", "FULL", "ZERO"),
        )
        self.assertEqual(result.windows[-1].delivered_m3, 0.0)
        self.assertLess(
            result.final_level_m,
            self.canonical().management_min_level_m,
        )
        self.assertGreaterEqual(result.final_level_m, self.canonical().datum_m)

    def test_p7_request_rate_remains_exogenous_after_shortage(self) -> None:
        result = self.run_equal(4)
        expected_request = 40.0 * 0.25

        for window in result.windows:
            self.assertAlmostEqual(window.requested_m3, expected_request, places=12)

        self.assertGreater(result.windows[-1].shortage_m3, 0.0)
        self.assertAlmostEqual(
            result.windows[-1].requested_m3,
            expected_request,
            places=12,
        )

    def test_p8_cumulative_balance_closes_for_multiple_partitions(self) -> None:
        for n in (1, 2, 4, 8, 16, 64):
            result = self.run_equal(n)
            self.assertAlmostEqual(
                result.cumulative_balance_residual_m3,
                0.0,
                places=9,
                msg=f"n={n}",
            )
            for window in result.windows:
                self.assertAlmostEqual(
                    window.window_balance_residual_m3,
                    0.0,
                    places=9,
                    msg=f"n={n}, window={window.index}",
                )

    def test_p9_refinement_sequence_conserves_despite_event_timing_jitter(self) -> None:
        ref = continuous_one_event_reference(
            self.canonical(),
            initial_level_m=1.0,
            horizon=1.0,
        )
        sequence = (16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192)
        results = [self.run_equal(n) for n in sequence]

        for n, result in zip(sequence, results):
            self.assertAlmostEqual(
                result.cumulative_balance_residual_m3,
                0.0,
                places=8,
                msg=f"n={n}",
            )

        first_h_error = abs(results[0].final_level_m - ref.final_level_m)
        last_h_error = abs(results[-1].final_level_m - ref.final_level_m)
        first_u_error = abs(
            results[0].cumulative_delivered_m3 - ref.cumulative_delivered_m3
        )
        last_u_error = abs(
            results[-1].cumulative_delivered_m3 - ref.cumulative_delivered_m3
        )
        self.assertLess(last_h_error, first_h_error)
        self.assertLess(last_u_error, first_u_error)

    def test_invalid_temporal_inputs_are_rejected(self) -> None:
        config = self.canonical()
        with self.assertRaises(ValueError):
            run_temporal_partition(config, initial_level_m=1.0, dts=[])
        with self.assertRaises(ValueError):
            run_temporal_partition(config, initial_level_m=1.0, dts=[0.0])
        with self.assertRaises(ValueError):
            continuous_one_event_reference(
                TemporalCouplingConfig(
                    basin_area_m2=100.0,
                    conductance_m2_per_time=0.0,
                    groundwater_head_m=0.0,
                    management_min_level_m=0.4,
                    request_rate_m3_per_time=40.0,
                ),
                initial_level_m=1.0,
                horizon=1.0,
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
