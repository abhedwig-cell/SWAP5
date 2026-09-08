#!/usr/bin/env python3
"""Deterministic F-GC01 contract models; no production physics."""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, getcontext

getcontext().prec = 50


@dataclass(frozen=True)
class CommittedColumn:
    lineage_id: int
    revision: int
    time: Decimal
    storage_m: Decimal
    internal_head_m: Decimal


@dataclass(frozen=True)
class Checkpoint:
    state: CommittedColumn


@dataclass(frozen=True)
class SwapTrial:
    lineage_id: int
    origin_revision: int
    t0: Decimal
    t1: Decimal
    boundary_head_m: Decimal
    endpoint_head_m: Decimal
    interface_flux_m_per_s: Decimal
    storage_start_m: Decimal
    storage_end_m: Decimal
    mass_residual_m: Decimal


@dataclass(frozen=True)
class GroundwaterResponse:
    head_m: Decimal
    interface_flux_m_per_s: Decimal


class DeterministicSwapColumn:
    """Linear Dirichlet-response contract double with exact interval mass."""

    def __init__(self, conductance_per_s: Decimal):
        if conductance_per_s <= 0:
            raise ValueError("conductance must be positive")
        self.conductance_per_s = conductance_per_s
        self.trial_origins: list[tuple[int, int, Decimal, Decimal]] = []

    @staticmethod
    def checkpoint(committed: CommittedColumn) -> Checkpoint:
        return Checkpoint(committed)

    def trial(self, checkpoint: Checkpoint, boundary_head_m: Decimal, t1: Decimal) -> SwapTrial:
        state = checkpoint.state
        if t1 <= state.time:
            raise ValueError("T1 must be greater than committed T0")
        self.trial_origins.append((state.lineage_id, state.revision, state.time, state.storage_m))
        flux = self.conductance_per_s * (state.internal_head_m - boundary_head_m)
        transfer = flux * (t1 - state.time)
        storage_end = state.storage_m - transfer
        residual = storage_end - state.storage_m - (Decimal(0) - transfer)
        return SwapTrial(
            state.lineage_id, state.revision, state.time, t1, boundary_head_m,
            boundary_head_m, flux, state.storage_m, storage_end, residual
        )

    @staticmethod
    def commit(committed: CommittedColumn, trial: SwapTrial) -> CommittedColumn:
        if (trial.lineage_id, trial.origin_revision, trial.t0) != (
            committed.lineage_id, committed.revision, committed.time
        ):
            raise ValueError("stale or foreign coupling candidate")
        return CommittedColumn(
            committed.lineage_id, committed.revision + 1, trial.t1,
            trial.storage_end_m, committed.internal_head_m
        )


class DeterministicAquifer:
    """Linear aquifer whose equilibrium with the SWAP double is analytic."""

    def __init__(self, reference_head_m: Decimal, resistance_s: Decimal):
        if resistance_s <= 0:
            raise ValueError("resistance must be positive")
        self.reference_head_m = reference_head_m
        self.resistance_s = resistance_s

    def respond(self, swap_flux_m_per_s: Decimal) -> GroundwaterResponse:
        groundwater_flux = -swap_flux_m_per_s
        return GroundwaterResponse(
            self.reference_head_m + self.resistance_s * groundwater_flux,
            groundwater_flux,
        )

    def analytic_equilibrium_head(self, column_head_m: Decimal, conductance_per_s: Decimal) -> Decimal:
        # H = Href - R*k*(Hcolumn-H)
        rk = self.resistance_s * conductance_per_s
        return (self.reference_head_m - rk * column_head_m) / (Decimal(1) - rk)

