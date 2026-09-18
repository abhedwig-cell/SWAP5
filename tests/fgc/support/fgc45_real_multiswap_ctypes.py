from __future__ import annotations
import ctypes
from pathlib import Path

class Fgc45RealMultiSwap:
    def __init__(self, library_path: str | Path) -> None:
        self.lib=ctypes.CDLL(str(Path(library_path).resolve()))
        self.lib.fgc45_initialize_c.restype=ctypes.c_int
        self.lib.fgc45_initialize_c.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
        self.lib.fgc45_trial_c.restype=ctypes.c_int
        self.lib.fgc45_trial_c.argtypes=[ctypes.c_double,ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
        for name in ["fgc45_discard_c","fgc45_swap_preflight_c","fgc45_ledgers_prepare_c","fgc45_ledgers_preflight_c",
                     "fgc45_swap_commit_c","fgc45_ledgers_commit_c","fgc45_abort_prepublication_c"]:
            fn=getattr(self.lib,name); fn.restype=ctypes.c_int; fn.argtypes=[]
        self.lib.fgc45_state_c.restype=ctypes.c_int
        self.lib.fgc45_state_c.argtypes=[
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
        ]

    def initialize(self)->tuple[float,float,float]:
        hcof=ctypes.c_double(); rhs=ctypes.c_double(); href=ctypes.c_double()
        s=self.lib.fgc45_initialize_c(ctypes.byref(hcof),ctypes.byref(rhs),ctypes.byref(href))
        if s: raise RuntimeError(f"F-GC45 initialize failed: {s}")
        return hcof.value,rhs.value,href.value

    def trial(self,head_m:float)->tuple[float,float,float]:
        qw=ctypes.c_double(); q1=ctypes.c_double(); q2=ctypes.c_double()
        s=self.lib.fgc45_trial_c(float(head_m),ctypes.byref(qw),ctypes.byref(q1),ctypes.byref(q2))
        if s: raise RuntimeError(f"F-GC45 trial failed: {s}")
        return qw.value,q1.value,q2.value

    def discard(self)->None:
        s=self.lib.fgc45_discard_c()
        if s: raise RuntimeError(f"F-GC45 discard failed: {s}")

    def swap_preflight(self)->bool: return self.lib.fgc45_swap_preflight_c()==0
    def prepare_ledgers(self)->None:
        s=self.lib.fgc45_ledgers_prepare_c()
        if s: raise RuntimeError(f"F-GC45 ledger prepare failed: {s}")
    def ledgers_preflight(self)->bool: return self.lib.fgc45_ledgers_preflight_c()==0
    def commit_swaps(self)->None:
        s=self.lib.fgc45_swap_commit_c()
        if s: raise RuntimeError(f"F-GC45 SWAP commit failed: {s}")
    def commit_ledgers(self)->None:
        s=self.lib.fgc45_ledgers_commit_c()
        if s: raise RuntimeError(f"F-GC45 ledger commit failed: {s}")
    def abort_prepublication(self)->None:
        s=self.lib.fgc45_abort_prepublication_c()
        if s: raise RuntimeError(f"F-GC45 abort failed: {s}")

    def state(self)->tuple[int,int,float,float,int,int,float,float]:
        r1=ctypes.c_int(); r2=ctypes.c_int(); t1=ctypes.c_double(); t2=ctypes.c_double()
        c1=ctypes.c_int(); c2=ctypes.c_int(); e1=ctypes.c_double(); e2=ctypes.c_double()
        s=self.lib.fgc45_state_c(ctypes.byref(r1),ctypes.byref(r2),ctypes.byref(t1),ctypes.byref(t2),
                                 ctypes.byref(c1),ctypes.byref(c2),ctypes.byref(e1),ctypes.byref(e2))
        if s: raise RuntimeError(f"F-GC45 state failed: {s}")
        return r1.value,r2.value,t1.value,t2.value,c1.value,c2.value,e1.value,e2.value
