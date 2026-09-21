"""One-Basin competing managed claims oracle for RIBASIM-DUMMY-15.

This first-stage oracle separates:
- exact coupled physical realizability of total managed withdrawal;
- explicit lexicographic distribution of that realizable total between
  root-zone irrigation and one external managed demand.

No forecast/allocation mismatch is included yet.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_rootzone_demand import RootZoneState, request_from_committed_state
from dummy_three_store_internal_ledger import (
    ThreeStoreConfig,
    ThreeStoreState,
    total_three_store_water_m3,
)
from dummy_two_store_management import TwoStoreManagementProblem


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


PRIORITY_ROOT_FIRST = "ROOT_FIRST"
PRIORITY_EXTERNAL_FIRST = "EXTERNAL_FIRST"
_VALID_PRIORITIES = {PRIORITY_ROOT_FIRST, PRIORITY_EXTERNAL_FIRST}


@dataclass(frozen=True)
class CompetingClaimsResult:
    start: ThreeStoreState
    priority: str
    root_request_m3: float
    external_request_m3: float
    total_requested_m3: float
    total_realized_m3: float
    root_delivered_m3: float
    external_delivered_m3: float
    root_shortage_m3: float
    external_shortage_m3: float
    exchange_volume_m3: float
    regime: str
    end: ThreeStoreState
    next_root_request_m3: float
    root_balance_residual_m3: float
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    combined_balance_residual_m3: float


def _split_realized_total(
    *,
    realized_total_m3: float,
    root_request_m3: float,
    external_request_m3: float,
    priority: str,
) -> tuple[float, float]:
    if priority not in _VALID_PRIORITIES:
        raise ValueError(f"unsupported priority: {priority}")

    remaining = realized_total_m3

    if priority == PRIORITY_ROOT_FIRST:
        root = min(root_request_m3, remaining)
        remaining -= root
        external = min(external_request_m3, remaining)
        remaining -= external
    else:
        external = min(external_request_m3, remaining)
        remaining -= external
        root = min(root_request_m3, remaining)
        remaining -= root

    volume_tol = 1.0e-12 * max(
        1.0,
        realized_total_m3,
        root_request_m3 + external_request_m3,
    )
    if remaining > volume_tol:
        raise RuntimeError("priority split left unexplained realized capacity")
    if root < -volume_tol or external < -volume_tol:
        raise RuntimeError("priority split produced negative realized claim")
    if root > root_request_m3 + volume_tol:
        raise RuntimeError("root claim exceeds request")
    if external > external_request_m3 + volume_tol:
        raise RuntimeError("external claim exceeds request")

    return max(0.0, root), max(0.0, external)


def solve_competing_claims(
    config: ThreeStoreConfig,
    state: ThreeStoreState,
    *,
    external_request_m3: float,
    priority: str,
) -> CompetingClaimsResult:
    start = state.validated(config)
    external_request = _finite("external_request_m3", external_request_m3)
    if external_request < 0.0:
        raise ValueError("external_request_m3 must be non-negative")
    if priority not in _VALID_PRIORITIES:
        raise ValueError(f"unsupported priority: {priority}")

    root_request = request_from_committed_state(config.root, start.root)
    total_request = root_request + external_request

    physical = TwoStoreManagementProblem(
        config=config.stores,
        start=start.water,
        dt=config.dt,
        requested_m3=total_request,
        management_min_surface_head_m=config.management_min_surface_head_m,
        surface_datum_m=config.surface_datum_m,
    ).solve()

    root_delivered, external_delivered = _split_realized_total(
        realized_total_m3=physical.delivered_m3,
        root_request_m3=root_request,
        external_request_m3=external_request,
        priority=priority,
    )

    split_residual = (
        root_delivered
        + external_delivered
        - physical.delivered_m3
    )
    split_tol = 1.0e-12 * max(
        1.0,
        physical.delivered_m3,
        total_request,
    )
    if abs(split_residual) > split_tol:
        raise RuntimeError(
            "managed-claim split does not reproduce exact realized total"
        )

    root_end = RootZoneState(
        start.root.storage_m3 + root_delivered
    ).validated(config.root)
    end = ThreeStoreState(
        root=root_end,
        water=physical.end,
    ).validated(config)

    next_root_request = request_from_committed_state(config.root, root_end)

    root_residual = (
        root_end.storage_m3
        - start.root.storage_m3
        - root_delivered
    )

    expected_total_end = (
        total_three_store_water_m3(config, start)
        - external_delivered
    )
    combined_residual = (
        total_three_store_water_m3(config, end)
        - expected_total_end
    )

    return CompetingClaimsResult(
        start=start,
        priority=priority,
        root_request_m3=root_request,
        external_request_m3=external_request,
        total_requested_m3=total_request,
        total_realized_m3=physical.delivered_m3,
        root_delivered_m3=root_delivered,
        external_delivered_m3=external_delivered,
        root_shortage_m3=root_request - root_delivered,
        external_shortage_m3=external_request - external_delivered,
        exchange_volume_m3=physical.exchange_volume_m3,
        regime=physical.regime,
        end=end,
        next_root_request_m3=next_root_request,
        root_balance_residual_m3=root_residual,
        surface_balance_residual_m3=physical.surface_balance_residual_m3,
        groundwater_balance_residual_m3=physical.groundwater_balance_residual_m3,
        combined_balance_residual_m3=combined_residual,
    )
