"""Read-only actual host commit, primitive flux and independent water-stock check."""
from pathlib import Path
import json,math,hashlib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-jac24'
def fields(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
result=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESUME';old=P/'data'/opt/'RESUME'
 run=json.loads((R/(opt+'_RESUME_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 for n in ['begin','context_begin','ledger_begin','ledger_installed','native_installed','target_begin','context_target_begin','target_return','context_target_return','node_operator','node_iterations','domain3_limit','jac24_trace','jac24_calibration','solver_1']:
  assert (d/(n+'.txt')).read_bytes()==(old/(n+'.txt')).read_bytes(),n
 arows=rows(d/'attempt_trace.txt');orows=rows(old/'attempt_trace.txt')
 assert len(arows)==38 and [v[:-1] for v in arows]==[v[:-1] for v in orows]
 raw=(d/'step_budget.txt').read_text().splitlines();prior=(old/'step_budget.txt').read_text().splitlines()
 assert len(raw)==37 and len(prior)==36 and raw[:36]==prior
 x=list(map(float,raw[-1].split()));assert len(x)==32 and x[16]==1
 a=fields(d/'target_begin.txt');b=fields(d/'committed.txt');ret=fields(d/'target_return.txt')
 ca=fields(d/'context_target_begin.txt');cb=fields(d/'context_committed.txt')
 la=fields(d/'ledger_target_begin.txt');lb=fields(d/'ledger_committed.txt')
 assert (d/'ledger_target_begin.txt').read_bytes()==(d/'ledger_target_return.txt').read_bytes()
 dt=x[1];assert dt==a['controls'][1]==.0013333333333333333
 assert b['controls'][0]==x[0] and abs(b['controls'][0]-a['controls'][0]-dt)<5e-12
 assert b['controls'][1]==.002 # original next-step control, not used dt
 assert b['policy'][:2]==[1,0] and b['controls'][2]==0 and b['controls'][7]==0
 assert b['h']==ret['h'] and b['theta']==ret['theta']
 assert len(rows(d/'cost_trace.txt'))==37
 assert 'COMMIT25_HOST_COMMITTED' in (d/'outcome.txt').read_text()
 assert b['macro_domain']!=a['macro_domain'] and b['clock']!=a['clock'] and b['wet_wall']!=a['wet_wall']
 matrix=math.fsum((v-u)*dz*f for u,v,dz,f in zip(a['theta'],b['theta'],a['dz'],a['fraction']))
 macro=math.fsum(v-u for u,v in zip(a['macro_domain'],b['macro_domain']))
 pond=b['pond'][0]-a['pond'][0];canopy=cb['sicact'][0]-ca['sicact'][0]
 gross=dt*(x[2]+x[3]+x[4]-x[5]-x[6]-x[7]-x[8]+x[9]-x[10]+x[11]-x[12])-x[13]
 net=dt*(x[14]+x[15]+x[4]-x[6]-x[7]-x[8]+x[9]-x[10]+x[11]-x[12])-x[13]
 error=matrix+macro+pond+canopy-gross;neterr=matrix+macro+pond-net
 assert abs(error)<dt*1e-5 and abs(error-neterr)<1e-15
 assert abs(error-dt*arows[-1][17])<1e-15
 assert abs(canopy-dt*(ca['crsflx_in'][0]-ca['crsflx_out'][0]))<1e-15
 assert x[13]==0 and math.fsum(b['matrix_immob'])==0
 for state in [a,b]:
  assert abs(state['matrix_stored'][0]-math.fsum(t*dz*f for t,dz,f in zip(state['theta'],state['dz'],state['fraction'])))<1e-12
  assert abs(state['macro_total'][0]-math.fsum(state['macro_domain']))<1e-14
  for j in range(5):
   assert state['macro_domain'][j]>=0 and abs(state['macro_domain'][j]-math.fsum(state['macro_compartment'][j::5]))<1e-14
 domains=[]
 for j in range(5):
  e=b['macro_domain'][j]-a['macro_domain'][j]-dt*(x[17+j]+x[22+j]-x[27+j]-(x[12] if j==0 else 0))
  assert abs(e)<1e-13;domains.append(e)
 # Real cumulative changes must equal primitive selected-step integrations.
 ledger_errors={}
 for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12),('cnrai',14),('cnird',15)]:
  e=lb[key][0]-la[key][0]-dt*x[col];assert abs(e)<1e-12;ledger_errors[key]=e
 assert abs(lb['crunoff'][0]-la['crunoff'][0]-x[13])<1e-15
 for suffix,ids in [('1',[0]),('2',[1,2,3,4])]:
  for part,col in [('intoplat',17),('intopvrt',22)]:
   key='cqmp'+part+'dm'+suffix
   assert abs(lb[key][0]-la[key][0]-dt*math.fsum(x[col+j] for j in ids))<1e-12
  def exchange(L):return L['cqmpinintsatdm'+suffix][0]+L['cqmpinmtxsatdm'+suffix][0]-L['cqmpoutmtxsatdm'+suffix][0]-L['cqmpoutmtxunsdm'+suffix][0]
  assert abs(exchange(lb)-exchange(la)+dt*math.fsum(x[27+j] for j in ids))<1e-12
 # Preserve the original minimum stock, not merely the total volume bound.
 final_limit=rows(d/'domain3_limit.txt')[-1]
 assert final_limit[0]==38 and final_limit[5]==3
 assert abs(b['macro_domain'][2]-final_limit[13])<1e-14
 assert b['macro_domain'][2]>=final_limit[13]-1e-15
 assert la['sicini']==lb['sicini'] and la['sicini'][0]>0
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==h for n,h in ident['sources'].items())
 result.append(dict(optimization=opt,seconds=run['seconds'],hostcommit=True,head_JAC24_byte_exact=True,accepted_budget_rows=37,prior_rows_byte_exact=36,head_attempts=38,begin_t1900=a['controls'][0],committed_t1900=b['controls'][0],used_dt_days=dt,next_dt_days=b['controls'][1],flux_factor=x[16],matrix_stock_change_cm=matrix,macro_stock_change_cm=macro,pond_change_cm=pond,canopy_change_cm=canopy,gross_external_integral_cm=gross,whole_inventory_error_cm=error,net_inventory_error_cm=neterr,original_total_residual_integral_limit_cm=dt*1e-5,domain_balance_errors_cm=domains,domain3_final_stock_cm=b['macro_domain'][2],domain3_original_min_stock_cm=final_limit[13],ledger_primitive_errors_cm=ledger_errors,canopy_initial_cm=ca['sicact'][0],canopy_final_cm=cb['sicact'][0],ledger_applied_only_by_real_host_integral=True))
for p in (R/'data/O0/RESUME').glob('*.txt'):
 if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
 assert p.read_bytes()==(R/'data/O2/RESUME'/p.name).read_bytes(),p.name
assert [v[:-1] for v in rows(R/'data/O0/RESUME/attempt_trace.txt')]==[v[:-1] for v in rows(R/'data/O2/RESUME/attempt_trace.txt')]
for p in P.glob('*.f90'):
 if p.name!='soilwater_native.f90':assert (R/p.name).read_bytes()==p.read_bytes(),p.name
q=dict(work_unit='SWAP431-MACRO-B1-COMMIT25',decision='PASS_LOCAL_HOST_COMMIT_AND_WATER_INVENTORY_O0_O2',model_routes=2,hard_timeout_seconds=20,all_uncensored=True,non_timing_O0_O2_byte_exact=True,solver_physics_criteria_dt_reduction_changes=False,driver_changes_only=True,scope='One original target step through real hostcommit, no nextstep, refusal/rollback/retry/restart/period admission',official_promotion=False,results=result)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
