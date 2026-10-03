"""Qualification-only stateful RFM two-tile/live-MODFLOW window sequence."""
import ctypes,json,math,os,sys,tempfile,time
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/fgc'))
import test_fgc45_real_multiswap_modflow_end_to_end as f
mode=sys.argv[1];nwindow=int(sys.argv[2]) if len(sys.argv)>2 else 64
H0=float(os.environ.get('A28_H0_CM','-10.'))
DT=float(os.environ.get('A28_DT_DAY','.001'))
RAIN=float(os.environ.get('A28_RAIN_CM_DAY','1.'))
lib=ctypes.CDLL(os.environ['FGC45_MULTISWAP_LIB'])
lib.a28_set_policy_c.argtypes=[ctypes.c_int];lib.a28_set_policy_c.restype=ctypes.c_int
lib.a28_set_fixture_c.argtypes=[ctypes.c_double]*3;lib.a28_set_fixture_c.restype=ctypes.c_int
lib.a28_next_window_c.argtypes=[ctypes.c_double]+[ctypes.POINTER(ctypes.c_double)]*3;lib.a28_next_window_c.restype=ctypes.c_int
assert lib.a28_set_policy_c(int(mode=='a28'))==0
assert lib.a28_set_fixture_c(H0,DT,RAIN)==0
swap=f.Fgc45RealMultiSwap(os.environ['FGC45_MULTISWAP_LIB'])
# Initialization includes FD qualification and is reported separately from live windows.
t0=time.perf_counter();hcof,rhs,href=swap.initialize();init_seconds=time.perf_counter()-t0
matrix=(ctypes.c_double*2)();rfm=(ctypes.c_double*2)()
lib.a28_storage_c(matrix,rfm);initial_matrix=list(matrix);initial_rfm=list(rfm)
counts=(ctypes.c_int*3)();panels=ctypes.c_int();hmin=ctypes.c_double();hmax=ctypes.c_double();seconds=ctypes.c_double()
lib.a28_sorptivity_stats_c.argtypes=[ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
lib.a28_sorptivity_stats_reset_c.argtypes=[]
rows=[];swap_seconds=0.;modflow_seconds=0.;coupling_seconds=0.;predictor_seconds=0.
with tempfile.TemporaryDirectory(prefix='a28-windows-') as tmp:
 p=Path(tmp);f.build_model(p,href)
 # Explicitly replace only TDIS schedule using FloPy before model execution.
 sim=f.flopy.mf6.MFSimulation.load(sim_ws=str(p),verbosity_level=0)
 sim.tdis.perioddata.set_data([(DT*nwindow,nwindow,1.)]);sim.write_simulation(silent=True)
 raw=f.XmiWrapper(os.environ['LIBMF6'],working_directory=str(p));raw.initialize()
 lib.a28_sorptivity_stats_reset_c() # Align quadrature counters and CPU time to the measured execution window.
 assert '6.8.0' in raw.get_version()
 kernel=f.CountingKernel(raw);publisher=f.Fgc34CtypesPublisher(os.environ['FGC45_MULTISWAP_LIB'])
 try:
  for w in range(nwindow):
   start=time.perf_counter()
   rain=RAIN if (w//4)%2==0 else 0.
   if w:
    a=ctypes.c_double();b=ctypes.c_double();c=ctypes.c_double()
    t=time.perf_counter();status=lib.a28_next_window_c(rain,ctypes.byref(a),ctypes.byref(b),ctypes.byref(c));predictor_seconds+=time.perf_counter()-t
    if status:
     Path(os.environ['A28_RESULT']).write_text(json.dumps(dict(status='EXACT_PREDICTOR_BLOCKER' if mode=='exact' else 'A28_PREDICTOR_FAILURE',failed_window=w+1,completed_windows=w,rows=rows),indent=2)+'\n')
    f.require(status==0,f'next RFM window failed {w}');hcof,rhs,href=a.value,b.value,c.value
   raw.prepare_time_step(0.)
   session=f.Modflow6PreparedSolveSession(kernel,'GWF_1','API_SWAP',publisher,solution_id=1)
   f.require(session.acquire_after_prepare_time_step()==f.PreparedSolveStatus.OK,session.last_error)
   f.require(session.open_prepared_solve()==f.PreparedSolveStatus.OK,session.last_error)
   old=session.accepted_xold.copy();binding=[f.Binding(7001,1,2)]
   converged=False
   for outer in range(1,min(40,session.max_solve_iterations)+1):
    t=time.perf_counter();status,it=session.publish_and_solve_iteration(binding,[f.Term(7001,hcof,rhs)]);modflow_seconds+=time.perf_counter()-t
    f.require(status==f.PreparedSolveStatus.OK,session.last_error)
    f.require(np.array_equal(it.accepted_head_old_m,old),'XOLD changed')
    head=float(it.head_m[1]);qgw=(hcof*head-rhs)/f.DAY_TO_S
    t=time.perf_counter();qw,q1,q2=swap.trial(head);swap_seconds+=time.perf_counter()-t
    res=qw-qgw
    f.require(abs(qw-(f.F1*q1+f.F2*q2))<=1e-15,'area closure')
    f.require(all(math.isfinite(x) for x in (head,qw,q1,q2,res)),'nonfinite')
    if it.modflow_converged and abs(res)<=f.FLUX_TOL:
     converged=True;break
    swap.discard();rhs=hcof*head-qw*f.DAY_TO_S
   f.require(converged,f'coupling convergence {w}')
   f.require(session.finalize_prepared_solve()==f.PreparedSolveStatus.OK,session.last_error)
   f.require(swap.swap_preflight(),'SWAP preflight');swap.prepare_ledgers();f.require(swap.ledgers_preflight(),'ledger preflight')
   f.require(session.timestep_ready_for_finalize(),'MF readiness')
   f.require(session.finalize_time_step_once()==f.PreparedSolveStatus.OK,session.last_error)
   swap.commit_swaps();swap.commit_ledgers();state=swap.state()
   f.require(state[:2]==(w+1,w+1),'revision');f.require(state[4:6]==(w+1,w+1),'ledger count')
   f.require(max(abs(state[2]-(w+1)*DT),abs(state[3]-(w+1)*DT))<1e-12,'time')
   lib.a28_storage_c(matrix,rfm)
   rows.append(dict(window=w+1,rain_cm_day=rain,head_m=head,q1=q1,q2=q2,qw=qw,residual=res,iterations=outer,ledger1=state[6],ledger2=state[7],matrix=list(matrix),rfm=list(rfm)))
   coupling_seconds+=time.perf_counter()-start
   Path(os.environ['A28_RESULT']).write_text(json.dumps(dict(status='RUNNING',completed_windows=w+1,rows=rows),indent=2)+'\n')
   print(f'A28_WINDOW_COMPLETED={w+1} H={head:.17g} iterations={outer} matrix={list(matrix)} rfm={list(rfm)}',flush=True)
 finally:raw.finalize()
lib.a28_sorptivity_stats_c(counts,ctypes.byref(panels),ctypes.byref(hmin),ctypes.byref(hmax),ctypes.byref(seconds))
result=dict(mode=mode,windows=nwindow,h0_cm=H0,rain_cm_day=RAIN,reference_head_m=href,dt_day=DT,initial_matrix_cm=initial_matrix,initial_rfm_cm=initial_rfm,init_seconds=init_seconds,execution_seconds=coupling_seconds,predictor_seconds=predictor_seconds,corrector_seconds=swap_seconds,modflow_seconds=modflow_seconds,sorptivity_counts=list(counts),panels=panels.value,consumer_head_range_cm=[hmin.value,hmax.value],sorptivity_seconds=seconds.value,rows=rows)
Path(os.environ['A28_RESULT']).write_text(json.dumps(result,indent=2)+'\n')
print('A28_COUPLED_WINDOWS=PASS',json.dumps({k:v for k,v in result.items() if k!='rows'}))
