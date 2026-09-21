from __future__ import annotations

import unittest

from dummy_irrigation_event_realization import (
    POLICY_ATOMIC_REJECT,
    POLICY_PARTIAL_COMPLETE,
    POLICY_PARTIAL_RESIDUAL_ACTIVE,
    IrrigationManagementState,
    finalize_event,
    management_memory_m3,
    next_event_request_m3,
    propose_event_realization,
)


class IrrigationEventRealizationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.start = IrrigationManagementState(
            dayfix_days=7.0,
            active_event=False,
            residual_event_m3=0.0,
        )

    def candidate(self, policy: str, capacity: float = 12.0):
        return propose_event_realization(
            self.start,
            requested_m3=20.0,
            external_capacity_m3=capacity,
            policy=policy,
        )

    def test_c1_atomic_reject_matches_preregistration(self) -> None:
        c = self.candidate(POLICY_ATOMIC_REJECT)
        self.assertEqual(c.supplied_m3, 0.0)
        self.assertEqual(c.capacity_shortfall_m3, 8.0)
        self.assertEqual(c.realization_shortfall_m3, 20.0)
        self.assertEqual(c.candidate_state, self.start)
        self.assertEqual(management_memory_m3(c.candidate_state), 0.0)

    def test_c2_partial_complete_matches_preregistration(self) -> None:
        c = self.candidate(POLICY_PARTIAL_COMPLETE)
        self.assertEqual(c.supplied_m3, 12.0)
        self.assertEqual(c.capacity_shortfall_m3, 8.0)
        self.assertEqual(c.realization_shortfall_m3, 8.0)
        self.assertFalse(c.candidate_state.active_event)
        self.assertEqual(c.candidate_state.dayfix_days, 0.0)
        self.assertEqual(c.candidate_state.residual_event_m3, 0.0)

    def test_c3_partial_residual_active_matches_preregistration(self) -> None:
        c = self.candidate(POLICY_PARTIAL_RESIDUAL_ACTIVE)
        self.assertEqual(c.supplied_m3, 12.0)
        self.assertEqual(c.capacity_shortfall_m3, 8.0)
        self.assertEqual(c.realization_shortfall_m3, 8.0)
        self.assertTrue(c.candidate_state.active_event)
        self.assertEqual(c.candidate_state.dayfix_days, 0.0)
        self.assertEqual(c.candidate_state.residual_event_m3, 8.0)
        self.assertEqual(management_memory_m3(c.candidate_state), 8.0)

    def test_c4_same_current_supply_can_commit_different_management_state(self) -> None:
        complete = self.candidate(POLICY_PARTIAL_COMPLETE)
        residual = self.candidate(POLICY_PARTIAL_RESIDUAL_ACTIVE)

        self.assertEqual(complete.supplied_m3, residual.supplied_m3)
        self.assertNotEqual(complete.candidate_state, residual.candidate_state)
        self.assertEqual(management_memory_m3(complete.candidate_state), 0.0)
        self.assertEqual(management_memory_m3(residual.candidate_state), 8.0)

    def test_c5_followup_request_exposes_policy_divergence(self) -> None:
        atomic = self.candidate(POLICY_ATOMIC_REJECT)
        complete = self.candidate(POLICY_PARTIAL_COMPLETE)
        residual = self.candidate(POLICY_PARTIAL_RESIDUAL_ACTIVE)

        kwargs = dict(
            scheduled_event_m3=20.0,
            minimum_interval_days=7.0,
            selection_opportunity=True,
        )
        self.assertEqual(
            next_event_request_m3(atomic.candidate_state, **kwargs),
            20.0,
        )
        self.assertEqual(
            next_event_request_m3(complete.candidate_state, **kwargs),
            0.0,
        )
        self.assertEqual(
            next_event_request_m3(residual.candidate_state, **kwargs),
            8.0,
        )

    def test_c6_accept_commits_water_and_management_state_together(self) -> None:
        c = self.candidate(POLICY_PARTIAL_RESIDUAL_ACTIVE)
        f = finalize_event(
            c,
            accept_water=True,
            accept_management_state=True,
        )
        self.assertTrue(f.accepted)
        self.assertEqual(f.state, c.candidate_state)
        self.assertEqual(f.supplied_m3, 12.0)
        self.assertEqual(f.source_storage_delta_m3, -12.0)
        self.assertEqual(f.irrigation_recipient_delta_m3, 12.0)
        self.assertEqual(f.water_balance_residual_m3, 0.0)

    def test_c7_rollback_rejects_water_and_management_state_together(self) -> None:
        c = self.candidate(POLICY_PARTIAL_RESIDUAL_ACTIVE)
        f = finalize_event(
            c,
            accept_water=False,
            accept_management_state=False,
        )
        self.assertFalse(f.accepted)
        self.assertEqual(f.state, self.start)
        self.assertEqual(f.supplied_m3, 0.0)
        self.assertEqual(f.source_storage_delta_m3, 0.0)
        self.assertEqual(f.irrigation_recipient_delta_m3, 0.0)
        self.assertEqual(f.water_balance_residual_m3, 0.0)

    def test_c8_half_commit_is_forbidden(self) -> None:
        c = self.candidate(POLICY_PARTIAL_COMPLETE)
        with self.assertRaises(ValueError):
            finalize_event(
                c,
                accept_water=True,
                accept_management_state=False,
            )
        with self.assertRaises(ValueError):
            finalize_event(
                c,
                accept_water=False,
                accept_management_state=True,
            )

    def test_c9_full_supply_collapses_all_policies_to_completed_event(self) -> None:
        candidates = [
            self.candidate(policy, capacity=25.0)
            for policy in (
                POLICY_ATOMIC_REJECT,
                POLICY_PARTIAL_COMPLETE,
                POLICY_PARTIAL_RESIDUAL_ACTIVE,
            )
        ]
        for c in candidates:
            self.assertEqual(c.supplied_m3, 20.0)
            self.assertEqual(c.realization_shortfall_m3, 0.0)
            self.assertFalse(c.candidate_state.active_event)
            self.assertEqual(c.candidate_state.dayfix_days, 0.0)
            self.assertEqual(c.candidate_state.residual_event_m3, 0.0)
        self.assertEqual(
            candidates[0].candidate_state,
            candidates[1].candidate_state,
        )
        self.assertEqual(
            candidates[1].candidate_state,
            candidates[2].candidate_state,
        )

    def test_c10_allocation_shortfall_is_not_implicit_management_memory(self) -> None:
        complete = self.candidate(POLICY_PARTIAL_COMPLETE)
        residual = self.candidate(POLICY_PARTIAL_RESIDUAL_ACTIVE)

        self.assertEqual(complete.capacity_shortfall_m3, 8.0)
        self.assertEqual(residual.capacity_shortfall_m3, 8.0)
        self.assertEqual(management_memory_m3(complete.candidate_state), 0.0)
        self.assertEqual(management_memory_m3(residual.candidate_state), 8.0)

    def test_c11_atomic_reject_does_not_double_shortfall_into_backlog(self) -> None:
        c = self.candidate(POLICY_ATOMIC_REJECT)
        self.assertEqual(c.realization_shortfall_m3, 20.0)
        self.assertEqual(management_memory_m3(c.candidate_state), 0.0)
        self.assertEqual(
            next_event_request_m3(
                c.candidate_state,
                scheduled_event_m3=20.0,
                minimum_interval_days=7.0,
                selection_opportunity=True,
            ),
            20.0,
        )

    def test_c12_candidate_evaluation_is_pure(self) -> None:
        snapshot = self.start
        _ = self.candidate(POLICY_PARTIAL_RESIDUAL_ACTIVE)
        self.assertEqual(self.start, snapshot)

    def test_c13_invalid_state_policy_and_volumes_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            IrrigationManagementState(
                dayfix_days=-1.0,
                active_event=False,
                residual_event_m3=0.0,
            )
        with self.assertRaises(ValueError):
            IrrigationManagementState(
                dayfix_days=0.0,
                active_event=False,
                residual_event_m3=1.0,
            )
        with self.assertRaises(ValueError):
            IrrigationManagementState(
                dayfix_days=0.0,
                active_event=True,
                residual_event_m3=0.0,
            )
        with self.assertRaises(ValueError):
            propose_event_realization(
                self.start,
                requested_m3=20.0,
                external_capacity_m3=-1.0,
                policy=POLICY_PARTIAL_COMPLETE,
            )
        with self.assertRaises(ValueError):
            propose_event_realization(
                self.start,
                requested_m3=20.0,
                external_capacity_m3=12.0,
                policy="UNKNOWN",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
