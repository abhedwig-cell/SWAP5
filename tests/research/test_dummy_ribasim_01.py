from __future__ import annotations

import math
import unittest

from dummy_ribasim_reservoir import (
    BasinWindowForcing,
    DummyRibasimConfig,
    DummyRibasimReservoir,
    InfeasibleHydrologyError,
    StaleCandidateError,
)


class DummyRibasim01Tests(unittest.TestCase):
    def assert_closed(self, residual_m3: float) -> None:
        self.assertLessEqual(abs(residual_m3), 1.0e-12)

    def test_e1_forecast_equals_realization_full_delivery_and_closure(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=100.0, datum_m=2.0),
            initial_volume_m3=100.0,
        )
        forcing = BasinWindowForcing(
            external_inflow_m3=20.0,
            basin_drainage_m3=5.0,
            basin_infiltration_m3=10.0,
        )
        before = model.committed_state

        allocation = model.prepare_allocation(30.0, forcing)
        candidate = model.realize_step(allocation, forcing)

        self.assertEqual(model.committed_state, before)
        self.assertEqual(allocation.forecast_post_hydrology_volume_m3, 115.0)
        self.assertEqual(allocation.user_demand_allocated_m3, 30.0)
        self.assertEqual(allocation.allocation_shortage_m3, 0.0)
        self.assertEqual(candidate.user_demand_delivered_m3, 30.0)
        self.assertEqual(candidate.realization_shortage_m3, 0.0)
        self.assertEqual(candidate.total_shortage_m3, 0.0)
        self.assertEqual(candidate.end_volume_m3, 85.0)
        self.assertEqual(candidate.end_stage_m, 2.85)
        self.assert_closed(candidate.mass_balance_residual_m3)

    def test_e2_late_conflict_between_allocation_and_realized_infiltration(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=10.0),
            initial_volume_m3=100.0,
        )

        allocation = model.prepare_allocation(
            50.0,
            BasinWindowForcing(basin_infiltration_m3=0.0),
        )
        candidate = model.realize_step(
            allocation,
            BasinWindowForcing(basin_infiltration_m3=60.0),
        )

        self.assertEqual(allocation.user_demand_allocated_m3, 50.0)
        self.assertEqual(allocation.allocation_shortage_m3, 0.0)
        self.assertEqual(candidate.actual_post_hydrology_volume_m3, 40.0)
        self.assertEqual(candidate.user_demand_delivered_m3, 40.0)
        self.assertEqual(candidate.realization_shortage_m3, 10.0)
        self.assertEqual(candidate.total_shortage_m3, 10.0)
        self.assertEqual(candidate.end_volume_m3, 0.0)
        self.assert_closed(candidate.mass_balance_residual_m3)

    def test_e3_user_demand_min_level_constrains_allocation_not_hydrology(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(
                area_m2=25.0,
                user_demand_min_level_m=0.4,
            ),
            initial_volume_m3=100.0,
        )
        forcing = BasinWindowForcing(basin_infiltration_m3=70.0)

        allocation = model.prepare_allocation(50.0, forcing)
        candidate = model.realize_step(allocation, forcing)

        self.assertEqual(model.config.user_demand_min_volume_m3, 10.0)
        self.assertEqual(allocation.forecast_post_hydrology_volume_m3, 30.0)
        self.assertEqual(allocation.user_demand_allocated_m3, 20.0)
        self.assertEqual(allocation.allocation_shortage_m3, 30.0)
        self.assertEqual(candidate.realization_shortage_m3, 0.0)
        self.assertEqual(candidate.total_shortage_m3, 30.0)
        self.assertEqual(candidate.end_volume_m3, 10.0)
        self.assert_closed(candidate.mass_balance_residual_m3)

    def test_e4_infeasible_actual_hydrology_fails_closed(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=10.0),
            initial_volume_m3=20.0,
            revision=7,
        )
        allocation = model.prepare_allocation(
            10.0,
            BasinWindowForcing(),
        )
        before = model.committed_state

        with self.assertRaises(InfeasibleHydrologyError):
            model.realize_step(
                allocation,
                BasinWindowForcing(basin_infiltration_m3=25.0),
            )

        self.assertEqual(model.committed_state, before)

    def test_e5_candidate_commit_and_stale_semantics(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=10.0),
            initial_volume_m3=40.0,
        )
        forcing = BasinWindowForcing()
        allocation_first = model.prepare_allocation(10.0, forcing)
        first = model.realize_step(allocation_first, forcing)
        allocation_stale = model.prepare_allocation(5.0, forcing)
        stale = model.realize_step(allocation_stale, forcing)

        self.assertEqual(model.committed_state.volume_m3, 40.0)
        committed = model.commit(first)
        self.assertEqual(committed.volume_m3, 30.0)
        self.assertEqual(committed.revision, 1)

        with self.assertRaises(StaleCandidateError):
            model.commit(stale)
        with self.assertRaises(StaleCandidateError):
            model.realize_step(allocation_stale, forcing)

        self.assertEqual(model.committed_state, committed)

    def test_e6_stage_volume_mapping_is_invertible(self) -> None:
        config = DummyRibasimConfig(area_m2=250.0, datum_m=-1.5)
        for volume in (0.0, 1.0, 125.0, 1000.0):
            stage = config.stage_from_volume(volume)
            reconstructed = config.volume_from_stage(stage)
            self.assertTrue(
                math.isclose(
                    reconstructed,
                    volume,
                    rel_tol=0.0,
                    abs_tol=1.0e-12,
                )
            )

    def test_unforecast_drainage_cannot_increase_delivery_above_allocation(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=10.0),
            initial_volume_m3=5.0,
        )
        allocation = model.prepare_allocation(20.0, BasinWindowForcing())
        candidate = model.realize_step(
            allocation,
            BasinWindowForcing(basin_drainage_m3=15.0),
        )
        self.assertEqual(allocation.user_demand_allocated_m3, 5.0)
        self.assertEqual(candidate.user_demand_delivered_m3, 5.0)
        self.assertEqual(candidate.end_volume_m3, 15.0)
        self.assert_closed(candidate.mass_balance_residual_m3)

    def test_negative_basin_forcing_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            BasinWindowForcing(basin_infiltration_m3=-1.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
