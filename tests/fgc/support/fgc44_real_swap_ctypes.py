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
        self.lib.fgc44_raw_corrector_diagnostics_c.restype=ctypes.c_int
        self.lib.fgc44_raw_corrector_diagnostics_c.argtypes=[
            ctypes.c_double,
            *([ctypes.POINTER(ctypes.c_int)]*20),
            *([ctypes.POINTER(ctypes.c_double)]*5),
        ]
        self.lib.fgc44_g14_fused_observation_c.restype=ctypes.c_int
        self.lib.fgc44_g14_fused_observation_c.argtypes=[
            ctypes.c_double,
            *([ctypes.POINTER(ctypes.c_int)]*14),
            *([ctypes.POINTER(ctypes.c_double)]*3),
        ]
        self.lib.fgc44_g14_fused_run_count_c.restype=ctypes.c_int
        self.lib.fgc44_g14_fused_run_count_c.argtypes=[ctypes.POINTER(ctypes.c_int)]
        self.lib.fgc44_g15_last_trial_observation_c.restype=ctypes.c_int
        self.lib.fgc44_g15_last_trial_observation_c.argtypes=[
            *([ctypes.POINTER(ctypes.c_int)]*16),
            *([ctypes.POINTER(ctypes.c_double)]*3),
        ]
        self.lib.fgc44_g15_trial_call_count_c.restype=ctypes.c_int
        self.lib.fgc44_g15_trial_call_count_c.argtypes=[ctypes.POINTER(ctypes.c_int)]
        self.lib.fgc44_g15_has_live_candidate_c.restype=ctypes.c_int
        self.lib.fgc44_g15_has_live_candidate_c.argtypes=[ctypes.POINTER(ctypes.c_int)]
        self.lib.fgc44_g16_begin_session_c.restype=ctypes.c_int
        self.lib.fgc44_g16_begin_session_c.argtypes=[]
        self.lib.fgc44_g16_observe_head_c.restype=ctypes.c_int
        self.lib.fgc44_g16_observe_head_c.argtypes=[
            ctypes.c_double,
            *([ctypes.POINTER(ctypes.c_int)]*16),
            *([ctypes.POINTER(ctypes.c_double)]*3),
        ]
        self.lib.fgc44_g16_counts_c.restype=ctypes.c_int
        self.lib.fgc44_g16_counts_c.argtypes=[*([ctypes.POINTER(ctypes.c_int)]*4)]
        self.lib.fgc44_g16_end_session_c.restype=ctypes.c_int
        self.lib.fgc44_g16_end_session_c.argtypes=[]
        self.lib.fgc44_g21g_backend_observation_c.restype=ctypes.c_int
        self.lib.fgc44_g21g_backend_observation_c.argtypes=[
            *([ctypes.POINTER(ctypes.c_int)]*16),
            *([ctypes.POINTER(ctypes.c_double)]*3),
        ]
        self.lib.fgc44_g21h_isolated_attempt_c.restype=ctypes.c_int
        self.lib.fgc44_g21h_isolated_attempt_c.argtypes=[
            ctypes.c_double,ctypes.c_double,
            *([ctypes.POINTER(ctypes.c_int)]*10),
            ctypes.POINTER(ctypes.c_double),
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

    def g15_trial_call_count(self) -> int:
        value=ctypes.c_int()
        status=self.lib.fgc44_g15_trial_call_count_c(ctypes.byref(value))
        if status:
            raise RuntimeError(f"G15 trial-call count query failed: {status}")
        return int(value.value)

    def g15_has_live_candidate(self) -> bool:
        value=ctypes.c_int()
        status=self.lib.fgc44_g15_has_live_candidate_c(ctypes.byref(value))
        if status:
            raise RuntimeError(f"G15 live-candidate query failed: {status}")
        return bool(value.value)

    def g15_last_trial_observation(self) -> dict[str,int|float|bool]:
        ints=[ctypes.c_int() for _ in range(16)]
        reals=[ctypes.c_double() for _ in range(3)]
        status=self.lib.fgc44_g15_last_trial_observation_c(
            *[ctypes.byref(v) for v in ints],
            *[ctypes.byref(v) for v in reals],
        )
        if status:
            raise RuntimeError(f"G15 observation query failed: {status}")
        names=[
            "available","participant_status","q_available","result_status",
            "completed","candidate_ready","transaction_calls","accepted_substeps",
            "attempts","retries","trial_rollbacks","solver_rejections",
            "temporal_rejections","temporal_unavailable_rejections",
            "mass_rejections","internal_retries",
        ]
        result={k:v.value for k,v in zip(names,ints)}
        for key in ["available","q_available","completed","candidate_ready"]:
            result[key]=bool(result[key])
        result["q_swap_m_per_s"]=reals[0].value
        result["min_substep"]=reals[1].value
        result["max_substep"]=reals[2].value
        return result

    def g16_begin_session(self) -> None:
        status=self.lib.fgc44_g16_begin_session_c()
        if status:
            raise RuntimeError(f"G16 begin session failed: {status}")

    def g16_observe_head(self, head_m: float) -> dict[str,int|float|bool]:
        ints=[ctypes.c_int() for _ in range(16)]
        reals=[ctypes.c_double() for _ in range(3)]
        status=self.lib.fgc44_g16_observe_head_c(
            float(head_m),
            *[ctypes.byref(v) for v in ints],
            *[ctypes.byref(v) for v in reals],
        )
        if status:
            raise RuntimeError(f"G16 observe head failed: {status}")
        names=[
            "available","participant_status","q_available","result_status",
            "completed","candidate_ready","transaction_calls","accepted_substeps",
            "attempts","retries","trial_rollbacks","solver_rejections",
            "temporal_rejections","temporal_unavailable_rejections",
            "mass_rejections","internal_retries",
        ]
        result={k:v.value for k,v in zip(names,ints)}
        for key in ["available","q_available","completed","candidate_ready"]:
            result[key]=bool(result[key])
        result["q_swap_m_per_s"]=reals[0].value
        result["min_substep"]=reals[1].value
        result["max_substep"]=reals[2].value
        return result

    def g16_counts(self) -> tuple[int,int,int,int]:
        values=[ctypes.c_int() for _ in range(4)]
        status=self.lib.fgc44_g16_counts_c(*[ctypes.byref(v) for v in values])
        if status:
            raise RuntimeError(f"G16 count query failed: {status}")
        return tuple(int(v.value) for v in values)

    def g16_end_session(self) -> None:
        status=self.lib.fgc44_g16_end_session_c()
        if status:
            raise RuntimeError(f"G16 end session failed: {status}")


    def g21g_backend_observation(self) -> dict[str,int|float|bool]:
        ints=[ctypes.c_int() for _ in range(16)]
        reals=[ctypes.c_double() for _ in range(3)]
        status=self.lib.fgc44_g21g_backend_observation_c(
            *[ctypes.byref(v) for v in ints],
            *[ctypes.byref(v) for v in reals],
        )
        if status:
            raise RuntimeError(f"G21G backend observation failed: {status}")
        names=[
            "solver_executed","solver_status","nonlinear_iterations","jacobian_builds",
            "linear_solves","backtracking_attempts","alternative_solver_calls","internal_retries",
            "temporal_indicator_enabled","temporal_previous_derivative_available",
            "temporal_current_derivative_available","temporal_indicator_status",
            "temporal_indicator_available","temporal_head_budget_supplied",
            "temporal_head_budget_valid","temporal_certificate_available",
        ]
        result={k:int(v.value) for k,v in zip(names,ints)}
        for key in [
            "solver_executed","temporal_indicator_enabled","temporal_previous_derivative_available",
            "temporal_current_derivative_available","temporal_indicator_available",
            "temporal_head_budget_supplied","temporal_head_budget_valid","temporal_certificate_available",
        ]:
            result[key]=bool(result[key])
        result["temporal_head_inf_bound"]=reals[0].value
        result["temporal_head_budget"]=reals[1].value
        result["temporal_normalized_indicator"]=reals[2].value
        return result

    def g21h_isolated_attempt(self,head_m:float,duration_day:float) -> dict[str,int|float|bool]:
        ints=[ctypes.c_int() for _ in range(10)]
        completed_t=ctypes.c_double()
        status=self.lib.fgc44_g21h_isolated_attempt_c(
            ctypes.c_double(head_m),ctypes.c_double(duration_day),
            *[ctypes.byref(v) for v in ints],ctypes.byref(completed_t),
        )
        if status:
            raise RuntimeError(f"G21H isolated attempt failed: {status}")
        names=[
            "result_status","completed","candidate_ready","attempts","retries",
            "solver_rejections","temporal_rejections","temporal_unavailable_rejections",
            "mass_rejections","internal_retries",
        ]
        out={k:int(v.value) for k,v in zip(names,ints)}
        out["completed"]=bool(out["completed"])
        out["candidate_ready"]=bool(out["candidate_ready"])
        out["completed_t"]=completed_t.value
        return out

    def g14_fused_run_count(self) -> int:
        value=ctypes.c_int()
        status=self.lib.fgc44_g14_fused_run_count_c(ctypes.byref(value))
        if status:
            raise RuntimeError(f"G14 fused run-count query failed: {status}")
        return int(value.value)

    def g14_fused_observation(self, head_m: float) -> dict[str,int|float|bool]:
        ints=[ctypes.c_int() for _ in range(14)]
        reals=[ctypes.c_double() for _ in range(3)]
        status=self.lib.fgc44_g14_fused_observation_c(
            float(head_m),
            *[ctypes.byref(v) for v in ints],
            *[ctypes.byref(v) for v in reals],
        )
        if status:
            raise RuntimeError(f"G14 fused observation failed: {status}")
        names=[
            "participant_status","result_status","completed","candidate_ready",
            "transaction_calls","accepted_substeps","attempts","retries",
            "trial_rollbacks","solver_rejections","temporal_rejections",
            "temporal_unavailable_rejections","mass_rejections","internal_retries",
        ]
        result={k:v.value for k,v in zip(names,ints)}
        result["completed"]=bool(result["completed"])
        result["candidate_ready"]=bool(result["candidate_ready"])
        result["q_swap_m_per_s"]=reals[0].value
        result["min_substep"]=reals[1].value
        result["max_substep"]=reals[2].value
        return result

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
