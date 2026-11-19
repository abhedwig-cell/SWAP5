"""Read-only bounded selection audit; does not fabricate a rejected step."""
from pathlib import Path
from collections import Counter
import json,hashlib,csv,math
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-combined63'
def rows(p):return [[float(v) for v in s.split()] for s in p.read_text().splitlines() if s.strip()]
def fields(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines() if s.strip()}
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(n,q):(R/n).write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
results=[];summary=[]
for opt,prof in [('O0','SELECT1'),('O0','SELECT2'),('O0','SELECT3'),('O2','SELECT3')]:
 d=R/'data'/opt/prof;run=json.loads((R/(opt+'_'+prof+'_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 at=rows(d/'attempt_trace.txt');assert len(at)==1;at=at[0];tr=rows(d/'jac63_trace.txt')
 assert at[0]==1 and at[8]==0 and at[4:7]==[0,0,1] and at[9:11]==[0,0] and at[25]==1
 active=[x for x in tr if x[2]==1];V=[x for x in active if x[4]==2];assert len(V)>0 and all(x[3]==1 and x[26]==1 for x in V)
 assert 'NATIVE55_RESTART_ONE_FULL_STEP' in (d/'outcome.txt').read_text()
 control=rows(d/'input_control64.txt')[0];assert control[0]==2.0951312035156963e-5 and control[2]==1e-5 and control[3]==0 and control[1]==at[3]
 assert control[2]<control[1]<control[0]
 before=fields(d/'context_initial.txt');baseline=fields(P/'data'/opt/'RESTART_D2/context_initial.txt')
 assert {k for k in baseline if baseline[k]!=before[k]}=={'dt'}
 assert (d/'ledger_initial.txt').read_bytes()==(P/'data'/opt/'RESTART_D2/ledger_initial.txt').read_bytes()
 assert sha(d/'own.end')=='59988fe0728bc51006085bbc957afc16ddf50b23a5cbb644228716dff743748e'
 assert not (d/'follow_begin_2.txt').exists() and not (d/'context_follow_begin_2.txt').exists()
 budget=rows(d/'step_budget.txt');iv=rows(d/'inventory_trace.txt');assert len(budget)==len(iv)==1
 solver=fields(d/'solver_1.txt');F=solver['residual'];assert max(map(abs,F))<1e-6 and abs(sum(F))<1e-5
 dt=at[3];error=iv[0][9];limit=dt*solver['controls'][6];assert abs(error)<limit
 assert (d/'follow.end').exists() and iv[0][11]==1
 results.append(dict(optimization=opt,profile=prof,seconds=run['seconds'],returncode=0,censored=False,dt=dt,initial_physical_state_exact_except_trial_dt=True,original_native_packet_sha256=sha(d/'own.end'),step_accepted=True,step_rejected=False,iterations=int(at[7]),fresh_checks=int(at[25]),Fmax=at[18],sumF=at[17],active_W=sum(x[4]==1 for x in active),active_V=len(V),eligible_V_iterations=[int(x[1]) for x in V],accepted_hostcommits=1,no_retry_or_rollback_event=True,FrReduQ=1,IDecMpRat=0,inventory_error_cm=error,existing_inventory_limit_cm=limit,own_follow_packet_sha256=sha(d/'follow.end')))
 summary.append([opt,prof,dt,int(at[7]),at[18],at[17],len(V),run['seconds'],error,limit])
x=R/'data/O0/SELECT3';y=R/'data/O2/SELECT3';names=[p.name for p in x.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt']]
for n in names:assert (x/n).read_bytes()==(y/n).read_bytes(),n
assert [a[:-1] for a in rows(x/'attempt_trace.txt')]==[a[:-1] for a in rows(y/'attempt_trace.txt')]
assert sha(x/'follow.end')==sha(y/'follow.end')
for p in P.glob('*.f90'):
 if p.name!='soilwater_native.f90':assert (R/p.name).read_bytes()==p.read_bytes(),p.name
# No change below the harness wrapper: actual native retry/controller/physics implementation is identical.
s=(R/'soilwater_native.f90').read_text();old=(P/'soilwater_native.f90').read_text();assert s[s.index('subroutine capture33()'):]==old[old.index('subroutine capture33()'):]
sel=json.loads((R/'SELECTION_PROGRESS.json').read_text());assert len(sel['candidates'])==3 and sel['remaining_O0_selections']==0 and not sel['found_active_V_rejection']
with (R/'SELECTION_AUDIT.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.writer(f);w.writerow(['opt','profile','dt','iterations','Fmax','sumF','active_V','seconds','inventory_error_cm','existing_limit_cm']);w.writerows(summary)
q=dict(work_unit='SWAP431-MACRO-B1-REJECT64',decision='NO_TRUE_V_STEP_REJECTION_IN_THREE_BOUNDED_ORIGINAL_D2_PROPOSALS',model_routes=4,O0_selection_routes=3,O2_confirmation_routes=1,hard_seconds_per_route=20,all_routes_normal_uncensored=True,selected_V_activity_proven=True,selected_step_rejections=0,no_forced_rejection_or_solver_guard_criterion_change=True,O0_O2_last_proposal_physical_traces_and_packet_exact=True,O0_O2_text_files_compared=len(names),actual_V_rejection_qualified=False,V_rollback_and_direct_smaller_retry_qualified=False,direct_smaller_retry_not_run_without_valid_rejected_origin=True,unsearched_interval=[sel['low'],sel['high']],unsearched_interval_not_claimed_monotone_or_exhausted=True,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',results=results)
save('RESULT.json',q);save('STATUS.json',dict(q,stage='BOUNDED_SELECTION_COMPLETE_REQUESTED_V_REJECTION_GATE_OPEN',recovery='REPORT.md; RESULT.json; SELECTION_PROGRESS.json; SELECTION_AUDIT.csv; CODEX_FOLLOWUP.md; EVIDENCE.json',no_broad_campaign=True,official_promotion=False))
print(json.dumps(dict(decision=q['decision'],routes=q['model_routes'],active_V=[x['active_V'] for x in results],accepted_iterations=[x['iterations'] for x in results],remaining_interval=q['unsearched_interval']),indent=2))
