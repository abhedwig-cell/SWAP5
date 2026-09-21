"""Controlled dummy SWAP - Ribasim - MODFLOW coupling triangle.

Research-only harness. No production physics is implemented here.

One coupling window follows:
1. read SWAP irrigation request from committed SWAP state;
2. read MODFLOW forecast exchange;
3. let dummy Ribasim allocate UserDemand;
4. read MODFLOW actual exchange;
5. let dummy Ribasim realize physical exchange and managed delivery;
6. publish one coupled candidate;
7. explicitly commit all three participants after a stale-state preflight.
"""

from __future__ import annotations

from dataclasses import dataclass

from dummy_ribasim_reservoir import (
    AllocationCandidate,
    BasinWindowForcing,
    DummyRibasimReservoir,
    RealizationCandidate,
    ReservoirState,
    StaleCandidateError,
)


def _nonnegative(name: str, value: float) -> float:
    value = float(value)
    if value < 0.0:
        raise ValueError(f"{name} must be non-negative")
    return value


@dataclass(frozen=True)
class DummySwapState:
    irrigation_request_m3: float
    last_delivered_m3: float = 0.0
    last_shortage_m3: float = 0.0
    revision: int = 0

    def __post_init__(self) -> None:
        object.__setattr__(
            self,
            "irrigation_request_m3",
            _nonnegative("irrigation_request_m3", self.irrigation_request_m3),
        )
        object.__setattr__(
            self,
            "last_delivered_m3",
            _nonnegative("last_delivered_m3", self.last_delivered_m3),
        )
        object.__setattr__(
            self,
            "last_shortage_m3",
            _nonnegative("last_shortage_m3", self.last_shortage_m3),
        )
        if self.revision < 0:
            raise ValueError("revision must be non-negative")


class DummySwapParticipant:
    def __init__(self, initial: DummySwapState) -> None:
        self._state = initial

    @property
    def committed_state(self) -> DummySwapState:
        return self._state

    def committed_request_m3(self) -> float:
        return self._state.irrigation_request_m3

    def _preflight_revision(self, expected: int) -> None:
        if self._state.revision != expected:
            raise StaleCandidateError(
                f"SWAP revision {self._state.revision} != candidate revision {expected}"
            )

    def _commit_delivery(
        self,
        expected_revision: int,
        delivered_m3: float,
        shortage_m3: float,
    ) -> DummySwapState:
        self._preflight_revision(expected_revision)
        self._state = DummySwapState(
            irrigation_request_m3=self._state.irrigation_request_m3,
            last_delivered_m3=delivered_m3,
            last_shortage_m3=shortage_m3,
            revision=self._state.revision + 1,
        )
        return self._state

    def advance_committed_request(self, next_request_m3: float) -> DummySwapState:
        """Advance demand between coupling windows, never within a candidate window."""
        self._state = DummySwapState(
            irrigation_request_m3=next_request_m3,
            last_delivered_m3=self._state.last_delivered_m3,
            last_shortage_m3=self._state.last_shortage_m3,
            revision=self._state.revision + 1,
        )
        return self._state


@dataclass(frozen=True)
class DummyModflowState:
    last_infiltration_m3: float = 0.0
    last_drainage_m3: float = 0.0
    revision: int = 0

    def __post_init__(self) -> None:
        object.__setattr__(
            self,
            "last_infiltration_m3",
            _nonnegative("last_infiltration_m3", self.last_infiltration_m3),
        )
        object.__setattr__(
            self,
            "last_drainage_m3",
            _nonnegative("last_drainage_m3", self.last_drainage_m3),
        )
        if self.revision < 0:
            raise ValueError("revision must be non-negative")


@dataclass(frozen=True)
class DummyModflowWindow:
    forecast: BasinWindowForcing
    actual: BasinWindowForcing


class DummyModflowParticipant:
    def __init__(self, initial: DummyModflowState | None = None) -> None:
        self._state = initial or DummyModflowState()

    @property
    def committed_state(self) -> DummyModflowState:
        return self._state

    def _preflight_revision(self, expected: int) -> None:
        if self._state.revision != expected:
            raise StaleCandidateError(
                f"MODFLOW revision {self._state.revision} != candidate revision {expected}"
            )

    def _commit_exchange(
        self,
        expected_revision: int,
        actual: BasinWindowForcing,
    ) -> DummyModflowState:
        self._preflight_revision(expected_revision)
        self._state = DummyModflowState(
            last_infiltration_m3=actual.basin_infiltration_m3,
            last_drainage_m3=actual.basin_drainage_m3,
            revision=self._state.revision + 1,
        )
        return self._state

    def advance_external_revision(self) -> DummyModflowState:
        """Test hook representing an independent committed MODFLOW advancement."""
        self._state = DummyModflowState(
            last_infiltration_m3=self._state.last_infiltration_m3,
            last_drainage_m3=self._state.last_drainage_m3,
            revision=self._state.revision + 1,
        )
        return self._state


@dataclass(frozen=True)
class CoupledWindowCandidate:
    swap_revision: int
    ribasim_revision: int
    modflow_revision: int
    swap_request_m3: float
    allocation: AllocationCandidate
    realization: RealizationCandidate
    modflow_window: DummyModflowWindow


@dataclass(frozen=True)
class CoupledCommitResult:
    swap: DummySwapState
    ribasim: ReservoirState
    modflow: DummyModflowState


class DummyThreeWayCoupler:
    def __init__(
        self,
        swap: DummySwapParticipant,
        ribasim: DummyRibasimReservoir,
        modflow: DummyModflowParticipant,
    ) -> None:
        self.swap = swap
        self.ribasim = ribasim
        self.modflow = modflow

    def prepare_window(self, window: DummyModflowWindow) -> CoupledWindowCandidate:
        swap_revision = self.swap.committed_state.revision
        ribasim_revision = self.ribasim.committed_state.revision
        modflow_revision = self.modflow.committed_state.revision
        request = self.swap.committed_request_m3()

        allocation = self.ribasim.prepare_allocation(request, window.forecast)
        realization = self.ribasim.realize_step(allocation, window.actual)

        # Reading tentative Ribasim results must not alter the SWAP request that
        # defined this window.
        if self.swap.committed_request_m3() != request:
            raise RuntimeError("same-window SWAP demand mutated during preparation")

        return CoupledWindowCandidate(
            swap_revision=swap_revision,
            ribasim_revision=ribasim_revision,
            modflow_revision=modflow_revision,
            swap_request_m3=request,
            allocation=allocation,
            realization=realization,
            modflow_window=window,
        )

    def _preflight(self, candidate: CoupledWindowCandidate) -> None:
        self.swap._preflight_revision(candidate.swap_revision)
        if self.ribasim.committed_state.revision != candidate.ribasim_revision:
            raise StaleCandidateError(
                "Ribasim committed revision changed after candidate preparation"
            )
        self.modflow._preflight_revision(candidate.modflow_revision)

    def commit(self, candidate: CoupledWindowCandidate) -> CoupledCommitResult:
        # All stale checks happen before the first participant mutation.
        self._preflight(candidate)

        ribasim_state = self.ribasim.commit(candidate.realization)
        swap_state = self.swap._commit_delivery(
            candidate.swap_revision,
            candidate.realization.user_demand_delivered_m3,
            candidate.realization.total_shortage_m3,
        )
        modflow_state = self.modflow._commit_exchange(
            candidate.modflow_revision,
            candidate.modflow_window.actual,
        )

        return CoupledCommitResult(
            swap=swap_state,
            ribasim=ribasim_state,
            modflow=modflow_state,
        )
