"""Recompute the bounded negative discriminator; zero model calls."""
from pathlib import Path
import hashlib,json,math,sys
R=Path(__file__).resolve().parent
D=Path(sys.argv[1]) if len(sys.argv)>1 else R/'data'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines() if s.strip()]
def fields(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines() if s.strip()}
def diff(a,b):
    x,y=fields(a),fields(b)
    assert x.keys()==y.keys()
    return {k:dict(count=sum(i!=j for i,j in zip(x[k],y[k])),max_abs=max(abs(i-j) for i,j in zip(x[k],y[k])),indices_zero_based=[n for n,(i,j) in enumerate(zip(x[k],y[k])) if i!=j]) for k in x if x[k]!=y[k]}
result=[];comparisons={};reproduction={}
for opt in ['O0','O2']:
    c=D/(opt+'_CHAIN');d=D/(opt+'_DIRECT')
    for mode,p,attempt in [('CHAIN',c,2),('DIRECT',d,1)]:
        run=json.loads((p/'RUN.json').read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
        at=rows(p/'attempt_trace.txt');assert len(at)==attempt and at[-1][8:11]==[0,0,0] and at[-1][25]==1
        assert at[-1][3:7]==[1e-5,0,0,1]
        if mode=='CHAIN':assert at[0][3]==2.0951312035156963e-5 and at[0][8:11]==[4,1,0] and at[0][7]==31
        sol=fields(p/('solver_'+str(attempt)+'.txt'));F=sol['residual']
        assert sol['outcome']==[0,3,1] and len(F)==112 and sol['controls'][5:7]==[1e-6,1e-5]
        assert max(map(abs,F))<1e-6 and abs(sum(F))<1e-5
        before=fields(p/('follow_begin_'+str(attempt)+'.txt'));after=fields(p/'follow_committed.txt')
        bc=fields(p/('context_follow_begin_'+str(attempt)+'.txt'));ac=fields(p/'context_follow_committed.txt')
        budget=rows(p/'step_budget.txt');iv=rows(p/'inventory_trace.txt');assert len(budget)==len(iv)==1
        v=budget[0];dt=v[1];assert dt==1e-5 and v[16]==1
        dm=math.fsum((b-a)*dz*fr for a,b,dz,fr in zip(before['theta'],after['theta'],before['dz'],before['fraction']))
        dx=math.fsum(b-a for a,b in zip(before['macro_compartment'],after['macro_compartment']))
        dp=after['pond'][0]-before['pond'][0];dc=ac['sicact'][0]-bc['sicact'][0]
        external=dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
        error=dm+dx+dp+dc-external;limit=dt*sol['controls'][6]
        assert abs(error)<limit and abs(error-iv[0][9])<2e-15 and abs(error-dt*sum(F))<2e-15
        domains=[]
        for j in range(5):
            dw=math.fsum(b-a for a,b in zip(before['macro_compartment'][j::5],after['macro_compartment'][j::5]))
            domains.append(dw-dt*(v[17+j]+v[22+j]-v[27+j])+(dt*v[12] if j==0 else 0))
        assert max(map(abs,domains))<1e-14
        assert (p/'ledger_follow_committed.txt').read_bytes()==(p/'ledger_final.txt').read_bytes()
        trace=rows(p/'jac63_trace.txt');active=[x for x in trace if x[2]==1]
        result.append(dict(opt=opt,mode=mode,seconds=run['seconds'],attempts=attempt,fresh_checks=at[-1][25],iterations=3,Fmax=max(map(abs,F)),sumF=sum(F),IDecMpRat=at[-1][4],FrReduQ=at[-1][6],hostcommits=1,active_W=sum(x[4]==1 for x in active),active_V=sum(x[4]==2 for x in active),matrix_delta_cm=dm,macro_delta_cm=dx,pond_delta_cm=dp,canopy_delta_cm=dc,external_cm=external,inventory_error_cm=error,inventory_limit_cm=limit,domain_errors_cm=domains,follow_packet_sha256=sha(p/'follow.end')))
    cm={}
    for a,b in [('context_follow_begin_2.txt','context_follow_begin_1.txt'),('follow_begin_2.txt','follow_begin_1.txt'),('origin_follow_begin_2.txt','origin_follow_begin_1.txt'),('context_follow_committed.txt','context_follow_committed.txt'),('follow_committed.txt','follow_committed.txt'),('solver_2.txt','solver_1.txt'),('ledger_final.txt','ledger_final.txt')]:
        cm[a+' versus '+b]=diff(c/a,d/b)
    assert not cm['context_follow_begin_2.txt versus context_follow_begin_1.txt']
    assert not cm['origin_follow_begin_2.txt versus origin_follow_begin_1.txt']
    assert (c/'ledger_follow_begin_2.txt').read_bytes()==(d/'ledger_follow_begin_1.txt').read_bytes()==(c/'ledger_initial.txt').read_bytes()
    assert sha(c/'own.end')==sha(d/'own.end')=='59988fe0728bc51006085bbc957afc16ddf50b23a5cbb644228716dff743748e'
    assert sha(c/'follow.end')!=sha(d/'follow.end')
    cm['rollback_initial_context_diff']=diff(c/'context_initial.txt',c/'context_follow_begin_2.txt')
    assert set(cm['rollback_initial_context_diff'])=={'dt','fldtmin'}
    comparisons[opt]=cm
    old=R.parent/'swap431-macro-b1-combined63/data'/opt/'RESTART_D2'
    names=[p.name for p in old.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt']]
    assert names
    for n in names:assert (c/n).read_bytes()==(old/n).read_bytes(),n
    assert [x[:-1] for x in rows(c/'attempt_trace.txt')]==[x[:-1] for x in rows(old/'attempt_trace.txt')]
    assert sha(c/'follow.end')==sha(old/'follow.end')
    reproduction[opt]=dict(common_texts_exact=names,attempts_exact_except_timing=True,follow_packet_exact=True)
o0o2={}
for mode in ['CHAIN','DIRECT']:
    a=D/('O0_'+mode);b=D/('O2_'+mode)
    names=[p.name for p in a.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt']]
    for n in names:assert (a/n).read_bytes()==(b/n).read_bytes(),n
    assert [x[:-1] for x in rows(a/'attempt_trace.txt')]==[x[:-1] for x in rows(b/'attempt_trace.txt')]
    assert sha(a/'follow.end')==sha(b/'follow.end')
    o0o2[mode]=dict(texts_exact=names,attempts_exact_except_timing=True,follow_packet_exact=True)
q=dict(work_unit='SWAP431-MACRO-B1-COUPLED65',decision='BOUNDED_UNRESOLVED',baseline='15d14a7b5679b6e11a97414e29a09738e09b9a29',routes=4,results=result,comparisons=comparisons,O0_O2=o0o2,COMBINED63_reproduction=reproduction,fresh_coupled_and_integrated_mass_pass=True,chain_direct_exact_equivalence=False,causal_attribution_of_difference='UNRESOLVED; complete named context and saved origin equal, rate/event scratch differs before HeadCalc; no claim of causal proof',active_V_refusal_available=False,production_promotion=False)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
(R/'STATUS.json').write_text(json.dumps({k:v for k,v in q.items() if k not in ['comparisons','O0_O2','COMBINED63_reproduction']},indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(decision=q['decision'],results=result),indent=2))
