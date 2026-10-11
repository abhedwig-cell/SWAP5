from __future__ import annotations

import ctypes
from pathlib import Path
from typing import Any, Sequence

import numpy as np
from numpy.ctypeslib import ndpointer


class Fgc34CtypesPublisher:
    """Thin ctypes marshalling seam to the real Fortran F-GC34 publisher."""

    def __init__(self, library_path: str | Path) -> None:
        self.library_path = Path(library_path)
        if not self.library_path.is_file():
            raise FileNotFoundError(self.library_path)

        self._library = ctypes.CDLL(str(self.library_path))
        self._publish = self._library.fgc34_publish_c
        self._publish.restype = ctypes.c_int
        self._publish.argtypes = [
            ctypes.c_int,
            ndpointer(dtype=np.int64, ndim=1, flags="C_CONTIGUOUS"),
            ndpointer(dtype=np.int32, ndim=1, flags="C_CONTIGUOUS"),
            ndpointer(dtype=np.int32, ndim=1, flags="C_CONTIGUOUS"),
            ndpointer(dtype=np.int64, ndim=1, flags="C_CONTIGUOUS"),
            ndpointer(dtype=np.float64, ndim=1, flags="C_CONTIGUOUS"),
            ndpointer(dtype=np.float64, ndim=1, flags="C_CONTIGUOUS"),
            ctypes.c_int,
            ndpointer(dtype=np.int32, ndim=1, flags=("C_CONTIGUOUS", "WRITEABLE")),
            ndpointer(dtype=np.float64, ndim=1, flags=("C_CONTIGUOUS", "WRITEABLE")),
            ndpointer(dtype=np.float64, ndim=1, flags=("C_CONTIGUOUS", "WRITEABLE")),
            ndpointer(dtype=np.int32, ndim=1, flags=("C_CONTIGUOUS", "WRITEABLE")),
        ]

    def __call__(
        self,
        bindings: Sequence[Any],
        terms: Sequence[Any],
        maxbound: int,
        nodelist: np.ndarray,
        hcof: np.ndarray,
        rhs: np.ndarray,
        nbound: np.ndarray,
    ) -> int:
        binding_cell_ids = np.ascontiguousarray(
            [item.groundwater_cell_id for item in bindings], dtype=np.int64
        )
        package_slots = np.ascontiguousarray(
            [item.package_slot for item in bindings], dtype=np.int32
        )
        modflow_node_ids = np.ascontiguousarray(
            [item.modflow_node_id for item in bindings], dtype=np.int32
        )

        term_cell_ids = np.ascontiguousarray(
            [item.groundwater_cell_id for item in terms], dtype=np.int64
        )
        term_hcof = np.ascontiguousarray(
            [item.hcof_m2_per_day for item in terms], dtype=np.float64
        )
        term_rhs = np.ascontiguousarray(
            [item.rhs_m3_per_day for item in terms], dtype=np.float64
        )

        self._require_live_array("NODELIST", nodelist, np.dtype(np.int32), maxbound)
        self._require_live_array("HCOF", hcof, np.dtype(np.float64), maxbound)
        self._require_live_array("RHS", rhs, np.dtype(np.float64), maxbound)
        self._require_live_array("NBOUND", nbound, np.dtype(np.int32), 1)

        return int(
            self._publish(
                len(bindings),
                binding_cell_ids,
                package_slots,
                modflow_node_ids,
                term_cell_ids,
                term_hcof,
                term_rhs,
                int(maxbound),
                nodelist,
                hcof,
                rhs,
                nbound,
            )
        )

    @staticmethod
    def _require_live_array(
        name: str,
        array: np.ndarray,
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
                f"{name} size {array.size} is smaller than required {minimum_size}"
            )
        if not array.flags.c_contiguous:
            raise ValueError(f"{name} must be C-contiguous")
        if not array.flags.writeable:
            raise ValueError(f"{name} must be writable")
