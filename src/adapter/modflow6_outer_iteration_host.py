from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from typing import Any, Protocol, Sequence

import numpy as np

from modflow6_xmi_package_adapter import (
    Fgc34PublisherProtocol,
    Modflow6XmiAdapterStatus,
    Modflow6XmiPackageAdapter,
)


class Modflow6OuterIterationHostStatus(IntEnum):
    OK = 0
    INVALID_CONFIG = 1
    INVALID_STATE = 2
    TIMESTEP_PREPARE_FAILED = 3
    PACKAGE_REFRESH_FAILED = 4
    HEAD_ACQUISITION_FAILED = 5
    RESPONSE_PROVIDER_FAILED = 6
    INITIAL_PUBLICATION_FAILED = 7
    SOLVE_PREPARE_FAILED = 8
    ITERATION_PUBLICATION_FAILED = 9
    SOLVE_FAILED = 10
    NOT_CONVERGED = 11
    FINALIZE_SOLVE_FAILED = 12
    COMMIT_FAILED = 13
    REINITIALIZATION_REQUIRED = 14


@dataclass(frozen=True)
class Modflow6OuterIterationPublication:
    bindings: Any
    terms: Any


@dataclass
class Modflow6OuterIterationResult:
    status: Modflow6OuterIterationHostStatus = Modflow6OuterIterationHostStatus.INVALID_STATE
    converged: bool = False
    candidate_ready: bool = False
    committed: bool = False
    requires_reinitialize: bool = False
    iteration_count: int = 0
    publication_count: int = 0
    final_max_head_delta_m: float = float("inf")
    final_monitored_head_m: np.ndarray | None = None
    failure_stage: str = "not-run"
    message: str = ""


class Modflow6SolveKernelProtocol(Protocol):
    def prepare_time_step(self, dt: float) -> None: ...

    def get_var_address(
        self, var_name: str, component_name: str, subcomponent_name: str = ""
    ) -> str: ...

    def get_value_ptr(self, name: str) -> Any: ...

    def prepare_solve(self, component_id: int = 1) -> None: ...

    def solve(self, component_id: int = 1) -> bool: ...

    def finalize_solve(self, component_id: int = 1) -> None: ...

    def finalize_time_step(self) -> None: ...


class ResponseProviderProtocol(Protocol):
    def __call__(
        self,
        head: np.ndarray,
        iteration: int,
    ) -> Modflow6OuterIterationPublication: ...


class Modflow6OuterIterationHost:
    """Bounded host for one live MODFLOW6 nonlinear solve.

    The host owns MODFLOW lifecycle ordering only. It does not own SWAP science,
    SWAP state, or cross-kernel transaction semantics.
    """

    def __init__(
        self,
        kernel: Modflow6SolveKernelProtocol,
        package_adapter: Modflow6XmiPackageAdapter,
        publisher: Fgc34PublisherProtocol,
        flowmodel_key: str,
        monitored_head_indices: Sequence[int],
        *,
        solution_id: int = 1,
        head_tolerance_m: float = 1.0e-10,
        max_iterations: int = 25,
    ) -> None:
        self.kernel = kernel
        self.package_adapter = package_adapter
        self.publisher = publisher
        self.flowmodel_key = flowmodel_key.strip()
        self.monitored_head_indices = np.asarray(monitored_head_indices, dtype=np.int64)
        self.solution_id = int(solution_id)
        self.head_tolerance_m = float(head_tolerance_m)
        self.max_iterations = int(max_iterations)

        self._candidate_ready = False
        self._committed = False
        self._requires_reinitialize = False
        self._active_generation: int | None = None
        self._head_view: np.ndarray | None = None
        self.last_result = Modflow6OuterIterationResult()

    @property
    def candidate_ready(self) -> bool:
        return self._candidate_ready

    @property
    def committed(self) -> bool:
        return self._committed

    @property
    def requires_reinitialize(self) -> bool:
        return self._requires_reinitialize

    def solve_candidate(
        self,
        response_provider: ResponseProviderProtocol,
    ) -> Modflow6OuterIterationResult:
        result = Modflow6OuterIterationResult()
        result.failure_stage = "configuration"

        if not self._configuration_valid():
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.INVALID_CONFIG,
                "invalid host configuration",
                requires_reinitialize=False,
            )
        if self._requires_reinitialize:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.REINITIALIZATION_REQUIRED,
                "host requires kernel reinitialization after a previous failed prepared solve",
                requires_reinitialize=True,
            )
        if self._candidate_ready or self._committed:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.INVALID_STATE,
                "candidate lifecycle already active or committed",
                requires_reinitialize=False,
            )
        if not self.package_adapter.acquired:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.INVALID_STATE,
                "F-GC35 package adapter has not been acquired after initialize",
                requires_reinitialize=False,
            )

        try:
            result.failure_stage = "prepare-time-step"
            self.kernel.prepare_time_step(0.0)
        except Exception as exc:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.TIMESTEP_PREPARE_FAILED,
                str(exc),
                requires_reinitialize=True,
            )

        refresh_status = self.package_adapter.refresh_after_prepare_time_step()
        if refresh_status != Modflow6XmiAdapterStatus.OK:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.PACKAGE_REFRESH_FAILED,
                self.package_adapter.last_error,
                requires_reinitialize=True,
            )

        try:
            result.failure_stage = "head-acquisition"
            head_address = self.kernel.get_var_address("X", self.flowmodel_key)
            head_view = self.kernel.get_value_ptr(head_address)
            self._validate_head_view(head_view)
            self._head_view = head_view
        except Exception as exc:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.HEAD_ACQUISITION_FAILED,
                str(exc),
                requires_reinitialize=True,
            )

        self._active_generation = self.package_adapter.generation

        try:
            initial_publication = response_provider(np.array(head_view, copy=True), 0)
            self._validate_publication(initial_publication)
        except Exception as exc:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.RESPONSE_PROVIDER_FAILED,
                str(exc),
                requires_reinitialize=True,
            )

        initial_status = self.package_adapter.publish_via_fgc34(
            initial_publication.bindings,
            initial_publication.terms,
            self.publisher,
        )
        if initial_status != Modflow6XmiAdapterStatus.OK:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.INITIAL_PUBLICATION_FAILED,
                self.package_adapter.last_error,
                requires_reinitialize=True,
            )
        result.publication_count = 1

        close_status = self.package_adapter.close_before_prepare_solve()
        if close_status != Modflow6XmiAdapterStatus.OK:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.INITIAL_PUBLICATION_FAILED,
                self.package_adapter.last_error,
                requires_reinitialize=True,
            )

        try:
            result.failure_stage = "prepare-solve"
            self.kernel.prepare_solve(self.solution_id)
        except Exception as exc:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.SOLVE_PREPARE_FAILED,
                str(exc),
                requires_reinitialize=True,
            )

        previous_head = np.array(
            head_view[self.monitored_head_indices],
            copy=True,
            dtype=np.float64,
        )

        for iteration in range(1, self.max_iterations + 1):
            result.iteration_count = iteration
            result.failure_stage = "solve"
            try:
                mf6_converged = bool(self.kernel.solve(self.solution_id))
            except Exception as exc:
                return self._finish_failure(
                    result,
                    Modflow6OuterIterationHostStatus.SOLVE_FAILED,
                    str(exc),
                    requires_reinitialize=True,
                )

            current_head = np.array(
                head_view[self.monitored_head_indices],
                copy=True,
                dtype=np.float64,
            )
            if not np.all(np.isfinite(current_head)):
                return self._finish_failure(
                    result,
                    Modflow6OuterIterationHostStatus.SOLVE_FAILED,
                    "MODFLOW head became nonfinite",
                    requires_reinitialize=True,
                )

            max_head_delta = float(np.max(np.abs(current_head - previous_head)))
            result.final_max_head_delta_m = max_head_delta
            result.final_monitored_head_m = current_head.copy()

            if mf6_converged and max_head_delta <= self.head_tolerance_m:
                try:
                    result.failure_stage = "finalize-solve"
                    self.kernel.finalize_solve(self.solution_id)
                except Exception as exc:
                    return self._finish_failure(
                        result,
                        Modflow6OuterIterationHostStatus.FINALIZE_SOLVE_FAILED,
                        str(exc),
                        requires_reinitialize=True,
                    )

                self._candidate_ready = True
                result.status = Modflow6OuterIterationHostStatus.OK
                result.converged = True
                result.candidate_ready = True
                result.failure_stage = "none"
                self.last_result = result
                return result

            if iteration == self.max_iterations:
                return self._finish_failure(
                    result,
                    Modflow6OuterIterationHostStatus.NOT_CONVERGED,
                    "bounded outer iteration did not reach coupled convergence",
                    requires_reinitialize=True,
                )

            try:
                result.failure_stage = "response-provider"
                publication = response_provider(np.array(head_view, copy=True), iteration)
                self._validate_publication(publication)
            except Exception as exc:
                return self._finish_failure(
                    result,
                    Modflow6OuterIterationHostStatus.RESPONSE_PROVIDER_FAILED,
                    str(exc),
                    requires_reinitialize=True,
                )

            publication_status = self._republish_current_generation(publication)
            if publication_status != Modflow6OuterIterationHostStatus.OK:
                return self._finish_failure(
                    result,
                    publication_status,
                    "F-GC34 outer-iteration publication failed",
                    requires_reinitialize=True,
                )
            result.publication_count += 1
            previous_head = current_head

        return self._finish_failure(
            result,
            Modflow6OuterIterationHostStatus.NOT_CONVERGED,
            "unreachable bounded iteration exit",
            requires_reinitialize=True,
        )

    def commit_candidate(self) -> Modflow6OuterIterationResult:
        result = self.last_result
        if self._requires_reinitialize:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.REINITIALIZATION_REQUIRED,
                "cannot commit after failed prepared solve",
                requires_reinitialize=True,
            )
        if not self._candidate_ready or self._committed:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.INVALID_STATE,
                "no uncommitted converged MODFLOW candidate is ready",
                requires_reinitialize=False,
            )

        try:
            result.failure_stage = "finalize-time-step"
            self.kernel.finalize_time_step()
        except Exception as exc:
            return self._finish_failure(
                result,
                Modflow6OuterIterationHostStatus.COMMIT_FAILED,
                str(exc),
                requires_reinitialize=True,
            )

        self._candidate_ready = False
        self._committed = True
        result.committed = True
        result.candidate_ready = False
        result.status = Modflow6OuterIterationHostStatus.OK
        result.failure_stage = "none"
        self.last_result = result
        return result

    def _republish_current_generation(
        self,
        publication: Modflow6OuterIterationPublication,
    ) -> Modflow6OuterIterationHostStatus:
        adapter = self.package_adapter
        view = adapter.view

        if (
            view is None
            or self._active_generation is None
            or adapter.generation != self._active_generation
            or view.generation != self._active_generation
            or adapter.published_generation != self._active_generation
            or adapter.publication_open
        ):
            return Modflow6OuterIterationHostStatus.ITERATION_PUBLICATION_FAILED

        try:
            publisher_status = int(
                self.publisher(
                    publication.bindings,
                    publication.terms,
                    view.maxbound_value,
                    view.nodelist,
                    view.hcof,
                    view.rhs,
                    view.nbound,
                )
            )
        except Exception:
            return Modflow6OuterIterationHostStatus.ITERATION_PUBLICATION_FAILED

        if publisher_status != 0:
            return Modflow6OuterIterationHostStatus.ITERATION_PUBLICATION_FAILED
        return Modflow6OuterIterationHostStatus.OK

    def _configuration_valid(self) -> bool:
        if not self.flowmodel_key:
            return False
        if self.solution_id <= 0:
            return False
        if self.max_iterations <= 0:
            return False
        if not np.isfinite(self.head_tolerance_m) or self.head_tolerance_m < 0.0:
            return False
        if self.monitored_head_indices.ndim != 1 or self.monitored_head_indices.size == 0:
            return False
        if np.any(self.monitored_head_indices < 0):
            return False
        return True

    def _validate_head_view(self, head_view: Any) -> None:
        if not isinstance(head_view, np.ndarray):
            raise TypeError("MODFLOW head pointer must be a NumPy array")
        if head_view.dtype != np.dtype(np.float64):
            raise TypeError(f"MODFLOW head dtype {head_view.dtype} is not float64")
        if head_view.ndim != 1:
            raise ValueError("MODFLOW head pointer must be one-dimensional")
        if int(np.max(self.monitored_head_indices)) >= head_view.size:
            raise ValueError("monitored head index is outside MODFLOW head array")
        if not np.all(np.isfinite(head_view[self.monitored_head_indices])):
            raise ValueError("initial monitored MODFLOW head is nonfinite")

    @staticmethod
    def _validate_publication(publication: Modflow6OuterIterationPublication) -> None:
        if not isinstance(publication, Modflow6OuterIterationPublication):
            raise TypeError("response provider returned the wrong publication type")
        if publication.bindings is None or publication.terms is None:
            raise ValueError("response provider returned an incomplete publication")

    def _finish_failure(
        self,
        result: Modflow6OuterIterationResult,
        status: Modflow6OuterIterationHostStatus,
        message: str,
        *,
        requires_reinitialize: bool,
    ) -> Modflow6OuterIterationResult:
        result.status = status
        result.converged = False
        result.candidate_ready = False
        result.committed = False
        result.requires_reinitialize = requires_reinitialize
        result.message = message
        self._candidate_ready = False
        if requires_reinitialize:
            self._requires_reinitialize = True
        self.last_result = result
        return result
