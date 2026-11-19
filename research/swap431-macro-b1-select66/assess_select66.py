"""Audit existing bounded SELECT66 evidence; launches no model."""
from pathlib import Path
import json,hashlib,csv,math
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-combined63';B=R.parent/'swap431-macro-b1-reject64'
def rows(p):return [list(map(float,l.split())) for l in p.read_text().splitlines() if l.strip()]
def fields(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines() if l.strip()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(n,v):(R/n).write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
results=[]
for runfile in sorted(R.glob('*_RUN.json')):
 opt,profile=runfile.stem[:-4].split('_',1);d=R/'data'/opt/profile;run=json.loads(runfile.read_text())
 assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 at=rows(d/'attempt_trace.txt');tr=rows(d/'jac63_trace.txt');initial=fields(d/'context_initial.txt');baseline=fields(P/'data'/opt/'RESTART_D2/context_initial.txt')
 dif={k for k in initial if initial[k]!=baseline[k]};assert dif<= {'dt'}
 assert (d/'ledger_initial.txt').read_bytes()==(P/'data'/opt/'RESTART_D2/ledger_initial.txt').read_bytes()
 assert sha(d/'own.end')=='59988fe0728bc51006085bbc957afc16ddf50b23a5cbb644228716dff743748e'
 attempts=[]
 for a in at:
  active=[x for x in tr if x[0]==a[0] and x[2]==1];assert all(x[3]==1 and x[26]==1 for x in active)
  assert a[4:7]==[0,0,1]
  attempts.append(dict(attempt=int(a[0]),dt=a[3],rejected=a[8]==4,iterations=int(a[7])-(1 if a[8]==4 else 0),active_W=sum(x[4]==1 for x in active),active_V=sum(x[4]==2 for x in active),Fmax=a[18],sumF=a[17],fresh=int(a[25])))
 assert at[-1][8]==0 and at[-1][25]==1
 solver=fields(d/f'solver_{len(at)}.txt');assert max(map(abs,solver['residual']))<1e-6 and abs(sum(solver['residual']))<1e-5
 iv=rows(d/'inventory_trace.txt');assert len(iv)==1 and iv[0][11]==1
 limit=at[-1][3]*solver['controls'][6];assert abs(iv[0][9])<limit
 before=fields(d/f'follow_begin_{len(at)}.txt');after=fields(d/'follow_committed.txt')
 bctx=fields(d/f'context_follow_begin_{len(at)}.txt');actx=fields(d/'context_follow_committed.txt');v=rows(d/'step_budget.txt')[0];dt=v[1];assert dt==at[-1][3] and v[16]==1
 dm=math.fsum((b-a)*dz*fr for a,b,dz,fr in zip(before['theta'],after['theta'],before['dz'],before['fraction']))
 dx=math.fsum(b-a for a,b in zip(before['macro_compartment'],after['macro_compartment']))
 dp=after['pond'][0]-before['pond'][0];dc=actx['sicact'][0]-bctx['sicact'][0]
 external=dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
 error=dm+dx+dp+dc-external;assert abs(error)<limit and abs(error-iv[0][9])<2e-15 and abs(error-dt*sum(solver['residual']))<2e-15
 domain_errors=[]
 for k in range(5):
  dw=math.fsum(b-a for a,b in zip(before['macro_compartment'][k::5],after['macro_compartment'][k::5]));expected=dt*(v[17+k]+v[22+k]-v[27+k])-(dt*v[12] if k==0 else 0);domain_errors.append(dw-expected)
 assert max(map(abs,domain_errors))<1e-14
 rollback=None
 if len(at)>1:
  assert len(at)==2 and at[0][8]==4 and at[0][9]==1 and at[0][7]==31 and at[1][3]==1e-5
  pre=fields(d/'context_follow_begin_2.txt');diff={k for k in initial if initial[k]!=pre[k]};assert diff=={'dt','fldtmin'}
  assert (d/'ledger_initial.txt').read_bytes()==(d/'ledger_follow_begin_2.txt').read_bytes()
  rollback=dict(physical_context_exact_except_controller_dt_and_floor=True,ledger_exact=True,qualifies_V=False)
 results.append(dict(opt=opt,profile=profile,seconds=run['seconds'],attempts=attempts,hostcommits=1,independent_inventory=dict(matrix_delta=dm,macro_delta=dx,pond_delta=dp,canopy_delta=dc,external=external,error_cm=error,domain_errors_cm=domain_errors),inventory_error_cm=iv[0][9],inventory_limit_cm=limit,rollback=rollback))
comparisons=[]
for profile in ['SELECT8']:
 x=R/'data/O0'/profile;y=R/'data/O2'/profile;names=[p.name for p in x.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt']]
 for n in names:assert (x/n).read_bytes()==(y/n).read_bytes(),(profile,n)
 assert [a[:-1] for a in rows(x/'attempt_trace.txt')]==[a[:-1] for a in rows(y/'attempt_trace.txt')]
 assert sha(x/'follow.end')==sha(y/'follow.end')
 comparisons.append(dict(profile=profile,physical_text_files_exact=len(names),attempts_exact_except_elapsed=True,native_follow_packet_exact=True))
for p in R.glob('*.f90'):assert p.read_bytes()==(B/p.name).read_bytes(),p.name
sel=json.loads((R/'SELECTION_PROGRESS.json').read_text());assert len(sel['candidates'])==8 and sel['remaining_O0_selections']==0
lo=2.0903186152189966e-5;hi=2.0908533472519632e-5
for c in sel['candidates']:
 assert c['dt']==(lo+hi)/2
 if c['accepted']:lo=c['dt']
 else:hi=c['dt']
assert [lo,hi]==[sel['low'],sel['high']]
res=json.loads((R/'RESOURCE_PATHS.json').read_text())
for opt in ['O0','O2']:assert sha(Path(res[opt]['path'])/'native09.exe')==json.loads((R/(opt+'_IDENTITY.json')).read_text())['exe_sha256']
assert (R/'select66.py').read_bytes()==(R.parent/'swap431-macro-b1-select65/select65.py').read_bytes()
assert not any(a['rejected'] and a['active_V'] for r in results for a in r['attempts'])
q=dict(work_unit='SWAP431-MACRO-B1-SELECT66',decision='NO_TRUE_V_REJECTION_IN_EIGHT_BOUNDED_D2_PROPOSALS',model_routes=len(results),hard_seconds_per_route=20,all_normal_uncensored=True,source_and_binaries_unchanged_from_REJECT64=True,inherited_SELECT65_interval_only=True,O0_O2_comparisons=comparisons,actual_V_rejection_qualified=False,V_rollback_and_direct_smaller_retry_qualified=False,direct_smaller_retry_not_run_without_valid_V_rejected_origin=True,remaining_unsearched_interval=[sel['low'],sel['high']],interval_not_exhausted_and_no_monotonicity_claim=True,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',results=results)
save('RESULT.json',q);save('STATUS.json',dict(q,stage='BOUNDED_SELECTION_COMPLETE_V_REJECTION_GATE_OPEN',no_broad_campaign=True,official_promotion=False))
with (R/'SELECTION_AUDIT.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.writer(f);w.writerow(['opt','profile','seconds','attempt','dt','rejected','iterations','active_W','active_V','Fmax','sumF'])
 for r in results:
  for a in r['attempts']:w.writerow([r['opt'],r['profile'],r['seconds']]+[a[k] for k in ['attempt','dt','rejected','iterations','active_W','active_V','Fmax','sumF']])
print(q['decision'],len(results),max(r['seconds'] for r in results))
