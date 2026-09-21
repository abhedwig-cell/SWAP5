"""Exact management complementarity with dynamic groundwater storage.

RIBASIM-DUMMY-10 combines the reciprocal DUMMY-09 two-store exchange with one
surface-water UserDemand. The physical exchange is never clipped for
management; management delivery is the active-set variable.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_two_store_exchange import (
    TwoStoreConfig,
    TwoStoreState,
    total_storage_m3,
)


class TwoStorePhysicalInfeasibleError(RuntimeError):
    """Zero-withdrawal physical solution crosses the surface-water datum."""


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class FixedDeliveryTwoStoreSolution:
    delivered_m3: float
    exchange_volume_m3: float
    end: TwoStoreState
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    exchange_residual_m3: float
    combined_ledger_residual_m3: float


@dataclass(frozen=True)
class TwoStoreManagementSolution:
    regime: str
    requested_m3: float
    delivered_m3: float
    shortage_m3: float
    exchange_volume_m3: float
    end: TwoStoreState
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    exchange_residual_m3: float
    combined_ledger_residual_m3: float


@dataclass(frozen=True)
class TwoStoreManagementProblem:
    config: TwoStoreConfig
    start: TwoStoreState
    dt: float
    requested_m3: float
    management_min_surface_head_m: float
    surface_datum_m: float = 0.0

    def __post_init__(self) -> None:
        dt = _finite("dt", self.dt)
        request = _finite("requested_m3", self.requested_m3)
        hmin = _finite(
            "management_min_surface_head_m",
            self.management_min_surface_head_m,
        )
        datum = _finite("surface_datum_m", self.surface_datum_m)
        if dt <= 0.0:
            raise ValueError("dt must be positive")
        if request < 0.0:
            raise ValueError("requested_m3 must be non-negative")
        if hmin < datum:
            raise ValueError("management minimum must not lie below surface datum")
        if self.start.surface_head_m < datum:
            raise ValueError("start surface head must not lie below surface datum")
        object.__setattr__(self, "dt", dt)
        object.__setattr__(self, "requested_m3", request)
        object.__setattr__(self, "management_min_surface_head_m", hmin)
        object.__setattr__(self, "surface_datum_m", datum)

    @property
    def mu(self) -> float:
        return (
            0.5
            * self.config.conductance_m2_per_time
            * self.dt
            * self.config.inverse_storage_sum
        )

    @property
    def exchange_scale_m2(self) -> float:
        return (
            self.config.conductance_m2_per_time
            * self.dt
            / (1.0 + self.mu)
        )

    def fixed_delivery(self, delivered_m3: float) -> FixedDeliveryTwoStoreSolution:
        delivered = _finite("delivered_m3", delivered_m3)
        if delivered < 0.0:
            raise ValueError("delivered_m3 must be non-negative")

        A_s = self.config.surface_storage_m2
        A_g = self.config.groundwater_storage_m2
        d0 = self.start.head_difference_m
        exchange = self.exchange_scale_m2 * (
            d0 - delivered / (2.0 * A_s)
        )

        end = TwoStoreState(
            surface_head_m=(
                self.start.surface_head_m - (delivered + exchange) / A_s
            ),
            groundwater_head_m=(
                self.start.groundwater_head_m + exchange / A_g
            ),
        )

        surface_residual = (
            A_s * (end.surface_head_m - self.start.surface_head_m)
            + delivered
            + exchange
        )
        groundwater_residual = (
            A_g * (end.groundwater_head_m - self.start.groundwater_head_m)
            - exchange
        )
        expected_exchange = (
            self.config.conductance_m2_per_time
            * self.dt
            * 0.5
            * (
                self.start.head_difference_m
                + end.head_difference_m
            )
        )
        exchange_residual = exchange - expected_exchange
        combined_residual = (
            total_storage_m3(self.config, end)
            - (
                total_storage_m3(self.config, self.start)
                - delivered
            )
        )

        return FixedDeliveryTwoStoreSolution(
            delivered_m3=delivered,
            exchange_volume_m3=exchange,
            end=end,
            surface_balance_residual_m3=surface_residual,
            groundwater_balance_residual_m3=groundwater_residual,
            exchange_residual_m3=exchange_residual,
            combined_ledger_residual_m3=combined_residual,
        )

    def delivery_for_surface_end(self, surface_end_m: float) -> float:
        target = _finite("surface_end_m", surface_end_m)
        A_s = self.config.surface_storage_m2
        B = self.exchange_scale_m2
        alpha = B / (2.0 * A_s)
        numerator = (
            A_s * (self.start.surface_head_m - target)
            - B * self.start.head_difference_m
        )
        denominator = 1.0 - alpha
        if denominator <= 0.0:
            raise RuntimeError("invalid curtailed active-set denominator")
        return numerator / denominator

    def solve(self) -> TwoStoreManagementSolution:
        scale = max(
            1.0,
            abs(self.start.surface_head_m),
            abs(self.management_min_surface_head_m),
            abs(self.surface_datum_m),
        )
        head_tol = 1.0e-12 * scale

        zero = self.fixed_delivery(0.0)
        if zero.end.surface_head_m < self.surface_datum_m - head_tol:
            raise TwoStorePhysicalInfeasibleError(
                "zero-withdrawal physical solution crosses surface datum: "
                f"end={zero.end.surface_head_m:.17g}, "
                f"datum={self.surface_datum_m:.17g}"
            )

        full = self.fixed_delivery(self.requested_m3)

        if (
            full.end.surface_head_m
            >= self.management_min_surface_head_m - head_tol
        ):
            regime = "FULL"
            chosen = full
        elif (
            zero.end.surface_head_m
            <= self.management_min_surface_head_m + head_tol
        ):
            regime = "ZERO"
            chosen = zero
        else:
            regime = "CURTAILED"
            delivered = self.delivery_for_surface_end(
                self.management_min_surface_head_m
            )
            volume_tol = (
                self.config.surface_storage_m2
                * max(
                    1.0,
                    abs(self.start.surface_head_m),
                    abs(self.management_min_surface_head_m),
                )
                * 1.0e-12
            )
            if delivered < -volume_tol:
                raise RuntimeError("curtailed solution produced negative delivery")
            if delivered > self.requested_m3 + volume_tol:
                raise RuntimeError("curtailed solution exceeds requested delivery")
            delivered = min(self.requested_m3, max(0.0, delivered))
            chosen = self.fixed_delivery(delivered)

        return TwoStoreManagementSolution(
            regime=regime,
            requested_m3=self.requested_m3,
            delivered_m3=chosen.delivered_m3,
            shortage_m3=self.requested_m3 - chosen.delivered_m3,
            exchange_volume_m3=chosen.exchange_volume_m3,
            end=chosen.end,
            surface_balance_residual_m3=chosen.surface_balance_residual_m3,
            groundwater_balance_residual_m3=chosen.groundwater_balance_residual_m3,
            exchange_residual_m3=chosen.exchange_residual_m3,
            combined_ledger_residual_m3=chosen.combined_ledger_residual_m3,
        )
