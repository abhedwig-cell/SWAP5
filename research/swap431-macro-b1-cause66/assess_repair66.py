"""Scope: real W-refusal rollback and actual smaller retry, zero model calls."""
from pathlib import Path
import hashlib,json,math,sys
R=Path(__file__).resolve().parent
D=Path(sys.argv[1]) if len(sys.argv)>1 else Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e/cause66-data/evidence/data')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines() if s.strip()]
def fields(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines() if s.strip()}
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
results=[];equivalence=[]
for opt in ['O0','O2']:
    c=D/(opt+'_REPAIR_CHAIN_NONE');d=D/(opt+'_REPAIR_DIRECT_NONE')
    initial=fields(c/'context_initial.txt');retry=fields(c/'context_follow_begin_2.txt')
    assert {k for k in initial if initial[k]!=retry[k]}=={'dt','fldtmin'}
    assert (c/'context_follow_begin_2.txt').read_bytes()==(d/'context_follow_begin_1.txt').read_bytes()
    assert (c/'origin_follow_begin_2.txt').read_bytes()==(d/'origin_follow_begin_1.txt').read_bytes()
    assert (c/'ledger_initial.txt').read_bytes()==(c/'ledger_follow_begin_2.txt').read_bytes()==(d/'ledger_follow_begin_1.txt').read_bytes()
    old=D/'O0_OBS_CHAIN_NONE'
    assert rows(c/'attempt_trace.txt')[0][:-1]==rows(old/'attempt_trace.txt')[0][:-1]
    assert (c/'solver_1.txt').read_bytes()==(old/'solver_1.txt').read_bytes()
    actuals=rows(c/'cause66_refresh.txt');assert len(actuals)==1 and actuals[0][1]==1e-5 and actuals[0][2]!=actuals[0][3]
    assert not (d/'cause66_refresh.txt').exists()
    pairs=[('solver_2.txt','solver_1.txt'),('follow_committed.txt','follow_committed.txt'),('context_follow_committed.txt','context_follow_committed.txt'),('ledger_final.txt','ledger_final.txt'),('step_budget.txt','step_budget.txt'),('follow.end','follow.end')]
    for a,b in pairs:assert (c/a).read_bytes()==(d/b).read_bytes(),(opt,a)
    # Same complete first coupled residual and every real retry linear system.
    f=rows(c/'cause66_F0.txt');g=rows(d/'cause66_F0.txt');assert f[3]==g[1] and len(f[3])==112
    cs=rows(c/'jac63_systems.txt')[-30:];ds=rows(d/'jac63_systems.txt');assert len(cs)==len(ds)==30
    for k in range(0,30,10):
        assert cs[k][1:-1]==ds[k][1:-1] # attempts/sequence intentionally differ
        assert cs[k+1:k+10]==ds[k+1:k+10]
    assert (d/'follow.end').read_bytes()==(D/'O0_OBS_DIRECT_NONE/follow.end').read_bytes()
    for mode,p,attempt in [('CHAIN',c,2),('DIRECT',d,1)]:
        run=json.loads((p/'RUN.json').read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
        at=rows(p/'attempt_trace.txt');assert len(at)==attempt and at[-1][8:11]==[0,0,0] and at[-1][25]==1
        assert at[-1][3:7]==[1e-5,0,0,1] and at[-1][7]==3
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
        domain=[]
        for j in range(5):
            dw=math.fsum(b-a for a,b in zip(before['macro_compartment'][j::5],after['macro_compartment'][j::5]))
            domain.append(dw-dt*(v[17+j]+v[22+j]-v[27+j])+(dt*v[12] if j==0 else 0))
        assert max(map(abs,domain))<1e-14
        assert (p/'ledger_follow_committed.txt').read_bytes()==(p/'ledger_final.txt').read_bytes()!=(p/'ledger_initial.txt').read_bytes()
        results.append(dict(opt=opt,mode=mode,seconds=run['seconds'],attempts=attempt,iterations=3,fresh_checks=1,Fmax=max(map(abs,F)),sumF=sum(F),IDecMpRat=0,FrReduQ=1,hostcommits=1,matrix_delta_cm=dm,macro_delta_cm=dx,pond_delta_cm=dp,canopy_delta_cm=dc,external_cm=external,inventory_error_cm=error,inventory_limit_cm=limit,domain_errors_cm=domain,t1900_after=ac['t1900'][0],follow_packet_sha256=sha(p/'follow.end')))
    equivalence.append(dict(opt=opt,native_origin_exact=True,ledger_before_retry_exact=True,rollback_context_exact_except=['dt','fldtmin'],stored_macro_origin_exact=True,first112_residual_exact=True,three_full_retry_linear_systems_exact=True,accepted_exact_files=[a for a,b in pairs],repaired_direct_unchanged_from_COUPLED65=True,larger_refusal_unchanged=True,provider_refreshes=1,pre_evaluation_all_scratch_bytes_equal=False))
o0o2={}
for mode in ['CHAIN','DIRECT']:
    a=D/('O0_REPAIR_'+mode+'_NONE');b=D/('O2_REPAIR_'+mode+'_NONE')
    names=[p.name for p in a.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt']]
    for n in names:assert (a/n).read_bytes()==(b/n).read_bytes(),(mode,n)
    assert [x[:-1] for x in rows(a/'attempt_trace.txt')]==[x[:-1] for x in rows(b/'attempt_trace.txt')]
    assert sha(a/'follow.end')==sha(b/'follow.end');o0o2[mode]=dict(exact_texts=names,attempts_exact_except_timing=True,packet_exact=True)
allruns=[]
for p in D.iterdir():
    if p.is_dir():
        run=json.loads((p/'RUN.json').read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
        allruns.append(dict(route=p.name,**run))
assert len(allruns)==8
q=dict(work_unit='SWAP431-MACRO-B1-CAUSE66',decision='QUALIFIED_BOUNDED_COUPLED_ACCEPTANCE',scope='single fixed D2 native origin; actual W-active larger refusal, refreshed smaller-endpoint implicit Cauchy forcing, fresh unscaled W/V/V retry and exact independent DIRECT on O0/O2',baseline='3db3836f3ad887605a265be25acbf4ceebfd4dc9',cause_result='CAUSAL_RESULT.json',results=results,rollback_direct_equivalence=equivalence,O0_O2=o0o2,model_runs=allruns,model_route_count=8,new_model_routes_after_selection=0,physics_criteria_dt_retry_solver_unchanged=True,production_promotion=False,exclusions=['active V refusal not selected or qualified','all pre-evaluation scratch bytes equal not required/proven','general restart or own accepted packet fresh-read not tested','full period and generic boundary modes not qualified','B1 reference or canonical admission not granted'])
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
(R/'STATUS.json').write_text(json.dumps({k:v for k,v in q.items() if k not in ['O0_O2','model_runs']},indent=2)+'\n')
print(json.dumps(dict(decision=q['decision'],results=results),indent=2))
