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
        self.lib.pub_gc_e3_set_duration_c.restype=ctypes.c_int
        self.lib.pub_gc_e3_set_duration_c.argtypes=[ctypes.c_double]
        self.lib.pub_gc_e3_begin_next_window_c.restype=ctypes.c_int
        self.lib.pub_gc_e3_begin_next_window_c.argtypes=[ctypes.c_double]
        self.lib.pub_gc_e3_committed_storage_c.restype=ctypes.c_int
        self.lib.pub_gc_e3_committed_storage_c.argtypes=[ctypes.POINTER(ctypes.c_double)]
        self.lib.pub_gc_e3_init_stage_c.restype=ctypes.c_int
        self.lib.pub_gc_e3_init_stage_c.argtypes=[ctypes.POINTER(ctypes.c_int)]
        self.lib.pub_gc_e3_diagnostic_trial_c.restype=ctypes.c_int
        self.lib.pub_gc_e3_diagnostic_trial_c.argtypes=[
            ctypes.c_double,
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_double),
        ]
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

    def init_stage(self) -> int:
        stage=ctypes.c_int()
        status=self.lib.pub_gc_e3_init_stage_c(ctypes.byref(stage))
        if status: raise RuntimeError(f"E3 init-stage query failed: {status}")
        return stage.value

    def initialize_window(self, duration_day: float) -> tuple[float,float,float]:
        status=self.lib.pub_gc_e3_set_duration_c(float(duration_day))
        if status: raise RuntimeError(f"E3 duration setup failed: {status}")
        try:
            return self.initialize()
        except RuntimeError as exc:
            raise RuntimeError(f"{exc}; init_stage={self.init_stage()}") from exc

    def begin_next_window(self, duration_day: float) -> None:
        status=self.lib.pub_gc_e3_begin_next_window_c(float(duration_day))
        if status: raise RuntimeError(f"E3 next-window origin capture failed: {status}")

    def committed_storage(self) -> float:
        value=ctypes.c_double()
        status=self.lib.pub_gc_e3_committed_storage_c(ctypes.byref(value))
        if status: raise RuntimeError(f"E3 committed-storage query failed: {status}")
        return value.value

    def diagnostic_trial(self, head_m: float) -> dict[str,int|float|bool]:
        kernel_status=ctypes.c_int(); completed=ctypes.c_int(); retries=ctypes.c_int()
        solver=ctypes.c_int(); temporal=ctypes.c_int(); mass=ctypes.c_int(); substeps=ctypes.c_int()
        exchange=ctypes.c_double()
        status=self.lib.pub_gc_e3_diagnostic_trial_c(
            float(head_m),ctypes.byref(kernel_status),ctypes.byref(completed),
            ctypes.byref(retries),ctypes.byref(solver),ctypes.byref(temporal),
            ctypes.byref(mass),ctypes.byref(substeps),ctypes.byref(exchange)
        )
        if status: raise RuntimeError(f"E3 diagnostic trial call failed: {status}")
        return {
            "kernel_status":kernel_status.value,
            "completed":bool(completed.value),
            "retries":retries.value,
            "solver_rejections":solver.value,
            "temporal_rejections":temporal.value,
            "mass_rejections":mass.value,
            "accepted_substeps":substeps.value,
            "bottom_exchange_cm":exchange.value,
        }

    def trial_status(self, head_m: float) -> tuple[int,float]:
        q=ctypes.c_double()
        status=self.lib.fgc44_swap_trial_c(float(head_m),ctypes.byref(q))
        return int(status),q.value

    def trial(self, head_m: float) -> float:
        status,q=self.trial_status(head_m)
        if status: raise RuntimeError(f"SWAP corrector trial failed: {status}")
        return q

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
