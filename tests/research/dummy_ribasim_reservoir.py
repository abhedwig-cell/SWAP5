"""Analytically controlled one-Basin surrogate for coupling research.

This module is test/research infrastructure. It deliberately does not implement
Ribasim network routing, goal-programming allocation, or production coupling.

The research contract mirrors the coupling concepts that matter for the first
experiments:

1. allocation predicts water availability and caps a UserDemand;
2. the physical window realizes Basin drainage and infiltration;
3. realized UserDemand can be smaller than the allocation when actual
   hydrology removes more water than forecast;
4. commit is explicit and is the only operation that mutates authoritative
   Basin storage.

All forcing terms are non-negative water volumes over one coupling window.
"""

from __future__ import annotations

from dataclasses import dataclass
import math


class DummyRibasimError(RuntimeError):
    """Base class for deterministic harness failures."""


class InfeasibleHydrologyError(DummyRibasimError):
    """Mandatory Basin infiltration exceeds physically available storage."""


class StaleCandidateError(DummyRibasimError):
    """Candidate was prepared from an older committed revision."""


def _finite_nonnegative(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative, got {value!r}")
    return value


@dataclass(frozen=True)
class DummyRibasimConfig:
    area_m2: float
    datum_m: float = 0.0
    user_demand_min_level_m: float | None = None

    def __post_init__(self) -> None:
        area = float(self.area_m2)
        datum = float(self.datum_m)
        if not math.isfinite(area) or area <= 0.0:
            raise ValueError(f"area_m2 must be finite and positive, got {area!r}")
        if not math.isfinite(datum):
            raise ValueError(f"datum_m must be finite, got {datum!r}")
        min_level = self.user_demand_min_level_m
        if min_level is not None:
            min_level = float(min_level)
            if not math.isfinite(min_level):
                raise ValueError("user_demand_min_level_m must be finite")
            tolerance = 1.0e-12 * max(1.0, abs(datum), abs(min_level))
            if min_level < datum - tolerance:
                raise ValueError(
                    "user_demand_min_level_m cannot lie below the linear-profile datum"
                )
        object.__setattr__(self, "area_m2", area)
        object.__setattr__(self, "datum_m", datum)
        object.__setattr__(self, "user_demand_min_level_m", min_level)

    def stage_from_volume(self, volume_m3: float) -> float:
        volume = _finite_nonnegative("volume_m3", volume_m3)
        return self.datum_m + volume / self.area_m2

    def volume_from_stage(self, stage_m: float) -> float:
        stage = float(stage_m)
        if not math.isfinite(stage):
            raise ValueError(f"stage_m must be finite, got {stage!r}")
        volume = (stage - self.datum_m) * self.area_m2
        tolerance = 1.0e-12 * max(1.0, abs(volume))
        if volume < -tolerance:
            raise ValueError(
                f"stage_m={stage!r} lies below datum_m={self.datum_m!r}"
            )
        return max(0.0, volume)

    @property
    def user_demand_min_volume_m3(self) -> float:
        if self.user_demand_min_level_m is None:
            return 0.0
        return self.volume_from_stage(self.user_demand_min_level_m)


@dataclass(frozen=True)
class ReservoirState:
    volume_m3: float
    revision: int

    def __post_init__(self) -> None:
        object.__setattr__(
            self, "volume_m3", _finite_nonnegative("volume_m3", self.volume_m3)
        )
        if self.revision < 0:
            raise ValueError("revision must be non-negative")


@dataclass(frozen=True)
class BasinWindowForcing:
    external_inflow_m3: float = 0.0
    basin_drainage_m3: float = 0.0
    basin_infiltration_m3: float = 0.0

    def __post_init__(self) -> None:
        for name in (
            "external_inflow_m3",
            "basin_drainage_m3",
            "basin_infiltration_m3",
        ):
            object.__setattr__(
                self, name, _finite_nonnegative(name, getattr(self, name))
            )


@dataclass(frozen=True)
class AllocationCandidate:
    base_revision: int
    user_demand_request_m3: float
    forecast_forcing: BasinWindowForcing
    forecast_post_hydrology_volume_m3: float
    user_demand_allocated_m3: float
    allocation_shortage_m3: float


@dataclass(frozen=True)
class RealizationCandidate:
    base_revision: int
    allocation: AllocationCandidate
    actual_forcing: BasinWindowForcing
    start_volume_m3: float
    actual_post_hydrology_volume_m3: float
    user_demand_delivered_m3: float
    realization_shortage_m3: float
    total_shortage_m3: float
    end_volume_m3: float
    end_stage_m: float
    mass_balance_residual_m3: float


class DummyRibasimReservoir:
    """Transactional one-Basin allocation and physical-realization oracle."""

    def __init__(
        self, config: DummyRibasimConfig, initial_volume_m3: float, revision: int = 0
    ) -> None:
        self._config = config
        self._state = ReservoirState(initial_volume_m3, revision)

    @property
    def config(self) -> DummyRibasimConfig:
        return self._config

    @property
    def committed_state(self) -> ReservoirState:
        return self._state

    @property
    def committed_stage_m(self) -> float:
        return self._config.stage_from_volume(self._state.volume_m3)

    def _post_hydrology_volume(
        self, forcing: BasinWindowForcing, *, label: str
    ) -> float:
        available = math.fsum(
            (
                self._state.volume_m3,
                forcing.external_inflow_m3,
                forcing.basin_drainage_m3,
            )
        )
        scale = max(1.0, available, forcing.basin_infiltration_m3)
        tolerance = 1.0e-12 * scale

        if forcing.basin_infiltration_m3 > available + tolerance:
            raise InfeasibleHydrologyError(
                f"{label} Basin infiltration exceeds physically available water: "
                f"available={available:.17g} m3, "
                f"infiltration={forcing.basin_infiltration_m3:.17g} m3"
            )

        remaining = available - forcing.basin_infiltration_m3
        if remaining < 0.0 and abs(remaining) <= tolerance:
            remaining = 0.0
        return remaining

    def prepare_allocation(
        self,
        user_demand_request_m3: float,
        forecast_forcing: BasinWindowForcing,
    ) -> AllocationCandidate:
        request = _finite_nonnegative(
            "user_demand_request_m3", user_demand_request_m3
        )
        post_hydrology = self._post_hydrology_volume(
            forecast_forcing, label="forecast"
        )
        allocatable = max(
            0.0, post_hydrology - self._config.user_demand_min_volume_m3
        )
        allocated = min(request, allocatable)

        return AllocationCandidate(
            base_revision=self._state.revision,
            user_demand_request_m3=request,
            forecast_forcing=forecast_forcing,
            forecast_post_hydrology_volume_m3=post_hydrology,
            user_demand_allocated_m3=allocated,
            allocation_shortage_m3=request - allocated,
        )

    def realize_step(
        self,
        allocation: AllocationCandidate,
        actual_forcing: BasinWindowForcing,
    ) -> RealizationCandidate:
        if allocation.base_revision != self._state.revision:
            raise StaleCandidateError(
                f"allocation revision {allocation.base_revision} does not match "
                f"committed revision {self._state.revision}"
            )

        start = self._state.volume_m3
        post_hydrology = self._post_hydrology_volume(
            actual_forcing, label="actual"
        )
        physically_deliverable = max(
            0.0, post_hydrology - self._config.user_demand_min_volume_m3
        )
        delivered = min(allocation.user_demand_allocated_m3, physically_deliverable)
        realization_shortage = allocation.user_demand_allocated_m3 - delivered
        total_shortage = allocation.user_demand_request_m3 - delivered
        end_volume = post_hydrology - delivered

        expected_end = math.fsum(
            (
                start,
                actual_forcing.external_inflow_m3,
                actual_forcing.basin_drainage_m3,
                -actual_forcing.basin_infiltration_m3,
                -delivered,
            )
        )
        residual = end_volume - expected_end

        return RealizationCandidate(
            base_revision=self._state.revision,
            allocation=allocation,
            actual_forcing=actual_forcing,
            start_volume_m3=start,
            actual_post_hydrology_volume_m3=post_hydrology,
            user_demand_delivered_m3=delivered,
            realization_shortage_m3=realization_shortage,
            total_shortage_m3=total_shortage,
            end_volume_m3=end_volume,
            end_stage_m=self._config.stage_from_volume(end_volume),
            mass_balance_residual_m3=residual,
        )

    def commit(self, candidate: RealizationCandidate) -> ReservoirState:
        if candidate.base_revision != self._state.revision:
            raise StaleCandidateError(
                f"candidate revision {candidate.base_revision} does not match "
                f"committed revision {self._state.revision}"
            )
        self._state = ReservoirState(
            volume_m3=candidate.end_volume_m3,
            revision=self._state.revision + 1,
        )
        return self._state
