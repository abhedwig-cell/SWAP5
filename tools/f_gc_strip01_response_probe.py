import argparse,ctypes,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--profile',choices=['C0','C1'],required=True);p.add_argument('--library',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--head-reference',choices=['actual','hydrostatic-origin'],default='actual');a=p.parse_args()
lib=ctypes.CDLL(str(a.library.resolve()));init=lib.fgc49d_fixture_initialize_c
init.argtypes=[ctypes.POINTER(ctypes.c_int64),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
handle,x,y=ctypes.c_int64(),ctypes.c_double(),ctypes.c_double();assert init(ctypes.byref(handle),ctypes.byref(x),ctypes.byref(y))==0
nnode=60 if a.profile=='C0' else 20
obs=lib.strip01_observe_c;obs.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_int)]
fields_fn=lib.strip01_fields_c;fields_fn.argtypes=[ctypes.POINTER(ctypes.c_double)]
def state():
 s,r=(ctypes.c_double*50)(),(ctypes.c_int*50)();assert obs(s,r)==0
 f=(ctypes.c_double*((3*nnode+3)*50))();assert fields_fn(f)==0
 return list(s),list(r),list(f)
before=state();fn=lib.strip01_diagnose_response_c
fn.argtypes=[ctypes.c_int,ctypes.c_double,ctypes.c_double,ctypes.c_int,ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_char),ctypes.POINTER(ctypes.c_char)]
heads=({1:-4.996934702272599,50:-4.964812337059502} if a.profile=='C0' else {1:-0.994865526330005,50:-0.9742777220884193}) if a.head_reference=='actual' else ({1:-5.0,50:-4.5} if a.profile=='C0' else {1:-1.0,50:-0.5})
code_names=['canonical_status','accepted_substeps','solver_rejections','temporal_rejections','mass_rejections','admission_rejections','attempts','retries']
int_names=['interface_exchange_available','trajectory_result_requested','tangent_available','tangent_accepted_steps','control_coordinate','additional_tridiagonal_backsolves','additional_jacobian_builds']
real_names=['bottom_outward_exchange_native_cm','terminal_bottom_outward_flux_native_cm_per_day','accepted_bottom_exchange_derivative_native_cm_per_cm','origin_t_day','accepted_t_day']
rows=[]
for col,base in heads.items():
 for offset in (-1e-8,0.0,1e-8):
  for tangent in (False,True):
   codes,ri,rr=(ctypes.c_int*8)(),(ctypes.c_int*7)(),(ctypes.c_double*5)(); route,method=(ctypes.c_char*64)(),(ctypes.c_char*48)()
   assert fn(col,base+offset,0.001,int(tangent),codes,ri,rr,route,method)==0
   dec=lambda x:bytes(x).split(b'\0',1)[0].decode()
   rows.append({'column':col,'base_trial_head_m':base,'head_offset_m':offset,'trial_head_m':base+offset,'duration_day':0.001,'codes':dict(zip(code_names,list(codes))),'tangent_input_requested':tangent,**dict(zip(int_names,list(ri))),**dict(zip(real_names,list(rr))),'trajectory_route':dec(route),'trajectory_method':dec(method)})
after=state();assert before==after,'committed state, history, storage, or revision changed'
out={'state':'RESP01D_RESPONSE_PROBES_COMPLETED','profile':a.profile,'head_reference':a.head_reference,'max_retries':8,'committed_state_and_temporal_history_preserved':True,'probe_count':len(rows),'rows':rows}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(out,indent=2)+'\n')
for r in rows:print(r['column'],r['head_offset_m'],r['tangent_input_requested'],r['codes'],r['bottom_outward_exchange_native_cm'],r['accepted_bottom_exchange_derivative_native_cm_per_cm'],r['trajectory_route'],r['trajectory_method'])
