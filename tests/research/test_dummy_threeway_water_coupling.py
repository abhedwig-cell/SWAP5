from __future__ import annotations

import unittest

from dummy_ribasim_reservoir import (
    BasinWindowForcing,
    DummyRibasimConfig,
    DummyRibasimReservoir,
    InfeasibleHydrologyError,
    StaleCandidateError,
)
from dummy_threeway_water_coupling import (
    DummyModflowParticipant,
    DummyModflowWindow,
    DummySwapParticipant,
    DummySwapState,
    DummyThreeWayCoupler,
)


class DummyThreeWayCouplingTests(unittest.TestCase):
    def build(self, request: float, storage: float = 100.0):
        swap = DummySwapParticipant(DummySwapState(irrigation_request_m3=request))
        ribasim = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=10.0),
            initial_volume_m3=storage,
        )
        modflow = DummyModflowParticipant()
        return swap, ribasim, modflow, DummyThreeWayCoupler(swap, ribasim, modflow)

    def test_c1_forecast_equals_actual_full_delivery_and_single_commit(self) -> None:
        swap, ribasim, modflow, coupler = self.build(30.0)
        forcing = BasinWindowForcing(
            external_inflow_m3=10.0,
            basin_drainage_m3=5.0,
            basin_infiltration_m3=20.0,
        )
        before = (
            swap.committed_state,
            ribasim.committed_state,
            modflow.committed_state,
        )

        candidate = coupler.prepare_window(
            DummyModflowWindow(forecast=forcing, actual=forcing)
        )

        self.assertEqual(
            before,
            (
                swap.committed_state,
                ribasim.committed_state,
                modflow.committed_state,
            ),
        )
        self.assertEqual(candidate.swap_request_m3, 30.0)
        self.assertEqual(candidate.allocation.user_demand_allocated_m3, 30.0)
        self.assertEqual(candidate.realization.user_demand_delivered_m3, 30.0)

        result = coupler.commit(candidate)
        self.assertEqual(result.swap.revision, 1)
        self.assertEqual(result.ribasim.revision, 1)
        self.assertEqual(result.modflow.revision, 1)
        self.assertEqual(result.swap.last_delivered_m3, 30.0)
        self.assertEqual(result.swap.last_shortage_m3, 0.0)
        self.assertEqual(result.ribasim.volume_m3, 65.0)
        self.assertEqual(result.modflow.last_infiltration_m3, 20.0)
        self.assertEqual(result.modflow.last_drainage_m3, 5.0)

    def test_c2_late_conflict_hydrology_reduces_realized_delivery(self) -> None:
        swap, ribasim, modflow, coupler = self.build(50.0)

        candidate = coupler.prepare_window(
            DummyModflowWindow(
                forecast=BasinWindowForcing(basin_infiltration_m3=0.0),
                actual=BasinWindowForcing(basin_infiltration_m3=60.0),
            )
        )

        self.assertEqual(candidate.allocation.user_demand_allocated_m3, 50.0)
        self.assertEqual(candidate.allocation.allocation_shortage_m3, 0.0)
        self.assertEqual(candidate.realization.user_demand_delivered_m3, 40.0)
        self.assertEqual(candidate.realization.realization_shortage_m3, 10.0)
        self.assertEqual(candidate.realization.total_shortage_m3, 10.0)
        self.assertEqual(candidate.realization.end_volume_m3, 0.0)

        result = coupler.commit(candidate)
        self.assertEqual(result.swap.last_delivered_m3, 40.0)
        self.assertEqual(result.swap.last_shortage_m3, 10.0)
        self.assertEqual(result.modflow.last_infiltration_m3, 60.0)
        self.assertEqual(result.ribasim.volume_m3, 0.0)

    def test_c3_allocation_shortage_and_realization_shortage_are_separate(self) -> None:
        swap, _, _, coupler = self.build(80.0)

        candidate = coupler.prepare_window(
            DummyModflowWindow(
                forecast=BasinWindowForcing(basin_infiltration_m3=30.0),
                actual=BasinWindowForcing(basin_infiltration_m3=50.0),
            )
        )

        self.assertEqual(candidate.allocation.user_demand_allocated_m3, 70.0)
        self.assertEqual(candidate.allocation.allocation_shortage_m3, 10.0)
        self.assertEqual(candidate.realization.user_demand_delivered_m3, 50.0)
        self.assertEqual(candidate.realization.realization_shortage_m3, 20.0)
        self.assertEqual(candidate.realization.total_shortage_m3, 30.0)
        self.assertEqual(swap.committed_state.last_shortage_m3, 0.0)

    def test_c4_infeasible_actual_hydrology_fails_with_zero_mutation(self) -> None:
        swap, ribasim, modflow, coupler = self.build(10.0, storage=20.0)
        before = (
            swap.committed_state,
            ribasim.committed_state,
            modflow.committed_state,
        )

        with self.assertRaises(InfeasibleHydrologyError):
            coupler.prepare_window(
                DummyModflowWindow(
                    forecast=BasinWindowForcing(),
                    actual=BasinWindowForcing(basin_infiltration_m3=25.0),
                )
            )

        self.assertEqual(
            before,
            (
                swap.committed_state,
                ribasim.committed_state,
                modflow.committed_state,
            ),
        )

    def test_c5_stale_participant_blocks_coupled_commit_before_mutation(self) -> None:
        swap, ribasim, modflow, coupler = self.build(20.0)
        candidate = coupler.prepare_window(
            DummyModflowWindow(
                forecast=BasinWindowForcing(),
                actual=BasinWindowForcing(),
            )
        )
        modflow.advance_external_revision()

        before = (
            swap.committed_state,
            ribasim.committed_state,
            modflow.committed_state,
        )

        with self.assertRaises(StaleCandidateError):
            coupler.commit(candidate)

        self.assertEqual(
            before,
            (
                swap.committed_state,
                ribasim.committed_state,
                modflow.committed_state,
            ),
        )

    def test_c6_same_window_swap_request_is_candidate_invariant(self) -> None:
        swap, _, _, coupler = self.build(50.0)
        candidate = coupler.prepare_window(
            DummyModflowWindow(
                forecast=BasinWindowForcing(),
                actual=BasinWindowForcing(basin_infiltration_m3=60.0),
            )
        )

        self.assertEqual(candidate.swap_request_m3, 50.0)
        self.assertEqual(swap.committed_request_m3(), 50.0)
        self.assertEqual(candidate.realization.user_demand_delivered_m3, 40.0)

        coupler.commit(candidate)
        self.assertEqual(swap.committed_request_m3(), 50.0)
        self.assertEqual(swap.committed_state.last_delivered_m3, 40.0)
        self.assertEqual(swap.committed_state.last_shortage_m3, 10.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
