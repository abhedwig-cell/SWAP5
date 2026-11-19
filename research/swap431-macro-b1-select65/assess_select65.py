"""Audit existing bounded SELECT65 evidence; launches no model."""
from pathlib import Path
import json,hashlib,csv
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
 rollback=None
 if len(at)>1:
  assert len(at)==2 and at[0][8]==4 and at[0][9]==1 and at[0][7]==31 and at[1][3]==1e-5
  pre=fields(d/'context_follow_begin_2.txt');diff={k for k in initial if initial[k]!=pre[k]};assert diff=={'dt','fldtmin'}
  assert (d/'ledger_initial.txt').read_bytes()==(d/'ledger_follow_begin_2.txt').read_bytes()
  rollback=dict(physical_context_exact_except_controller_dt_and_floor=True,ledger_exact=True,qualifies_V=False)
 results.append(dict(opt=opt,profile=profile,seconds=run['seconds'],attempts=attempts,hostcommits=1,inventory_error_cm=iv[0][9],inventory_limit_cm=limit,rollback=rollback))
comparisons=[]
for profile in ['SELECT4','SELECT8']:
 x=R/'data/O0'/profile;y=R/'data/O2'/profile;names=[p.name for p in x.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt']]
 for n in names:assert (x/n).read_bytes()==(y/n).read_bytes(),(profile,n)
 assert [a[:-1] for a in rows(x/'attempt_trace.txt')]==[a[:-1] for a in rows(y/'attempt_trace.txt')]
 assert sha(x/'follow.end')==sha(y/'follow.end')
 comparisons.append(dict(profile=profile,physical_text_files_exact=len(names),attempts_exact_except_elapsed=True,native_follow_packet_exact=True))
ref=R/'data/O0/REFERENCE_UPPER';original=P/'data/O0/RESTART_D2'
for n in ['context_initial.txt','context_committed.txt','ledger_initial.txt','ledger_committed.txt','jac63_trace.txt','inventory_trace.txt','follow.end']:
 assert (ref/n).read_bytes()==(original/n).read_bytes(),n
assert [a[:-1] for a in rows(ref/'attempt_trace.txt')]==[a[:-1] for a in rows(original/'attempt_trace.txt')]
for p in R.glob('*.f90'):assert p.read_bytes()==(B/p.name).read_bytes(),p.name
sel=json.loads((R/'SELECTION_PROGRESS.json').read_text());assert len(sel['candidates'])==8 and sel['remaining_O0_selections']==0
assert not any(a['rejected'] and a['active_V'] for r in results for a in r['attempts'])
q=dict(work_unit='SWAP431-MACRO-B1-SELECT65',decision='NO_TRUE_V_REJECTION_IN_EIGHT_BOUNDED_D2_PROPOSALS',model_routes=len(results),hard_seconds_per_route=20,all_normal_uncensored=True,source_and_binaries_unchanged_from_REJECT64=True,original_upper_reference_reproduces_COMBINED63=True,O0_O2_comparisons=comparisons,actual_V_rejection_qualified=False,V_rollback_and_direct_smaller_retry_qualified=False,direct_smaller_retry_not_run_without_valid_V_rejected_origin=True,remaining_unsearched_interval=[sel['low'],sel['high']],interval_not_exhausted_and_no_monotonicity_claim=True,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',results=results)
save('RESULT.json',q);save('STATUS.json',dict(q,stage='BOUNDED_SELECTION_COMPLETE_V_REJECTION_GATE_OPEN',no_broad_campaign=True,official_promotion=False))
with (R/'SELECTION_AUDIT.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.writer(f);w.writerow(['opt','profile','seconds','attempt','dt','rejected','iterations','active_W','active_V','Fmax','sumF'])
 for r in results:
  for a in r['attempts']:w.writerow([r['opt'],r['profile'],r['seconds']]+[a[k] for k in ['attempt','dt','rejected','iterations','active_W','active_V','Fmax','sumF']])
print(q['decision'],len(results),max(r['seconds'] for r in results))
