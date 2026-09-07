from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction
from hashlib import sha256
import json
from typing import Iterable, Sequence


@dataclass(frozen=True)
class TileWaterRecord:
    tile_id: str
    fraction: Fraction
    storage_start: int
    storage_end: int
    boundary_in: int
    boundary_out: int

    @property
    def residual(self) -> int:
        return self.storage_end - self.storage_start - self.boundary_in + self.boundary_out

    @property
    def storage_change(self) -> int:
        return self.storage_end - self.storage_start

    @property
    def net_boundary(self) -> int:
        return self.boundary_in - self.boundary_out


@dataclass(frozen=True)
class CellAggregate:
    storage_change: Fraction
    net_boundary: Fraction
    residual: Fraction

    def semantic_payload(self) -> dict:
        return {
            "storage_change": [self.storage_change.numerator, self.storage_change.denominator],
            "net_boundary": [self.net_boundary.numerator, self.net_boundary.denominator],
            "residual": [self.residual.numerator, self.residual.denominator],
        }

    def canonical_hash(self) -> str:
        text = json.dumps(self.semantic_payload(), sort_keys=True, separators=(",", ":"))
        return sha256(text.encode("utf-8")).hexdigest()


def aggregate_tiles(records: Sequence[TileWaterRecord]) -> CellAggregate:
    if not records:
        raise ValueError("at least one tile is required")
    ids = [row.tile_id for row in records]
    if len(ids) != len(set(ids)):
        raise ValueError("tile_id values must be unique")
    if any(row.fraction <= 0 for row in records):
        raise ValueError("tile fractions must be positive")
    if sum((row.fraction for row in records), Fraction(0, 1)) != Fraction(1, 1):
        raise ValueError("tile fractions must sum exactly to one")
    bad = [row.tile_id for row in records if row.residual != 0]
    if bad:
        raise ValueError(f"synthetic hard tile mass gate failed for {bad}")
    storage = sum((row.fraction * row.storage_change for row in records), Fraction(0, 1))
    boundary = sum((row.fraction * row.net_boundary for row in records), Fraction(0, 1))
    residual = storage - boundary
    if residual != 0:
        raise RuntimeError("synthetic hard aggregate mass gate failed")
    return CellAggregate(storage_change=storage, net_boundary=boundary, residual=residual)


@dataclass(frozen=True)
class CouplingState:
    water_units: int


@dataclass(frozen=True)
class TrialResult:
    label: str
    candidate: CouplingState
    flux_into_swap: int
    accepted: bool


@dataclass(frozen=True)
class PredictorCorrectorResult:
    initial: CouplingState
    committed: CouplingState
    trials: tuple[TrialResult, ...]
    commits: int
    rollbacks: int
    committed_flux_into_swap: int


def _trial(checkpoint: CouplingState, *, label: str, delta: int, accepted: bool) -> TrialResult:
    return TrialResult(
        label=label,
        candidate=CouplingState(checkpoint.water_units + delta),
        flux_into_swap=delta,
        accepted=accepted,
    )


def run_predictor_corrector(
    committed: CouplingState,
    *,
    predictor_delta: int,
    corrector_delta: int,
    accept_predictor: bool = False,
    accept_corrector: bool = True,
) -> PredictorCorrectorResult:
    # Every physical trial starts from the same externally committed checkpoint.
    checkpoint = CouplingState(committed.water_units)
    predictor = _trial(
        checkpoint,
        label="predictor",
        delta=predictor_delta,
        accepted=accept_predictor,
    )

    # Predictor acceptance may be useful numerically, but it is not an external
    # physical commit. The corrector remains based on the committed checkpoint.
    corrector = _trial(
        checkpoint,
        label="corrector",
        delta=corrector_delta,
        accepted=accept_corrector,
    )

    if accept_corrector:
        endpoint = corrector.candidate
        commits = 1
        committed_flux = corrector.flux_into_swap
    else:
        endpoint = checkpoint
        commits = 0
        committed_flux = 0

    rollbacks = int(not accept_predictor) + int(not accept_corrector)
    if endpoint.water_units - checkpoint.water_units != committed_flux:
        raise RuntimeError("synthetic committed coupling mass gate failed")
    return PredictorCorrectorResult(
        initial=checkpoint,
        committed=endpoint,
        trials=(predictor, corrector),
        commits=commits,
        rollbacks=rollbacks,
        committed_flux_into_swap=committed_flux,
    )


@dataclass(frozen=True)
class InterfaceObservation:
    h_swap_units: int
    h_mf_units: int
    q_swap_units: int
    q_mf_units: int


@dataclass(frozen=True)
class InterfaceGateResult:
    flux_conserved: bool
    flux_residual: int
    head_residual: int
    head_within_tolerance: bool

    @property
    def accepted(self) -> bool:
        return self.flux_conserved and self.head_within_tolerance


def evaluate_interface(
    observation: InterfaceObservation,
    *,
    qualified_head_tolerance_units: int,
) -> InterfaceGateResult:
    if qualified_head_tolerance_units < 0:
        raise ValueError("head tolerance must be nonnegative")
    flux_residual = observation.q_swap_units + observation.q_mf_units
    head_residual = observation.h_swap_units - observation.h_mf_units
    return InterfaceGateResult(
        flux_conserved=(flux_residual == 0),
        flux_residual=flux_residual,
        head_residual=head_residual,
        head_within_tolerance=(abs(head_residual) <= qualified_head_tolerance_units),
    )


def canonical_tile_set_hash(records: Iterable[TileWaterRecord]) -> str:
    payload = [
        {
            "tile_id": row.tile_id,
            "fraction": [row.fraction.numerator, row.fraction.denominator],
            "storage_start": row.storage_start,
            "storage_end": row.storage_end,
            "boundary_in": row.boundary_in,
            "boundary_out": row.boundary_out,
        }
        for row in sorted(records, key=lambda row: row.tile_id)
    ]
    text = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return sha256(text.encode("utf-8")).hexdigest()
