"""Analytically controlled single-reservoir surrogate for coupling research.

This module is test/research infrastructure. It deliberately does not implement
Ribasim network routing, allocation optimization, or production coupling.

Sign convention
---------------
All forcing terms are non-negative volumes over one coupling window.

* external_inflow_m3: surface-water inflow into the reservoir.
* gw_exfiltration_m3: groundwater -> surface water, physically forced inflow.
* gw_infiltration_m3: surface water -> groundwater, physically forced outflow.
* irrigation_request_m3: discretionary management withdrawal request.

Mandatory groundwater exchange is resolved before irrigation allocation.
"""

from __future__ import annotations

from dataclasses import dataclass
import math


class DummyRibasimError(RuntimeError):
    """Base class for deterministic harness failures."""


class InfeasibleHydrologyError(DummyRibasimError):
    """Mandatory physical outflow exceeds available surface-water storage."""


class StaleCandidateError(DummyRibasimError):
    """Candidate was prepared from an older committed revision."""


def _require_finite_nonnegative(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative, got {value!r}")
    return value


@dataclass(frozen=True)
class DummyRibasimConfig:
    area_m2: float
    datum_m: float = 0.0
    management_reserve_m3: float = 0.0

    def __post_init__(self) -> None:
        area = float(self.area_m2)
        datum = float(self.datum_m)
        reserve = _require_finite_nonnegative(
            "management_reserve_m3", self.management_reserve_m3
        )
        if not math.isfinite(area) or area <= 0.0:
            raise ValueError(f"area_m2 must be finite and positive, got {area!r}")
        if not math.isfinite(datum):
            raise ValueError(f"datum_m must be finite, got {datum!r}")
        object.__setattr__(self, "area_m2", area)
        object.__setattr__(self, "datum_m", datum)
        object.__setattr__(self, "management_reserve_m3", reserve)

    def stage_from_volume(self, volume_m3: float) -> float:
        volume = _require_finite_nonnegative("volume_m3", volume_m3)
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


@dataclass(frozen=True)
class ReservoirState:
    volume_m3: float
    revision: int

    def __post_init__(self) -> None:
        object.__setattr__(
            self, "volume_m3", _require_finite_nonnegative("volume_m3", self.volume_m3)
        )
        if self.revision < 0:
            raise ValueError("revision must be non-negative")


@dataclass(frozen=True)
class StepForcing:
    external_inflow_m3: float = 0.0
    gw_exfiltration_m3: float = 0.0
    gw_infiltration_m3: float = 0.0
    irrigation_request_m3: float = 0.0

    def __post_init__(self) -> None:
        for name in (
            "external_inflow_m3",
            "gw_exfiltration_m3",
            "gw_infiltration_m3",
            "irrigation_request_m3",
        ):
            object.__setattr__(
                self, name, _require_finite_nonnegative(name, getattr(self, name))
            )


@dataclass(frozen=True)
class StepCandidate:
    base_revision: int
    start_volume_m3: float
    pre_hydrology_volume_m3: float
    post_hydrology_volume_m3: float
    irrigation_request_m3: float
    irrigation_delivered_m3: float
    irrigation_shortage_m3: float
    end_volume_m3: float
    end_stage_m: float
    mass_balance_residual_m3: float
    forcing: StepForcing


class DummyRibasimReservoir:
    """Transactional one-reservoir coupling oracle.

    prepare_step is pure with respect to committed state. commit is the only
    operation that advances the authoritative reservoir state.
    """

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

    def prepare_step(self, forcing: StepForcing) -> StepCandidate:
        start = self._state.volume_m3

        pre_hydrology = math.fsum(
            (start, forcing.external_inflow_m3, forcing.gw_exfiltration_m3)
        )
        scale = max(1.0, pre_hydrology, forcing.gw_infiltration_m3)
        tolerance = 1.0e-12 * scale

        if forcing.gw_infiltration_m3 > pre_hydrology + tolerance:
            raise InfeasibleHydrologyError(
                "mandatory groundwater infiltration exceeds physically available "
                f"surface water: available={pre_hydrology:.17g} m3, "
                f"required={forcing.gw_infiltration_m3:.17g} m3"
            )

        post_hydrology = pre_hydrology - forcing.gw_infiltration_m3
        if post_hydrology < 0.0 and abs(post_hydrology) <= tolerance:
            post_hydrology = 0.0

        allocatable = max(
            0.0, post_hydrology - self._config.management_reserve_m3
        )
        delivered = min(forcing.irrigation_request_m3, allocatable)
        shortage = forcing.irrigation_request_m3 - delivered
        end_volume = post_hydrology - delivered

        expected_end = math.fsum(
            (
                start,
                forcing.external_inflow_m3,
                forcing.gw_exfiltration_m3,
                -forcing.gw_infiltration_m3,
                -delivered,
            )
        )
        residual = end_volume - expected_end

        return StepCandidate(
            base_revision=self._state.revision,
            start_volume_m3=start,
            pre_hydrology_volume_m3=pre_hydrology,
            post_hydrology_volume_m3=post_hydrology,
            irrigation_request_m3=forcing.irrigation_request_m3,
            irrigation_delivered_m3=delivered,
            irrigation_shortage_m3=shortage,
            end_volume_m3=end_volume,
            end_stage_m=self._config.stage_from_volume(end_volume),
            mass_balance_residual_m3=residual,
            forcing=forcing,
        )

    def commit(self, candidate: StepCandidate) -> ReservoirState:
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
