from __future__ import annotations

import unittest

from dummy_rootzone_demand import (
    RootZoneConfig,
    RootZoneForcing,
    RootZoneInfeasibleLossError,
    RootZoneState,
    prepare_rootzone_window,
    request_from_committed_state,
    run_rootzone_sequence,
)


class RootZoneDemandTests(unittest.TestCase):
    def config(self) -> RootZoneConfig:
        return RootZoneConfig(capacity_m3=100.0, target_m3=80.0)

    def assert_closed(self, result) -> None:
        self.assertAlmostEqual(result.balance_residual_m3, 0.0, places=12)

    def test_r1_full_supply_fills_committed_deficit(self) -> None:
        r = prepare_rootzone_window(
            self.config(),
            RootZoneState(60.0),
            RootZoneForcing(available_supply_m3=20.0),
        )

        self.assertEqual(r.request_m3, 20.0)
        self.assertEqual(r.delivered_m3, 20.0)
        self.assertEqual(r.shortage_m3, 0.0)
        self.assertEqual(r.end.storage_m3, 80.0)
        self.assertEqual(r.next_request_m3, 0.0)
        self.assert_closed(r)

    def test_r2_same_window_loss_creates_next_request_not_second_current_request(self) -> None:
        r = prepare_rootzone_window(
            self.config(),
            RootZoneState(60.0),
            RootZoneForcing(
                available_supply_m3=20.0,
                prescribed_loss_m3=10.0,
            ),
        )

        self.assertEqual(r.request_m3, 20.0)
        self.assertEqual(r.delivered_m3, 20.0)
        self.assertEqual(r.shortage_m3, 0.0)
        self.assertEqual(r.end.storage_m3, 70.0)
        self.assertEqual(r.next_request_m3, 10.0)
        self.assert_closed(r)

    def test_r3_rain_can_erase_next_demand_after_current_shortage(self) -> None:
        r = prepare_rootzone_window(
            self.config(),
            RootZoneState(60.0),
            RootZoneForcing(
                available_supply_m3=5.0,
                rainfall_m3=20.0,
            ),
        )

        self.assertEqual(r.request_m3, 20.0)
        self.assertEqual(r.delivered_m3, 5.0)
        self.assertEqual(r.shortage_m3, 15.0)
        self.assertEqual(r.end.storage_m3, 85.0)
        self.assertEqual(r.next_request_m3, 0.0)
        self.assert_closed(r)

    def test_r4_capacity_excess_becomes_exact_drainage(self) -> None:
        r = prepare_rootzone_window(
            RootZoneConfig(capacity_m3=100.0, target_m3=90.0),
            RootZoneState(90.0),
            RootZoneForcing(
                rainfall_m3=25.0,
                prescribed_loss_m3=5.0,
            ),
        )

        self.assertEqual(r.request_m3, 0.0)
        self.assertEqual(r.delivered_m3, 0.0)
        self.assertEqual(r.drainage_m3, 10.0)
        self.assertEqual(r.end.storage_m3, 100.0)
        self.assert_closed(r)

    def test_r5_multiwindow_cumulative_balance_closes(self) -> None:
        result = run_rootzone_sequence(
            self.config(),
            initial=RootZoneState(60.0),
            forcings=[
                RootZoneForcing(
                    available_supply_m3=5.0,
                    rainfall_m3=0.0,
                    prescribed_loss_m3=5.0,
                ),
                RootZoneForcing(
                    available_supply_m3=10.0,
                    rainfall_m3=20.0,
                    prescribed_loss_m3=3.0,
                ),
                RootZoneForcing(
                    available_supply_m3=50.0,
                    rainfall_m3=10.0,
                    prescribed_loss_m3=8.0,
                ),
            ],
        )

        for window in result.windows:
            self.assert_closed(window)
        self.assertAlmostEqual(
            result.cumulative_balance_residual_m3,
            0.0,
            places=12,
        )
        self.assertAlmostEqual(
            result.final.storage_m3 - result.initial.storage_m3,
            result.cumulative_delivered_m3
            + result.cumulative_rainfall_m3
            - result.cumulative_prescribed_loss_m3
            - result.cumulative_drainage_m3,
            places=12,
        )

    def test_r6_same_committed_storage_implies_same_request_despite_different_shortage_history(self) -> None:
        history_with_shortage = prepare_rootzone_window(
            self.config(),
            RootZoneState(60.0),
            RootZoneForcing(
                available_supply_m3=5.0,
                rainfall_m3=15.0,
            ),
        )
        history_without_shortage = prepare_rootzone_window(
            self.config(),
            RootZoneState(80.0),
            RootZoneForcing(),
        )

        self.assertEqual(history_with_shortage.shortage_m3, 15.0)
        self.assertEqual(history_without_shortage.shortage_m3, 0.0)
        self.assertEqual(history_with_shortage.end.storage_m3, 80.0)
        self.assertEqual(history_without_shortage.end.storage_m3, 80.0)
        self.assertEqual(
            request_from_committed_state(
                self.config(),
                history_with_shortage.end,
            ),
            request_from_committed_state(
                self.config(),
                history_without_shortage.end,
            ),
        )

    def test_r7_available_supply_above_request_does_not_overdeliver(self) -> None:
        r = prepare_rootzone_window(
            self.config(),
            RootZoneState(60.0),
            RootZoneForcing(available_supply_m3=100.0),
        )

        self.assertEqual(r.request_m3, 20.0)
        self.assertEqual(r.delivered_m3, 20.0)
        self.assertEqual(r.end.storage_m3, 80.0)
        self.assert_closed(r)

    def test_r8_request_is_frozen_from_start_state(self) -> None:
        state = RootZoneState(60.0)
        start_request = request_from_committed_state(self.config(), state)
        r = prepare_rootzone_window(
            self.config(),
            state,
            RootZoneForcing(
                available_supply_m3=20.0,
                prescribed_loss_m3=15.0,
            ),
        )

        self.assertEqual(start_request, 20.0)
        self.assertEqual(r.request_m3, start_request)
        self.assertEqual(r.end.storage_m3, 65.0)
        self.assertEqual(r.next_request_m3, 15.0)
        self.assertEqual(r.delivered_m3, 20.0)

    def test_r9_infeasible_prescribed_loss_fails_closed(self) -> None:
        with self.assertRaises(RootZoneInfeasibleLossError):
            prepare_rootzone_window(
                self.config(),
                RootZoneState(10.0),
                RootZoneForcing(
                    available_supply_m3=0.0,
                    prescribed_loss_m3=11.0,
                ),
            )

    def test_r10_invalid_inputs_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            RootZoneConfig(capacity_m3=0.0, target_m3=0.0)
        with self.assertRaises(ValueError):
            RootZoneConfig(capacity_m3=100.0, target_m3=101.0)
        with self.assertRaises(ValueError):
            RootZoneState(-1.0).validated(self.config())
        with self.assertRaises(ValueError):
            RootZoneForcing(available_supply_m3=-1.0)
        with self.assertRaises(ValueError):
            run_rootzone_sequence(
                self.config(),
                initial=RootZoneState(60.0),
                forcings=[],
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
