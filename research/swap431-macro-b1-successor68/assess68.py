"""Selected one-step acceptance/ownership/continuation audit, zero model calls."""
from pathlib import Path
import json,math,hashlib,sys
R=Path(__file__).resolve().parent
D=Path(sys.argv[1]) if len(sys.argv)>1 else Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e/successor68-data/evidence/data')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines() if s.strip()]
def fields(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines() if s.strip()}
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
results=[];equivalence=[]
for opt in ['O0','O2']:
    c=D/(opt+'_CONT');r=D/(opt+'_BARE');fd=D/(opt+'_FD')
    assert sha(c/'cut67.end')==sha(r/'own.end')=='d5ee169f99cebe1a8dd849b39bfe51d06bdbcf5f226e127d2d70246807a373d7'
    assert (c/'context_cut67.txt').read_bytes()==(r/'native_installed.txt').read_bytes()
    assert (c/'ledger_cut67.txt').read_bytes()==(r/'ledger_installed.txt').read_bytes()
    pairs=[]
    for ci,ri in [(3,1),(4,2)]:
        for pre in ['solver_','context_follow_begin_','context_follow_returned_','ledger_follow_begin_','ledger_follow_returned_','origin_follow_begin_']:
            a=pre+str(ci)+'.txt';b=pre+str(ri)+'.txt';assert (c/a).read_bytes()==(r/b).read_bytes(),(opt,a);pairs.append([a,b])
    for name in ['follow_committed.txt','context_follow_committed.txt','ledger_final.txt','follow67.end']:
        assert (c/name).read_bytes()==(r/name).read_bytes()==(fd/name).read_bytes(),(opt,name)
    ct=rows(c/'attempt_trace.txt');rt=rows(r/'attempt_trace.txt');assert len(ct)==4 and len(rt)==2
    for x,y in zip(ct[2:],rt):assert x[2:-1]==y[2:-1]
    for i in range(2):assert rows(c/'cause66_F0.txt')[5+2*i]==rows(r/'cause66_F0.txt')[1+2*i]
    ini=fields(r/'context_initial.txt');retry=fields(r/'context_follow_begin_2.txt')
    assert {k for k in ini if ini[k]!=retry[k]}=={'dt','fldtmin'}
    assert (r/'ledger_initial.txt').read_bytes()==(r/'ledger_follow_begin_2.txt').read_bytes()
    assert rt[0][3]==2e-5 and rt[0][7]==31 and rt[0][8:11]==[4,1,0]
    assert rt[1][3]==1e-5 and rt[1][7]==10 and rt[1][8:11]==[0,0,0] and rt[1][25]==1
    sol=fields(r/'solver_2.txt');F=sol['residual'];assert len(F)==112 and max(map(abs,F))<1e-6 and abs(sum(F))<1e-5
    assert sol['controls'][5:7]==[1e-6,1e-5] and sol['outcome']==[0,10,1]
    before=fields(r/'follow_begin_2.txt');after=fields(r/'follow_committed.txt');bc=fields(r/'context_follow_begin_2.txt');ac=fields(r/'context_follow_committed.txt')
    bud=rows(r/'step_budget.txt');iv=rows(r/'inventory_trace.txt');assert len(bud)==len(iv)==1
    assert rows(c/'step_budget.txt')[-1]==bud[0] and len(rows(c/'step_budget.txt'))==2
    v=bud[0];dt=v[1];assert dt==1e-5 and v[16]==1
    dm=math.fsum((b-a)*dz*f for a,b,dz,f in zip(before['theta'],after['theta'],before['dz'],before['fraction']))
    dx=math.fsum(b-a for a,b in zip(before['macro_compartment'],after['macro_compartment']))
    dp=after['pond'][0]-before['pond'][0];dc=ac['sicact'][0]-bc['sicact'][0]
    external=dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
    err=dm+dx+dp+dc-external;limit=dt*sol['controls'][6]
    assert abs(err)<limit and abs(err-iv[0][9])<2e-15 and abs(err-dt*sum(F))<2e-15
    domain=[]
    for j in range(5):
        dw=math.fsum(b-a for a,b in zip(before['macro_compartment'][j::5],after['macro_compartment'][j::5]))
        domain.append(dw-dt*(v[17+j]+v[22+j]-v[27+j])+(dt*v[12] if j==0 else 0))
    assert max(map(abs,domain))<1e-14
    assert (r/'ledger_final.txt').read_bytes()==(r/'ledger_follow_committed.txt').read_bytes()!=(r/'ledger_initial.txt').read_bytes()
    assert ac['t1900'][0]==ini['t1900'][0]+dt
    tr=rows(r/'jac63_trace.txt');active=[x for x in tr if x[26]==1];assert len(active)==30
    audit=json.loads((R/(opt+'_DERIVATIVE_AUDIT.json')).read_text());assert audit['parent_core_and_packet_exact'] and audit['full_actual_linear_systems_checked']==30
    # Independent conservation derivative check of all actual corrections.
    pts=rows(fd/'potential68_b1_points.txt');CD=pts[9];z=pts[10];rho=pts[0][21]
    nodes=rows(r/'iteration_nodes.txt');systems=rows(r/'jac63_systems.txt');maxmass=0
    for k in range(0,len(systems),10):
        hd,a,b,c0,rhs,x,u1,v1,u2,v2=systems[k:k+10];attempt,it,n,branch,t,ddt,seq=hd
        meta=next(x[2:26] for x in active if x[0:2]==[attempt,it])
        h50=next(x[5] for x in nodes if x[0:3]==[attempt,it,2] and x[4]==50);h51=next(x[5] for x in nodes if x[0:3]==[attempt,it,2] and x[4]==51)
        den=h51-h50;g0=(z[49]-z[50])*h51/den**2;g1=-(z[49]-z[50])*h50/den**2
        l=[0.]*112
        if branch==2:l[49]=rho*g0;l[50]=rho*g1
        mass=max(abs((meta[3]*CD[j] if 50<=j<=56 else 0)+math.fsum(u1)*v1[j]+math.fsum(u2)*v2[j]-l[j]/ddt) for j in range(112));assert mass<1e-10;maxmass=max(maxmass,mass)
    results.append(dict(opt=opt,larger_refusal=dict(dt=rt[0][3],performed_iterations=30,Fmax=rt[0][18],sumF=rt[0][17],active_W=sum(x[0]==1 and x[4]==1 for x in active),active_V=sum(x[0]==1 and x[4]==2 for x in active)),accepted=dict(dt=dt,iterations=10,fresh_checks=1,Fmax=max(map(abs,F)),sumF=sum(F),IDecMpRat=rt[1][5],FrReduQ=rt[1][6],hostcommits_after_cut=1,ledger_integrations_after_cut=1,t1900=ac['t1900'][0],active_W=sum(x[0]==2 and x[4]==1 for x in active),active_V=sum(x[0]==2 and x[4]==2 for x in active)),independent_waterinventory=dict(matrix_delta_cm=dm,macro_compartment_delta_cm=dx,pond_delta_cm=dp,canopy_delta_cm=dc,external_cm=external,error_cm=err,existing_limit_cm=limit,domain_errors_cm=domain),max_mass_derivative_column_error=maxmass,max_linear_residual=audit['max_linear_error'],output_packet_sha256=sha(r/'follow67.end'),output_packet_bytes=(r/'follow67.end').stat().st_size))
    equivalence.append(dict(opt=opt,actual_own_cut_and_fresh_install_exact=True,rollback_except_normal_dt_fldtmin_exact=True,pre_retry_ledger_exact=True,first112_coupled_residuals_exact=True,accepted_state_ledger_budget_packet_exact=True,matched_files=pairs))
o0o2={}
for mode in ['BARE','FD','CONT']:
    a=D/('O0_'+mode);b=D/('O2_'+mode);names=[p.name for p in a.glob('*.txt') if p.name not in ['cost_trace.txt','attempt_trace.txt']]
    for n in names:assert (a/n).read_bytes()==(b/n).read_bytes(),(mode,n)
    assert [x[:-1] for x in rows(a/'attempt_trace.txt')]==[x[:-1] for x in rows(b/'attempt_trace.txt')]
    assert sha(a/'follow67.end')==sha(b/'follow67.end');o0o2[mode]=dict(exact_texts=names,attempts_exact_except_timing=True,packet_exact=True)
runs=[]
for p in sorted(D.iterdir()):
    if p.is_dir():
        run=json.loads((p/'RUN.json').read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20;runs.append(dict(route=p.name,**run))
assert len(runs)==7
q=dict(work_unit='SWAP431-MACRO-B1-SUCCESSOR68',decision='QUALIFIED_BOUNDED_COUPLED_ACCEPTANCE',scope='one FOLLOW67 successor step: unchanged COMBINED63 algebra with one named additional time, qualified physical guards and W/V derivatives, fresh vs continuous O0/O2 unscaled accepted retry',baseline='3d4b0d378da190682fd9e30c3e9cf555104acec2',model_routes=7,results=results,equivalence=equivalence,O0_O2=o0o2,runs=runs,derivative_audits=['O0_DERIVATIVE_AUDIT.json','O2_DERIVATIVE_AUDIT.json'],no_new_solver_or_Jacobian_algebra=True,no_physics_criteria_or_dt_rule_changes=True,production_promotion=False,exclusions=['general time/physical envelopes','active V rejection or independent direct-small retry','second newly accepted successor or own new output checkpoint restart','full period or reference promotion'])
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');(R/'STATUS.json').write_text(json.dumps({k:v for k,v in q.items() if k not in ['O0_O2','runs']},indent=2)+'\n')
print(json.dumps(dict(decision=q['decision'],results=results),indent=2))
