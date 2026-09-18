from __future__ import annotations
import ctypes
from pathlib import Path

class Fgc46RealMultiCell:
    def __init__(self, library_path: str | Path) -> None:
        self.lib=ctypes.CDLL(str(Path(library_path).resolve()))
        self.lib.fgc46_initialize_c.restype=ctypes.c_int
        self.lib.fgc46_initialize_c.argtypes=[ctypes.POINTER(ctypes.c_double)]*6
        self.lib.fgc46_trial_c.restype=ctypes.c_int
        self.lib.fgc46_trial_c.argtypes=[ctypes.c_double,ctypes.c_double,ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
        for name in ["fgc46_discard_c","fgc46_swap_preflight_c","fgc46_ledgers_prepare_c","fgc46_ledgers_preflight_c",
                     "fgc46_swap_commit_c","fgc46_ledgers_commit_c","fgc46_abort_prepublication_c"]:
            fn=getattr(self.lib,name); fn.restype=ctypes.c_int; fn.argtypes=[]
        self.lib.fgc46_state_c.restype=ctypes.c_int
        self.lib.fgc46_state_c.argtypes=[
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
        ]

    def initialize(self)->tuple[float,float,float,float,float,float]:
        values=[ctypes.c_double() for _ in range(6)]
        s=self.lib.fgc46_initialize_c(*[ctypes.byref(v) for v in values])
        if s: raise RuntimeError(f"F-GC46 initialize failed: {s}")
        return tuple(v.value for v in values)

    def trial(self,head1_m:float,head2_m:float)->tuple[float,float]:
        q1=ctypes.c_double(); q2=ctypes.c_double()
        s=self.lib.fgc46_trial_c(float(head1_m),float(head2_m),ctypes.byref(q1),ctypes.byref(q2))
        if s: raise RuntimeError(f"F-GC46 trial failed: {s}")
        return q1.value,q2.value

    def discard(self)->None:
        s=self.lib.fgc46_discard_c()
        if s: raise RuntimeError(f"F-GC46 discard failed: {s}")

    def swap_preflight(self)->bool: return self.lib.fgc46_swap_preflight_c()==0
    def prepare_ledgers(self)->None:
        s=self.lib.fgc46_ledgers_prepare_c()
        if s: raise RuntimeError(f"F-GC46 ledger prepare failed: {s}")
    def ledgers_preflight(self)->bool: return self.lib.fgc46_ledgers_preflight_c()==0
    def commit_swaps(self)->None:
        s=self.lib.fgc46_swap_commit_c()
        if s: raise RuntimeError(f"F-GC46 SWAP commit failed: {s}")
    def commit_ledgers(self)->None:
        s=self.lib.fgc46_ledgers_commit_c()
        if s: raise RuntimeError(f"F-GC46 ledger commit failed: {s}")
    def abort_prepublication(self)->None:
        s=self.lib.fgc46_abort_prepublication_c()
        if s: raise RuntimeError(f"F-GC46 abort failed: {s}")

    def state(self)->tuple[int,int,float,float,int,int,float,float]:
        r1=ctypes.c_int(); r2=ctypes.c_int(); t1=ctypes.c_double(); t2=ctypes.c_double()
        c1=ctypes.c_int(); c2=ctypes.c_int(); e1=ctypes.c_double(); e2=ctypes.c_double()
        s=self.lib.fgc46_state_c(ctypes.byref(r1),ctypes.byref(r2),ctypes.byref(t1),ctypes.byref(t2),
                                 ctypes.byref(c1),ctypes.byref(c2),ctypes.byref(e1),ctypes.byref(e2))
        if s: raise RuntimeError(f"F-GC46 state failed: {s}")
        return r1.value,r2.value,t1.value,t2.value,c1.value,c2.value,e1.value,e2.value
