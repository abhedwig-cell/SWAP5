"""Multi-window state propagation for RIBASIM-DUMMY-08.

Each discrete coupling window uses the qualified DUMMY-07 direct active-set
solution. Accepted end level becomes the next committed start level. Request is
an exogenous rate converted to a per-window volume; shortage is not carried
forward.

An independent continuous one-event reference is included only for the frozen
constant-parameter domain documented in RIBASIM-DUMMY-08.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_active_set_stabilization import direct_active_set_solve
from dummy_head_management_complementarity import HeadDependentManagementProblem


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class TemporalCouplingConfig:
    basin_area_m2: float
    conductance_m2_per_time: float
    groundwater_head_m: float
    management_min_level_m: float
    request_rate_m3_per_time: float
    datum_m: float = 0.0

    def __post_init__(self) -> None:
        for name in (
            "basin_area_m2",
            "conductance_m2_per_time",
            "groundwater_head_m",
            "management_min_level_m",
            "request_rate_m3_per_time",
            "datum_m",
        ):
            object.__setattr__(self, name, _finite(name, getattr(self, name)))

        if self.basin_area_m2 <= 0.0:
            raise ValueError("basin_area_m2 must be positive")
        if self.conductance_m2_per_time < 0.0:
            raise ValueError("conductance_m2_per_time must be non-negative")
        if self.request_rate_m3_per_time < 0.0:
            raise ValueError("request_rate_m3_per_time must be non-negative")
        if self.management_min_level_m < self.datum_m:
            raise ValueError("management_min_level_m must not lie below datum_m")


@dataclass(frozen=True)
class TemporalWindowResult:
    index: int
    dt: float
    start_level_m: float
    requested_m3: float
    regime: str
    delivered_m3: float
    shortage_m3: float
    signed_exchange_m3: float
    end_level_m: float
    window_balance_residual_m3: float


@dataclass(frozen=True)
class TemporalRunResult:
    initial_level_m: float
    final_level_m: float
    windows: tuple[TemporalWindowResult, ...]
    cumulative_requested_m3: float
    cumulative_delivered_m3: float
    cumulative_shortage_m3: float
    cumulative_signed_exchange_m3: float
    cumulative_balance_residual_m3: float


@dataclass(frozen=True)
class ContinuousEventReference:
    horizon: float
    hit_time: float | None
    final_level_m: float
    cumulative_requested_m3: float
    cumulative_delivered_m3: float
    cumulative_shortage_m3: float
    cumulative_signed_exchange_m3: float


def run_temporal_partition(
    config: TemporalCouplingConfig,
    *,
    initial_level_m: float,
    dts: tuple[float, ...] | list[float],
) -> TemporalRunResult:
    initial = _finite("initial_level_m", initial_level_m)
    if initial < config.datum_m:
        raise ValueError("initial_level_m must not lie below datum_m")
    if not dts:
        raise ValueError("dts must contain at least one coupling window")

    current = initial
    windows = []
    cumulative_requested = 0.0
    cumulative_delivered = 0.0
    cumulative_shortage = 0.0
    cumulative_exchange = 0.0

    for index, dt_raw in enumerate(dts):
        dt = _finite("dt", dt_raw)
        if dt <= 0.0:
            raise ValueError("all coupling-window durations must be positive")

        requested = config.request_rate_m3_per_time * dt
        problem = HeadDependentManagementProblem(
            basin_area_m2=config.basin_area_m2,
            conductance_m2_per_time=config.conductance_m2_per_time,
            dt=dt,
            start_level_m=current,
            groundwater_head_m=config.groundwater_head_m,
            requested_delivery_m3=requested,
            management_min_level_m=config.management_min_level_m,
            datum_m=config.datum_m,
        )
        solution = direct_active_set_solve(problem)

        balance_residual = (
            config.basin_area_m2 * (current - solution.end_level_m)
            - solution.delivered_m3
            - solution.signed_exchange_m3
        )

        windows.append(
            TemporalWindowResult(
                index=index,
                dt=dt,
                start_level_m=current,
                requested_m3=requested,
                regime=solution.regime,
                delivered_m3=solution.delivered_m3,
                shortage_m3=solution.shortage_m3,
                signed_exchange_m3=solution.signed_exchange_m3,
                end_level_m=solution.end_level_m,
                window_balance_residual_m3=balance_residual,
            )
        )

        cumulative_requested += requested
        cumulative_delivered += solution.delivered_m3
        cumulative_shortage += solution.shortage_m3
        cumulative_exchange += solution.signed_exchange_m3
        current = solution.end_level_m

    cumulative_balance_residual = (
        config.basin_area_m2 * (initial - current)
        - cumulative_delivered
        - cumulative_exchange
    )

    return TemporalRunResult(
        initial_level_m=initial,
        final_level_m=current,
        windows=tuple(windows),
        cumulative_requested_m3=cumulative_requested,
        cumulative_delivered_m3=cumulative_delivered,
        cumulative_shortage_m3=cumulative_shortage,
        cumulative_signed_exchange_m3=cumulative_exchange,
        cumulative_balance_residual_m3=cumulative_balance_residual,
    )


def continuous_one_event_reference(
    config: TemporalCouplingConfig,
    *,
    initial_level_m: float,
    horizon: float,
) -> ContinuousEventReference:
    """Continuous reference for one irreversible management shutoff event.

    Domain:
      C > 0,
      groundwater_head < management_min_level < initial_level,
      constant request rate and parameters,
      no external inflow,
      after the min-level event physical hydrology continues without managed
      withdrawal.
    """

    h0 = _finite("initial_level_m", initial_level_m)
    T = _finite("horizon", horizon)
    if T <= 0.0:
        raise ValueError("horizon must be positive")
    if config.conductance_m2_per_time <= 0.0:
        raise ValueError("continuous event reference requires positive conductance")
    if not (
        config.groundwater_head_m
        < config.management_min_level_m
        < h0
    ):
        raise ValueError(
            "continuous event reference requires hgw < hmin < initial level"
        )

    A = config.basin_area_m2
    C = config.conductance_m2_per_time
    hgw = config.groundwater_head_m
    hmin = config.management_min_level_m
    rate = config.request_rate_m3_per_time
    decay = C / A
    requested = rate * T

    h_eq_full = hgw - rate / C
    full_end = h_eq_full + (h0 - h_eq_full) * math.exp(-decay * T)

    if full_end >= hmin:
        delivered = requested
        final_level = full_end
        hit_time = None
    else:
        numerator = hmin - h_eq_full
        denominator = h0 - h_eq_full
        if numerator <= 0.0 or denominator <= 0.0:
            raise ValueError("configured event domain does not have a valid hit time")
        hit_time = -(A / C) * math.log(numerator / denominator)
        if not 0.0 <= hit_time <= T:
            raise ValueError("computed management hit time lies outside horizon")
        delivered = rate * hit_time
        final_level = hgw + (hmin - hgw) * math.exp(
            -decay * (T - hit_time)
        )

    tolerance = 1.0e-12 * max(1.0, abs(config.datum_m), abs(final_level))
    if final_level < config.datum_m - tolerance:
        raise ValueError(
            "continuous reference crosses physical datum; dry-boundary physics "
            "is outside DUMMY-08 scope"
        )

    exchange = A * (h0 - final_level) - delivered
    shortage = requested - delivered

    return ContinuousEventReference(
        horizon=T,
        hit_time=hit_time,
        final_level_m=final_level,
        cumulative_requested_m3=requested,
        cumulative_delivered_m3=delivered,
        cumulative_shortage_m3=shortage,
        cumulative_signed_exchange_m3=exchange,
    )
