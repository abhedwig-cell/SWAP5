from pathlib import Path
import json,math,hashlib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-native09'
def f(p):return {s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
results=[]
for opt in ['O0','O2']:
 c=R/'data'/opt/'CONTINUE';r=R/'data'/opt/'RESUME'
 for n in ['crossed','nextday_begin','nextday','context_crossed','context_nextday','nextday_return']:
  assert (c/(n+'.txt')).read_bytes()==(r/(n+'.txt')).read_bytes(),(opt,n)
 a=f(c/'cross_return.txt');b=f(r/'cross_return.txt')
 assert all(a[k]==b[k] for k in a if k!='matrix_vertical')
 assert (c/'checkpoint.txt').read_bytes()==(c/'after_io.txt').read_bytes()
 assert (c/'context_checkpoint.txt').read_bytes()==(r/'native_installed.txt').read_bytes()
 assert (c/'daycheckpoint.end').read_bytes()==(r/'own.end').read_bytes()
 rows=[]
 for step,end in [('cross','crossed'),('nextday','nextday')]:
  a=f(c/(step+'_begin.txt'));b=f(c/(end+'.txt'));t=f(c/(step+'_return.txt'));dt=a['controls'][1];nd=int(a['controls'][4])
  matrix=math.fsum((y-x)*d*z for x,y,d,z in zip(a['theta'],b['theta'],a['dz'],a['fraction']))
  macro=math.fsum(y-x for x,y in zip(a['macro_domain'],b['macro_domain']));pond=b['pond'][0]-a['pond'][0]
  qt,qb,rain,irr,melt,runon,evp,eva=t['boundary_rates']
  external=dt*(rain+irr+melt+runon-evp-eva+qb-math.fsum(t['matrix_root'])-math.fsum(t['matrix_drains'])+math.fsum(t['matrix_ssdi'])-math.fsum(t['macro_rapid']))-t['surface'][0]
  error=matrix+macro+pond-external;assert abs(error)<dt*1e-5+1e-12
  domains=[]
  for j in range(nd):
   rate=t['macro_in_lat'][j]+t['macro_in_vert'][j]-math.fsum(t['macro_exchange'][j::nd])-(math.fsum(t['macro_rapid']) if j==0 else 0)
   e=b['macro_domain'][j]-a['macro_domain'][j]-dt*rate;assert abs(e)<1e-13;domains.append(e)
  pair=max(abs(math.fsum(t['macro_exchange'][j:j+nd])-x) for j,x in zip(range(0,len(t['macro_exchange']),nd),t['matrix_exchange']));assert pair<1e-13
  assert t['controls'][-1]==0 and t['controls'][2]==0
  rows.append(dict(step=step,begin=a['controls'][0],dt=dt,end=b['controls'][0],combined_inventory_error_cm=error,domain_errors_cm=domains,paired_exchange_error=pair))
 assert rows[0]['end']==35797 and rows[1]['begin']==35797 and rows[1]['end']>35797
 results.append(dict(optimization=opt,steps=rows,checkpoint=f(c/'checkpoint.txt')['controls'][0]))
for mode in ['CONTINUE','RESUME']:
 for p in (R/'data/O0'/mode).glob('*.txt'):assert p.read_bytes()==(R/'data/O2'/mode/p.name).read_bytes(),str(p)
for n in ['native_state.f90','macropore_native.f90','meteo_native.f90','swapoutput_native.f90','swap_native.f90']:
 assert (R/n).read_bytes()==(P/n).read_bytes(),n
for opt in ['O0','O2']:
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text())
 for n,h in ident['sources'].items():assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h
runs=[json.loads(p.read_text()) for p in R.glob('*_RUN.json')];assert len(runs)==4 and all(x['returncode']==0 and not x['censored'] and x['seconds']<20 for x in runs)
q=dict(decision='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',day_crossing='PASS_LAST_SUBDAY_OWN_CHECKPOINT_CROSSING_AND_FIRST_NEXTDAY_STEP_O0_O2',results=results,physical_and_format_changes=False,source_boundary='Only soilwater qualification harness changed',model_routes=4,max_seconds=max(x['seconds'] for x in runs),no_censored=True,full_campaign=False,exclusions=['No checkpoint AT midnight/dayend: existing subday file guard unchanged','No cumulative output/PEARL continuity claim','No other modes/reduced state/dry h0 transitions or official promotion'])
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
