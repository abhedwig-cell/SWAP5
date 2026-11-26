"""Read-only distinction between execution cap and nonlinear refusal on day27."""
from pathlib import Path
import json,collections,hashlib
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());reports=[];streams=[]
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])/'ORDINARY_V27_FIXED_DAY27';q=json.loads((b/'RESULT.json').read_text());rows=[];partial=0
 for line in (b/'original/jac37_trace.txt').read_text().splitlines():
  a=list(map(float,line.split()))
  if len(a)!=22:partial+=1;continue
  rows.append(a)
 assert q['status']=='MODEL_CAP_REACHED' and not q['rows'];assert rows
 bystep=collections.defaultdict(list)
 for a in rows:bystep[(a[0],a[1])].append(a)
 # These are recorded solver observations, not an accepted-step count or proof
 # that every physical endpoint succeeded. No day receipt/native checkpoint27.
 reports.append(dict(opt=opt,status=q['status'],elapsed_seconds=q['elapsed_seconds'],observed_solver_rows=len(rows),partial_tail_lines=partial,observed_step_contexts=len(bystep),first_time=rows[0][0],last_time=rows[-1][0],fraction_day_observed=rows[-1][0]-35821.,observed_dt_min=min(a[1] for a in rows),observed_dt_max=max(a[1] for a in rows),max_observed_iteration=max(a[2] for a in rows),helper_status_counts=dict(collections.Counter(str(int(a[3])) for a in rows)),max_handled_linear_residual=max(a[-1] for a in rows if a[3]==1),no_day27_accepted_receipt=True,source_sha256=hashlib.sha256((b/'original/jac37_trace.txt').read_bytes()).hexdigest()))
 streams.append(rows)
n=min(map(len,streams));assert streams[0][:n]==streams[1][:n]
out=dict(scope='Existing two capped day27routes only. Smooth progressing .002day iterations; execution boundary, not demonstrated dtmin nonlinear rejection. No rerun, tolerance extension or false daily acceptance.',results=reports,common_observed_trace_rows_exact=n,models_launched=0,next_boundary='Original20sperroute remains. Fullperiod blocked atday27. Profile nativecost/diagnosticoutput with existing evidence before any revised route; no speculation-driven physicschange.')
(R/'BLOCK29_DAY27_CAP_DIAGNOSIS.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
