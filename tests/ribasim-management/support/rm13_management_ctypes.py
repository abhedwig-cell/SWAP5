from __future__ import annotations
import ctypes
from pathlib import Path

class Rm13Management:
    def __init__(self, library_path: str | Path) -> None:
        self.lib=ctypes.CDLL(str(Path(library_path).resolve()))
        self.lib.rm13_management_initialize_c.restype=ctypes.c_int
        self.lib.rm13_management_initialize_c.argtypes=[ctypes.POINTER(ctypes.c_double)]
        self.lib.rm13_management_prepare_candidate_c.restype=ctypes.c_int
        self.lib.rm13_management_prepare_candidate_c.argtypes=[
            ctypes.c_int,ctypes.c_int,
            ctypes.c_double,ctypes.c_double,ctypes.c_double,ctypes.c_double,ctypes.c_double,
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)
        ]
        for name in [
            "rm13_management_discard_candidate_c",
            "rm13_management_preflight_c",
            "rm13_management_commit_c",
        ]:
            fn=getattr(self.lib,name); fn.restype=ctypes.c_int; fn.argtypes=[]
        self.lib.rm13_management_state_c.restype=ctypes.c_int
        self.lib.rm13_management_state_c.argtypes=[
            ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_double),
        ]

    def initialize(self)->float:
        request=ctypes.c_double()
        status=self.lib.rm13_management_initialize_c(ctypes.byref(request))
        if status:
            raise RuntimeError(f"RM13 management initialize failed: {status}")
        return request.value

    def prepare_candidate(
        self,
        *,
        ribasim_origin_id:int,
        ribasim_origin_revision:int,
        allocated_depth_cm:float,
        supplied_depth_cm:float,
        source_level_margin_m:float,
        level_difference_threshold_m:float,
        low_storage_factor:float,
    )->tuple[float,float]:
        net=ctypes.c_double(); rate=ctypes.c_double()
        status=self.lib.rm13_management_prepare_candidate_c(
            int(ribasim_origin_id),int(ribasim_origin_revision),
            float(allocated_depth_cm),float(supplied_depth_cm),
            float(source_level_margin_m),float(level_difference_threshold_m),float(low_storage_factor),
            ctypes.byref(net),ctypes.byref(rate),
        )
        if status:
            raise RuntimeError(f"RM13 management candidate failed: {status}")
        return net.value,rate.value

    def preflight(self)->bool:
        return self.lib.rm13_management_preflight_c()==0

    def discard(self)->None:
        status=self.lib.rm13_management_discard_candidate_c()
        if status:
            raise RuntimeError(f"RM13 management discard failed: {status}")

    def commit(self)->None:
        status=self.lib.rm13_management_commit_c()
        if status:
            raise RuntimeError(f"RM13 management commit failed: {status}")

    def state(self)->tuple[int,float,float,float,float,float]:
        revision=ctypes.c_int()
        vals=[ctypes.c_double() for _ in range(5)]
        status=self.lib.rm13_management_state_c(
            ctypes.byref(revision),*[ctypes.byref(v) for v in vals]
        )
        if status:
            raise RuntimeError(f"RM13 management state failed: {status}")
        return (revision.value,*[v.value for v in vals])
