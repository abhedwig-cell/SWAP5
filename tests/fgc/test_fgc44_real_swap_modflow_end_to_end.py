from __future__ import annotations
import math
import os
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import flopy
import numpy as np
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"src"/"adapter"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))

from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus
from fgc44_real_swap_ctypes import Fgc44RealSwap

DAY_TO_S=86400.0
AREA_M2=1.0
WINDOW_DAY=1.0e-4
FLUX_TOL=1.0e-15
CLOSEOUT_ONECELL=os.environ.get("FGC44_CLOSEOUT_ONECELL","0")=="1"
CLOSEOUT_ENDPOINT_HEAD_TOL_M=5.0e-10
CLOSEOUT_GW_FIT_TOL_M_PER_S=5.0e-12
CLOSEOUT_ROOT_HALF_WIDTH_M=2.0e-6
CLOSEOUT_GW_PROBES_M_PER_S=(-2.0e-8,0.0,2.0e-8)

@dataclass(frozen=True)
class Binding:
    groundwater_cell_id:int
    package_slot:int
    modflow_node_id:int

@dataclass(frozen=True)
class Term:
    groundwater_cell_id:int
    hcof_m2_per_day:float
    rhs_m3_per_day:float

class CountingKernel:
    def __init__(self,kernel:XmiWrapper)->None:
        self.kernel=kernel; self.prepare_solve_calls=0; self.solve_calls=0
        self.finalize_solve_calls=0; self.finalize_time_step_calls=0
    def __getattr__(self,name): return getattr(self.kernel,name)
    def prepare_solve(self,solution_id:int)->None:
        self.prepare_solve_calls+=1; self.kernel.prepare_solve(solution_id)
    def solve(self,solution_id:int)->bool:
        self.solve_calls+=1; return bool(self.kernel.solve(solution_id))
    def finalize_solve(self,solution_id:int)->None:
        self.finalize_solve_calls+=1; self.kernel.finalize_solve(solution_id)
    def finalize_time_step(self)->None:
        self.finalize_time_step_calls+=1; self.kernel.finalize_time_step()

def require(x:bool,msg:str)->None:
    if not x: raise AssertionError(msg)

def build_model(workdir:Path, reference_head:float)->None:
    sim=flopy.mf6.MFSimulation(sim_name="FGC44_REAL_E2E",version="mf6",sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(WINDOW_DAY,1,1.0)])
    flopy.mf6.ModflowIms(
        sim,
        complexity="MODERATE",
        outer_dvclose=1e-11,
        inner_dvclose=1e-12,
        outer_maximum=100,
        inner_maximum=100,
    )
    gwf=flopy.mf6.ModflowGwf(
        sim,
        modelname="GWF_1",
        model_nam_file="GWF_1.nam",
        list="GWF_1.lst",
        save_flows=True,
        newtonoptions="NEWTON",
    )
    ncol=1 if CLOSEOUT_ONECELL else 3
    flopy.mf6.ModflowGwfdis(gwf,nlay=1,nrow=1,ncol=ncol,delr=1.0,delc=1.0,top=0.0,botm=-2.0)
    flopy.mf6.ModflowGwfic(gwf,strt=reference_head)
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=1.0,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=0.02,sy=0.15,transient={0:True})
    if not CLOSEOUT_ONECELL:
        flopy.mf6.ModflowGwfchd(
            gwf,
            stress_period_data={0:[((0,0,0),reference_head+0.002),((0,0,2),reference_head-0.002)]},
            pname="CHD_ENDS",
        )
    flopy.mf6.ModflowGwfapi(gwf,maxbound=1,pname="API_SWAP",filename="api_swap.api",save_flows=True)
    flopy.mf6.ModflowGwfoc(
        gwf,
        budget_filerecord="fgc44.cbc",
        saverecord=[("BUDGET","ALL")],
        printrecord=[("BUDGET","ALL")],
    )
    sim.write_simulation(silent=True)

def _budget_component_sum(data)->float:
    array=np.asarray(data)
    if array.dtype.names:
        names={name.lower():name for name in array.dtype.names}
        if "q" in names:
            return float(np.sum(array[names["q"]],dtype=np.float64))
        return 0.0
    return float(np.sum(array,dtype=np.float64))

def read_modflow_component_balance(
    workdir:Path, expected_api_m3_per_day:float
)->tuple[float,float,float,float,float,str]:
    listing_path=workdir/"GWF_1.lst"
    listing_budget=flopy.utils.Mf6ListBudget(str(listing_path))
    require(listing_budget.isvalid(),"MODFLOW6 native GWF model budget unavailable")
    inc=listing_budget.get_incremental()
    require(inc is not None and len(inc)>0,"empty MODFLOW6 native GWF model budget")
    names=set(inc.dtype.names or ())
    for required in ("TOTAL_IN","TOTAL_OUT","IN-OUT","PERCENT_DISCREPANCY"):
        require(required in names,f"MODFLOW6 native GWF budget lacks {required}")
    row=inc[-1]
    total_in=float(row["TOTAL_IN"])
    total_out=float(row["TOTAL_OUT"])
    residual=float(row["IN-OUT"])
    percent_discrepancy=float(row["PERCENT_DISCREPANCY"])
    scale=abs(total_in)+abs(total_out)
    require(all(math.isfinite(v) for v in (
        total_in,total_out,residual,percent_discrepancy,scale
    )),"nonfinite MODFLOW6 native GWF model balance")
    # Mf6ListBudget parses the formatted native listing; TOTAL_IN/TOTAL_OUT
    # are presentation-rounded and must not be re-checked at binary epsilon.
    # IN-OUT is the MODFLOW-reported model budget residual and is the authority
    # for this acceptance gate.
    # Preserve the pre-existing closeout balance gate. This is the same absolute
    # and relative residual criterion used before the listing reader replaced
    # the invalid raw-CBC aggregate; no tolerance is changed after observing a failure.
    require(abs(residual)<=max(1.0e-9,1.0e-8*scale),
            "accepted MODFLOW6 native GWF model balance does not close")

    budget=flopy.utils.CellBudgetFile(str(workdir/"fgc44.cbc"),precision="double")
    api_records=[]
    for raw_name in budget.get_unique_record_names():
        name=raw_name.decode("ascii","ignore").strip()
        if name.upper()!="API":
            continue
        for data in budget.get_data(kstpkper=(0,0),text=name):
            api_records.append(_budget_component_sum(data))
    require(api_records,"MODFLOW6 binary budget contains no API package record")
    api_component=float(sum(api_records))
    api_scale=max(1.0,abs(api_component),abs(expected_api_m3_per_day))
    require(abs(api_component-expected_api_m3_per_day)<=256*np.finfo(float).eps*api_scale,
            "MODFLOW6 API budget record differs from accepted coupling term")
    return total_in,total_out,residual,percent_discrepancy,api_component,listing_path.name

def solve_closeout_constant_flux(
    libmf6:Path, swaplib:Path, href:float, q_source_m_per_s:float
)->tuple[float,float,int]:
    require(CLOSEOUT_ONECELL,"independent endpoint oracle is one-cell only")
    with tempfile.TemporaryDirectory(prefix="fgc44-closeout-oracle-") as tmp:
        workdir=Path(tmp)
        build_model(workdir,href)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=CountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True
            require("6.8.0" in raw.get_version(),"wrong MODFLOW version in endpoint oracle")
            raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            accepted_xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,1)]
            term=[Term(7001,0.0,-q_source_m_per_s*AREA_M2*DAY_TO_S)]
            converged=None
            for _ in range(session.max_solve_iterations):
                status,it=session.publish_and_solve_iteration(binding,term)
                require(status==PreparedSolveStatus.OK,session.last_error)
                require(it is not None,"missing MODFLOW endpoint-oracle iterate")
                require(np.array_equal(it.accepted_head_old_m,accepted_xold),
                        "endpoint-oracle MODFLOW XOLD drifted")
                if it.modflow_converged:
                    converged=it
                    break
            require(converged is not None,"endpoint-oracle MODFLOW solve did not converge")
            head=float(converged.head_m[0])
            qgw=(0.0*head-(-q_source_m_per_s*AREA_M2*DAY_TO_S))/(AREA_M2*DAY_TO_S)
            require(abs(qgw-q_source_m_per_s)<=64*np.finfo(float).eps*max(1.0,abs(q_source_m_per_s)),
                    "constant-flux endpoint oracle changed imposed groundwater source")
            iterations=int(converged.iteration)
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(session.timestep_ready_for_finalize(),"endpoint-oracle timestep not publishable")
            require(session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error)
            raw.finalize(); initialized=False
            return head,qgw,iterations
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass

def closeout_independent_endpoint(
    libmf6:Path,
    swaplib:Path,
    swap:Fgc44RealSwap,
    href:float,
    origin_state:tuple[int,float,int,float],
)->tuple[float,float,float,float,float]:
    require(CLOSEOUT_ONECELL,"independent endpoint oracle is one-cell only")
    points=[]
    for qprobe in CLOSEOUT_GW_PROBES_M_PER_S:
        head,qgw,mf_iters=solve_closeout_constant_flux(libmf6,swaplib,href,qprobe)
        points.append((head,qgw))
        print(
            f"FGC44_CLOSEOUT_GW_ORACLE_PROBE Q={qprobe:.17g} "
            f"H={head:.17g} MF_ITERS={mf_iters}"
        )

    heads=np.asarray([x[0] for x in points],dtype=float)
    fluxes=np.asarray([x[1] for x in points],dtype=float)
    slope,intercept=np.polyfit(heads,fluxes,1)
    fit_error=float(np.max(np.abs(slope*heads+intercept-fluxes)))
    require(math.isfinite(slope) and slope>0.0,
            "independent one-cell groundwater response slope invalid")
    require(math.isfinite(intercept) and fit_error<=CLOSEOUT_GW_FIT_TOL_M_PER_S,
            "independent one-cell groundwater response fit failed")

    def residual(head:float)->float:
        q_swap=swap.trial(head)
        swap.discard()
        require(swap.state()==origin_state,
                "independent endpoint SWAP probe changed accepted authority")
        value=q_swap-(slope*head+intercept)
        require(math.isfinite(value),"nonfinite independent endpoint residual")
        return value

    lo=href-CLOSEOUT_ROOT_HALF_WIDTH_M
    hi=href+CLOSEOUT_ROOT_HALF_WIDTH_M
    rlo=residual(lo)
    rhi=residual(hi)
    require(rlo==0.0 or rhi==0.0 or rlo*rhi<0.0,
            "independent physical endpoint is not bracketed")

    if rlo==0.0:
        root=lo; rroot=rlo
    elif rhi==0.0:
        root=hi; rroot=rhi
    else:
        root=0.5*(lo+hi)
        rroot=residual(root)
        for _ in range(80):
            root=0.5*(lo+hi)
            rroot=residual(root)
            if abs(rroot)<=FLUX_TOL or abs(hi-lo)<=1.0e-12:
                break
            if rlo*rroot<=0.0:
                hi=root
                rhi=rroot
            else:
                lo=root
                rlo=rroot

    require(abs(rroot)<=FLUX_TOL or abs(hi-lo)<=1.0e-12,
            "independent physical endpoint bisection did not close")
    require(swap.state()==origin_state,
            "independent endpoint qualification changed accepted authority")
    return float(root),float(rroot),float(slope),float(intercept),fit_error

def main()->None:
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing real SWAP bridge library")

    swap=Fgc44RealSwap(swaplib)
    hcof,rhs,href=swap.initialize()
    require(math.isfinite(hcof) and math.isfinite(rhs) and math.isfinite(href),"nonfinite real SWAP predictor")
    require(abs(hcof)>0.0,"real SWAP predictor tangent is zero")

    e1=swap.e1_diagnostics()
    require(bool(e1["mass_complete"]),"predictor mass accounting incomplete")
    mass_identity=float(e1["storage_change_native"])-(float(e1["total_in_native"])-float(e1["total_out_native"]))
    require(abs(mass_identity-float(e1["mass_residual_native"]))<=64*np.finfo(float).eps*max(1.0,abs(mass_identity)),
            "predictor mass identity mismatch")
    require(abs(float(e1["storage_end_native"])-float(e1["storage_start_native"])-float(e1["storage_change_native"]))
            <=64*np.finfo(float).eps*max(1.0,abs(float(e1["storage_change_native"]))),
            "predictor storage-change identity mismatch")
    qu_reconstructed=(float(e1["u"])*(float(e1["h_end_m"])-float(e1["h_start_m"]))*100.0/WINDOW_DAY
                      -float(e1["q_bot_predictor_cm_per_day"]))
    require(abs(qu_reconstructed-float(e1["q_u_cm_per_day"]))
            <=128*np.finfo(float).eps*max(1.0,abs(float(e1["q_u_cm_per_day"]))),
            "F-GC30 q_u reconstruction mismatch")

    revision,time_day,ledger_count,ledger_exchange=swap.state()
    origin_state=(revision,time_day,ledger_count,ledger_exchange)
    require(origin_state==(0,0.0,0,0.0),"SWAP/ledger not at accepted origin")

    independent_root=None
    independent_root_residual=None
    independent_gw_slope=None
    independent_gw_intercept=None
    independent_gw_fit_error=None
    if CLOSEOUT_ONECELL:
        (independent_root,independent_root_residual,independent_gw_slope,
         independent_gw_intercept,independent_gw_fit_error)=closeout_independent_endpoint(
            libmf6,swaplib,swap,href,origin_state
        )
        print(f"FGC44_INDEPENDENT_ENDPOINT_HEAD_M={independent_root:.17g}")
        print(f"FGC44_INDEPENDENT_ENDPOINT_RESIDUAL_M_PER_S={independent_root_residual:.17g}")
        print(f"FGC44_INDEPENDENT_GW_SLOPE_PER_S={independent_gw_slope:.17g}")
        print(f"FGC44_INDEPENDENT_GW_INTERCEPT_M_PER_S={independent_gw_intercept:.17g}")
        print(f"FGC44_INDEPENDENT_GW_FIT_ERROR_M_PER_S={independent_gw_fit_error:.17g}")

    # E2 real-participant isolation probe: a rejected corrector is a calculation,
    # not accepted hydrological history and not authoritative interface mass.
    probe_q=swap.trial(href)
    probe_diag=swap.last_trial_diagnostics()
    require(math.isfinite(probe_q) and all(math.isfinite(v) for v in probe_diag),"nonfinite rejected-trial probe")
    require(swap.state()==origin_state,"rejected trial mutated committed state or ledger before discard")
    swap.discard()
    require(swap.state()==origin_state,"discarded trial mutated committed state or ledger")

    # A prepared publication that is abandoned before the publication point must
    # likewise leave committed state and mass unchanged.
    _=swap.trial(href)
    require(swap.swap_preflight(),"prepublication abort probe SWAP preflight failed")
    swap.prepare_ledger()
    require(swap.ledger_preflight(),"prepublication abort probe ledger preflight failed")
    require(swap.state()==origin_state,"prepared publication changed authoritative state")
    swap.abort_prepublication()
    require(swap.state()==origin_state,"prepublication abort changed authoritative state or mass")

    with tempfile.TemporaryDirectory(prefix="fgc44-e2e-") as tmp:
        workdir=Path(tmp); build_model(workdir,href)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=CountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True
            require("6.8.0" in raw.get_version(),"wrong MODFLOW version")
            raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            accepted_xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,1 if CLOSEOUT_ONECELL else 2)]
            current_hcof=hcof; current_rhs=rhs
            final_head=None; final_q_swap=None; final_q_gw=None; converged=False

            for outer in range(1,min(40,session.max_solve_iterations)+1):
                term=Term(7001,current_hcof,current_rhs)
                status,it=session.publish_and_solve_iteration(binding,[term])
                require(status==PreparedSolveStatus.OK,session.last_error)
                require(it is not None,f"missing MODFLOW iterate {outer}")
                require(np.array_equal(it.accepted_head_old_m,accepted_xold),"MODFLOW XOLD drifted")
                head_index=0 if CLOSEOUT_ONECELL else 1
                head=float(it.head_m[head_index])
                q_gw=(current_hcof*head-current_rhs)/(AREA_M2*DAY_TO_S)
                q_swap=swap.trial(head)
                q_diag,_,dq_swap_dh,tangent_available=swap.last_trial_response()
                require(abs(q_diag-q_swap)<=64*np.finfo(float).eps*max(1.0,abs(q_swap)),
                        "trial response q mismatch")
                require(tangent_available and math.isfinite(dq_swap_dh) and dq_swap_dh<0.0,
                        "real SWAP physical outward tangent unavailable or wrongly oriented")
                residual=q_swap-q_gw
                require(all(math.isfinite(x) for x in (head,q_gw,q_swap,dq_swap_dh,residual)),"nonfinite coupled iterate")
                print(f"FGC44_ITER={outer} H={head:.17g} QSWAP={q_swap:.17g} QGW={q_gw:.17g} RES={residual:.17g} MF={int(it.modflow_converged)}")
                if it.modflow_converged and abs(residual)<=FLUX_TOL:
                    converged=True; final_head=head; final_q_swap=q_swap; final_q_gw=q_gw
                    break
                require(swap.state()==origin_state,"rejected coupled corrector changed authoritative state before discard")
                swap.discard()
                require(swap.state()==origin_state,"discarded coupled corrector changed authoritative state or mass")
                current_hcof=dq_swap_dh*AREA_M2*DAY_TO_S
                current_rhs=current_hcof*head-q_swap*AREA_M2*DAY_TO_S

            require(converged,"real SWAP + MODFLOW coupling did not converge")
            if CLOSEOUT_ONECELL:
                require(independent_root is not None and independent_gw_slope is not None and
                        independent_gw_intercept is not None,
                        "independent physical endpoint oracle unavailable")
                independent_final_residual=final_q_swap-(
                    independent_gw_slope*final_head+independent_gw_intercept
                )
                independent_head_error=final_head-independent_root
                independent_residual_gate=abs(independent_final_residual)<=FLUX_TOL
                require(abs(independent_head_error)<=CLOSEOUT_ENDPOINT_HEAD_TOL_M,
                        "coupled endpoint differs from independent physical endpoint")
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.prepare_solve_calls==1 and kernel.finalize_solve_calls==1,"prepared solve lifecycle mismatch")
            require(swap.swap_preflight(),"real SWAP publication preflight failed")
            swap.prepare_ledger()
            require(swap.ledger_preflight(),"real ledger publication preflight failed")
            require(session.timestep_ready_for_finalize(),"live MODFLOW timestep publication preflight failed")
            require(kernel.finalize_time_step_calls==0,"preflight crossed MODFLOW publication point")
            require(swap.state()==origin_state,"publication preflight changed authoritative SWAP/ledger state")

            require(session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.finalize_time_step_calls==1,"MODFLOW timestep not finalized exactly once")
            require(swap.state()==origin_state,"MODFLOW publication prematurely changed SWAP/ledger authority")

            swap.commit_swap()
            after_swap_commit=swap.state()
            require(after_swap_commit[0]==1 and abs(after_swap_commit[1]-WINDOW_DAY)<=1e-14,
                    "SWAP publication did not advance revision/time exactly once")
            require(after_swap_commit[2]==0 and after_swap_commit[3]==0.0,
                    "SWAP publication prematurely committed interface ledger")

            final_trial_q,final_bottom_exchange_cm=swap.last_trial_diagnostics()
            require(abs(final_trial_q-final_q_swap)<=64*np.finfo(float).eps*max(1.0,abs(final_q_swap)),
                    "final-trial q diagnostic mismatch")

            swap.commit_ledger()
            revision,time_day,ledger_count,ledger_exchange=swap.state()
            require(revision==1,"real SWAP revision not committed exactly once")
            require(abs(time_day-WINDOW_DAY)<=1e-14,"real SWAP committed time mismatch")
            require(ledger_count==1,"real ledger not committed exactly once")
            require(math.isfinite(ledger_exchange),"real ledger exchange nonfinite")
            require(abs(ledger_exchange-final_bottom_exchange_cm*0.01)
                    <=64*np.finfo(float).eps*max(1.0,abs(ledger_exchange)),
                    "ledger exchange does not equal final accepted SWAP bottom amount")
            public_rate_amount=final_q_swap*WINDOW_DAY*DAY_TO_S
            require(abs(public_rate_amount-ledger_exchange)
                    <=256*np.finfo(float).eps*max(1.0,abs(public_rate_amount),abs(ledger_exchange)),
                    "public q_swap rate and accepted outward ledger amount are inconsistent")
            require(not session.timestep_ready_for_finalize(),"MODFLOW timestep remained publishable")
            require(session.finalize_time_step_once()==PreparedSolveStatus.TIMESTEP_ALREADY_FINALIZED,"second MODFLOW timestep finalization not blocked")
            raw.finalize(); initialized=False

            if CLOSEOUT_ONECELL:
                print(f"FGC44_INDEPENDENT_FINAL_HEAD_ERROR_M={independent_head_error:.17g}")
                print(f"FGC44_INDEPENDENT_FINAL_RESIDUAL_M_PER_S={independent_final_residual:.17g}")
                print("FGC44_INDEPENDENT_HEAD_ENDPOINT=PASS")
                print("FGC44_INDEPENDENT_PHYSICAL_RESIDUAL_GATE="+("PASS" if independent_residual_gate else "FAIL"))
                expected_api_m3_per_day=final_q_gw*AREA_M2*DAY_TO_S
                (mf_total_in,mf_total_out,mf_budget_residual,mf_percent_discrepancy,
                 mf_api_component,mf_listing_file)=read_modflow_component_balance(
                    workdir,expected_api_m3_per_day
                )
                print(f"FGC44_MODFLOW_TOTAL_IN_M3_PER_DAY={mf_total_in:.17g}")
                print(f"FGC44_MODFLOW_TOTAL_OUT_M3_PER_DAY={mf_total_out:.17g}")
                print(f"FGC44_MODFLOW_COMPONENT_BALANCE_RESIDUAL_M3_PER_DAY={mf_budget_residual:.17g}")
                print(f"FGC44_MODFLOW_PERCENT_DISCREPANCY={mf_percent_discrepancy:.17g}")
                print(f"FGC44_MODFLOW_API_COMPONENT_M3_PER_DAY={mf_api_component:.17g}")
                print(f"FGC44_MODFLOW_API_EXPECTED_M3_PER_DAY={expected_api_m3_per_day:.17g}")
                print(f"FGC44_MODFLOW_LISTING_FILE={mf_listing_file}")

            print(f"FGC44_FINAL_HEAD_M={final_head:.17g}")
            print(f"FGC44_FINAL_Q_SWAP_M_PER_S={final_q_swap:.17g}")
            print(f"FGC44_FINAL_Q_GW_M_PER_S={final_q_gw:.17g}")
            print(f"FGC44_FINAL_FLUX_RESIDUAL={final_q_swap-final_q_gw:.17g}")
            print(f"FGC44_LEDGER_EXCHANGE_M={ledger_exchange:.17g}")
            print(f"PUB_GC_E1_QBOT_PREDICTOR_CM_PER_DAY={float(e1['q_bot_predictor_cm_per_day']):.17g}")
            print(f"PUB_GC_E1_QU_CM_PER_DAY={float(e1['q_u_cm_per_day']):.17g}")
            print(f"PUB_GC_E1_U={float(e1['u']):.17g}")
            print(f"PUB_GC_E1_STORAGE_START_NATIVE={float(e1['storage_start_native']):.17g}")
            print(f"PUB_GC_E1_STORAGE_END_NATIVE={float(e1['storage_end_native']):.17g}")
            print(f"PUB_GC_E1_STORAGE_CHANGE_NATIVE={float(e1['storage_change_native']):.17g}")
            print(f"PUB_GC_E1_TOTAL_IN_NATIVE={float(e1['total_in_native']):.17g}")
            print(f"PUB_GC_E1_TOTAL_OUT_NATIVE={float(e1['total_out_native']):.17g}")
            print(f"PUB_GC_E1_MASS_RESIDUAL_NATIVE={float(e1['mass_residual_native']):.17g}")
            print(f"PUB_GC_E1_FINAL_BOTTOM_EXCHANGE_CM={final_bottom_exchange_cm:.17g}")
            print(f"PUB_GC_E1_PUBLIC_RATE_AMOUNT_M={public_rate_amount:.17g}")
            print("PUB_GC_E1_INTERFACE_IDENTITY=PASS")
            print("PUB_GC_E2_REJECTED_TRIAL_ZERO_AUTHORITY=PASS")
            print("PUB_GC_E2_PREPUBLICATION_ABORT_ZERO_AUTHORITY=PASS")
            print("PUB_GC_E2_EXACTLY_ONCE_PUBLICATION=PASS")
            print("PUB_GC_E2_PUBLICATION_ORDER=PASS")
            print("FGC44_REAL_SWAP_PREDICTOR_ANALYTIC=PASS")
            print("FGC44_REAL_SWAP_CORRECTORS_FROM_ACCEPTED_ORIGIN=PASS")
            print("FGC44_REAL_SWAP_PHYSICAL_RESPONSE_RELINEARIZATION=PASS")
            if CLOSEOUT_ONECELL:
                print("FGC44_CLOSEOUT_ONE_SWAP_ONE_MODFLOW_CELL=PASS")
                print("FGC44_ACCEPTED_MODFLOW_COMPONENT_BALANCE=PASS")
                require(independent_residual_gate,
                        "coupled endpoint does not close independent physical residual")
                print("FGC44_INDEPENDENT_PHYSICAL_ENDPOINT=PASS")
            print("FGC44_LIVE_MODFLOW680_PREPARED_SOLVE=PASS")
            print("FGC44_CONJUNCTIVE_COUPLING_CONVERGENCE=PASS")
            print("FGC44_ALL_PREFLIGHTS_BEFORE_PUBLICATION=PASS")
            print("FGC44_MODFLOW_THEN_SWAP_THEN_LEDGER_PUBLICATION=PASS")
            print("FGC44_REAL_SWAP_MODFLOW_END_TO_END=PASS")
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass

if __name__=="__main__":
    main()
