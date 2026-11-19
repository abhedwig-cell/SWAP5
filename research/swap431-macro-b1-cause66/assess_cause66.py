"""Causal discriminator; zero model calls and no acceptance weakening."""
from pathlib import Path
import json,math,hashlib,sys
R=Path(__file__).resolve().parent
W=Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e/cause66-data')
D=Path(sys.argv[1]) if len(sys.argv)>1 else W/'evidence/data'
B=Path(sys.argv[2]) if len(sys.argv)>2 else W/'coupled65'
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines() if s.strip()]
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
reproduction={};crossover=[]
for mode in ['CHAIN','DIRECT']:
    a=B/('O0_'+mode);b=D/('O0_OBS_'+mode+'_NONE')
    names=[p.name for p in a.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt']]
    for n in names:assert (a/n).read_bytes()==(b/n).read_bytes(),n
    assert sha(a/'follow.end')==sha(b/'follow.end')
    assert [x[:-1] for x in rows(a/'attempt_trace.txt')]==[x[:-1] for x in rows(b/'attempt_trace.txt')]
    reproduction[mode]=dict(exact_texts=names,exact_packet=True,attempts_exact_except_timing=True)
for a,b,ai,bi in [('O0_OBS_CHAIN_SMALL','O0_OBS_DIRECT_NONE',2,1),('O0_OBS_DIRECT_LARGE','O0_OBS_CHAIN_NONE',1,2)]:
    x,y=D/a,D/b;names=[]
    for n,m in [('solver_'+str(ai)+'.txt','solver_'+str(bi)+'.txt'),('follow_committed.txt','follow_committed.txt'),('context_follow_committed.txt','context_follow_committed.txt'),('ledger_final.txt','ledger_final.txt'),('step_budget.txt','step_budget.txt'),('follow.end','follow.end')]:
        assert (x/n).read_bytes()==(y/m).read_bytes(),(a,n);names.append(n)
    f=rows(x/'cause66_F0.txt');g=rows(y/'cause66_F0.txt');assert f[2*(ai-1)+1]==g[2*(bi-1)+1]
    crossover.append(dict(route=a,exact_counterpart=b,exact_outputs=names,first_full_residual_exact=True))
c=D/'O0_OBS_CHAIN_NONE';d=D/'O0_OBS_DIRECT_NONE'
cb=rows(c/'cause66_boundary.txt')[3];db=rows(d/'cause66_boundary.txt')[1]
F=rows(c/'cause66_F0.txt')[3];G=rows(d/'cause66_F0.txt')[1]
assert F[:-1]==G[:-1] and F[-1]!=G[-1]
den=cb[18]/cb[19]+cb[10];predicted=-(cb[6]-db[6])/den;actual=F[-1]-G[-1]
assert abs(predicted-actual)<2e-17
q=dict(work_unit='SWAP431-MACRO-B1-CAUSE66',stage='BIDIRECTIONAL_CAUSE_ISOLATED_BEFORE_REPAIR',cause='deepgw is interpolated once at larger t+dt; TimeControl(5) shrinks dt without refreshing BoundBottom; implicit bottom residual consumes stale endpoint forcing',observer_reproduction=reproduction,crossover=crossover,deepgw_CHAIN=cb[6],deepgw_DIRECT=db[6],deepgw_difference_cm=cb[6]-db[6],Cauchy_denominator_days=den,first_F_differing_nodes_one_based=[112],first_F112_difference_cm_per_day=actual,predicted_F112_difference_cm_per_day=predicted,prediction_error=actual-predicted,no_macro_memory_intervention=True,physics_or_criteria_change=False,causal_repair_authorized_by_evidence=True)
(R/'CAUSAL_RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
print(json.dumps({k:v for k,v in q.items() if k not in ['observer_reproduction','crossover']},indent=2))
