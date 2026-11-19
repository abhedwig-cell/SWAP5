"""Zero-model verification of matched negative own-checkpoint continuation."""
from pathlib import Path
import json,hashlib,sys
R=Path(__file__).resolve().parent
W=Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e/follow67-data')
D=Path(sys.argv[1]) if len(sys.argv)>1 else W/'evidence/data'
B=Path(sys.argv[2]) if len(sys.argv)>2 else W/'cause66/data'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines() if s.strip()]
def fields(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines() if s.strip()}
def diff(a,b):
    x,y=fields(a),fields(b);assert x.keys()==y.keys()
    return {k:dict(count=sum(u!=v for u,v in zip(x[k],y[k])),max_abs=max(abs(u-v) for u,v in zip(x[k],y[k]))) for k in x if x[k]!=y[k]}
result=[]
for opt in ['O0','O2']:
    c=D/(opt+'_CONT');r=D/(opt+'_RESTART');old=B/(opt+'_REPAIR_CHAIN_NONE')
    for p in [c,r]:
        run=json.loads((p/'RUN.json').read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
        assert 'NATIVE55_FOLLOW_SCALED_REQUEST_EXCLUDED' in (p/'outcome.txt').read_text()
        assert not (p/'follow67.end').exists()
    assert sha(c/'cut67.end')==sha(r/'own.end')==sha(old/'follow.end')=='d5ee169f99cebe1a8dd849b39bfe51d06bdbcf5f226e127d2d70246807a373d7'
    for name in ['cut67','context_cut67','ledger_cut67']:
        assert (c/(name+'.txt')).read_bytes()==(c/(name+'_after_io.txt')).read_bytes()
    for a,b in [('context_cut67.txt','context_follow_committed.txt'),('cut67.txt','follow_committed.txt'),('ledger_cut67.txt','ledger_final.txt')]:
        assert (c/a).read_bytes()==(old/b).read_bytes(),a
    assert (c/'context_cut67.txt').read_bytes()==(r/'native_installed.txt').read_bytes()
    assert (c/'ledger_cut67.txt').read_bytes()==(r/'ledger_installed.txt').read_bytes()
    matches=[]
    for ci,ri in [(3,1),(4,2)]:
        for prefix in ['context_follow_begin_','context_follow_returned_','ledger_follow_begin_','ledger_follow_returned_','origin_follow_begin_','solver_']:
            assert (c/(prefix+str(ci)+'.txt')).read_bytes()==(r/(prefix+str(ri)+'.txt')).read_bytes(),(prefix,ci)
            matches.append([prefix+str(ci)+'.txt',prefix+str(ri)+'.txt'])
    for i in [1,2]:assert (c/('solver_'+str(i)+'.txt')).read_bytes()==(old/('solver_'+str(i)+'.txt')).read_bytes()
    ct=rows(c/'attempt_trace.txt');rt=rows(r/'attempt_trace.txt');assert len(ct)==4 and len(rt)==2
    for x,y in zip(ct[2:],rt):assert x[2:-1]==y[2:-1] # attempt, process-local steps, timing excluded
    assert [x[:-1] for x in ct[:2]]==[x[:-1] for x in rows(old/'attempt_trace.txt')]
    assert rt[0][3]==2e-5 and rt[1][3]==1e-5
    assert rt[0][8:11]==[4,1,0] and rt[1][8:11]==[4,0,1] and rt[1][5:7]==[1,1]
    assert rt[0][7]==31 and rt[1][7]==61
    # First full112-node residuals and numerical boundary contexts match exactly.
    cf=rows(c/'cause66_F0.txt');rf=rows(r/'cause66_F0.txt');assert len(cf)==8 and len(rf)==4
    for j in range(2):assert cf[5+2*j]==rf[1+2*j] and len(rf[1+2*j])==112
    cb=rows(c/'cause66_boundary.txt')[4:];rb=rows(r/'cause66_boundary.txt')
    assert len(cb)==len(rb)==4
    for x,y in zip(cb,rb):assert x[1:]==y[1:]
    assert (c/'context_final.txt').read_bytes()==(r/'context_final.txt').read_bytes()
    assert (c/'ledger_cut67.txt').read_bytes()==(c/'ledger_final.txt').read_bytes()==(r/'ledger_final.txt').read_bytes()
    assert len(rows(c/'step_budget.txt'))==len(rows(c/'inventory_trace.txt'))==1
    assert rows(r/'step_budget.txt')==rows(r/'inventory_trace.txt')==[]
    assert fields(c/'context_final.txt')['t1900']==[35797.290441125151]
    rollback=diff(c/'context_cut67.txt',c/'context_final.txt');assert set(rollback)=={'dt','dtold'}
    scratch_initial=diff(c/'follow_begin_3.txt',r/'follow_begin_1.txt')
    scratch_final=diff(c/'final.txt',r/'final.txt');assert set(scratch_final)=={'matrix_vertical'}
    tr=[x for x in rows(c/'jac63_trace.txt') if x[0]>=3];assert len(tr)==90 and all(x[2]==-1 and x[26]==0 for x in tr)
    before=fields(c/'cut67.txt');after=fields(c/'final.txt')
    for k in ['h','theta','pond','macro_compartment','macro_sat','time','sorp_ref','sorptivity','geometry_dynamic','geometry_subsid']:
        if k in before:assert before[k]==after[k],k
    result.append(dict(opt=opt,CONT_seconds=json.loads((c/'RUN.json').read_text())['seconds'],RESTART_seconds=json.loads((r/'RUN.json').read_text())['seconds'],cut_sha256=sha(c/'cut67.end'),cut_writer_state_ledger_unchanged=True,CAUSE66_step_exact=True,native_install_context_and_ledger_byte_exact=True,matched_files=matches,first_full_residuals_exact=True,follow_attempts=[dict(dt=x[3],performed_iterations=int(x[7]-1),Fmax=x[18],sumF=x[17],worst_node=int(x[19]),fresh_acceptance_checks=int(x[25]),kind=int(x[8]),IDecMpRat=int(x[5]),FrReduQ=x[6]) for x in rt],next_hostcommits=0,new_ledger_integrations=0,time_advance_after_cut=0,numerical_reduction_requested=True,numerical_reduction_executed=False,next_jac63_active_uses=0,jac63_time_gate_unchanged=True,rollback_context_differences=rollback,initial_scratch_differences=scratch_initial,final_scratch_differences=scratch_final,accepted_follow_packet_written=False,new_follow_waterinventory_qualification='NOT_AVAILABLE_NO_ACCEPTED_STEP'))
o0o2={}
for mode in ['CONT','RESTART']:
    a=D/('O0_'+mode);b=D/('O2_'+mode)
    names=[p.name for p in a.glob('*.txt') if p.name not in ['cost_trace.txt','attempt_trace.txt']]
    for n in names:assert (a/n).read_bytes()==(b/n).read_bytes(),(mode,n)
    assert [x[:-1] for x in rows(a/'attempt_trace.txt')]==[x[:-1] for x in rows(b/'attempt_trace.txt')]
    if mode=='CONT':assert sha(a/'cut67.end')==sha(b/'cut67.end')
    o0o2[mode]=dict(exact_texts=names,attempt_fields_exact_except_elapsed=True)
q=dict(work_unit='SWAP431-MACRO-B1-FOLLOW67',baseline='96f1a1f7b4325d4933f32235bbd724767dad808f',decision='BOUNDED_UNRESOLVED',finding='EXACT_OWN_CHECKPOINT_TRANSFER_AND_MATCHED_UNSCALED_REFUSALS_NO_ACCEPTED_FOLLOW',model_processes=4,all_normal_uncensored=True,results=result,O0_O2=o0o2,physics_criteria_Jac63_eligibility_unchanged=True,CAUSE66_BoundBottom_refresh_applied_at_named_successor=True,new_native_fields=0,production_promotion=False,qualified_scope='phase1 own accepted checkpoint transfer and exact same unscaled negative next-step trajectory, O0/O2',not_qualified=['accepted full next step','new follow host waterbalance','general restart','next-time Jac63 convergence/eligibility','full period or reference promotion'])
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
(R/'STATUS.json').write_text(json.dumps({k:v for k,v in q.items() if k!='O0_O2'},indent=2)+'\n')
print(json.dumps(dict(decision=q['decision'],finding=q['finding'],results=[{k:v for k,v in x.items() if k in ['opt','CONT_seconds','RESTART_seconds','follow_attempts','next_hostcommits','final_scratch_differences']} for x in result]),indent=2))
