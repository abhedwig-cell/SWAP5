from __future__ import annotations

import ctypes
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Sequence

from modflow6_groundwater_application_service import (
    GroundwaterApplicationCorrectorBatch,
    GroundwaterApplicationPlanView,
)


@dataclass(frozen=True)
class FmrGroundwaterApplicationBinding:
    groundwater_cell_id: int
    package_slot: int
    modflow_node_id: int


@dataclass(frozen=True)
class FmrGroundwaterApplicationTerm:
    groundwater_cell_id: int
    hcof_m2_per_day: float
    rhs_m3_per_day: float
    valid: bool = True


@dataclass(frozen=True)
class FmrGroundwaterApplicationTile:
    tile_id: int
    groundwater_cell_id: int
    ledger_id: int
    participant_handle: int
    area_fraction: float


class FmrGroundwaterApplicationRuntime:
    """Production Python port over the Fortran-owned F-GC49D application context.

    The opaque context handle identifies an externally owned Fortran context.
    This adapter only marshals immutable primitive views and operation results.
    SWAP/FMR committed state, candidate state, F-GC40 aggregation, F-GC33
    linear-response mathematics and ledgers remain on the Fortran side.
    """

    OK = 0

    def __init__(self, library_path: str | Path, context_handle: int) -> None:
        self.library_path = Path(library_path).resolve()
        if not self.library_path.is_file():
            raise FileNotFoundError(self.library_path)
        self.context_handle = int(context_handle)
        if self.context_handle <= 0:
            raise ValueError("context_handle must be positive")

        self._library = ctypes.CDLL(str(self.library_path))
        self._configure_abi()

        ncell = ctypes.c_int()
        ntile = ctypes.c_int()
        self._require_status(
            self._context_counts(
                ctypes.c_int64(self.context_handle),
                ctypes.byref(ncell),
                ctypes.byref(ntile),
            ),
            "context-counts",
        )
        if ncell.value <= 0 or ntile.value <= 0:
            raise RuntimeError("F-GC49D context has an empty plan")
        self._ncell = int(ncell.value)
        self._ntile = int(ntile.value)
        self._tiles = self._read_tile_view()
        self.participant_handles = tuple(tile.participant_handle for tile in self._tiles)
        self.tile_ids = tuple(tile.tile_id for tile in self._tiles)
        self._released = False

    def materialize_plan(self) -> GroundwaterApplicationPlanView:
        self._ensure_open()
        bindings, terms, cell_ids = self._read_plan_view()
        return GroundwaterApplicationPlanView(
            bindings=bindings,
            terms=terms,
            cell_ids=cell_ids,
        )

    def capture_origins(self) -> bool:
        self._ensure_open()
        return self._status_ok(
            self._capture_origins(ctypes.c_int64(self.context_handle))
        )

    def evaluate_groundwater_fluxes(
        self, terms: Sequence[Any], cell_heads_m: Sequence[float]
    ) -> tuple[float, ...]:
        self._ensure_open()
        self._require_current_terms(terms)
        heads = self._double_array(cell_heads_m, self._ncell, "cell_heads_m")
        fluxes = (ctypes.c_double * self._ncell)()
        self._require_status(
            self._evaluate(
                ctypes.c_int64(self.context_handle),
                ctypes.c_int(self._ncell),
                heads,
                fluxes,
            ),
            "evaluate-groundwater-fluxes",
        )
        return tuple(float(value) for value in fluxes)

    def trial_cell_heads(
        self, cell_heads_m: Sequence[float]
    ) -> GroundwaterApplicationCorrectorBatch:
        self._ensure_open()
        heads = self._double_array(cell_heads_m, self._ncell, "cell_heads_m")
        fluxes = (ctypes.c_double * self._ncell)()
        tangents = (ctypes.c_double * self._ncell)()
        status = int(
            self._trial(
                ctypes.c_int64(self.context_handle),
                ctypes.c_int(self._ncell),
                heads,
                fluxes,
            )
        )
        if status != self.OK:
            return GroundwaterApplicationCorrectorBatch(False, ())
        tangent_status = int(
            self._trial_tangents(
                ctypes.c_int64(self.context_handle),
                ctypes.c_int(self._ncell),
                tangents,
            )
        )
        if tangent_status != self.OK:
            return GroundwaterApplicationCorrectorBatch(False, ())
        return GroundwaterApplicationCorrectorBatch(
            True,
            tuple(float(value) for value in fluxes),
            tuple(float(value) for value in tangents),
        )

    def discard_candidates(self) -> bool:
        self._ensure_open()
        return self._status_ok(
            self._discard(ctypes.c_int64(self.context_handle))
        )

    def reanchor_terms(
        self,
        cell_heads_m: Sequence[float],
        cell_q_swap_m_per_s: Sequence[float],
    ) -> tuple[FmrGroundwaterApplicationTerm, ...]:
        self._ensure_open()
        heads = self._double_array(cell_heads_m, self._ncell, "cell_heads_m")
        fluxes = self._double_array(
            cell_q_swap_m_per_s, self._ncell, "cell_q_swap_m_per_s"
        )
        self._require_status(
            self._reanchor(
                ctypes.c_int64(self.context_handle),
                ctypes.c_int(self._ncell),
                heads,
                fluxes,
            ),
            "reanchor-terms",
        )
        _, terms, _ = self._read_plan_view()
        return terms

    def relinearize_terms(
        self,
        cell_heads_m: Sequence[float],
        cell_q_swap_m_per_s: Sequence[float],
        cell_dq_swap_dh_per_s: Sequence[float],
    ) -> tuple[FmrGroundwaterApplicationTerm, ...]:
        self._ensure_open()
        heads = self._double_array(cell_heads_m, self._ncell, "cell_heads_m")
        fluxes = self._double_array(
            cell_q_swap_m_per_s, self._ncell, "cell_q_swap_m_per_s"
        )
        tangents = self._double_array(
            cell_dq_swap_dh_per_s, self._ncell, "cell_dq_swap_dh_per_s"
        )
        self._require_status(
            self._relinearize(
                ctypes.c_int64(self.context_handle),
                ctypes.c_int(self._ncell),
                heads,
                fluxes,
                tangents,
            ),
            "relinearize-terms",
        )
        _, terms, _ = self._read_plan_view()
        return terms

    def swap_preflight(self) -> bool:
        self._ensure_open()
        ready = ctypes.c_int()
        status = int(
            self._swap_preflight(
                ctypes.c_int64(self.context_handle), ctypes.byref(ready)
            )
        )
        return status == self.OK and ready.value == 1

    def prepare_ledgers(self) -> bool:
        self._ensure_open()
        return self._status_ok(
            self._prepare_ledgers(ctypes.c_int64(self.context_handle))
        )

    def ledgers_preflight(self) -> bool:
        self._ensure_open()
        ready = ctypes.c_int()
        status = int(
            self._ledgers_preflight(
                ctypes.c_int64(self.context_handle), ctypes.byref(ready)
            )
        )
        return status == self.OK and ready.value == 1

    def abort_prepublication(self) -> bool:
        self._ensure_open()
        return self._status_ok(
            self._abort_prepublication(ctypes.c_int64(self.context_handle))
        )

    def commit_swaps(self) -> bool:
        self._ensure_open()
        return self._status_ok(
            self._commit_swaps(ctypes.c_int64(self.context_handle))
        )

    def commit_ledgers(self) -> bool:
        self._ensure_open()
        return self._status_ok(
            self._commit_ledgers(ctypes.c_int64(self.context_handle))
        )

    def release(self) -> None:
        if self._released:
            return
        self._require_status(
            self._release(ctypes.c_int64(self.context_handle)),
            "release-context",
        )
        self._released = True

    @property
    def tiles(self) -> tuple[FmrGroundwaterApplicationTile, ...]:
        return self._tiles

    def _configure_abi(self) -> None:
        i64 = ctypes.c_int64
        cint = ctypes.c_int
        pd = ctypes.POINTER(ctypes.c_double)
        pi = ctypes.POINTER(cint)
        pi64 = ctypes.POINTER(i64)

        self._context_counts = self._library.fgc49d_context_counts_c
        self._context_counts.restype = cint
        self._context_counts.argtypes = [i64, pi, pi]

        self._plan_view = self._library.fgc49d_plan_view_c
        self._plan_view.restype = cint
        self._plan_view.argtypes = [i64, cint, pi64, pi64, pi, pi, pi64, pd, pd]

        self._tile_view = self._library.fgc49d_tile_view_c
        self._tile_view.restype = cint
        self._tile_view.argtypes = [i64, cint, pi64, pi64, pi64, pi64, pd]

        self._capture_origins = self._library.fgc49d_capture_origins_c
        self._capture_origins.restype = cint
        self._capture_origins.argtypes = [i64]

        self._evaluate = self._library.fgc49d_evaluate_groundwater_fluxes_c
        self._evaluate.restype = cint
        self._evaluate.argtypes = [i64, cint, pd, pd]

        self._trial = self._library.fgc49d_trial_cell_heads_c
        self._trial.restype = cint
        self._trial.argtypes = [i64, cint, pd, pd]

        self._trial_tangents = self._library.fgc49d_trial_response_tangents_c
        self._trial_tangents.restype = cint
        self._trial_tangents.argtypes = [i64, cint, pd]

        self._discard = self._library.fgc49d_discard_candidates_c
        self._discard.restype = cint
        self._discard.argtypes = [i64]

        self._reanchor = self._library.fgc49d_reanchor_terms_c
        self._reanchor.restype = cint
        self._reanchor.argtypes = [i64, cint, pd, pd]

        self._relinearize = self._library.fgc49d_relinearize_terms_c
        self._relinearize.restype = cint
        self._relinearize.argtypes = [i64, cint, pd, pd, pd]

        self._swap_preflight = self._library.fgc49d_swap_preflight_c
        self._swap_preflight.restype = cint
        self._swap_preflight.argtypes = [i64, pi]

        self._prepare_ledgers = self._library.fgc49d_prepare_ledgers_c
        self._prepare_ledgers.restype = cint
        self._prepare_ledgers.argtypes = [i64]

        self._ledgers_preflight = self._library.fgc49d_ledgers_preflight_c
        self._ledgers_preflight.restype = cint
        self._ledgers_preflight.argtypes = [i64, pi]

        self._abort_prepublication = self._library.fgc49d_abort_prepublication_c
        self._abort_prepublication.restype = cint
        self._abort_prepublication.argtypes = [i64]

        self._commit_swaps = self._library.fgc49d_commit_swaps_c
        self._commit_swaps.restype = cint
        self._commit_swaps.argtypes = [i64]

        self._commit_ledgers = self._library.fgc49d_commit_ledgers_c
        self._commit_ledgers.restype = cint
        self._commit_ledgers.argtypes = [i64]

        self._release = self._library.fgc49d_release_context_c
        self._release.restype = cint
        self._release.argtypes = [i64]

    def _read_plan_view(
        self,
    ) -> tuple[
        tuple[FmrGroundwaterApplicationBinding, ...],
        tuple[FmrGroundwaterApplicationTerm, ...],
        tuple[int, ...],
    ]:
        n = self._ncell
        cell_ids = (ctypes.c_int64 * n)()
        binding_cell_ids = (ctypes.c_int64 * n)()
        package_slots = (ctypes.c_int * n)()
        node_ids = (ctypes.c_int * n)()
        term_cell_ids = (ctypes.c_int64 * n)()
        hcof = (ctypes.c_double * n)()
        rhs = (ctypes.c_double * n)()

        self._require_status(
            self._plan_view(
                ctypes.c_int64(self.context_handle),
                ctypes.c_int(n),
                cell_ids,
                binding_cell_ids,
                package_slots,
                node_ids,
                term_cell_ids,
                hcof,
                rhs,
            ),
            "plan-view",
        )
        bindings = tuple(
            FmrGroundwaterApplicationBinding(
                int(binding_cell_ids[i]),
                int(package_slots[i]),
                int(node_ids[i]),
            )
            for i in range(n)
        )
        terms = tuple(
            FmrGroundwaterApplicationTerm(
                int(term_cell_ids[i]),
                float(hcof[i]),
                float(rhs[i]),
            )
            for i in range(n)
        )
        return bindings, terms, tuple(int(value) for value in cell_ids)

    def _read_tile_view(self) -> tuple[FmrGroundwaterApplicationTile, ...]:
        n = self._ntile
        tile_ids = (ctypes.c_int64 * n)()
        cell_ids = (ctypes.c_int64 * n)()
        ledger_ids = (ctypes.c_int64 * n)()
        participant_handles = (ctypes.c_int64 * n)()
        fractions = (ctypes.c_double * n)()
        self._require_status(
            self._tile_view(
                ctypes.c_int64(self.context_handle),
                ctypes.c_int(n),
                tile_ids,
                cell_ids,
                ledger_ids,
                participant_handles,
                fractions,
            ),
            "tile-view",
        )
        return tuple(
            FmrGroundwaterApplicationTile(
                int(tile_ids[i]),
                int(cell_ids[i]),
                int(ledger_ids[i]),
                int(participant_handles[i]),
                float(fractions[i]),
            )
            for i in range(n)
        )

    def _require_current_terms(self, terms: Sequence[Any]) -> None:
        _, authoritative, _ = self._read_plan_view()
        if len(terms) != len(authoritative):
            raise RuntimeError("term count does not match F-GC49D context")
        for supplied, current in zip(terms, authoritative, strict=True):
            if (
                int(supplied.groundwater_cell_id) != current.groundwater_cell_id
                or float(supplied.hcof_m2_per_day) != current.hcof_m2_per_day
                or float(supplied.rhs_m3_per_day) != current.rhs_m3_per_day
            ):
                raise RuntimeError("stale or foreign linear term supplied to F-GC49D context")

    @staticmethod
    def _double_array(
        values: Sequence[float], expected: int, name: str
    ) -> ctypes.Array[ctypes.c_double]:
        if len(values) != expected:
            raise ValueError(f"{name} length {len(values)} does not match {expected}")
        return (ctypes.c_double * expected)(*[float(value) for value in values])

    def _ensure_open(self) -> None:
        if self._released:
            raise RuntimeError("F-GC49D context handle has been released")

    @classmethod
    def _status_ok(cls, status: int) -> bool:
        return int(status) == cls.OK

    @classmethod
    def _require_status(cls, status: int, stage: str) -> None:
        value = int(status)
        if value != cls.OK:
            raise RuntimeError(f"F-GC49D {stage} failed with status {value}")
