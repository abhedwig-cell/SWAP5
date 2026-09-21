from __future__ import annotations

import math
import unittest

from dummy_ribasim_reservoir import (
    DummyRibasimConfig,
    DummyRibasimReservoir,
    InfeasibleHydrologyError,
    StaleCandidateError,
    StepForcing,
)


class DummyRibasim01Tests(unittest.TestCase):
    def assert_closed(self, residual_m3: float) -> None:
        self.assertLessEqual(abs(residual_m3), 1.0e-12)

    def test_e1_no_conflict_full_delivery_and_mass_closure(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=100.0, datum_m=2.0),
            initial_volume_m3=100.0,
        )
        before = model.committed_state
        candidate = model.prepare_step(
            StepForcing(
                external_inflow_m3=20.0,
                gw_exfiltration_m3=5.0,
                gw_infiltration_m3=10.0,
                irrigation_request_m3=30.0,
            )
        )

        self.assertEqual(model.committed_state, before)
        self.assertEqual(candidate.pre_hydrology_volume_m3, 125.0)
        self.assertEqual(candidate.post_hydrology_volume_m3, 115.0)
        self.assertEqual(candidate.irrigation_delivered_m3, 30.0)
        self.assertEqual(candidate.irrigation_shortage_m3, 0.0)
        self.assertEqual(candidate.end_volume_m3, 85.0)
        self.assertEqual(candidate.end_stage_m, 2.85)
        self.assert_closed(candidate.mass_balance_residual_m3)

    def test_e2_late_conflict_hydrology_has_priority(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=10.0),
            initial_volume_m3=100.0,
        )

        candidate = model.prepare_step(
            StepForcing(
                gw_infiltration_m3=60.0,
                irrigation_request_m3=50.0,
            )
        )

        # Looking only at start-of-step storage would suggest 50 m3 can be
        # delivered. The mandatory physical loss leaves only 40 m3.
        self.assertGreaterEqual(candidate.start_volume_m3, 50.0)
        self.assertEqual(candidate.post_hydrology_volume_m3, 40.0)
        self.assertEqual(candidate.irrigation_delivered_m3, 40.0)
        self.assertEqual(candidate.irrigation_shortage_m3, 10.0)
        self.assertEqual(candidate.end_volume_m3, 0.0)
        self.assert_closed(candidate.mass_balance_residual_m3)

    def test_e3_management_reserve_only_constrains_management(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(
                area_m2=25.0,
                management_reserve_m3=10.0,
            ),
            initial_volume_m3=100.0,
        )

        candidate = model.prepare_step(
            StepForcing(
                gw_infiltration_m3=70.0,
                irrigation_request_m3=50.0,
            )
        )

        self.assertEqual(candidate.post_hydrology_volume_m3, 30.0)
        self.assertEqual(candidate.irrigation_delivered_m3, 20.0)
        self.assertEqual(candidate.irrigation_shortage_m3, 30.0)
        self.assertEqual(candidate.end_volume_m3, 10.0)
        self.assert_closed(candidate.mass_balance_residual_m3)

    def test_e4_infeasible_hydrology_fails_closed_without_mutation(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=10.0),
            initial_volume_m3=20.0,
            revision=7,
        )
        before = model.committed_state

        with self.assertRaises(InfeasibleHydrologyError):
            model.prepare_step(
                StepForcing(
                    gw_infiltration_m3=25.0,
                    irrigation_request_m3=100.0,
                )
            )

        self.assertEqual(model.committed_state, before)

    def test_e5_candidate_commit_and_stale_candidate_semantics(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=10.0),
            initial_volume_m3=40.0,
        )
        first = model.prepare_step(StepForcing(irrigation_request_m3=10.0))
        stale = model.prepare_step(StepForcing(irrigation_request_m3=5.0))

        self.assertEqual(model.committed_state.volume_m3, 40.0)
        committed = model.commit(first)
        self.assertEqual(committed.volume_m3, 30.0)
        self.assertEqual(committed.revision, 1)

        with self.assertRaises(StaleCandidateError):
            model.commit(stale)

        self.assertEqual(model.committed_state, committed)

    def test_e6_stage_volume_mapping_is_invertible(self) -> None:
        config = DummyRibasimConfig(area_m2=250.0, datum_m=-1.5)
        for volume in (0.0, 1.0, 125.0, 1000.0):
            stage = config.stage_from_volume(volume)
            reconstructed = config.volume_from_stage(stage)
            self.assertTrue(math.isclose(reconstructed, volume, rel_tol=0.0, abs_tol=1e-12))

    def test_groundwater_exfiltration_adds_physical_water(self) -> None:
        model = DummyRibasimReservoir(
            DummyRibasimConfig(area_m2=10.0),
            initial_volume_m3=5.0,
        )
        candidate = model.prepare_step(
            StepForcing(
                gw_exfiltration_m3=15.0,
                gw_infiltration_m3=8.0,
                irrigation_request_m3=7.0,
            )
        )
        self.assertEqual(candidate.end_volume_m3, 5.0)
        self.assertEqual(candidate.irrigation_delivered_m3, 7.0)
        self.assert_closed(candidate.mass_balance_residual_m3)

    def test_negative_forcing_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            StepForcing(gw_infiltration_m3=-1.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
