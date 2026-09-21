from __future__ import annotations

import unittest

from dummy_canopy_irrigation_ledger import (
    CanopyIrrigationFluxes,
    CanopyIrrigationState,
    binding_variant_full_system_residual_m3,
    solve_canopy_irrigation_window,
)


class CanopyIrrigationLedgerTests(unittest.TestCase):
    def state(self) -> CanopyIrrigationState:
        return CanopyIrrigationState(
            surface_storage_m3=100.0,
            canopy_storage_m3=0.0,
            root_storage_m3=40.0,
            groundwater_storage_m3=50.0,
        )

    def fluxes(self, *, exchange: float = 4.0) -> CanopyIrrigationFluxes:
        return CanopyIrrigationFluxes(
            gross_supplied_irrigation_m3=20.0,
            intercepted_m3=5.0,
            net_soil_irrigation_m3=15.0,
            interception_evaporation_m3=2.0,
            surface_groundwater_exchange_m3=exchange,
        )

    def test_d1_canonical_four_store_ledger_matches_preregistration(self) -> None:
        r = solve_canopy_irrigation_window(self.state(), self.fluxes())

        self.assertEqual(r.end.surface_storage_m3, 76.0)
        self.assertEqual(r.end.canopy_storage_m3, 3.0)
        self.assertEqual(r.end.root_storage_m3, 55.0)
        self.assertEqual(r.end.groundwater_storage_m3, 54.0)
        self.assertEqual(r.canopy_storage_change_m3, 3.0)
        self.assertEqual(r.start.total_m3, 190.0)
        self.assertEqual(r.end.total_m3, 188.0)
        self.assertEqual(r.full_system_change_m3, -2.0)
        self.assertAlmostEqual(
            r.full_system_balance_residual_m3, 0.0, places=12
        )

    def test_d2_gross_equals_net_plus_intercepted(self) -> None:
        f = self.fluxes()
        self.assertEqual(
            f.gross_supplied_irrigation_m3,
            f.net_soil_irrigation_m3 + f.intercepted_m3,
        )

    def test_d3_surface_groundwater_exchange_cancels_from_full_ledger(self) -> None:
        plus = solve_canopy_irrigation_window(
            self.state(), self.fluxes(exchange=4.0)
        )
        minus = solve_canopy_irrigation_window(
            self.state(), self.fluxes(exchange=-4.0)
        )

        self.assertAlmostEqual(plus.full_system_change_m3, -2.0, places=12)
        self.assertAlmostEqual(minus.full_system_change_m3, -2.0, places=12)
        self.assertAlmostEqual(
            plus.full_system_balance_residual_m3, 0.0, places=12
        )
        self.assertAlmostEqual(
            minus.full_system_balance_residual_m3, 0.0, places=12
        )

    def test_d4_canopy_excluded_boundary_requires_evaporation_plus_storage_change(self) -> None:
        r = solve_canopy_irrigation_window(self.state(), self.fluxes())

        self.assertEqual(r.canopy_excluded_change_m3, -5.0)
        self.assertEqual(r.canopy_storage_change_m3, 3.0)
        self.assertAlmostEqual(
            r.canopy_excluded_correct_boundary_residual_m3,
            0.0,
            places=12,
        )

    def test_d5_omitting_canopy_storage_term_creates_apparent_three_m3_defect(self) -> None:
        r = solve_canopy_irrigation_window(self.state(), self.fluxes())

        self.assertAlmostEqual(
            r.canopy_excluded_evaporation_only_residual_m3,
            -3.0,
            places=12,
        )

    def test_d6_using_gross_as_soil_input_creates_five_m3_water(self) -> None:
        s = self.state()
        f = self.fluxes()
        residual = binding_variant_full_system_residual_m3(
            s,
            f,
            source_withdrawal_m3=20.0,
            soil_input_m3=20.0,
        )
        self.assertAlmostEqual(residual, 5.0, places=12)

    def test_d7_using_net_as_source_withdrawal_creates_five_m3_water(self) -> None:
        s = self.state()
        f = self.fluxes()
        residual = binding_variant_full_system_residual_m3(
            s,
            f,
            source_withdrawal_m3=15.0,
            soil_input_m3=15.0,
        )
        self.assertAlmostEqual(residual, 5.0, places=12)

    def test_d8_correct_binding_variant_has_zero_residual(self) -> None:
        s = self.state()
        f = self.fluxes()
        residual = binding_variant_full_system_residual_m3(
            s,
            f,
            source_withdrawal_m3=20.0,
            soil_input_m3=15.0,
        )
        self.assertAlmostEqual(residual, 0.0, places=12)

    def test_d9_zero_interception_reduces_to_direct_irrigation_transfer(self) -> None:
        s = self.state()
        f = CanopyIrrigationFluxes(
            gross_supplied_irrigation_m3=20.0,
            intercepted_m3=0.0,
            net_soil_irrigation_m3=20.0,
            interception_evaporation_m3=0.0,
            surface_groundwater_exchange_m3=4.0,
        )
        r = solve_canopy_irrigation_window(s, f)

        self.assertEqual(r.end.canopy_storage_m3, 0.0)
        self.assertEqual(r.end.root_storage_m3, 60.0)
        self.assertAlmostEqual(r.full_system_change_m3, 0.0, places=12)
        self.assertAlmostEqual(
            r.full_system_balance_residual_m3, 0.0, places=12
        )

    def test_d10_preloaded_canopy_can_evaporate_more_than_new_interception(self) -> None:
        s = CanopyIrrigationState(
            surface_storage_m3=100.0,
            canopy_storage_m3=5.0,
            root_storage_m3=40.0,
            groundwater_storage_m3=50.0,
        )
        f = CanopyIrrigationFluxes(
            gross_supplied_irrigation_m3=10.0,
            intercepted_m3=2.0,
            net_soil_irrigation_m3=8.0,
            interception_evaporation_m3=4.0,
            surface_groundwater_exchange_m3=0.0,
        )
        r = solve_canopy_irrigation_window(s, f)

        self.assertEqual(r.end.canopy_storage_m3, 3.0)
        self.assertAlmostEqual(r.full_system_change_m3, -4.0, places=12)
        self.assertAlmostEqual(
            r.full_system_balance_residual_m3, 0.0, places=12
        )

    def test_d11_input_state_is_not_mutated(self) -> None:
        s = self.state()
        snapshot = s
        _ = solve_canopy_irrigation_window(s, self.fluxes())
        self.assertEqual(s, snapshot)

    def test_d12_invalid_gross_net_identity_and_negative_fluxes_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            CanopyIrrigationFluxes(
                gross_supplied_irrigation_m3=20.0,
                intercepted_m3=5.0,
                net_soil_irrigation_m3=16.0,
                interception_evaporation_m3=2.0,
            )
        with self.assertRaises(ValueError):
            CanopyIrrigationFluxes(
                gross_supplied_irrigation_m3=-1.0,
                intercepted_m3=0.0,
                net_soil_irrigation_m3=0.0,
                interception_evaporation_m3=0.0,
            )

    def test_d13_negative_endpoint_storage_is_rejected(self) -> None:
        s = CanopyIrrigationState(
            surface_storage_m3=10.0,
            canopy_storage_m3=0.0,
            root_storage_m3=40.0,
            groundwater_storage_m3=50.0,
        )
        with self.assertRaises(ValueError):
            solve_canopy_irrigation_window(s, self.fluxes())

        s2 = CanopyIrrigationState(
            surface_storage_m3=100.0,
            canopy_storage_m3=1.0,
            root_storage_m3=40.0,
            groundwater_storage_m3=50.0,
        )
        f = CanopyIrrigationFluxes(
            gross_supplied_irrigation_m3=5.0,
            intercepted_m3=1.0,
            net_soil_irrigation_m3=4.0,
            interception_evaporation_m3=3.0,
        )
        with self.assertRaises(ValueError):
            solve_canopy_irrigation_window(s2, f)


if __name__ == "__main__":
    unittest.main(verbosity=2)
