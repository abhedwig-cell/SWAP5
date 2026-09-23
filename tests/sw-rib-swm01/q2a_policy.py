from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Tuple


@dataclass(frozen=True)
class AutomaticManagementConfig:
    wlsman_cm: Tuple[float, ...]
    gwlcrit_cm: Tuple[float, ...]
    vcrit_cm: Tuple[float, ...]
    hcrit_cm: Tuple[float, ...]
    dropr_cm_per_day: float
    dropr_activation_threshold_cm_per_day: float = 0.001

    def __post_init__(self) -> None:
        n = len(self.wlsman_cm)
        if n < 1:
            raise ValueError("at least one management phase is required")
        if not (len(self.gwlcrit_cm) == len(self.vcrit_cm) == len(self.hcrit_cm) == n):
            raise ValueError("management tables must have equal length")

    @property
    def nphase(self) -> int:
        return len(self.wlsman_cm)


@dataclass(frozen=True)
class AcceptedPolicyState:
    wlstar_cm: float


@dataclass(frozen=True)
class AcceptedHydraulicView:
    groundwater_level_cm: float
    total_air_volume_cm: float
    selected_pressure_head_cm: float


@dataclass(frozen=True)
class PolicyTrial:
    origin_wlstar_cm: float
    adjustment_event: bool
    selected_phase: Optional[int]
    requested_target_cm: float
    candidate_wlstar_cm: float
    dt_day: float


def select_phase(
    cfg: AutomaticManagementConfig, view: AcceptedHydraulicView
) -> int:
    phase = cfg.nphase

    while phase > 1 and view.groundwater_level_cm > cfg.gwlcrit_cm[phase - 1]:
        phase -= 1

    while phase > 1 and view.total_air_volume_cm < cfg.vcrit_cm[phase - 1]:
        phase -= 1

    while (
        phase > 1
        and view.selected_pressure_head_cm > cfg.hcrit_cm[phase - 1]
    ):
        phase -= 1

    return phase


def evaluate_policy_trial(
    cfg: AutomaticManagementConfig,
    accepted: AcceptedPolicyState,
    view: AcceptedHydraulicView,
    *,
    adjustment_event: bool,
    dt_day: float,
) -> PolicyTrial:
    if dt_day < 0.0:
        raise ValueError("dt_day must be non-negative")

    if adjustment_event:
        phase = select_phase(cfg, view)
        requested = cfg.wlsman_cm[phase - 1]
    else:
        phase = None
        requested = accepted.wlstar_cm

    candidate = requested
    if (
        requested < accepted.wlstar_cm
        and cfg.dropr_cm_per_day > cfg.dropr_activation_threshold_cm_per_day
    ):
        candidate = max(
            requested,
            accepted.wlstar_cm - cfg.dropr_cm_per_day * dt_day,
        )

    return PolicyTrial(
        origin_wlstar_cm=accepted.wlstar_cm,
        adjustment_event=adjustment_event,
        selected_phase=phase,
        requested_target_cm=requested,
        candidate_wlstar_cm=candidate,
        dt_day=dt_day,
    )


def commit_policy_trial(
    accepted: AcceptedPolicyState, trial: PolicyTrial
) -> AcceptedPolicyState:
    if trial.origin_wlstar_cm != accepted.wlstar_cm:
        raise ValueError("stale policy trial: accepted origin changed")
    return AcceptedPolicyState(wlstar_cm=trial.candidate_wlstar_cm)
