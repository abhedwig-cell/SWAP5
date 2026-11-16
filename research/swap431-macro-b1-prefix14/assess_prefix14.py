"""Assess bounded censored prefix captures; never infers missing period PASS."""
from pathlib import Path
import json,hashlib,math
R=Path(__file__).resolve().parent
def fields(p):return {s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
rows={};result=[]
for opt in ['O0','O2']:
 q=json.loads((R/(opt+'_PREFIX_RUN.json')).read_text());assert q['censored']
 d=R/'data'/opt/'PREFIX';assert not (d/'midnight.end').exists() and not (d/'checkpoint.txt').exists()
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text())
 for n,h in ident['sources'].items():assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h
 lines=(d/'step_budget.txt').read_text().splitlines();rows[opt]=lines
 a=[list(map(float,s.split())) for s in lines];assert all(len(x)==32 for x in a)
 assert all(x[1]>0 and x[16]==1 for x in a)
 assert all(x[0]<35797 for x in a) and all(x[0]<y[0] for x,y in zip(a,a[1:]))
 initial=fields(d/'initial.txt');assert initial['controls'][0]==35795
 result.append(dict(optimization=opt,status='CENSORED_AT_20_SECOND_LIMIT',wall_seconds_including_termination=q['seconds'],accepted_step_records=len(a),last_record_time=a[-1][0],last_dt=a[-1][1],unreduced_record_count=len(a),original_matrix_inventory_cm=initial['matrix_stored'][0],original_macro_MB_cm=initial['macro_domain'][0],original_macro_IC_cm=math.fsum(initial['macro_domain'][1:]),original_macro_total_cm=initial['macro_total'][0],full_period_checkpoint_available=False))
n=min(len(x) for x in rows.values());assert rows['O0'][:n]==rows['O2'][:n]
for name in ['initial.txt','ledger_initial.txt','context_initial.txt']:
 assert (R/'data/O0/PREFIX'/name).read_bytes()==(R/'data/O2/PREFIX'/name).read_bytes()
q=dict(work_unit='SWAP431-MACRO-B1-PREFIX14',decision='PREFIX_CAPTURE_CENSORED_FULL_PERIOD_NOT_QUALIFIED',candidate='Existing V1 plus unchanged CONTRACT06 Darcy correction active from first head/original balance origin, with explicit LEDGER12 output history owner',period_origin=35795,target_completed_day_boundary=35797,results=result,common_exact_step_records=n,initial_exports_O0_O2_byte_exact=True,configured_route_timeout_seconds=20,model_routes=2,additional_retries=0,own_resume_routes_not_launched='No completed period file exists',full_period_balance='NOT_QUALIFIED',partial_balance='No independent endpoint snapshot at timeout; no partial balance PASS inferred from flux records',metadata_implementation='V4 origin/end/complete-policy record implemented/compiled but not exercised at target, therefore unqualified',io_check='IO_CHECK.json is only a no-model microbenchmark; it does not establish logging as the dominant cause of the limit',official_reference_promoted=False,production_changed=False,next_safe_step='Retain cap result and exact original inventories. Any future progress requires separately selected bounded diagnosis of the fixed-candidate prefix cost/convergence; no silent timeout increase, chunking, variant substitution or campaign.')
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
