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
        self.lib.fgc44_swap_initialize_configured_c.restype = ctypes.c_int
        self.lib.fgc44_swap_initialize_configured_c.argtypes = [
            ctypes.c_double, ctypes.c_double,
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
        self.lib.fgc44_predictor_run_diagnostics_c.restype=ctypes.c_int
        self.lib.fgc44_predictor_run_diagnostics_c.argtypes=[
            *([ctypes.POINTER(ctypes.c_int)]*14),
            *([ctypes.POINTER(ctypes.c_double)]*3),
        ]
        self.lib.fgc44_committed_profile_observables_c.restype=ctypes.c_int
        self.lib.fgc44_committed_profile_observables_c.argtypes=[ctypes.POINTER(ctypes.c_double)]*4
        self.lib.fgc44_committed_profile_nodes_c.restype=ctypes.c_int
        self.lib.fgc44_committed_profile_nodes_c.argtypes=[
            ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
        ]
        self.lib.fgc44_raw_corrector_diagnostics_c.restype=ctypes.c_int
        self.lib.fgc44_raw_corrector_diagnostics_c.argtypes=[
            ctypes.c_double,
            *([ctypes.POINTER(ctypes.c_int)]*20),
            *([ctypes.POINTER(ctypes.c_double)]*5),
        ]
        self.lib.fgc44_research_interval_c.restype=ctypes.c_int
        self.lib.fgc44_research_interval_c.argtypes=[
            ctypes.c_double,ctypes.c_double,ctypes.c_double,ctypes.c_int
        ]
        self.lib.fgc44_research_last_interval_diagnostics_c.restype=ctypes.c_int
        self.lib.fgc44_research_last_interval_diagnostics_c.argtypes=[
            *([ctypes.POINTER(ctypes.c_int)]*18),
            *([ctypes.POINTER(ctypes.c_double)]*11),
        ]

    def initialize(self) -> tuple[float,float,float]:
        hcof=ctypes.c_double(); rhs=ctypes.c_double(); href=ctypes.c_double()
        status=self.lib.fgc44_swap_initialize_c(ctypes.byref(hcof),ctypes.byref(rhs),ctypes.byref(href))
        if status: raise RuntimeError(f"SWAP initialize failed: {status}")
        return hcof.value,rhs.value,href.value

    def try_initialize_configured(self, duration_day: float, predictor_qbot_cm_per_day: float) -> tuple[int,float,float,float]:
        hcof=ctypes.c_double(); rhs=ctypes.c_double(); href=ctypes.c_double()
        status=self.lib.fgc44_swap_initialize_configured_c(
            float(duration_day),float(predictor_qbot_cm_per_day),
            ctypes.byref(hcof),ctypes.byref(rhs),ctypes.byref(href)
        )
        return int(status),hcof.value,rhs.value,href.value

    def initialize_configured(self, duration_day: float, predictor_qbot_cm_per_day: float) -> tuple[float,float,float]:
        status,hcof,rhs,href=self.try_initialize_configured(duration_day,predictor_qbot_cm_per_day)
        if status:
            raise RuntimeError(f"configured SWAP initialize failed: {status}")
        return hcof,rhs,href

    def try_trial(self, head_m: float) -> tuple[int,float]:
        q=ctypes.c_double()
        status=self.lib.fgc44_swap_trial_c(float(head_m),ctypes.byref(q))
        return int(status),q.value

    def trial(self, head_m: float) -> float:
        status,q=self.try_trial(head_m)
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

    def committed_profile_observables(self) -> dict[str,float]:
        v=[ctypes.c_double() for _ in range(4)]
        status=self.lib.fgc44_committed_profile_observables_c(*[ctypes.byref(x) for x in v])
        if status: raise RuntimeError(f"committed profile diagnostics failed: {status}")
        return dict(zip(["profile_water_cm","root_water_cm","distribution_moment_cm","groundwater_level_cm"],[x.value for x in v]))

    def committed_profile_nodes(self) -> dict[str,int|list[float]]:
        nmax=64
        n=ctypes.c_int()
        arrays=[(ctypes.c_double*nmax)() for _ in range(4)]
        status=self.lib.fgc44_committed_profile_nodes_c(
            ctypes.byref(n),arrays[0],arrays[1],arrays[2],arrays[3]
        )
        if status: raise RuntimeError(f"committed node-profile diagnostics failed: {status}")
        if n.value < 0 or n.value > nmax:
            raise RuntimeError(f"invalid committed node count: {n.value}")
        keys=["pressure_head_native","water_content","z_native","dz_native"]
        result={"active_nodes":n.value}
        result.update({k:[float(a[i]) for i in range(n.value)] for k,a in zip(keys,arrays)})
        return result

    def predictor_run_diagnostics(self) -> dict[str,int|float|bool]:
        ints=[ctypes.c_int() for _ in range(14)]
        reals=[ctypes.c_double() for _ in range(3)]
        status=self.lib.fgc44_predictor_run_diagnostics_c(
            *[ctypes.byref(v) for v in ints],
            *[ctypes.byref(v) for v in reals],
        )
        if status:
            raise RuntimeError(f"predictor diagnostics query failed: {status}")
        names=[
            "available","result_status","completed","direction_available",
            "transaction_calls","accepted_substeps","attempts","retries",
            "trial_rollbacks","solver_rejections","temporal_rejections",
            "temporal_unavailable_rejections","mass_rejections","internal_retries",
        ]
        result={k:v.value for k,v in zip(names,ints)}
        result["available"]=bool(result["available"])
        result["completed"]=bool(result["completed"])
        result["direction_available"]=bool(result["direction_available"])
        result["max_temporal_indicator"]=reals[0].value
        result["min_accepted_substep_duration"]=reals[1].value
        result["max_accepted_substep_duration"]=reals[2].value
        return result

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

    def raw_corrector_diagnostics(self, head_m: float) -> dict[str,int|float|bool]:
        ints=[ctypes.c_int() for _ in range(20)]
        reals=[ctypes.c_double() for _ in range(5)]
        status=self.lib.fgc44_raw_corrector_diagnostics_c(
            float(head_m),
            *[ctypes.byref(v) for v in ints],
            *[ctypes.byref(v) for v in reals],
        )
        if status:
            raise RuntimeError(f"raw corrector diagnostics failed: {status}")
        names=[
            "forcing_status","result_status","completed","candidate_ready",
            "bottom_available","bottom_finite","terminal_finite",
            "requested_match","completed_match","interval_match",
            "transaction_calls","accepted_substeps","attempts","retries",
            "trial_rollbacks","solver_rejections","temporal_rejections",
            "temporal_unavailable_rejections","mass_rejections","internal_retries",
        ]
        result={k:v.value for k,v in zip(names,ints)}
        for key in [
            "completed","candidate_ready","bottom_available","bottom_finite",
            "terminal_finite","requested_match","completed_match","interval_match",
        ]:
            result[key]=bool(result[key])
        result["min_substep"]=reals[0].value
        result["max_substep"]=reals[1].value
        result["completed_t"]=reals[2].value
        result["candidate_t0"]=reals[3].value
        result["candidate_t1"]=reals[4].value
        return result


    def research_interval(self, top_flux_cm_per_day: float, head_m: float, duration_day: float, *, commit: bool) -> tuple[int,dict[str,int|float|bool]]:
        status=self.lib.fgc44_research_interval_c(
            float(top_flux_cm_per_day),float(head_m),float(duration_day),int(bool(commit))
        )
        return int(status),self.research_last_interval_diagnostics()

    def research_last_interval_diagnostics(self) -> dict[str,int|float|bool]:
        ints=[ctypes.c_int() for _ in range(18)]
        reals=[ctypes.c_double() for _ in range(11)]
        status=self.lib.fgc44_research_last_interval_diagnostics_c(
            *[ctypes.byref(v) for v in ints],
            *[ctypes.byref(v) for v in reals],
        )
        if status:
            raise RuntimeError(f"RZM06A research diagnostics unavailable: {status}")
        ikeys=[
            "available","call_status","forcing_status","result_status","completed","candidate_ready",
            "mass_complete","committed","transaction_calls","accepted_substeps","attempts","retries",
            "trial_rollbacks","solver_rejections","temporal_rejections",
            "temporal_unavailable_rejections","mass_rejections","internal_retries",
        ]
        rkeys=[
            "requested_top_flux_cm_per_day","requested_head_m","duration_day","t0_day","t1_day",
            "materialized_top_flux_cm_per_day","materialized_bottom_head_cm",
            "bottom_outward_exchange_native","terminal_bottom_outward_flux_native",
            "mass_residual_native","q_swap_m_per_s",
        ]
        result={k:v.value for k,v in zip(ikeys,ints)}
        for key in ["available","completed","candidate_ready","mass_complete","committed"]:
            result[key]=bool(result[key])
        result.update({k:v.value for k,v in zip(rkeys,reals)})
        return result
