from __future__ import annotations

import unittest

from dummy_head_exchange_diagnostic import (
    LinearHeadExchange,
    prepare_head_driven_window,
)
from dummy_ribasim_reservoir import (
    DummyRibasimConfig,
    DummyRibasimReservoir,
    InfeasibleHydrologyError,
)
from dummy_threeway_water_coupling import (
    DummyModflowParticipant,
    DummySwapParticipant,
    DummySwapState,
    DummyThreeWayCoupler,
)


class HeadExchangeDiagnosticTests(unittest.TestCase):
    def build(self, request: float, storage: float = 100.0, area: float = 100.0):
        swap = DummySwapParticipant(DummySwapState(irrigation_request_m3=request))
        ribasim = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=area),
            initial_volume_m3=storage,
        )
        modflow = DummyModflowParticipant()
        return DummyThreeWayCoupler(swap, ribasim, modflow)

    def test_h1_sign_and_zero_crossing(self) -> None:
        exchange = LinearHeadExchange(conductance_m2_per_time=10.0, dt=2.0)

        infiltration = exchange.forcing(2.0, 1.0)
        drainage = exchange.forcing(1.0, 2.0)
        zero = exchange.forcing(1.5, 1.5)

        self.assertEqual(infiltration.basin_infiltration_m3, 20.0)
        self.assertEqual(infiltration.basin_drainage_m3, 0.0)
        self.assertEqual(drainage.basin_infiltration_m3, 0.0)
        self.assertEqual(drainage.basin_drainage_m3, 20.0)
        self.assertEqual(zero.basin_infiltration_m3, 0.0)
        self.assertEqual(zero.basin_drainage_m3, 0.0)

    def test_h2_groundwater_head_drop_creates_canonical_late_conflict(self) -> None:
        coupler = self.build(request=50.0)
        exchange = LinearHeadExchange(conductance_m2_per_time=60.0, dt=1.0)

        diagnostic = prepare_head_driven_window(
            coupler,
            exchange,
            forecast_groundwater_head_m=1.0,
            actual_groundwater_head_m=0.0,
        )

        self.assertEqual(diagnostic.start_basin_level_m, 1.0)
        self.assertEqual(diagnostic.forecast_signed_exchange_m3, 0.0)
        self.assertEqual(diagnostic.one_pass_actual_signed_exchange_m3, 60.0)
        self.assertEqual(
            diagnostic.candidate.allocation.user_demand_allocated_m3,
            50.0,
        )
        self.assertEqual(
            diagnostic.candidate.realization.user_demand_delivered_m3,
            40.0,
        )
        self.assertEqual(
            diagnostic.candidate.realization.realization_shortage_m3,
            10.0,
        )
        self.assertEqual(diagnostic.realized_end_basin_level_m, 0.0)
        self.assertEqual(diagnostic.endpoint_consistent_signed_exchange_m3, 0.0)
        self.assertEqual(diagnostic.endpoint_exchange_residual_m3, 60.0)

    def test_h3_level_change_produces_nonzero_endpoint_residual(self) -> None:
        coupler = self.build(request=20.0)
        exchange = LinearHeadExchange(conductance_m2_per_time=30.0, dt=1.0)

        diagnostic = prepare_head_driven_window(
            coupler,
            exchange,
            forecast_groundwater_head_m=0.0,
            actual_groundwater_head_m=0.0,
        )

        self.assertEqual(diagnostic.one_pass_actual_signed_exchange_m3, 30.0)
        self.assertEqual(
            diagnostic.candidate.realization.user_demand_delivered_m3,
            20.0,
        )
        self.assertEqual(diagnostic.candidate.realization.end_volume_m3, 50.0)
        self.assertEqual(diagnostic.realized_end_basin_level_m, 0.5)
        self.assertEqual(diagnostic.endpoint_consistent_signed_exchange_m3, 15.0)
        self.assertEqual(diagnostic.endpoint_exchange_residual_m3, 15.0)

    def test_h4_zero_state_change_has_zero_endpoint_residual(self) -> None:
        coupler = self.build(request=0.0)
        exchange = LinearHeadExchange(conductance_m2_per_time=30.0, dt=1.0)

        diagnostic = prepare_head_driven_window(
            coupler,
            exchange,
            forecast_groundwater_head_m=1.0,
            actual_groundwater_head_m=1.0,
        )

        self.assertEqual(diagnostic.start_basin_level_m, 1.0)
        self.assertEqual(diagnostic.realized_end_basin_level_m, 1.0)
        self.assertEqual(diagnostic.one_pass_actual_signed_exchange_m3, 0.0)
        self.assertEqual(diagnostic.endpoint_consistent_signed_exchange_m3, 0.0)
        self.assertEqual(diagnostic.endpoint_exchange_residual_m3, 0.0)

    def test_h5_start_state_physical_exchange_is_management_independent(self) -> None:
        exchange = LinearHeadExchange(conductance_m2_per_time=40.0, dt=1.0)

        no_demand = prepare_head_driven_window(
            self.build(request=0.0),
            exchange,
            forecast_groundwater_head_m=0.0,
            actual_groundwater_head_m=0.0,
        )
        high_demand = prepare_head_driven_window(
            self.build(request=50.0),
            exchange,
            forecast_groundwater_head_m=0.0,
            actual_groundwater_head_m=0.0,
        )

        self.assertEqual(
            no_demand.one_pass_actual_signed_exchange_m3,
            high_demand.one_pass_actual_signed_exchange_m3,
        )
        self.assertNotEqual(
            no_demand.realized_end_basin_level_m,
            high_demand.realized_end_basin_level_m,
        )
        self.assertNotEqual(
            no_demand.endpoint_exchange_residual_m3,
            high_demand.endpoint_exchange_residual_m3,
        )

    def test_h6_excessive_head_driven_infiltration_fails_closed(self) -> None:
        coupler = self.build(request=0.0, storage=10.0, area=100.0)
        exchange = LinearHeadExchange(conductance_m2_per_time=100.0, dt=1.0)

        before = (
            coupler.swap.committed_state,
            coupler.ribasim.committed_state,
            coupler.modflow.committed_state,
        )

        with self.assertRaises(InfeasibleHydrologyError):
            prepare_head_driven_window(
                coupler,
                exchange,
                forecast_groundwater_head_m=-10.0,
                actual_groundwater_head_m=-10.0,
            )

        self.assertEqual(
            before,
            (
                coupler.swap.committed_state,
                coupler.ribasim.committed_state,
                coupler.modflow.committed_state,
            ),
        )

    def test_nonfinite_or_invalid_exchange_configuration_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            LinearHeadExchange(conductance_m2_per_time=-1.0, dt=1.0)
        with self.assertRaises(ValueError):
            LinearHeadExchange(conductance_m2_per_time=1.0, dt=0.0)
        with self.assertRaises(ValueError):
            LinearHeadExchange(conductance_m2_per_time=float("nan"), dt=1.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
