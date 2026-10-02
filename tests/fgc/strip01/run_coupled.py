"""Isolated research outer coupling, real FMR Richards and live MODFLOW6.

Uses existing head materializer and prepared-solve publication adapter. No
production bootstrap guard is altered. All numbers are in metres and days.
"""
import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
import flopy
import numpy as np
from xmipy import XmiWrapper
from component import Swap

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/"src/adapter"))
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession,PreparedSolveStatus


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


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--swap-library",required=True)
    p.add_argument("--mf-library",required=True)
    p.add_argument("--dt",type=float,required=True)
    p.add_argument("--startup-dt",type=float)
    p.add_argument("--initial-head",type=float,default=-4.5)
    p.add_argument("--elastic-per-cm",type=float,default=0)
    p.add_argument("--windows",type=int,default=1)
    p.add_argument("--output",type=Path,required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    durations=[a.dt]*a.windows
    if a.startup_dt is not None:durations[0]=a.startup_dt
    sim=flopy.mf6.MFSimulation(sim_name="strip01_research",sim_ws=str(a.output))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=a.windows,perioddata=[(duration,1,1.) for duration in durations])
    flopy.mf6.ModflowIms(sim,outer_dvclose=1e-11,inner_dvclose=1e-12,
                        rcloserecord=1e-12,outer_maximum=200,inner_maximum=200,
                        linear_acceleration="BICGSTAB")
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True)
    flopy.mf6.ModflowGwfdis(gwf,nlay=1,nrow=1,ncol=50,delr=1.,delc=1.,top=-6.,botm=-10.)
    flopy.mf6.ModflowGwfic(gwf,strt=a.initial_head)
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=0,k=.5)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=0,ss=1e-5,sy=0.,transient={0:True})
    flopy.mf6.ModflowGwfdrn(gwf,stress_period_data=[((0,0,0),-5.,100.)],pname="LEFT_DRAIN")
    flopy.mf6.ModflowGwfapi(gwf,maxbound=50,pname="API_SWAP")
    flopy.mf6.ModflowGwfoc(gwf,head_filerecord="strip.hds",budget_filerecord="strip.cbc",
                         saverecord=[("HEAD","ALL"),("BUDGET","ALL")])
    sim.write_simulation(silent=True)
    swap=Swap(a.swap_library);assert swap.initialize(initial_head_m=a.initial_head,elastic_per_cm=a.elastic_per_cm)==0
    raw=XmiWrapper(lib_path=Path(a.mf_library).resolve(),working_directory=a.output)
    raw.initialize();assert "6.8.0" in raw.get_version()
    publisher=Fgc34CtypesPublisher(a.swap_library)
    bindings=[Binding(i+1,i+1,i+1) for i in range(50)]
    records=[];result=dict(status="NOT_QUALIFIED",windows=records,coupled_research_only=True,
                          dt_day=a.dt,initial_head_m=a.initial_head,elastic_per_cm=a.elastic_per_cm,outer_attempts=[])
    try:
        for w,dt in enumerate(durations):
            before=swap.state();assert swap.begin(dt)==0
            raw.prepare_time_step(dt)
            session=Modflow6PreparedSolveSession(raw,"GWF_1","API_SWAP",publisher)
            assert session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error
            assert session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error
            origin=session.accepted_xold.copy();head=origin.copy()
            last_head=None;last_q=None;converged=False
            for outer in range(40):
                rc,q,delta,residual=swap.trial(head)
                if rc:raise RuntimeError(f"SWAP trial failure {rc}, window {w}, outer {outer}")
                assert all(np.array_equal(v,u) for v,u in zip(before,swap.state())),"trial changed committed origin"
                if last_head is None:
                    slopes=np.full(50,-.01)  # numerical initial secant, no storage interpretation
                else:
                    dh=head-last_head
                    slopes=np.divide(q-last_q,dh,out=np.full(50,-.01),where=abs(dh)>1e-12)
                    slopes=np.minimum(slopes,-1e-12)
                terms=[Term(i+1,float(slopes[i]),float(slopes[i]*head[i]-q[i])) for i in range(50)]
                status,it=session.publish_and_solve_iteration(bindings,terms)
                if status!=PreparedSolveStatus.OK:raise RuntimeError(session.last_error)
                new_head=it.head_m.copy();assert np.min(new_head)>-6.,"aquifer no longer wholly saturated"
                result["outer_attempts"].append(dict(window=w,outer=outer,origin_head_m=head.tolist(),
                    corrected_head_m=new_head.tolist(),linearization_hcof_m2_day=slopes.tolist()))
                rc,new_q,new_delta,new_residual=swap.trial(new_head)
                if rc:raise RuntimeError(f"SWAP corrected trial failure {rc}, window {w}, outer {outer}")
                api=slopes*new_head-np.array([t.rhs_m3_per_day for t in terms])
                error=float(np.max(abs(api-new_q)))
                print(f"STRIP01_OUTER={outer} WINDOW={w} ERROR_M3_D={error:.17g}",flush=True)
                if it.modflow_converged and error<=1e-10:
                    head=new_head;q=new_q;delta=new_delta;residual=new_residual;converged=True;break
                last_head=head.copy();last_q=q.copy();head=new_head
            if not converged:raise RuntimeError("research outer coupling ceiling 40")
            replay=swap.trial(head);assert replay[0]==0
            assert np.array_equal(q,replay[1]),"accepted-origin replay differs"
            assert session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error
            assert session.timestep_ready_for_finalize()
            # All SWAP candidates exist before the irreversible MF publication.
            assert np.max(abs(residual))<=1e-14
            assert session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error
            assert swap.commit()==0
            after=swap.state()
            assert np.all(after[0]==w+1)
            assert np.max(abs(after[2]-before[2]-delta))<1e-12
            records.append(dict(window=w,day=float(sum(durations[:w+1])),dt_day=dt,outer=outer+1,
                                interface_residual_m3_day=error,head_m=head.tolist(),
                                swap_gwl_m=after[3].tolist(),swap_storage_m=after[2].tolist(),
                                delta_swap_storage_m3=float(np.sum(delta)),q_m_day=q.tolist(),
                                mf_delta_storage_m3=float(4e-5*np.sum(head-origin)),rain_m3=.05*dt))
        result["status"]="COUPLED_COMPONENTS_COMPLETED_BUDGET_PENDING"
    except Exception as e:
        result["failure"]=str(e)
        raise
    finally:
        raw.finalize()
        (a.output/"coupled_result.json").write_text(json.dumps(result,indent=2)+"\n")
    budgets=flopy.utils.CellBudgetFile(a.output/"strip.cbc",precision="double")
    for record,t in zip(records,budgets.get_times()):
        drain=budgets.get_data(text="DRN",totim=t)[0]
        qdrn=float(np.sum(drain["q"]))
        record["drain_out_m3"]=-qdrn*record["dt_day"]
        record["whole_balance_residual_m3"]=record["rain_m3"]-record["drain_out_m3"]-record["delta_swap_storage_m3"]-record["mf_delta_storage_m3"]
        assert abs(record["whole_balance_residual_m3"])<=1e-8,record
    result["status"]="COUPLED_SHORT_RESEARCH_PASS"
    (a.output/"coupled_result.json").write_text(json.dumps(result,indent=2)+"\n")
    print("STRIP01_COUPLED_SHORT_RESEARCH=PASS")


if __name__=="__main__":main()
