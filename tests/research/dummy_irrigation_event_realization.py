"""Irrigation-event realization policy oracle for RIBASIM-DUMMY-15C.

This research-only model separates:
- selected irrigation-event request;
- externally available physical supply;
- event-realization policy;
- management continuation state;
- accepted water transfer.

Management state and supplied water share one finalize boundary.
"""

from __future__ import annotations

from dataclasses import dataclass
import math


POLICY_ATOMIC_REJECT = "ATOMIC_EVENT_REJECT"
POLICY_PARTIAL_COMPLETE = "PARTIAL_COMPLETE"
POLICY_PARTIAL_RESIDUAL_ACTIVE = "PARTIAL_RESIDUAL_ACTIVE"
_VALID_POLICIES = {
    POLICY_ATOMIC_REJECT,
    POLICY_PARTIAL_COMPLETE,
    POLICY_PARTIAL_RESIDUAL_ACTIVE,
}


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class IrrigationManagementState:
    dayfix_days: float
    active_event: bool = False
    residual_event_m3: float = 0.0

    def __post_init__(self) -> None:
        dayfix = _finite("dayfix_days", self.dayfix_days)
        residual = _finite("residual_event_m3", self.residual_event_m3)
        if dayfix < 0.0:
            raise ValueError("dayfix_days must be non-negative")
        if residual < 0.0:
            raise ValueError("residual_event_m3 must be non-negative")
        if self.active_event and residual <= 0.0:
            raise ValueError("active_event requires positive residual_event_m3")
        if (not self.active_event) and residual != 0.0:
            raise ValueError(
                "inactive event cannot own residual_event_m3"
            )
        object.__setattr__(self, "dayfix_days", dayfix)
        object.__setattr__(self, "residual_event_m3", residual)


@dataclass(frozen=True)
class IrrigationEventCandidate:
    start_state: IrrigationManagementState
    policy: str
    requested_m3: float
    external_capacity_m3: float
    capacity_shortfall_m3: float
    supplied_m3: float
    realization_shortfall_m3: float
    candidate_state: IrrigationManagementState


@dataclass(frozen=True)
class FinalizedIrrigationEvent:
    accepted: bool
    state: IrrigationManagementState
    supplied_m3: float
    source_storage_delta_m3: float
    irrigation_recipient_delta_m3: float
    water_balance_residual_m3: float


def propose_event_realization(
    state: IrrigationManagementState,
    *,
    requested_m3: float,
    external_capacity_m3: float,
    policy: str,
) -> IrrigationEventCandidate:
    if policy not in _VALID_POLICIES:
        raise ValueError(f"unsupported event realization policy: {policy}")
    requested = _finite("requested_m3", requested_m3)
    capacity = _finite("external_capacity_m3", external_capacity_m3)
    if requested <= 0.0:
        raise ValueError("requested_m3 must be positive")
    if capacity < 0.0:
        raise ValueError("external_capacity_m3 must be non-negative")
    if state.active_event:
        raise ValueError(
            "first-stage DUMMY-15C expects a newly selected event, not an "
            "already active residual event"
        )

    available = min(requested, capacity)
    tol = 1.0e-12 * max(1.0, requested, capacity)
    full = available >= requested - tol
    capacity_shortfall = max(0.0, requested - capacity)

    if full:
        supplied = requested
        candidate_state = IrrigationManagementState(
            dayfix_days=0.0,
            active_event=False,
            residual_event_m3=0.0,
        )
    elif policy == POLICY_ATOMIC_REJECT:
        supplied = 0.0
        candidate_state = state
    elif policy == POLICY_PARTIAL_COMPLETE:
        supplied = available
        candidate_state = IrrigationManagementState(
            dayfix_days=0.0,
            active_event=False,
            residual_event_m3=0.0,
        )
    else:
        supplied = available
        residual = requested - supplied
        if residual <= tol:
            candidate_state = IrrigationManagementState(
                dayfix_days=0.0,
                active_event=False,
                residual_event_m3=0.0,
            )
        else:
            candidate_state = IrrigationManagementState(
                dayfix_days=0.0,
                active_event=True,
                residual_event_m3=residual,
            )

    return IrrigationEventCandidate(
        start_state=state,
        policy=policy,
        requested_m3=requested,
        external_capacity_m3=capacity,
        capacity_shortfall_m3=capacity_shortfall,
        supplied_m3=supplied,
        realization_shortfall_m3=requested - supplied,
        candidate_state=candidate_state,
    )


def finalize_event(
    candidate: IrrigationEventCandidate,
    *,
    accept_water: bool,
    accept_management_state: bool,
) -> FinalizedIrrigationEvent:
    if accept_water != accept_management_state:
        raise ValueError(
            "irrigation water and management state must share one "
            "accept/reject boundary"
        )

    if not accept_water:
        return FinalizedIrrigationEvent(
            accepted=False,
            state=candidate.start_state,
            supplied_m3=0.0,
            source_storage_delta_m3=0.0,
            irrigation_recipient_delta_m3=0.0,
            water_balance_residual_m3=0.0,
        )

    supplied = candidate.supplied_m3
    source_delta = -supplied
    recipient_delta = supplied
    return FinalizedIrrigationEvent(
        accepted=True,
        state=candidate.candidate_state,
        supplied_m3=supplied,
        source_storage_delta_m3=source_delta,
        irrigation_recipient_delta_m3=recipient_delta,
        water_balance_residual_m3=source_delta + recipient_delta,
    )


def next_event_request_m3(
    state: IrrigationManagementState,
    *,
    scheduled_event_m3: float,
    minimum_interval_days: float,
    selection_opportunity: bool,
) -> float:
    scheduled = _finite("scheduled_event_m3", scheduled_event_m3)
    minimum_interval = _finite(
        "minimum_interval_days", minimum_interval_days
    )
    if scheduled <= 0.0:
        raise ValueError("scheduled_event_m3 must be positive")
    if minimum_interval < 0.0:
        raise ValueError("minimum_interval_days must be non-negative")

    if state.active_event:
        return state.residual_event_m3
    if selection_opportunity and state.dayfix_days >= minimum_interval:
        return scheduled
    return 0.0


def management_memory_m3(state: IrrigationManagementState) -> float:
    """Return only explicitly owned event-residual memory."""
    return state.residual_event_m3 if state.active_event else 0.0
