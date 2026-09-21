"""Forecast allocation versus physical realization for RIBASIM-DUMMY-15B.

The model separates four layers:

1. demand from committed state;
2. forecast capacity;
3. lexicographic allocation;
4. physical realization and supplied-flow policy.

Only supplied flow changes physical state.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_competing_claims import (
    PRIORITY_EXTERNAL_FIRST,
    PRIORITY_ROOT_FIRST,
)
from dummy_rootzone_demand import RootZoneState, request_from_committed_state
from dummy_three_store_internal_ledger import (
    ThreeStoreConfig,
    ThreeStoreState,
    total_three_store_water_m3,
)
from dummy_two_store_management import TwoStoreManagementProblem


POLICY_PRIORITY_PRESERVING = "PRIORITY_PRESERVING"
POLICY_PROPORTIONAL = "PROPORTIONAL"
_VALID_POLICIES = {POLICY_PRIORITY_PRESERVING, POLICY_PROPORTIONAL}
_VALID_PRIORITIES = {PRIORITY_ROOT_FIRST, PRIORITY_EXTERNAL_FIRST}


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


def _canonicalize_surface_datum_roundoff(
    config: ThreeStoreConfig,
    water,
):
    head = water.surface_head_m
    datum = config.surface_datum_m
    scale = max(1.0, abs(head), abs(datum))
    tol = 1.0e-12 * scale
    if head < datum:
        if head < datum - tol:
            raise ValueError("physical endpoint lies materially below surface datum")
        return type(water)(
            surface_head_m=datum,
            groundwater_head_m=water.groundwater_head_m,
        )
    return water


@dataclass(frozen=True)
class AllocationVector:
    root_m3: float
    external_m3: float

    @property
    def total_m3(self) -> float:
        return self.root_m3 + self.external_m3


@dataclass(frozen=True)
class ForecastRealizationResult:
    start: ThreeStoreState
    priority: str
    realization_policy: str
    forecast_capacity_m3: float
    root_demand_m3: float
    external_demand_m3: float
    allocated: AllocationVector
    supplied: AllocationVector
    allocation_shortfall: AllocationVector
    realization_shortfall: AllocationVector
    physical_requested_m3: float
    physical_supplied_total_m3: float
    exchange_volume_m3: float
    regime: str
    end: ThreeStoreState
    next_root_request_m3: float
    root_balance_residual_m3: float
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    combined_balance_residual_m3: float


def _allocate(
    *,
    root_demand_m3: float,
    external_demand_m3: float,
    forecast_capacity_m3: float,
    priority: str,
) -> AllocationVector:
    if priority not in _VALID_PRIORITIES:
        raise ValueError(f"unsupported priority: {priority}")

    remaining = min(
        root_demand_m3 + external_demand_m3,
        forecast_capacity_m3,
    )

    if priority == PRIORITY_ROOT_FIRST:
        root = min(root_demand_m3, remaining)
        remaining -= root
        external = min(external_demand_m3, remaining)
        remaining -= external
    else:
        external = min(external_demand_m3, remaining)
        remaining -= external
        root = min(root_demand_m3, remaining)
        remaining -= root

    tol = 1.0e-12 * max(
        1.0,
        forecast_capacity_m3,
        root_demand_m3 + external_demand_m3,
    )
    if remaining > tol:
        raise RuntimeError("allocation left unexplained forecast capacity")

    return AllocationVector(
        root_m3=max(0.0, root),
        external_m3=max(0.0, external),
    )


def _priority_preserving_supply(
    *,
    allocated: AllocationVector,
    supplied_total_m3: float,
    priority: str,
) -> AllocationVector:
    remaining = supplied_total_m3

    if priority == PRIORITY_ROOT_FIRST:
        root = min(allocated.root_m3, remaining)
        remaining -= root
        external = min(allocated.external_m3, remaining)
        remaining -= external
    elif priority == PRIORITY_EXTERNAL_FIRST:
        external = min(allocated.external_m3, remaining)
        remaining -= external
        root = min(allocated.root_m3, remaining)
        remaining -= root
    else:
        raise ValueError(f"unsupported priority: {priority}")

    tol = 1.0e-12 * max(1.0, allocated.total_m3, supplied_total_m3)
    if remaining > tol:
        raise RuntimeError("priority-preserving supply left unexplained capacity")

    return AllocationVector(
        root_m3=max(0.0, root),
        external_m3=max(0.0, external),
    )


def _proportional_supply(
    *,
    allocated: AllocationVector,
    supplied_total_m3: float,
) -> AllocationVector:
    if allocated.total_m3 <= 0.0:
        if abs(supplied_total_m3) > 1.0e-12:
            raise RuntimeError("positive supplied volume without allocation")
        return AllocationVector(0.0, 0.0)

    rho = supplied_total_m3 / allocated.total_m3
    tol = 1.0e-12
    if rho < -tol or rho > 1.0 + tol:
        raise RuntimeError("proportional realization factor outside [0,1]")
    rho = min(1.0, max(0.0, rho))

    return AllocationVector(
        root_m3=rho * allocated.root_m3,
        external_m3=rho * allocated.external_m3,
    )


def solve_forecast_realization(
    config: ThreeStoreConfig,
    state: ThreeStoreState,
    *,
    external_demand_m3: float,
    forecast_capacity_m3: float,
    priority: str,
    realization_policy: str,
) -> ForecastRealizationResult:
    start = state.validated(config)
    external_demand = _finite("external_demand_m3", external_demand_m3)
    forecast_capacity = _finite("forecast_capacity_m3", forecast_capacity_m3)

    if external_demand < 0.0:
        raise ValueError("external_demand_m3 must be non-negative")
    if forecast_capacity < 0.0:
        raise ValueError("forecast_capacity_m3 must be non-negative")
    if priority not in _VALID_PRIORITIES:
        raise ValueError(f"unsupported priority: {priority}")
    if realization_policy not in _VALID_POLICIES:
        raise ValueError(f"unsupported realization policy: {realization_policy}")

    root_demand = request_from_committed_state(config.root, start.root)

    allocated = _allocate(
        root_demand_m3=root_demand,
        external_demand_m3=external_demand,
        forecast_capacity_m3=forecast_capacity,
        priority=priority,
    )

    physical = TwoStoreManagementProblem(
        config=config.stores,
        start=start.water,
        dt=config.dt,
        requested_m3=allocated.total_m3,
        management_min_surface_head_m=config.management_min_surface_head_m,
        surface_datum_m=config.surface_datum_m,
    ).solve()

    supplied_total = physical.delivered_m3
    if realization_policy == POLICY_PRIORITY_PRESERVING:
        supplied = _priority_preserving_supply(
            allocated=allocated,
            supplied_total_m3=supplied_total,
            priority=priority,
        )
    else:
        supplied = _proportional_supply(
            allocated=allocated,
            supplied_total_m3=supplied_total,
        )

    tol = 1.0e-10 * max(
        1.0,
        root_demand + external_demand,
        allocated.total_m3,
        supplied_total,
    )
    if supplied.root_m3 > allocated.root_m3 + tol:
        raise RuntimeError("supplied root flow exceeds allocation")
    if supplied.external_m3 > allocated.external_m3 + tol:
        raise RuntimeError("supplied external flow exceeds allocation")
    if abs(supplied.total_m3 - supplied_total) > tol:
        raise RuntimeError("supplied split does not reproduce physical total")

    root_end = RootZoneState(
        start.root.storage_m3 + supplied.root_m3
    ).validated(config.root)
    physical_end = _canonicalize_surface_datum_roundoff(config, physical.end)
    end = ThreeStoreState(
        root=root_end,
        water=physical_end,
    ).validated(config)

    next_root_request = request_from_committed_state(config.root, root_end)

    root_residual = (
        root_end.storage_m3
        - start.root.storage_m3
        - supplied.root_m3
    )

    expected_total_end = (
        total_three_store_water_m3(config, start)
        - supplied.external_m3
    )
    combined_residual = (
        total_three_store_water_m3(config, end)
        - expected_total_end
    )

    return ForecastRealizationResult(
        start=start,
        priority=priority,
        realization_policy=realization_policy,
        forecast_capacity_m3=forecast_capacity,
        root_demand_m3=root_demand,
        external_demand_m3=external_demand,
        allocated=allocated,
        supplied=supplied,
        allocation_shortfall=AllocationVector(
            root_m3=root_demand - allocated.root_m3,
            external_m3=external_demand - allocated.external_m3,
        ),
        realization_shortfall=AllocationVector(
            root_m3=allocated.root_m3 - supplied.root_m3,
            external_m3=allocated.external_m3 - supplied.external_m3,
        ),
        physical_requested_m3=allocated.total_m3,
        physical_supplied_total_m3=supplied_total,
        exchange_volume_m3=physical.exchange_volume_m3,
        regime=physical.regime,
        end=end,
        next_root_request_m3=next_root_request,
        root_balance_residual_m3=root_residual,
        surface_balance_residual_m3=physical.surface_balance_residual_m3,
        groundwater_balance_residual_m3=physical.groundwater_balance_residual_m3,
        combined_balance_residual_m3=combined_residual,
    )
