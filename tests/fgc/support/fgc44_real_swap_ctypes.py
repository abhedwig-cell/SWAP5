from __future__ import annotations
import ctypes
from pathlib import Path

class Fgc44RealSwap:
    def __init__(self, library_path: str | Path) -> None:
        self.lib = ctypes.CDLL(str(Path(library_path).resolve()))
        self.lib.fgc44_swap_initialize_c.restype = ctypes.c_int
        self.lib.fgc44_swap_initialize_c.argtypes = [
            ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double)
        ]
        self.lib.fgc44_swap_trial_c.restype = ctypes.c_int
        self.lib.fgc44_swap_trial_c.argtypes = [ctypes.c_double, ctypes.POINTER(ctypes.c_double)]
        for name in [
            "fgc44_swap_discard_c","fgc44_swap_preflight_c","fgc44_ledger_prepare_c",
            "fgc44_ledger_preflight_c","fgc44_swap_commit_c","fgc44_ledger_commit_c",
            "fgc44_abort_prepublication_c",
        ]:
            fn=getattr(self.lib,name); fn.restype=ctypes.c_int; fn.argtypes=[]
        self.lib.fgc44_state_c.restype=ctypes.c_int
        self.lib.fgc44_state_c.argtypes=[
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_double)
        ]
        self.lib.fgc44_e1_diagnostics_c.restype=ctypes.c_int
        self.lib.fgc44_e1_diagnostics_c.argtypes=[
            ctypes.POINTER(ctypes.c_int),
            *([ctypes.POINTER(ctypes.c_double)]*13),
        ]
        self.lib.fgc44_last_trial_diagnostics_c.restype=ctypes.c_int
        self.lib.fgc44_last_trial_diagnostics_c.argtypes=[
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)
        ]

    def initialize(self) -> tuple[float,float,float]:
        hcof=ctypes.c_double(); rhs=ctypes.c_double(); href=ctypes.c_double()
        status=self.lib.fgc44_swap_initialize_c(ctypes.byref(hcof),ctypes.byref(rhs),ctypes.byref(href))
        if status: raise RuntimeError(f"SWAP initialize failed: {status}")
        return hcof.value,rhs.value,href.value

    def trial(self, head_m: float) -> float:
        q=ctypes.c_double()
        status=self.lib.fgc44_swap_trial_c(float(head_m),ctypes.byref(q))
        if status: raise RuntimeError(f"SWAP corrector trial failed: {status}")
        return q.value

    def discard(self) -> None:
        status=self.lib.fgc44_swap_discard_c()
        if status: raise RuntimeError(f"SWAP discard failed: {status}")

    def swap_preflight(self) -> bool:
        return self.lib.fgc44_swap_preflight_c()==0

    def prepare_ledger(self) -> None:
        status=self.lib.fgc44_ledger_prepare_c()
        if status: raise RuntimeError(f"ledger prepare failed: {status}")

    def ledger_preflight(self) -> bool:
        return self.lib.fgc44_ledger_preflight_c()==0

    def commit_swap(self) -> None:
        status=self.lib.fgc44_swap_commit_c()
        if status: raise RuntimeError(f"SWAP commit failed: {status}")

    def commit_ledger(self) -> None:
        status=self.lib.fgc44_ledger_commit_c()
        if status: raise RuntimeError(f"ledger commit failed: {status}")

    def abort_prepublication(self) -> None:
        status=self.lib.fgc44_abort_prepublication_c()
        if status: raise RuntimeError(f"prepublication abort failed: {status}")

    def state(self) -> tuple[int,float,int,float]:
        revision=ctypes.c_int(); time=ctypes.c_double(); count=ctypes.c_int(); exchange=ctypes.c_double()
        status=self.lib.fgc44_state_c(ctypes.byref(revision),ctypes.byref(time),ctypes.byref(count),ctypes.byref(exchange))
        if status: raise RuntimeError(f"state query failed: {status}")
        return revision.value,time.value,count.value,exchange.value

    def e1_diagnostics(self) -> dict[str,float|bool]:
        mass_complete=ctypes.c_int()
        values=[ctypes.c_double() for _ in range(13)]
        status=self.lib.fgc44_e1_diagnostics_c(
            ctypes.byref(mass_complete), *[ctypes.byref(v) for v in values]
        )
        if status: raise RuntimeError(f"E1 diagnostics query failed: {status}")
        keys=[
            "q_bot_predictor_cm_per_day","q_u_cm_per_day","u",
            "h_start_m","h_end_m","bottom_outward_exchange_native",
            "terminal_bottom_outward_flux_native","storage_start_native",
            "storage_end_native","storage_change_native","total_in_native",
            "total_out_native","mass_residual_native",
        ]
        result={k:v.value for k,v in zip(keys,values)}
        result["mass_complete"]=bool(mass_complete.value)
        return result

    def last_trial_diagnostics(self) -> tuple[float,float]:
        q=ctypes.c_double(); exchange=ctypes.c_double()
        status=self.lib.fgc44_last_trial_diagnostics_c(ctypes.byref(q),ctypes.byref(exchange))
        if status: raise RuntimeError(f"last-trial diagnostics query failed: {status}")
        return q.value,exchange.value
