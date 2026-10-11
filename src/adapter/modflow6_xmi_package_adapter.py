from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from typing import Any, Protocol, Sequence


class XmiKernelProtocol(Protocol):
    def get_var_address(
        self, var_name: str, component_name: str, subcomponent_name: str = ""
    ) -> str: ...

    def get_value_ptr(self, name: str) -> Any: ...


class Fgc34PublisherProtocol(Protocol):
    def __call__(
        self,
        bindings: Any,
        terms: Any,
        maxbound: int,
        nodelist: Any,
        hcof: Any,
        rhs: Any,
        nbound: Any,
    ) -> int: ...


class Modflow6XmiAdapterStatus(IntEnum):
    OK = 0
    INVALID_CONFIG = 1
    ACQUISITION_FAILED = 2
    INVALID_POINTERS = 3
    NOT_ACQUIRED = 4
    PUBLICATION_WINDOW_CLOSED = 5
    PUBLISHER_FAILED = 6
    MISSING_PUBLICATION = 7


_VARIABLES: tuple[str, ...] = ("NODELIST", "HCOF", "RHS", "MAXBOUND", "NBOUND")


@dataclass(frozen=True)
class Modflow6ApiPackageView:
    addresses: dict[str, str]
    nodelist: Any
    hcof: Any
    rhs: Any
    maxbound: Any
    nbound: Any
    maxbound_value: int
    generation: int


class Modflow6XmiPackageAdapter:
    """Lifecycle guard around one MODFLOW6 API package's live XMI memory.

    The external host owns MODFLOW execution. This adapter never invokes
    initialize/prepare/solve/finalize methods on the kernel.
    """

    def __init__(
        self,
        kernel: XmiKernelProtocol,
        flowmodel_key: str,
        package_key: str,
    ) -> None:
        self.kernel = kernel
        self.flowmodel_key = flowmodel_key.strip()
        self.package_key = package_key.strip()
        self.addresses: dict[str, str] = {}
        self.view: Modflow6ApiPackageView | None = None
        self.acquired = False
        self.publication_open = False
        self.generation = 0
        self.published_generation = -1
        self.last_error = ""
        self.last_publisher_status: int | None = None

    def acquire_after_initialize(self) -> Modflow6XmiAdapterStatus:
        """Resolve package addresses and acquire initial kernel-memory views.

        This establishes package identity only. Publication remains closed until
        the host has prepared a MODFLOW timestep and asks this adapter to refresh.
        """

        self._close_window()
        self.last_error = ""
        self.last_publisher_status = None

        if not self.flowmodel_key or not self.package_key:
            self.last_error = "flowmodel_key and package_key must be non-empty"
            return Modflow6XmiAdapterStatus.INVALID_CONFIG

        try:
            addresses = {
                variable: self.kernel.get_var_address(
                    variable, self.flowmodel_key, self.package_key
                )
                for variable in _VARIABLES
            }
            if any(not isinstance(address, str) or not address for address in addresses.values()):
                raise ValueError("XMI returned an empty/non-string variable address")
            pointers = self._acquire_pointers(addresses)
            maxbound_value = self._validate_initial_pointers(pointers)
        except Exception as exc:
            self.last_error = str(exc)
            self.acquired = False
            self.addresses = {}
            self.view = None
            if isinstance(exc, ValueError):
                return Modflow6XmiAdapterStatus.INVALID_POINTERS
            return Modflow6XmiAdapterStatus.ACQUISITION_FAILED

        self.addresses = addresses
        self.view = self._make_view(pointers, maxbound_value, generation=0)
        self.acquired = True
        return Modflow6XmiAdapterStatus.OK

    def refresh_after_prepare_time_step(self) -> Modflow6XmiAdapterStatus:
        """Reacquire live views after the host has called prepare_time_step."""

        self._close_window()
        self.last_error = ""
        self.last_publisher_status = None

        if not self.acquired or not self.addresses:
            self.last_error = "package addresses have not been acquired after initialize"
            return Modflow6XmiAdapterStatus.NOT_ACQUIRED

        try:
            pointers = self._acquire_pointers(self.addresses)
            maxbound_value = self._validate_publication_pointers(pointers)
        except Exception as exc:
            self.last_error = str(exc)
            if isinstance(exc, ValueError):
                return Modflow6XmiAdapterStatus.INVALID_POINTERS
            return Modflow6XmiAdapterStatus.ACQUISITION_FAILED

        self.generation += 1
        self.view = self._make_view(pointers, maxbound_value, self.generation)
        self.publication_open = True
        return Modflow6XmiAdapterStatus.OK

    def publish_via_fgc34(
        self,
        bindings: Any,
        terms: Any,
        publisher: Fgc34PublisherProtocol,
    ) -> Modflow6XmiAdapterStatus:
        """Invoke the qualified F-GC34 publisher against live XMI-backed views."""

        self.last_error = ""
        self.last_publisher_status = None

        if not self.acquired or self.view is None:
            self.last_error = "package has not been acquired"
            return Modflow6XmiAdapterStatus.NOT_ACQUIRED

        if not self.publication_open or self.view.generation != self.generation:
            self.last_error = "publication window is not open for the current timestep"
            return Modflow6XmiAdapterStatus.PUBLICATION_WINDOW_CLOSED

        try:
            publisher_status = int(
                publisher(
                    bindings,
                    terms,
                    self.view.maxbound_value,
                    self.view.nodelist,
                    self.view.hcof,
                    self.view.rhs,
                    self.view.nbound,
                )
            )
        except Exception as exc:
            self.last_error = str(exc)
            return Modflow6XmiAdapterStatus.PUBLISHER_FAILED

        self.last_publisher_status = publisher_status
        if publisher_status != 0:
            self.last_error = f"F-GC34 publisher returned status {publisher_status}"
            return Modflow6XmiAdapterStatus.PUBLISHER_FAILED

        self.published_generation = self.generation
        return Modflow6XmiAdapterStatus.OK

    def close_before_prepare_solve(self) -> Modflow6XmiAdapterStatus:
        """Close the current publication window before the host prepares solve."""

        self.last_error = ""

        if not self.acquired or self.view is None:
            self.last_error = "package has not been acquired"
            return Modflow6XmiAdapterStatus.NOT_ACQUIRED

        if not self.publication_open:
            self.last_error = "publication window is already closed"
            return Modflow6XmiAdapterStatus.PUBLICATION_WINDOW_CLOSED

        if self.published_generation != self.generation:
            self.last_error = "current prepared timestep has no successful F-GC34 publication"
            return Modflow6XmiAdapterStatus.MISSING_PUBLICATION

        self.publication_open = False
        return Modflow6XmiAdapterStatus.OK

    def _close_window(self) -> None:
        self.publication_open = False

    def _acquire_pointers(self, addresses: dict[str, str]) -> dict[str, Any]:
        return {
            variable: self.kernel.get_value_ptr(addresses[variable])
            for variable in _VARIABLES
        }

    def _validate_initial_pointers(self, pointers: dict[str, Any]) -> int:
        maxbound = self._read_positive_maxbound(pointers["MAXBOUND"])
        self._validate_scalar_view("NBOUND", pointers["NBOUND"], "int32")
        self._validate_vector_view("HCOF", pointers["HCOF"], maxbound, "float64")
        self._validate_vector_view("RHS", pointers["RHS"], maxbound, "float64")

        # NODELIST is deliberately weaker before prepare_time_step. iMOD
        # documents a dummy/unallocated state at this point.
        self._validate_mutable_view("NODELIST", pointers["NODELIST"])
        self._validate_dtype_if_exposed("NODELIST", pointers["NODELIST"], "int32")
        return maxbound

    def _validate_publication_pointers(self, pointers: dict[str, Any]) -> int:
        maxbound = self._read_positive_maxbound(pointers["MAXBOUND"])
        self._validate_scalar_view("NBOUND", pointers["NBOUND"], "int32")
        self._validate_vector_view("NODELIST", pointers["NODELIST"], maxbound, "int32")
        self._validate_vector_view("HCOF", pointers["HCOF"], maxbound, "float64")
        self._validate_vector_view("RHS", pointers["RHS"], maxbound, "float64")
        return maxbound

    def _read_positive_maxbound(self, view: Any) -> int:
        self._validate_scalar_view("MAXBOUND", view, "int32")
        try:
            value = int(view[0])
        except Exception as exc:
            raise ValueError("MAXBOUND scalar view is unreadable") from exc
        if value <= 0:
            raise ValueError("MAXBOUND must be positive")
        return value

    def _validate_scalar_view(self, name: str, view: Any, dtype: str) -> None:
        self._validate_mutable_view(name, view)
        try:
            size = len(view)
        except Exception as exc:
            raise ValueError(f"{name} pointer view has no length") from exc
        if size < 1:
            raise ValueError(f"{name} scalar view is empty")
        self._validate_dtype_if_exposed(name, view, dtype)

    def _validate_vector_view(
        self, name: str, view: Any, minimum_size: int, dtype: str
    ) -> None:
        self._validate_mutable_view(name, view)
        try:
            size = len(view)
        except Exception as exc:
            raise ValueError(f"{name} pointer view has no length") from exc
        if size < minimum_size:
            raise ValueError(
                f"{name} capacity {size} is smaller than MAXBOUND {minimum_size}"
            )
        self._validate_dtype_if_exposed(name, view, dtype)

    @staticmethod
    def _validate_mutable_view(name: str, view: Any) -> None:
        if view is None:
            raise ValueError(f"{name} pointer view is missing")
        if not hasattr(view, "__getitem__") or not hasattr(view, "__setitem__"):
            raise ValueError(f"{name} pointer view is not mutable/indexable")

    @staticmethod
    def _validate_dtype_if_exposed(name: str, view: Any, required: str) -> None:
        dtype = getattr(view, "dtype", None)
        if dtype is None:
            return
        dtype_name = str(dtype).lower()
        if required not in dtype_name:
            raise ValueError(
                f"{name} dtype {dtype_name!r} is incompatible with {required}"
            )

    def _make_view(
        self, pointers: dict[str, Any], maxbound_value: int, generation: int
    ) -> Modflow6ApiPackageView:
        return Modflow6ApiPackageView(
            addresses=dict(self.addresses) if self.addresses else {},
            nodelist=pointers["NODELIST"],
            hcof=pointers["HCOF"],
            rhs=pointers["RHS"],
            maxbound=pointers["MAXBOUND"],
            nbound=pointers["NBOUND"],
            maxbound_value=maxbound_value,
            generation=generation,
        )
