from __future__ import annotations
import ctypes
from pathlib import Path

class Fgc47MixedTopology:
    def __init__(self, library_path: str | Path) -> None:
        self.lib=ctypes.CDLL(str(Path(library_path).resolve()))
        self.lib.fgc47_initialize_c.restype=ctypes.c_int
        self.lib.fgc47_initialize_c.argtypes=[ctypes.POINTER(ctypes.c_double)]*6
        self.lib.fgc47_trial_c.restype=ctypes.c_int
        self.lib.fgc47_trial_c.argtypes=[ctypes.c_double,ctypes.c_double]+[ctypes.POINTER(ctypes.c_double)]*5
        for name in ["fgc47_discard_c","fgc47_swap_preflight_c","fgc47_ledgers_prepare_c","fgc47_ledgers_preflight_c",
                     "fgc47_swap_commit_c","fgc47_ledgers_commit_c","fgc47_abort_prepublication_c"]:
            fn=getattr(self.lib,name); fn.restype=ctypes.c_int; fn.argtypes=[]
        self.lib.fgc47_state_c.restype=ctypes.c_int
        self.lib.fgc47_state_c.argtypes=[
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
        ]

    def initialize(self)->tuple[float,float,float,float,float,float]:
        vals=[ctypes.c_double() for _ in range(6)]
        s=self.lib.fgc47_initialize_c(*[ctypes.byref(v) for v in vals])
        if s: raise RuntimeError(f"F-GC47 initialize failed: {s}")
        return tuple(v.value for v in vals)

    def trial(self,head1:float,head2:float)->tuple[float,float,float,float,float]:
        vals=[ctypes.c_double() for _ in range(5)]
        s=self.lib.fgc47_trial_c(float(head1),float(head2),*[ctypes.byref(v) for v in vals])
        if s: raise RuntimeError(f"F-GC47 trial failed: {s}")
        return tuple(v.value for v in vals)

    def discard(self)->None:
        s=self.lib.fgc47_discard_c()
        if s: raise RuntimeError(f"F-GC47 discard failed: {s}")
    def swap_preflight(self)->bool: return self.lib.fgc47_swap_preflight_c()==0
    def prepare_ledgers(self)->None:
        s=self.lib.fgc47_ledgers_prepare_c()
        if s: raise RuntimeError(f"F-GC47 ledger prepare failed: {s}")
    def ledgers_preflight(self)->bool: return self.lib.fgc47_ledgers_preflight_c()==0
    def commit_swaps(self)->None:
        s=self.lib.fgc47_swap_commit_c()
        if s: raise RuntimeError(f"F-GC47 SWAP commit failed: {s}")
    def commit_ledgers(self)->None:
        s=self.lib.fgc47_ledgers_commit_c()
        if s: raise RuntimeError(f"F-GC47 ledger commit failed: {s}")
    def abort_prepublication(self)->None:
        s=self.lib.fgc47_abort_prepublication_c()
        if s: raise RuntimeError(f"F-GC47 abort failed: {s}")

    def state(self):
        r=[ctypes.c_int() for _ in range(3)]
        t=[ctypes.c_double() for _ in range(3)]
        c=[ctypes.c_int() for _ in range(3)]
        e=[ctypes.c_double() for _ in range(3)]
        s=self.lib.fgc47_state_c(*([ctypes.byref(x) for x in r+t+c+e]))
        if s: raise RuntimeError(f"F-GC47 state failed: {s}")
        return tuple(x.value for x in r+t+c+e)
