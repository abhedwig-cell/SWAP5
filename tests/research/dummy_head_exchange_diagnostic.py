"""Head-dependent groundwater exchange diagnostic for RIBASIM-DUMMY-03.

The exchange law is deliberately linear:

    V_ex = conductance * dt * (basin_level - groundwater_head)

Positive signed volume is Basin -> groundwater infiltration.
Negative signed volume is groundwater -> Basin drainage.

This is a GHB-like research surrogate only. It is not a MODFLOW package
implementation or package-equivalence claim.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_ribasim_reservoir import BasinWindowForcing
from dummy_threeway_water_coupling import (
    CoupledWindowCandidate,
    DummyModflowWindow,
    DummyThreeWayCoupler,
)


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class LinearHeadExchange:
    conductance_m2_per_time: float
    dt: float

    def __post_init__(self) -> None:
        conductance = _finite(
            "conductance_m2_per_time", self.conductance_m2_per_time
        )
        dt = _finite("dt", self.dt)
        if conductance < 0.0:
            raise ValueError("conductance_m2_per_time must be non-negative")
        if dt <= 0.0:
            raise ValueError("dt must be positive")
        object.__setattr__(self, "conductance_m2_per_time", conductance)
        object.__setattr__(self, "dt", dt)

    def signed_exchange_volume_m3(
        self,
        basin_level_m: float,
        groundwater_head_m: float,
    ) -> float:
        basin = _finite("basin_level_m", basin_level_m)
        groundwater = _finite("groundwater_head_m", groundwater_head_m)
        return self.conductance_m2_per_time * self.dt * (basin - groundwater)

    def forcing(
        self,
        basin_level_m: float,
        groundwater_head_m: float,
        *,
        external_inflow_m3: float = 0.0,
    ) -> BasinWindowForcing:
        signed = self.signed_exchange_volume_m3(
            basin_level_m,
            groundwater_head_m,
        )
        if signed >= 0.0:
            return BasinWindowForcing(
                external_inflow_m3=external_inflow_m3,
                basin_infiltration_m3=signed,
            )
        return BasinWindowForcing(
            external_inflow_m3=external_inflow_m3,
            basin_drainage_m3=-signed,
        )

    @staticmethod
    def signed_from_forcing(forcing: BasinWindowForcing) -> float:
        return forcing.basin_infiltration_m3 - forcing.basin_drainage_m3


@dataclass(frozen=True)
class HeadDrivenWindowDiagnostic:
    candidate: CoupledWindowCandidate
    start_basin_level_m: float
    realized_end_basin_level_m: float
    forecast_groundwater_head_m: float
    actual_groundwater_head_m: float
    forecast_signed_exchange_m3: float
    one_pass_actual_signed_exchange_m3: float
    endpoint_consistent_signed_exchange_m3: float
    endpoint_exchange_residual_m3: float


def prepare_head_driven_window(
    coupler: DummyThreeWayCoupler,
    exchange: LinearHeadExchange,
    *,
    forecast_groundwater_head_m: float,
    actual_groundwater_head_m: float,
    external_inflow_m3: float = 0.0,
) -> HeadDrivenWindowDiagnostic:
    """Prepare one non-iterative head-driven coupling window.

    Forecast and one-pass actual exchange are both evaluated from the committed
    Basin level. After the DUMMY-02 realization, exchange is re-evaluated at the
    realized end level as a diagnostic only. No participant is mutated here.
    """

    forecast_head = _finite(
        "forecast_groundwater_head_m", forecast_groundwater_head_m
    )
    actual_head = _finite("actual_groundwater_head_m", actual_groundwater_head_m)

    start_level = coupler.ribasim.committed_stage_m

    forecast_forcing = exchange.forcing(
        start_level,
        forecast_head,
        external_inflow_m3=external_inflow_m3,
    )
    actual_forcing = exchange.forcing(
        start_level,
        actual_head,
        external_inflow_m3=external_inflow_m3,
    )

    candidate = coupler.prepare_window(
        DummyModflowWindow(
            forecast=forecast_forcing,
            actual=actual_forcing,
        )
    )

    end_level = candidate.realization.end_stage_m
    endpoint_forcing = exchange.forcing(
        end_level,
        actual_head,
        external_inflow_m3=external_inflow_m3,
    )

    forecast_signed = exchange.signed_from_forcing(forecast_forcing)
    actual_signed = exchange.signed_from_forcing(actual_forcing)
    endpoint_signed = exchange.signed_from_forcing(endpoint_forcing)

    return HeadDrivenWindowDiagnostic(
        candidate=candidate,
        start_basin_level_m=start_level,
        realized_end_basin_level_m=end_level,
        forecast_groundwater_head_m=forecast_head,
        actual_groundwater_head_m=actual_head,
        forecast_signed_exchange_m3=forecast_signed,
        one_pass_actual_signed_exchange_m3=actual_signed,
        endpoint_consistent_signed_exchange_m3=endpoint_signed,
        endpoint_exchange_residual_m3=actual_signed - endpoint_signed,
    )
