from __future__ import annotations

import ctypes
from pathlib import Path

class Map09ActiveDrainageSwap:
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
        self.lib.pub_gc_e6_corrector_diagnostics_c.restype=ctypes.c_int
        self.lib.pub_gc_e6_corrector_diagnostics_c.argtypes=[
            ctypes.c_double,
            *([ctypes.POINTER(ctypes.c_int)]*14),
            *([ctypes.POINTER(ctypes.c_double)]*4),
        ]
        self.lib.pub_gc_e6_corrector_mass_diagnostics_c.restype=ctypes.c_int
        self.lib.pub_gc_e6_corrector_mass_diagnostics_c.argtypes=[
            ctypes.c_double,
            *([ctypes.POINTER(ctypes.c_int)]*4),
            *([ctypes.POINTER(ctypes.c_double)]*5),
        ]

    def initialize(self)->tuple[float,float,float]:
        hcof=ctypes.c_double(); rhs=ctypes.c_double(); href=ctypes.c_double()
        status=self.lib.pub_gc_e6_swap_initialize_c(ctypes.byref(hcof),ctypes.byref(rhs),ctypes.byref(href))
        if status: raise RuntimeError(f"E6 initialize failed: {status}")
        return hcof.value,rhs.value,href.value

    def try_trial(self,head_m:float)->tuple[int,float]:
        q=ctypes.c_double()
        status=self.lib.pub_gc_e6_swap_trial_c(float(head_m),ctypes.byref(q))
        return int(status),q.value

    def trial(self,head_m:float)->float:
        status,q=self.try_trial(head_m)
        if status: raise RuntimeError(f"E6 trial failed: {status}")
        return q

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

    def corrector_mass_diagnostics(self,head_m:float)->dict[str,float|int|bool]:
        ints=[ctypes.c_int() for _ in range(4)]
        vals=[ctypes.c_double() for _ in range(5)]
        status=self.lib.pub_gc_e6_corrector_mass_diagnostics_c(
            float(head_m),*[ctypes.byref(x) for x in ints],*[ctypes.byref(x) for x in vals]
        )
        if status: raise RuntimeError(f"E6 corrector mass diagnostics failed: {status}")
        ikeys=["result_status","completed","candidate_ready","mass_complete"]
        d={k:int(v.value) for k,v in zip(ikeys,ints)}
        d["completed"]=bool(d["completed"])
        d["candidate_ready"]=bool(d["candidate_ready"])
        d["mass_complete"]=bool(d["mass_complete"])
        for k,v in zip(
            ["storage_change_native","total_in_native","total_out_native","bottom_outward_exchange_native","mass_residual_native"],
            vals,
        ):
            d[k]=v.value
        return d

    def corrector_diagnostics(self,head_m:float)->dict[str,float|int|bool]:
        ints=[ctypes.c_int() for _ in range(14)]
        vals=[ctypes.c_double() for _ in range(4)]
        status=self.lib.pub_gc_e6_corrector_diagnostics_c(
            float(head_m),*[ctypes.byref(x) for x in ints],*[ctypes.byref(x) for x in vals]
        )
        if status: raise RuntimeError(f"E6 corrector diagnostics failed: {status}")
        ikeys=[
            "result_status","completed","candidate_ready","transaction_calls","accepted_substeps","attempts","retries",
            "trial_rollbacks","solver_rejections","temporal_rejections","temporal_unavailable_rejections",
            "mass_rejections","internal_retries","mass_complete",
        ]
        d={k:int(v.value) for k,v in zip(ikeys,ints)}
        d["completed"]=bool(d["completed"]); d["candidate_ready"]=bool(d["candidate_ready"]); d["mass_complete"]=bool(d["mass_complete"])
        for k,v in zip(["mass_residual_native","max_temporal_indicator","min_accepted_substep_day","max_accepted_substep_day"],vals):
            d[k]=v.value
        return d
