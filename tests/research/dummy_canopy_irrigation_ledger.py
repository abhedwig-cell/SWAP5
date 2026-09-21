"""Explicit canopy irrigation ledger for RIBASIM-DUMMY-15D.

Research-only algebra for distinguishing:
- gross irrigation withdrawn from surface water;
- intercepted water entering canopy storage;
- net irrigation reaching the soil/root store;
- interception evaporation;
- reciprocal surface-groundwater exchange.

No production Rutter algorithm is reproduced here.
"""

from __future__ import annotations

from dataclasses import dataclass
import math


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class CanopyIrrigationState:
    surface_storage_m3: float
    canopy_storage_m3: float
    root_storage_m3: float
    groundwater_storage_m3: float

    def __post_init__(self) -> None:
        values = {
            "surface_storage_m3": self.surface_storage_m3,
            "canopy_storage_m3": self.canopy_storage_m3,
            "root_storage_m3": self.root_storage_m3,
            "groundwater_storage_m3": self.groundwater_storage_m3,
        }
        for name, value in values.items():
            value = _finite(name, value)
            if value < 0.0:
                raise ValueError(f"{name} must be non-negative")
            object.__setattr__(self, name, value)

    @property
    def total_m3(self) -> float:
        return (
            self.surface_storage_m3
            + self.canopy_storage_m3
            + self.root_storage_m3
            + self.groundwater_storage_m3
        )

    @property
    def total_without_canopy_m3(self) -> float:
        return (
            self.surface_storage_m3
            + self.root_storage_m3
            + self.groundwater_storage_m3
        )


@dataclass(frozen=True)
class CanopyIrrigationFluxes:
    gross_supplied_irrigation_m3: float
    intercepted_m3: float
    net_soil_irrigation_m3: float
    interception_evaporation_m3: float
    surface_groundwater_exchange_m3: float = 0.0

    def __post_init__(self) -> None:
        nonnegative = {
            "gross_supplied_irrigation_m3": self.gross_supplied_irrigation_m3,
            "intercepted_m3": self.intercepted_m3,
            "net_soil_irrigation_m3": self.net_soil_irrigation_m3,
            "interception_evaporation_m3": self.interception_evaporation_m3,
        }
        for name, value in nonnegative.items():
            value = _finite(name, value)
            if value < 0.0:
                raise ValueError(f"{name} must be non-negative")
            object.__setattr__(self, name, value)

        exchange = _finite(
            "surface_groundwater_exchange_m3",
            self.surface_groundwater_exchange_m3,
        )
        object.__setattr__(
            self,
            "surface_groundwater_exchange_m3",
            exchange,
        )

        residual = (
            self.gross_supplied_irrigation_m3
            - self.net_soil_irrigation_m3
            - self.intercepted_m3
        )
        tol = 1.0e-12 * max(
            1.0,
            self.gross_supplied_irrigation_m3,
            self.net_soil_irrigation_m3,
            self.intercepted_m3,
        )
        if abs(residual) > tol:
            raise ValueError(
                "gross irrigation must equal net soil irrigation plus "
                "intercepted irrigation"
            )


@dataclass(frozen=True)
class CanopyLedgerResult:
    start: CanopyIrrigationState
    fluxes: CanopyIrrigationFluxes
    end: CanopyIrrigationState
    canopy_storage_change_m3: float
    full_system_change_m3: float
    full_system_balance_residual_m3: float
    canopy_excluded_change_m3: float
    canopy_excluded_correct_boundary_residual_m3: float
    canopy_excluded_evaporation_only_residual_m3: float


def solve_canopy_irrigation_window(
    state: CanopyIrrigationState,
    fluxes: CanopyIrrigationFluxes,
) -> CanopyLedgerResult:
    g = fluxes.gross_supplied_irrigation_m3
    i = fluxes.intercepted_m3
    n = fluxes.net_soil_irrigation_m3
    e = fluxes.interception_evaporation_m3
    v = fluxes.surface_groundwater_exchange_m3

    end_values = {
        "surface_storage_m3": state.surface_storage_m3 - g - v,
        "canopy_storage_m3": state.canopy_storage_m3 + i - e,
        "root_storage_m3": state.root_storage_m3 + n,
        "groundwater_storage_m3": state.groundwater_storage_m3 + v,
    }

    tol = 1.0e-12 * max(
        1.0,
        *(abs(x) for x in end_values.values()),
        state.total_m3,
        g,
        i,
        n,
        e,
        abs(v),
    )
    for name, value in end_values.items():
        if value < -tol:
            raise ValueError(f"{name} would become negative")
        if value < 0.0:
            end_values[name] = 0.0

    end = CanopyIrrigationState(**end_values)
    delta_c = end.canopy_storage_m3 - state.canopy_storage_m3
    full_change = end.total_m3 - state.total_m3
    full_residual = full_change + e

    excluded_change = (
        end.total_without_canopy_m3
        - state.total_without_canopy_m3
    )
    excluded_correct_residual = excluded_change + e + delta_c
    excluded_evap_only_residual = excluded_change + e

    return CanopyLedgerResult(
        start=state,
        fluxes=fluxes,
        end=end,
        canopy_storage_change_m3=delta_c,
        full_system_change_m3=full_change,
        full_system_balance_residual_m3=full_residual,
        canopy_excluded_change_m3=excluded_change,
        canopy_excluded_correct_boundary_residual_m3=(
            excluded_correct_residual
        ),
        canopy_excluded_evaporation_only_residual_m3=(
            excluded_evap_only_residual
        ),
    )


def binding_variant_full_system_residual_m3(
    state: CanopyIrrigationState,
    fluxes: CanopyIrrigationFluxes,
    *,
    source_withdrawal_m3: float,
    soil_input_m3: float,
) -> float:
    """Evaluate a deliberately selected gross/net binding variant.

    Canopy interception and evaporation retain their declared values while
    source withdrawal and soil input may be intentionally misbound.
    The returned residual is zero only for a globally consistent full-system
    ledger.
    """
    source = _finite("source_withdrawal_m3", source_withdrawal_m3)
    soil = _finite("soil_input_m3", soil_input_m3)
    if source < 0.0 or soil < 0.0:
        raise ValueError("binding variant volumes must be non-negative")

    i = fluxes.intercepted_m3
    e = fluxes.interception_evaporation_m3
    v = fluxes.surface_groundwater_exchange_m3

    surface_end = state.surface_storage_m3 - source - v
    canopy_end = state.canopy_storage_m3 + i - e
    root_end = state.root_storage_m3 + soil
    groundwater_end = state.groundwater_storage_m3 + v

    total_end = surface_end + canopy_end + root_end + groundwater_end
    total_change = total_end - state.total_m3
    return total_change + e
