"""Assess the two bounded diagnostics, without rerunning prefixes."""
from pathlib import Path
import json,hashlib,math,collections,statistics
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-prefix14'
result=[];traces={}
for opt in ['O2','O0']:
 d=R/'data'/opt/'PREFIX';q=json.loads((R/(opt+'_PREFIX_RUN.json')).read_text())
 assert q['returncode']==0 and not q['censored'] and q['seconds']<20
 assert (d/'outcome.txt').read_text().split()[0]=='COST15_BOUNDED_DIAGNOSTIC'
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text())
 for n,h in ident['sources'].items():assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h
 b=(d/'step_budget.txt').read_text().splitlines();old=(P/'data'/opt/'PREFIX/step_budget.txt').read_text().splitlines()
 assert b==old[:len(b)]
 for n in ['initial.txt','ledger_initial.txt','context_initial.txt']:
  assert (d/n).read_bytes()==(P/'data'/opt/'PREFIX'/n).read_bytes()
 a=[list(map(float,s.split())) for s in (d/'cost_trace.txt').read_text().splitlines()];traces[opt]=a
 assert len(a)==len(b) and len(a)<=700 and all(len(x)==(18 if opt=='O0' else 17) for x in a)
 assert all(x[4]==1 and x[9]==x[6] and x[3]<=6 for x in a)
 assert all(float(x.split()[16])==1 for x in b)
 span=math.fsum(x[15] for x in a);head=math.fsum(x[14] for x in a)
 bins=[]
 for label,group in [('first100',a[:100]),('last100',a[-100:])]:
  bins.append(dict(window=label,mean_head_wall_seconds=statistics.mean(x[14] for x in group),mean_span_wall_seconds=statistics.mean(x[15] for x in group),mean_budget_IO_wall_seconds=statistics.mean(x[17] for x in group) if opt=='O0' else None,mean_iterations=statistics.mean(x[3] for x in group)))
 result.append(dict(optimization=opt,steps=len(a),last_model_time=a[-1][1],model_call_wall_seconds=q['seconds'],trace_elapsed_seconds=a[-1][16],measured_span_wall_seconds=span,head_wall_seconds=head,head_wall_fraction=head/span,non_head_wall_seconds=span-head,head_CPU_quantized_seconds=math.fsum(x[11] for x in a),macro_CPU_quantized_seconds=math.fsum(x[12] for x in a),span_CPU_quantized_seconds=math.fsum(x[13] for x in a),
  budget_IO_wall_seconds=math.fsum(x[17] for x in a) if opt=='O0' else None,budget_IO_fraction=math.fsum(x[17] for x in a)/span if opt=='O0' else None,
  iteration_counts=dict(collections.Counter(int(x[3]) for x in a)),fresh_certification_counts=dict(collections.Counter(int(x[10]) for x in a)),total_vector_calls=sum(int(x[5]) for x in a),total_jacobian_calls=sum(int(x[6]) for x in a),total_rate_calls=sum(int(x[7]) for x in a),total_derivative_calls=sum(int(x[8]) for x in a),extra_line_search_trials=0,refusals=0,flux_reductions=0,budget_matches_existing_prefix_exact=True,windows=bins))
n=min(map(len,traces.values()))
assert all(x[:11]==y[:11] for x,y in zip(traces['O0'][:n],traces['O2'][:n]))
assert result[1]['budget_IO_fraction']>.9
# Cost observations introduce no new physical/provider/native format changes.
for name in ['ledger_state.f90','macropore_native.f90','meteo_native.f90','native_state.f90','swapoutput_native.f90','swap_native.f90']:
 assert (R/name).read_bytes()==(P/name).read_bytes(),name
q=dict(work_unit='SWAP431-MACRO-B1-COST15',decision='DIAGNOSIS_IDENTIFIES_STEP_BUDGET_IO_AS_DOMINANT_MEASURED_COST',results=result,common_counter_records_exact=n,model_routes=2,route_cap_seconds=20,diagnostic_early_stop='700 commits or16seconds at accepted commit',physics_solver_changes=False,full_period_qualification=False,
 conclusion='Direct O0 group timing attributes >90% of measured continuation wall time to the original step_budget append open/write/close; O2 independently shows headcalc is a small fraction. No solver stagnation in the measured common prefix.',
 limitations=['Direct budget I/O timing exists only for O0; O2 has head/host timing','CPU_TIME readings are quantized; per-call zeros do not mean no CPU and do not support fine macro component ranking','Measurements stop before PREFIX14 end; later prefix/target35797 behavior is unmeasured','Cause inside OS/filesystem/open/format/write/close is not separated; no disk/antivirus/sync attribution','No logging optimization or speedup/full-period completion demonstrated'],
 next_safe_step='Optimize only diagnostic budget logging with one open buffered stream or in-memory records, preserve primitive rows exactly, then separately select the same bounded prefix capture. Do not change Newton/physics/tolerances/dt or timeout.',official_promotion=False)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
