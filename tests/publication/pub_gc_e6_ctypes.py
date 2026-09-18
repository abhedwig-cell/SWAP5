from __future__ import annotations

import ctypes
from pathlib import Path

class E6ActiveDrainageSwap:
    def __init__(self, library: Path) -> None:
        self.lib=ctypes.CDLL(str(library))
        self.lib.pub_gc_e6_swap_initialize_c.restype=ctypes.c_int
        self.lib.pub_gc_e6_swap_initialize_c.argtypes=[
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)
        ]
        self.lib.pub_gc_e6_swap_trial_c.restype=ctypes.c_int
        self.lib.pub_gc_e6_swap_trial_c.argtypes=[ctypes.c_double,ctypes.POINTER(ctypes.c_double)]
        self.lib.pub_gc_e6_swap_discard_c.restype=ctypes.c_int
        self.lib.pub_gc_e6_state_c.restype=ctypes.c_int
        self.lib.pub_gc_e6_state_c.argtypes=[
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_double)
        ]
        self.lib.pub_gc_e6_e1_diagnostics_c.restype=ctypes.c_int
        self.lib.pub_gc_e6_e1_diagnostics_c.argtypes=[
            ctypes.POINTER(ctypes.c_int), *([ctypes.POINTER(ctypes.c_double)]*13)
        ]
        self.lib.pub_gc_e6_drainage_coverage_c.restype=ctypes.c_int
        self.lib.pub_gc_e6_drainage_coverage_c.argtypes=[ctypes.POINTER(ctypes.c_int)]

    def initialize(self)->tuple[float,float,float]:
        hcof=ctypes.c_double(); rhs=ctypes.c_double(); href=ctypes.c_double()
        status=self.lib.pub_gc_e6_swap_initialize_c(ctypes.byref(hcof),ctypes.byref(rhs),ctypes.byref(href))
        if status: raise RuntimeError(f"E6 initialize failed: {status}")
        return hcof.value,rhs.value,href.value

    def trial(self,head_m:float)->float:
        q=ctypes.c_double()
        status=self.lib.pub_gc_e6_swap_trial_c(float(head_m),ctypes.byref(q))
        if status: raise RuntimeError(f"E6 trial failed: {status}")
        return q.value

    def discard(self)->None:
        status=self.lib.pub_gc_e6_swap_discard_c()
        if status: raise RuntimeError(f"E6 discard failed: {status}")

    def state(self)->tuple[int,float,int,float]:
        rev=ctypes.c_int(); t=ctypes.c_double(); n=ctypes.c_int(); v=ctypes.c_double()
        status=self.lib.pub_gc_e6_state_c(ctypes.byref(rev),ctypes.byref(t),ctypes.byref(n),ctypes.byref(v))
        if status: raise RuntimeError(f"E6 state failed: {status}")
        return rev.value,t.value,n.value,v.value

    def drainage_coverage(self)->bool:
        covered=ctypes.c_int()
        status=self.lib.pub_gc_e6_drainage_coverage_c(ctypes.byref(covered))
        if status: raise RuntimeError(f"E6 drainage coverage query failed: {status}")
        return bool(covered.value)

    def predictor(self)->dict[str,float|bool]:
        complete=ctypes.c_int()
        vals=[ctypes.c_double() for _ in range(13)]
        status=self.lib.pub_gc_e6_e1_diagnostics_c(ctypes.byref(complete),*[ctypes.byref(x) for x in vals])
        if status: raise RuntimeError(f"E6 predictor diagnostics failed: {status}")
        keys=[
            "q_bot_predictor_cm_per_day","q_u_cm_per_day","u","h_start_m","h_end_m",
            "bottom_outward_exchange_native","terminal_bottom_outward_flux_native",
            "storage_start_native","storage_end_native","storage_change_native",
            "total_in_native","total_out_native","mass_residual_native",
        ]
        d={k:v.value for k,v in zip(keys,vals)}
        d["mass_complete"]=bool(complete.value)
        return d
