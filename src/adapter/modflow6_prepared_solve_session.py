from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from typing import Any, Sequence

import numpy as np


class PreparedSolveStatus(IntEnum):
    OK = 0
    INVALID_CONFIG = 1
    ACQUISITION_FAILED = 2
    INVALID_POINTERS = 3
    NOT_ACQUIRED = 4
    SOLVE_ALREADY_OPEN = 5
    SOLVE_NOT_OPEN = 6
    PUBLICATION_FAILED = 7
    SOLVE_FAILED = 8
    ACCEPTED_ORIGIN_DRIFT = 9
    SESSION_INVALID = 10
    ALREADY_FINALIZED = 11


@dataclass(frozen=True)
class PreparedSolveIteration:
    iteration: int
    modflow_converged: bool
    head_m: np.ndarray
    accepted_head_old_m: np.ndarray


class Modflow6PreparedSolveSession:
    """MODFLOW6 backend for one externally coupled prepared solve.

    This adapter owns only the MODFLOW/XMI solve session.  Predictor/corrector
    science, SWAP trials and coupling convergence belong to the internal
    SWAP5-MODFLOW coupling service above this backend.
    """

    _PACKAGE_VARIABLES = ("NODELIST", "HCOF", "RHS", "MAXBOUND", "NBOUND")

    def __init__(
        self,
        kernel: Any,
        flowmodel_key: str,
        package_key: str,
        publisher: Any,
        solution_id: int = 1,
    ) -> None:
        self.kernel = kernel
        self.flowmodel_key = flowmodel_key.strip()
        self.package_key = package_key.strip()
        self.publisher = publisher
        self.solution_id = int(solution_id)

        self.addresses: dict[str, str] = {}
        self.nodelist: np.ndarray | None = None
        self.hcof: np.ndarray | None = None
        self.rhs: np.ndarray | None = None
        self.maxbound_view: np.ndarray | None = None
        self.nbound: np.ndarray | None = None
        self.maxbound = 0

        self.head: np.ndarray | None = None
        self.xold: np.ndarray | None = None
        self.accepted_xold: np.ndarray | None = None

        self.acquired = False
        self.solve_open = False
        self.finalized = False
        self.invalid = False
        self.iteration_count = 0
        self.last_error = ""
        self.last_publisher_status: int | None = None

    def acquire_after_prepare_time_step(self) -> PreparedSolveStatus:
        self.last_error = ""
        if self.invalid:
            return PreparedSolveStatus.SESSION_INVALID
        if not self.flowmodel_key or not self.package_key or self.solution_id <= 0:
            self.last_error = "invalid model/package/solution configuration"
            return PreparedSolveStatus.INVALID_CONFIG
        if self.solve_open:
            self.last_error = "cannot reacquire while solve is open"
            return PreparedSolveStatus.SOLVE_ALREADY_OPEN

        try:
            self.addresses = {
                name: self.kernel.get_var_address(
                    name, self.flowmodel_key, self.package_key
                )
                for name in self._PACKAGE_VARIABLES
            }
            self._refresh_package_views()
            self._validate_package_views()
        except Exception as exc:
            self.last_error = str(exc)
            self._invalidate()
            if isinstance(exc, (TypeError, ValueError)):
                return PreparedSolveStatus.INVALID_POINTERS
            return PreparedSolveStatus.ACQUISITION_FAILED

        self.acquired = True
        return PreparedSolveStatus.OK

    def open_prepared_solve(self) -> PreparedSolveStatus:
        self.last_error = ""
        if self.invalid:
            return PreparedSolveStatus.SESSION_INVALID
        if not self.acquired:
            self.last_error = "package views have not been acquired after prepare_time_step"
            return PreparedSolveStatus.NOT_ACQUIRED
        if self.finalized:
            return PreparedSolveStatus.ALREADY_FINALIZED
        if self.solve_open:
            return PreparedSolveStatus.SOLVE_ALREADY_OPEN

        try:
            self.kernel.prepare_solve(self.solution_id)
            # Reacquire all views after model/package advance.  XOLD receives the
            # accepted previous-time state during prepare_solve.
            self._refresh_package_views()
            self._validate_package_views()
            head_address = self.kernel.get_var_address("X", self.flowmodel_key)
            xold_address = self.kernel.get_var_address("XOLD", self.flowmodel_key)
            self.head = self.kernel.get_value_ptr(head_address)
            self.xold = self.kernel.get_value_ptr(xold_address)
            self._require_array("X", self.head, np.dtype(np.float64), 1)
            self._require_array("XOLD", self.xold, np.dtype(np.float64), 1)
            if self.head.shape != self.xold.shape:
                raise ValueError("X and XOLD shapes differ")
            self.accepted_xold = self.xold.copy()
        except Exception as exc:
            self.last_error = str(exc)
            self._invalidate()
            if isinstance(exc, (TypeError, ValueError)):
                return PreparedSolveStatus.INVALID_POINTERS
            return PreparedSolveStatus.SOLVE_FAILED

        self.solve_open = True
        self.iteration_count = 0
        return PreparedSolveStatus.OK

    def publish_and_solve_iteration(
        self,
        bindings: Sequence[Any],
        terms: Sequence[Any],
    ) -> tuple[PreparedSolveStatus, PreparedSolveIteration | None]:
        self.last_error = ""
        self.last_publisher_status = None

        if self.invalid:
            return PreparedSolveStatus.SESSION_INVALID, None
        if not self.solve_open:
            return PreparedSolveStatus.SOLVE_NOT_OPEN, None
        if self.finalized:
            return PreparedSolveStatus.ALREADY_FINALIZED, None

        assert self.nodelist is not None
        assert self.hcof is not None
        assert self.rhs is not None
        assert self.nbound is not None
        assert self.head is not None
        assert self.xold is not None
        assert self.accepted_xold is not None

        try:
            publisher_status = int(
                self.publisher(
                    bindings,
                    terms,
                    self.maxbound,
                    self.nodelist,
                    self.hcof,
                    self.rhs,
                    self.nbound,
                )
            )
        except Exception as exc:
            self.last_error = str(exc)
            self._invalidate()
            return PreparedSolveStatus.PUBLICATION_FAILED, None

        self.last_publisher_status = publisher_status
        if publisher_status != 0:
            self.last_error = f"F-GC34 publisher returned {publisher_status}"
            self._invalidate()
            return PreparedSolveStatus.PUBLICATION_FAILED, None

        try:
            converged = bool(self.kernel.solve(self.solution_id))
        except Exception as exc:
            self.last_error = str(exc)
            self._invalidate()
            return PreparedSolveStatus.SOLVE_FAILED, None

        if not np.array_equal(self.xold, self.accepted_xold):
            self.last_error = "MODFLOW XOLD changed inside prepared solve"
            self._invalidate()
            return PreparedSolveStatus.ACCEPTED_ORIGIN_DRIFT, None

        self.iteration_count += 1
        return (
            PreparedSolveStatus.OK,
            PreparedSolveIteration(
                iteration=self.iteration_count,
                modflow_converged=converged,
                head_m=self.head.copy(),
                accepted_head_old_m=self.accepted_xold.copy(),
            ),
        )

    def finalize_prepared_solve(self) -> PreparedSolveStatus:
        self.last_error = ""
        if self.invalid:
            return PreparedSolveStatus.SESSION_INVALID
        if self.finalized:
            return PreparedSolveStatus.ALREADY_FINALIZED
        if not self.solve_open:
            return PreparedSolveStatus.SOLVE_NOT_OPEN
        if self.iteration_count <= 0:
            self.last_error = "cannot finalize solve before any solve iteration"
            self._invalidate()
            return PreparedSolveStatus.SOLVE_FAILED

        try:
            self.kernel.finalize_solve(self.solution_id)
        except Exception as exc:
            self.last_error = str(exc)
            self._invalidate()
            return PreparedSolveStatus.SOLVE_FAILED

        self.solve_open = False
        self.finalized = True
        return PreparedSolveStatus.OK

    def invalidate_without_finalize(self) -> None:
        """Invalidate an abandoned solve.

        XMI has no abort_solve primitive.  A caller that abandons the whole
        coupling window must not reuse this session as accepted MODFLOW state.
        """

        self._invalidate()

    def _refresh_package_views(self) -> None:
        self.nodelist = self.kernel.get_value_ptr(self.addresses["NODELIST"])
        self.hcof = self.kernel.get_value_ptr(self.addresses["HCOF"])
        self.rhs = self.kernel.get_value_ptr(self.addresses["RHS"])
        self.maxbound_view = self.kernel.get_value_ptr(self.addresses["MAXBOUND"])
        self.nbound = self.kernel.get_value_ptr(self.addresses["NBOUND"])

    def _validate_package_views(self) -> None:
        assert self.maxbound_view is not None
        self._require_array("MAXBOUND", self.maxbound_view, np.dtype(np.int32), 1)
        maxbound = int(self.maxbound_view[0])
        if maxbound <= 0:
            raise ValueError("MAXBOUND must be positive")

        assert self.nodelist is not None
        assert self.hcof is not None
        assert self.rhs is not None
        assert self.nbound is not None
        self._require_array("NODELIST", self.nodelist, np.dtype(np.int32), maxbound)
        self._require_array("HCOF", self.hcof, np.dtype(np.float64), maxbound)
        self._require_array("RHS", self.rhs, np.dtype(np.float64), maxbound)
        self._require_array("NBOUND", self.nbound, np.dtype(np.int32), 1)
        self.maxbound = maxbound

    @staticmethod
    def _require_array(
        name: str,
        array: Any,
        dtype: np.dtype[Any],
        minimum_size: int,
    ) -> None:
        if not isinstance(array, np.ndarray):
            raise TypeError(f"{name} must be a NumPy array")
        if array.dtype != dtype:
            raise TypeError(f"{name} dtype {array.dtype} does not match {dtype}")
        if array.ndim != 1:
            raise ValueError(f"{name} must be one-dimensional")
        if array.size < minimum_size:
            raise ValueError(
                f"{name} size {array.size} smaller than required {minimum_size}"
            )
        if not array.flags.c_contiguous or not array.flags.writeable:
            raise ValueError(f"{name} must be writable C-contiguous memory")

    def _invalidate(self) -> None:
        self.invalid = True
        self.solve_open = False
