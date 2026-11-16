"""Read-only diagnosis: original NEXT18 streams plus two measured native routes."""
from pathlib import Path
import json,math,statistics,collections,hashlib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-next18'
def read(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def hist(xs):return dict(sorted(collections.Counter(xs).items()))
def metrics(c,a):
 h=math.fsum(x[6] for x in c);b=math.fsum(x[7] for x in c);span=math.fsum(x[8] for x in c)
 fail=[x for x in a if x[8]==4]
 return dict(commits=len(c),attempts=len(a),failed_attempts=len(fail),head_wall_seconds=h,budget_wall_seconds=b,measured_span_seconds=span,head_share=h/span,budget_share=b/span,failed_head_wall_seconds=math.fsum(x[-1] for x in fail),iteration_counter_histogram=hist(x[7] for x in a),failure_flags_histogram=dict(collections.Counter(str(x[12:17]) for x in fail)),worst_failure_nodes=dict(collections.Counter(int(x[19]) for x in fail).most_common(10)),sum_vector_calls=sum(x[20] for x in a),sum_jacobian_calls=sum(x[21] for x in a),sum_macro_rate_calls=sum(x[22] for x in a),sum_macro_derivative_calls=sum(x[23] for x in a),additional_line_search_trials=sum(x[24]-x[21] for x in a),fresh_certifications=sum(x[25] for x in a))
results=[];traces=[];costs=[];offline=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESUME';old=P/'data'/opt/'RESUME'
 budget=(d/'step_budget.txt').read_text().splitlines();prior=(old/'step_budget.txt').read_text().splitlines()
 assert budget==prior[:len(budget)]
 for name in ['begin','context_begin','ledger_begin','ledger_installed','native_installed']:
  assert (d/(name+'.txt')).read_bytes()==(old/(name+'.txt')).read_bytes()
 assert (d/'own.end').read_bytes()==(P/'data'/opt/'PREFIX/midnight.end').read_bytes()
 a=read(d/'attempt_trace.txt');c=read(d/'cost_trace.txt');assert len(c)==len(budget)
 assert all(len(x)==27 for x in a) and all(len(x)==10 for x in c)
 assert all(x[8] in [0,4] for x in a)
 assert sum(x[8]==0 for x in a)==len(c)
 # All failed outcomes are actually retried, never the original forced warning continuation.
 assert all(x[9] or x[10] for x in a if x[8]==4)
 assert all(x[15]==0 and x[16]==0 for x in a if x[8]==4)
 q=metrics(c,a)
 first=next(i for i,x in enumerate(a) if x[5]>x[4])
 assert a[first][3]==1e-5 and a[first][7]==61 and a[first][8]==4
 assert a[first][19]==52 and a[first][13]==1 and abs(a[first][17])>1e-5
 assert c[41][4]==.1
 windows=[]
 for lo,hi in [(0,.0714),(.0714,.25),(.25,.5),(.5,.67)]:
  cs=[v for v in c if lo<v[1]-35797<=hi];ids={int(v[0]) for v in cs};aa=[v for v in a if int(v[1]) in ids]
  windows.append(dict(from_fraction=lo,to_fraction=hi,commits=len(cs),attempts=len(aa),failed_attempts=sum(v[8]==4 for v in aa),head_seconds=math.fsum(v[-1] for v in aa)))
 late=[v for v in c if v[1]>=35797.5]
 q.update(optimization=opt,last_model_time=c[-1][1],first_reduction_trigger=a[first],first_reduced_commit=read(d/'step_budget.txt')[41],first_reduced_accept_attempt=a[first+1],reduction_level_increases=sum(v[5]>v[4] for v in a),reduction_level_decreases=sum(v[5]<v[4] for v in a),maximum_pre_reduction_level=max(v[4] for v in a),windows=windows,late_commits=len(late),late_growth_iteration_criterion_met=sum(v[3]<=4 for v in late),budget_prefix_exact=True,pre_head_exports_exact=True)
 run=json.loads((R/(opt+'_RESUME_RUN.json')).read_text());assert not run['censored'] and run['returncode']==0 and run['seconds']<20
 assert (d/'outcome.txt').exists();q['run_seconds']=run['seconds'];results.append(q);traces.append(a);costs.append(c)
 identity=json.loads((R/(opt+'_IDENTITY.json')).read_text())
 assert all(hashlib.sha256((R/n).read_bytes()).hexdigest()==h for n,h in identity['sources'].items())
 # All committed NEXT18 evidence retained, never a stitched continuation.
 x=read(old/'step_budget.txt');bins=[]
 for lo,hi in [(0,.0714),(.0714,.25),(.25,.5),(.5,.67),(.67,1)]:
  z=[v for v in x if lo<v[0]-35797<=hi]
  bins.append(dict(from_fraction=lo,to_fraction=hi,steps=len(z),median_dt_days=statistics.median(v[1] for v in z),reduced_steps=sum(v[16]<1 for v in z)))
 offline.append(dict(optimization=opt,source='NEXT18_RESUME',steps=len(x),flux_factors=hist(v[16] for v in x),first_factor_point01_time=next(v[0] for v in x if v[16]<.1),minimum_dt_days=min(v[1] for v in x),bins=bins))
n=min(map(len,costs));na=int(costs[0][n-1][5]);assert na==int(costs[1][n-1][5])
assert [x[:-1] for x in traces[0][:na]]==[x[:-1] for x in traces[1][:na]]
assert [x[:6] for x in costs[0][:n]]==[x[:6] for x in costs[1][:n]]
common=[metrics(c[:n],a[:na]) for c,a in zip(costs,traces)]
for q,opt in zip(common,['O0','O2']):q['optimization']=opt
for p in P.glob('*.f90'):
 if p.name!='soilwater_native.f90':assert (R/p.name).read_bytes()==p.read_bytes()
q=dict(work_unit='SWAP431-MACRO-B1-DIAG19',decision='DIAGNOSIS_ONLY_NO_PHYSICS_CORRECTION',model_routes=2,hard_timeout_seconds=20,early_stop='7000 commits or16 measured seconds',results=results,common_commits=n,common_attempts=na,common_non_timing_trace_exact=True,common_metrics=common,existing_evidence=offline,full_period_qualification=False,official_promotion=False)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
print(json.dumps(dict(results=[{k:v for k,v in z.items() if 'histogram' not in k and 'first_redu' not in k} for z in results],common_metrics=common),indent=2))
