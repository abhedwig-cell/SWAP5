#!/usr/bin/env python3
"""Executable F-GC01 predictor/corrector contract prototype."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from decimal import Decimal
from typing import Iterable

from fgc01_models import (
    CommittedColumn, DeterministicAquifer, DeterministicSwapColumn, SwapTrial,
)


@dataclass(frozen=True)
class CouplingDiagnostics:
    coupling_id: str
    t0: str
    t1: str
    predictor_count: int
    corrector_count: int
    swap_origin_revision: int
    candidate_revision: int
    commit_revision: int | None
    boundary_head_m: str
    swap_interface_flux_m_per_s: str
    groundwater_interface_flux_m_per_s: str
    head_residual_m: str
    flux_residual_m_per_s: str
    swap_mass_residual_m: str
    interface_mass_residual_m: str
    accepted: bool
    rejected: bool
    rollback_count: int
    retry_count: int
    convergence_status: str


@dataclass(frozen=True)
class CouplingOutcome:
    committed: CommittedColumn
    diagnostics: CouplingDiagnostics


def couple_window(
    coupling_id: str,
    committed: CommittedColumn,
    t1: Decimal,
    swap: DeterministicSwapColumn,
    aquifer: DeterministicAquifer,
    predictor_head_m: Decimal,
    head_tolerance_m: Decimal,
    allow_corrector: bool = True,
) -> CouplingOutcome:
    if not coupling_id or head_tolerance_m < 0 or t1 <= committed.time:
        raise ValueError("invalid coupling request")
    checkpoint = swap.checkpoint(committed)
    predictor = swap.trial(checkpoint, predictor_head_m, t1)
    predictor_gw = aquifer.respond(predictor.interface_flux_m_per_s)
    head_residual = predictor.endpoint_head_m - predictor_gw.head_m
    trial = predictor
    groundwater = predictor_gw
    correctors = 0

    if abs(head_residual) > head_tolerance_m and allow_corrector:
        correctors = 1
        exact_head = aquifer.analytic_equilibrium_head(
            committed.internal_head_m, swap.conductance_per_s
        )
        # Physical origin is checkpoint, not predictor candidate. Worker-local
        # numerical information could be reused without entering this state.
        trial = swap.trial(checkpoint, exact_head, t1)
        groundwater = aquifer.respond(trial.interface_flux_m_per_s)
        head_residual = trial.endpoint_head_m - groundwater.head_m

    flux_residual = trial.interface_flux_m_per_s + groundwater.interface_flux_m_per_s
    dt = t1 - committed.time
    interface_mass_residual = flux_residual * dt
    accepted = (
        abs(head_residual) <= head_tolerance_m
        and flux_residual == 0
        and interface_mass_residual == 0
        and trial.mass_residual_m == 0
    )
    published = DeterministicSwapColumn.commit(committed, trial) if accepted else committed
    diagnostics = CouplingDiagnostics(
        coupling_id, str(committed.time), str(t1), 1, correctors,
        committed.revision, committed.revision + 1,
        published.revision if accepted else None, str(trial.boundary_head_m),
        str(trial.interface_flux_m_per_s), str(groundwater.interface_flux_m_per_s),
        str(head_residual), str(flux_residual), str(trial.mass_residual_m),
        str(interface_mass_residual), accepted, not accepted,
        0 if accepted else 1, 0, "CONVERGED" if accepted else "REJECTED_HEAD_RESIDUAL",
    )
    return CouplingOutcome(published, diagnostics)


def aggregate_cell_flux(tiles: Iterable[tuple[str, Decimal, Decimal]], complete_cell: bool = True) -> Decimal:
    rows = list(tiles)
    if not rows or any(fraction < 0 for _, fraction, _ in rows):
        raise ValueError("invalid tile composition")
    fraction_sum = sum((fraction for _, fraction, _ in rows), Decimal(0))
    if complete_cell and fraction_sum != Decimal(1):
        raise ValueError("complete-cell fractions must sum exactly to one")
    return sum((fraction * flux for _, fraction, flux in rows), Decimal(0))


def switch_transfer_mode(storage_m: Decimal, source_mode: str, target_mode: str, disposition_m: Decimal) -> Decimal:
    if source_mode not in {"DIRECT", "TRANSFER_ZONE"} or target_mode not in {"DIRECT", "TRANSFER_ZONE"}:
        raise ValueError("unknown deep-vadose mode")
    if storage_m < 0 or disposition_m < 0 or disposition_m != storage_m:
        raise ValueError("mode switch must account for all stored water exactly once")
    return disposition_m


def diagnostics_dict(outcome: CouplingOutcome) -> dict[str, object]:
    return asdict(outcome.diagnostics)

