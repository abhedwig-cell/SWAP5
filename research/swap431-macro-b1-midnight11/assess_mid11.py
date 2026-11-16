from pathlib import Path
import json,math,hashlib
R=Path(__file__).resolve().parent
f=lambda p:{s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
results=[]
for opt in ['O0','O2']:
 c=R/'data'/opt/'CONTINUE';r=R/'data'/opt/'RESUME'
 assert (c/'context_checkpoint.txt').read_bytes()==(r/'native_installed.txt').read_bytes()
 assert (c/'checkpoint.txt').read_bytes()==(c/'after_io.txt').read_bytes()
 assert (c/'midnight.end').read_bytes()==(r/'own.end').read_bytes()
 for n in ['context_begin','context_accepted','accepted']:
  assert (c/(n+'.txt')).read_bytes()==(r/(n+'.txt')).read_bytes(),(opt,n)
 a=f(c/'returned.txt');b=f(r/'returned.txt');assert all(a[k]==b[k] for k in a if k!='matrix_vertical')
 ctx=f(c/'context_checkpoint.txt');assert ctx['t1900']==[35797.] and ctx['fldaystart']==ctx['fldayend']==[1.]
 balances=[]
 for d in [c,r]:
  a=f(d/'begin.txt');b=f(d/'accepted.txt');t=f(d/'returned.txt');dt=a['controls'][1];nd=5
  assert a['controls'][0]==35797 and b['controls'][0]>35797 and t['controls'][-1]==0
  matrix=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(a['theta'],b['theta'],a['dz'],a['fraction']))
  mp=math.fsum(y-x for x,y in zip(a['macro_domain'],b['macro_domain']));pd=b['pond'][0]-a['pond'][0]
  qt,qb,rain,irr,melt,runon,epd,reva=t['boundary_rates']
  external=dt*(rain+irr+melt+runon-epd-reva+qb-math.fsum(t['matrix_root'])-math.fsum(t['matrix_drains'])+math.fsum(t['matrix_ssdi'])-math.fsum(t['macro_rapid']))-t['surface'][0]
  error=matrix+mp+pd-external;assert abs(error)<dt*1e-5+1e-12
  for j in range(nd):
   rate=t['macro_in_lat'][j]+t['macro_in_vert'][j]-math.fsum(t['macro_exchange'][j::nd])-(math.fsum(t['macro_rapid']) if j==0 else 0)
   assert abs(b['macro_domain'][j]-a['macro_domain'][j]-dt*rate)<1e-13
  pair=max(abs(math.fsum(t['macro_exchange'][j:j+5])-v) for j,v in zip(range(0,560,5),t['matrix_exchange']));assert pair<1e-13
  balances.append(dict(begin=a['controls'][0],dt=dt,end=b['controls'][0],inventory_error_cm=error,paired_exchange_error=pair))
 assert balances[0]==balances[1];results.append(dict(optimization=opt,step=balances[0]))
for mode in ['CONTINUE','RESUME']:
 for p in (R/'data/O0'/mode).glob('*.txt'):assert p.read_bytes()==(R/'data/O2'/mode/p.name).read_bytes()
for opt in ['O0','O2']:
 q=json.loads((R/(opt+'_IDENTITY.json')).read_text())
 for n,h in q['sources'].items():assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h
for label in ['PHASE','V1DAY']:
 q=json.loads((R/('O2_RESUME_'+label+'_RUN.json')).read_text());assert q['returncode']!=0 and not q['censored'] and 'MID11' in q['stderr']
 assert not (R/'data/O2'/('RESUME_'+label)/'native_installed.txt').exists()
runs=[json.loads(p.read_text()) for p in R.glob('*_RUN.json')];assert len(runs)==6 and all(not q['censored'] and q['seconds']<20 for q in runs)
q=dict(decision='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',midnight_restart='PASS_COMPLETED_DAY_PHASE_EXACT_35797_O0_O2_ONE_NEXTDAY_STEP',results=results,phase='After all original dayend crop/output actions, before next loop TimeControl2',format='V2 completed-day header; V1 read remains subday-only',guards=['Invalid V2 phase rejected before install','Day state masquerading as V1 rejected before install'],physical_solver_changes=False,model_routes=6,max_seconds=max(q['seconds'] for q in runs),exclusions=['No intermediate dayend checkpoint before crop/output completion','No cumulative/PEARL/output-ledger continuity','No general midnight/other mode/reduced state/full trajectory or official promotion'])
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
