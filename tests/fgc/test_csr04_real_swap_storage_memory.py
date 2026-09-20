from __future__ import annotations
import math, os, sys, tempfile
from dataclasses import dataclass
from pathlib import Path
import flopy, numpy as np
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"src"/"adapter"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus
from fgc44_real_swap_ctypes import Fgc44RealSwap

DAY=86400.0; AREA=1.0; DT=1e-4; TOL=1e-15
SY=(0.30,0.05,1e-2,1e-3,1e-4,1e-5)
Q=(1e-6,1e-6,5e-6,5e-6,1e-6,1e-6)

@dataclass(frozen=True)
class Binding: groundwater_cell_id:int; package_slot:int; modflow_node_id:int
@dataclass(frozen=True)
class Term: groundwater_cell_id:int; hcof_m2_per_day:float; rhs_m3_per_day:float
def req(x,m): 
    if not x: raise AssertionError(m)

def build(w,href,sy):
    sim=flopy.mf6.MFSimulation(sim_name="CSR04",version="mf6",sim_ws=str(w))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=len(Q),perioddata=[(DT,1,1.0)]*len(Q))
    flopy.mf6.ModflowIms(sim,complexity="MODERATE",outer_dvclose=1e-11,inner_dvclose=1e-12,outer_maximum=100,inner_maximum=100)
    g=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True,newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(g,nlay=1,nrow=1,ncol=3,delr=1.,delc=1.,top=0.,botm=-2.)
    flopy.mf6.ModflowGwfic(g,strt=href); flopy.mf6.ModflowGwfnpf(g,icelltype=1,k=1.,save_flows=True)
    flopy.mf6.ModflowGwfoc(g,budget_filerecord="csr04.cbc",head_filerecord="csr04.hds",saverecord=[("HEAD","ALL"),("BUDGET","ALL")])
    flopy.mf6.ModflowGwfsto(g,iconvert=1,ss=0.02,sy=sy,transient={i:True for i in range(len(Q))})
    chd={i:[((0,0,0),href+0.002),((0,0,2),href-0.002)] for i in range(len(Q))}
    flopy.mf6.ModflowGwfchd(g,stress_period_data=chd,pname="CHD_ENDS")
    flopy.mf6.ModflowGwfapi(g,maxbound=1,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def run(libmf,swaplib,sy):
    swap=Fgc44RealSwap(swaplib); hcof,rhs,href=swap.initialize_configured(DT,Q[0])
    with tempfile.TemporaryDirectory(prefix="csr04-") as td:
      w=Path(td); build(w,href,sy); raw=XmiWrapper(lib_path=libmf,working_directory=w); pub=Fgc34CtypesPublisher(swaplib)
      raw.initialize(); rows=[]
      try:
       for k,q in enumerate(Q):
        if k:
            hcof,rhs,href=swap.csr04_next_window_predictor(DT,q)
        e=swap.e1_diagnostics(); origin=swap.state()
        raw.prepare_time_step(0.0)
        ses=Modflow6PreparedSolveSession(raw,"GWF_1","API_SWAP",pub,1)
        req(ses.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,ses.last_error); req(ses.open_prepared_solve()==PreparedSolveStatus.OK,ses.last_error)
        cur=rhs; final=None
        for _ in range(min(40,ses.max_solve_iterations)):
            st,it=ses.publish_and_solve_iteration([Binding(7001,1,2)],[Term(7001,hcof,cur)])
            req(st==PreparedSolveStatus.OK,ses.last_error); head=float(it.head_m[1]); qgw=(hcof*head-cur)/(AREA*DAY); qs=swap.trial(head); res=qs-qgw
            if it.modflow_converged and abs(res)<=TOL: final=(head,qs,qgw,res); break
            swap.discard(); cur=hcof*head-qs*AREA*DAY
        req(final is not None,f"no convergence sy={sy} window={k}")
        req(ses.finalize_prepared_solve()==PreparedSolveStatus.OK,ses.last_error)
        swap.prepare_ledger(); req(swap.swap_preflight() and swap.ledger_preflight(),"preflight")
        req(ses.finalize_time_step_once()==PreparedSolveStatus.OK,ses.last_error)
        obs=ses.accepted_budget_observation(); req(obs is not None,"budget observation")
        swap.commit_swap(); swap.commit_ledger()
        state=swap.state(); req(state[0]==k+1 and abs(state[1]-(k+1)*DT)<1e-13,"SWAP continuation")
        rows.append((final[0],final[1],float(e["storage_start_native"]),float(e["storage_end_native"]),float(e["mass_residual_native"]),float(e["q_u_cm_per_day"]),float(e["u"]),final[3]))
       raw.finalize()
      except Exception:
       try: raw.finalize()
       except Exception: pass
       raise
      cb=flopy.utils.CellBudgetFile(w/"csr04.cbc",precision="double")
      unique={str(x).strip() for x in cb.get_unique_record_names(decode=True)}
      sto=[]
      for label in ("STO-SS","STO-SY"):
       if label in unique:
        data=cb.get_data(text=label)
        # one accepted record per time; sum each record over cells
        if not sto: sto=[0.0]*len(data)
        for i,a in enumerate(data): sto[i]+=float(np.sum(np.asarray(a)))
      req(len(sto)>=len(Q),"native STO records missing")
      return rows,sto[:len(Q)]

def main():
 lib=Path(os.environ["LIBMF6"]).resolve(); sl=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
 allr={}
 for sy in SY:
  rows,sto=run(lib,sl,sy); allr[sy]=rows
  for i,(r,st) in enumerate(zip(rows,sto)):
   print(f"CSR04_WINDOW SY={sy:.17g} I={i} HEAD={r[0]:.17g} QSWAP={r[1]:.17g} STO={st:.17g} S0={r[2]:.17g} S1={r[3]:.17g} MRES={r[4]:.17g} QU={r[5]:.17g} U={r[6]:.17g} IRES={r[7]:.17g}")
 heads=[allr[x][-1][0] for x in SY]
 req(abs(heads[0]-heads[-1])>1e-12,"Sy perturbation produced no trajectory separation")
 tail=abs(heads[-1]-heads[-2])
 print(f"CSR04_PHASE_B_TAIL_HEAD_DIFF={tail:.17g}")
 print("CSR04_PHASE_B_REAL_MULTIWINDOW_EXECUTION=PASS")
 print("CSR04_PHASE_B_MEMORY_SEPARATION_OBSERVED=PASS")
if __name__=="__main__": main()
