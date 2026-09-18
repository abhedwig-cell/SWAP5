from __future__ import annotations
import ctypes
from pathlib import Path

class Fgc45RealMultiSwap:
    def __init__(self, library_path: str | Path) -> None:
        self.lib=ctypes.CDLL(str(Path(library_path).resolve()))
        self.lib.fgc45_multiswap_initialize_c.restype=ctypes.c_int
        self.lib.fgc45_multiswap_initialize_c.argtypes=[
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)
        ]
        self.lib.fgc45_multiswap_predictor_meta_c.restype=ctypes.c_int
        self.lib.fgc45_multiswap_predictor_meta_c.argtypes=[ctypes.POINTER(ctypes.c_double)]*6
        self.lib.fgc45_multiswap_trial_c.restype=ctypes.c_int
        self.lib.fgc45_multiswap_trial_c.argtypes=[ctypes.c_double,ctypes.POINTER(ctypes.c_double)]
        for name in [
            "fgc45_multiswap_discard_c","fgc45_multiswap_preflight_c","fgc45_multiswap_ledger_prepare_c",
            "fgc45_multiswap_ledger_preflight_c","fgc45_multiswap_commit_c","fgc45_multiswap_ledger_commit_c",
            "fgc45_multiswap_abort_prepublication_c",
        ]:
            fn=getattr(self.lib,name); fn.restype=ctypes.c_int; fn.argtypes=[]
        self.lib.fgc45_multiswap_state_c.restype=ctypes.c_int
        self.lib.fgc45_multiswap_state_c.argtypes=[
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_double),
        ]

    def initialize(self)->tuple[float,float,float]:
        hcof=ctypes.c_double(); rhs=ctypes.c_double(); href=ctypes.c_double()
        status=self.lib.fgc45_multiswap_initialize_c(ctypes.byref(hcof),ctypes.byref(rhs),ctypes.byref(href))
        if status: raise RuntimeError(f"MultiSWAP initialize failed: {status}")
        return hcof.value,rhs.value,href.value

    def predictor_meta(self)->tuple[float,float,float,float,float,float]:
        values=[ctypes.c_double() for _ in range(6)]
        status=self.lib.fgc45_multiswap_predictor_meta_c(*[ctypes.byref(v) for v in values])
        if status: raise RuntimeError(f"MultiSWAP predictor metadata failed: {status}")
        return tuple(v.value for v in values)

    def trial(self,head_m:float)->float:
        q=ctypes.c_double()
        status=self.lib.fgc45_multiswap_trial_c(float(head_m),ctypes.byref(q))
        if status: raise RuntimeError(f"MultiSWAP corrector trial failed: {status}")
        return q.value

    def discard(self)->None:
        status=self.lib.fgc45_multiswap_discard_c()
        if status: raise RuntimeError(f"MultiSWAP discard failed: {status}")

    def swap_preflight(self)->bool:
        return self.lib.fgc45_multiswap_preflight_c()==0

    def prepare_ledgers(self)->None:
        status=self.lib.fgc45_multiswap_ledger_prepare_c()
        if status: raise RuntimeError(f"MultiSWAP ledger prepare failed: {status}")

    def ledger_preflight(self)->bool:
        return self.lib.fgc45_multiswap_ledger_preflight_c()==0

    def commit_swap(self)->None:
        status=self.lib.fgc45_multiswap_commit_c()
        if status: raise RuntimeError(f"MultiSWAP SWAP commit failed: {status}")

    def commit_ledgers(self)->None:
        status=self.lib.fgc45_multiswap_ledger_commit_c()
        if status: raise RuntimeError(f"MultiSWAP ledger commit failed: {status}")

    def abort_prepublication(self)->None:
        status=self.lib.fgc45_multiswap_abort_prepublication_c()
        if status: raise RuntimeError(f"MultiSWAP prepublication abort failed: {status}")

    def state(self)->tuple[int,int,float,float,int,int,float]:
        r1=ctypes.c_int(); r2=ctypes.c_int(); t1=ctypes.c_double(); t2=ctypes.c_double()
        c1=ctypes.c_int(); c2=ctypes.c_int(); total=ctypes.c_double()
        status=self.lib.fgc45_multiswap_state_c(
            ctypes.byref(r1),ctypes.byref(r2),ctypes.byref(t1),ctypes.byref(t2),
            ctypes.byref(c1),ctypes.byref(c2),ctypes.byref(total)
        )
        if status: raise RuntimeError(f"MultiSWAP state query failed: {status}")
        return r1.value,r2.value,t1.value,t2.value,c1.value,c2.value,total.value
