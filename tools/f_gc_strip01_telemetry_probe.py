import argparse,ctypes,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--profile',choices=['C0','C1'],required=True);p.add_argument('--library',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
lib=ctypes.CDLL(str(a.library.resolve()))
init=lib.fgc49d_fixture_initialize_c
init.argtypes=[ctypes.POINTER(ctypes.c_int64),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
handle,x,y=ctypes.c_int64(),ctypes.c_double(),ctypes.c_double();assert init(ctypes.byref(handle),ctypes.byref(x),ctypes.byref(y))==0
obs=lib.strip01_observe_c;obs.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_int)]
def state():
 s,r=(ctypes.c_double*50)(),(ctypes.c_int*50)();assert obs(s,r)==0;return list(s),list(r)
before=state();fn=lib.strip01_diagnose_telemetry_c
fn.argtypes=[ctypes.c_int,ctypes.c_double,ctypes.c_double,ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_char),ctypes.POINTER(ctypes.c_char),ctypes.POINTER(ctypes.c_char)]
heads={1:-4.996934702272599,50:-4.964812337059502} if a.profile=='C0' else {1:-0.994865526330005,50:-0.9742777220884193}
int_names=['solver_executed','solver_status','nonlinear_iterations','linear_solves','solver_equation_residual_available','temporal_indicator_enabled','previous_derivative_available','current_derivative_available','temporal_indicator_status','temporal_indicator_available','head_budget_supplied','head_budget_valid','temporal_certificate_available','additional_tridiagonal_solves']
real_names=['solver_equation_residual','temporal_head_inf_bound','temporal_head_budget','temporal_normalized_indicator','completed_time_day']
rows=[]
for col,head in heads.items():
 for dt in (0.001,0.0005,0.0001,0.00001):
  codes,ti,tr=(ctypes.c_int*8)(),(ctypes.c_int*14)(),(ctypes.c_double*5)()
  sr,troute,reason=(ctypes.c_char*32)(),(ctypes.c_char*40)(),(ctypes.c_char*48)()
  assert fn(col,head,dt,codes,ti,tr,sr,troute,reason)==0
  route=lambda x: bytes(x).split(b'\0',1)[0].decode()
  rows.append({'column':col,'trial_head_m':head,'duration_day':dt,'codes':list(codes),**dict(zip(int_names,list(ti))),**dict(zip(real_names,list(tr))),'solver_route':route(sr),'temporal_route':route(troute),'certificate_reason':route(reason)})
after=state();assert before==after
out={'state':'TELEMETRY_PROBE_COMPLETED','profile':a.profile,'max_retries':0,'tangent_requested':False,'committed_state_preserved':True,'code_fields':['canonical_status','accepted_substeps','solver_rejections','temporal_rejections','mass_rejections','admission_rejections','attempts','retries'],'rows':rows}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(out,indent=2)+'\n');print(a.profile,[(r['column'],r['duration_day'],r['codes'],r['temporal_indicator_status'],r['temporal_head_inf_bound'],r['temporal_head_budget'],r['solver_route'],r['temporal_route'],r['certificate_reason'],r['solver_status'],r['solver_equation_residual'],r['nonlinear_iterations']) for r in rows])
