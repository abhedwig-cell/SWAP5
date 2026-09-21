"""Exact piecewise hydrology-before-management solution for DUMMY-05.

The physical exchange and Basin balance are inherited from the qualified
DUMMY-04 trapezoidal linear problem. UserDemand introduces an active-set rule:

* FULL: requested delivery is feasible without crossing the management min level.
* CURTAILED: delivery is reduced so the coupled end level equals the min level.
* ZERO: hydrology alone reaches or crosses the management min level, so delivery is zero.
* INFEASIBLE: hydrology alone drives the frozen surrogate below the physical datum.

The management min level never clips the physical groundwater exchange.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_trapezoid_exchange_iteration import TrapezoidExchangeProblem


class PhysicalStorageInfeasibleError(RuntimeError):
    """Frozen exchange closure implies end level below the physical datum."""


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class CoupledManagementSolution:
    regime: str
    requested_delivery_m3: float
    delivered_m3: float
    shortage_m3: float
    signed_exchange_m3: float
    end_level_m: float
    exchange_residual_m3: float
    balance_residual_m: float


@dataclass(frozen=True)
class HeadDependentManagementProblem:
    basin_area_m2: float
    conductance_m2_per_time: float
    dt: float
    start_level_m: float
    groundwater_head_m: float
    requested_delivery_m3: float
    management_min_level_m: float
    datum_m: float = 0.0

    def __post_init__(self) -> None:
        values = {
            "basin_area_m2": self.basin_area_m2,
            "conductance_m2_per_time": self.conductance_m2_per_time,
            "dt": self.dt,
            "start_level_m": self.start_level_m,
            "groundwater_head_m": self.groundwater_head_m,
            "requested_delivery_m3": self.requested_delivery_m3,
            "management_min_level_m": self.management_min_level_m,
            "datum_m": self.datum_m,
        }
        for name, value in values.items():
            object.__setattr__(self, name, _finite(name, value))

        if self.basin_area_m2 <= 0.0:
            raise ValueError("basin_area_m2 must be positive")
        if self.conductance_m2_per_time < 0.0:
            raise ValueError("conductance_m2_per_time must be non-negative")
        if self.dt <= 0.0:
            raise ValueError("dt must be positive")
        if self.requested_delivery_m3 < 0.0:
            raise ValueError("requested_delivery_m3 must be non-negative")
        if self.start_level_m < self.datum_m:
            raise ValueError("start_level_m must not lie below datum_m")
        if self.management_min_level_m < self.datum_m:
            raise ValueError("management_min_level_m must not lie below datum_m")

    @property
    def coupling_stiffness(self) -> float:
        return (
            self.conductance_m2_per_time
            * self.dt
            / (2.0 * self.basin_area_m2)
        )

    def fixed_delivery_problem(self, delivered_m3: float) -> TrapezoidExchangeProblem:
        delivered = _finite("delivered_m3", delivered_m3)
        if delivered < 0.0:
            raise ValueError("delivered_m3 must be non-negative")
        return TrapezoidExchangeProblem(
            basin_area_m2=self.basin_area_m2,
            conductance_m2_per_time=self.conductance_m2_per_time,
            dt=self.dt,
            start_level_m=self.start_level_m,
            groundwater_head_m=self.groundwater_head_m,
            managed_delivery_m3=delivered,
        )

    def fixed_delivery_end_level(self, delivered_m3: float) -> float:
        return self.fixed_delivery_problem(delivered_m3).fixed_point_end_level_m

    def fixed_delivery_exchange(self, delivered_m3: float) -> float:
        return self.fixed_delivery_problem(delivered_m3).fixed_point_exchange_m3

    def exchange_at_levels(self, end_level_m: float) -> float:
        end_level = _finite("end_level_m", end_level_m)
        return (
            self.conductance_m2_per_time
            * self.dt
            * (
                0.5 * (self.start_level_m + end_level)
                - self.groundwater_head_m
            )
        )

    def delivery_for_end_level(self, end_level_m: float) -> float:
        end_level = _finite("end_level_m", end_level_m)
        exchange = self.exchange_at_levels(end_level)
        return (
            self.basin_area_m2 * (self.start_level_m - end_level)
            - exchange
        )

    def _tolerance(self) -> float:
        scale = max(
            1.0,
            abs(self.start_level_m),
            abs(self.groundwater_head_m),
            abs(self.management_min_level_m),
            abs(self.datum_m),
        )
        return 1.0e-12 * scale

    def solve(self) -> CoupledManagementSolution:
        tol = self._tolerance()
        zero_problem = self.fixed_delivery_problem(0.0)
        zero_end = zero_problem.fixed_point_end_level_m

        if zero_end < self.datum_m - tol:
            raise PhysicalStorageInfeasibleError(
                "zero-withdrawal coupled hydrology lies below physical datum: "
                f"end_level={zero_end:.17g}, datum={self.datum_m:.17g}"
            )

        full_problem = self.fixed_delivery_problem(self.requested_delivery_m3)
        full_end = full_problem.fixed_point_end_level_m

        if full_end >= self.management_min_level_m - tol:
            regime = "FULL"
            delivered = self.requested_delivery_m3
            exchange = full_problem.fixed_point_exchange_m3
            end_level = full_end
        elif zero_end <= self.management_min_level_m + tol:
            regime = "ZERO"
            delivered = 0.0
            exchange = zero_problem.fixed_point_exchange_m3
            end_level = zero_end
        else:
            regime = "CURTAILED"
            end_level = self.management_min_level_m
            exchange = self.exchange_at_levels(end_level)
            delivered = self.delivery_for_end_level(end_level)

            volume_tol = (
                self.basin_area_m2
                * max(1.0, abs(self.start_level_m), abs(end_level))
                * 1.0e-12
            )
            if delivered < -volume_tol:
                raise RuntimeError("curtailed active-set solution produced negative delivery")
            if delivered > self.requested_delivery_m3 + volume_tol:
                raise RuntimeError("curtailed active-set solution exceeds request")
            delivered = min(
                self.requested_delivery_m3,
                max(0.0, delivered),
            )

        check = self.fixed_delivery_problem(delivered)
        exchange_residual = exchange - check.picard_map(exchange)
        balance_residual = end_level - check.end_level_from_exchange(exchange)

        return CoupledManagementSolution(
            regime=regime,
            requested_delivery_m3=self.requested_delivery_m3,
            delivered_m3=delivered,
            shortage_m3=self.requested_delivery_m3 - delivered,
            signed_exchange_m3=exchange,
            end_level_m=end_level,
            exchange_residual_m3=exchange_residual,
            balance_residual_m=balance_residual,
        )
