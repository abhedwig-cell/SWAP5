"""Assess recorded native routes; launches no model and cannot turn restart FAIL into PASS."""
from pathlib import Path
import hashlib,json,math,sys
R=Path(__file__).resolve().parent
eps=sys.float_info.epsilon
def fields(p):
    return {s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def delta(a,b):
    assert a.keys()==b.keys()
    return {k:max(abs(x-y) for x,y in zip(a[k],b[k])) for k in a if a[k]!=b[k]}
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def inventory(a,c,trial,s):
    dt=s['controls'][1];n=int(s['controls'][3]);nd=int(a['controls'][4])
    assert n==112 and nd==5 and a['fraction']==c['fraction']==trial['fraction']
    grad=[(s['h'][j-1]-s['h'][j])/(.5*(s['dz'][j-1]+s['dz'][j]))+1 for j in range(1,n)]
    assert grad==s['hgrad'][1:n]
    q=[s['boundary'][0]]+[-k*g for k,g in zip(s['kmean'][1:n],grad)]+[s['boundary'][1]]
    changes=[(y-x)*d*f for x,y,d,f in zip(a['theta'],c['theta'],a['dz'],a['fraction'])]
    reconstructed=[changes[j]/dt+s['sink'][j]-s['source'][j]+s['qroot'][j]+q[j]-q[j+1]-s['qexchange'][j] for j in range(n)]
    rem=max(abs(x-y) for x,y in zip(reconstructed,s['residual']));assert rem<64*eps
    local=max(map(abs,s['residual']));total=math.fsum(s['residual'])
    assert local<=s['controls'][5] and abs(total)<=s['controls'][6]
    assert s['controls'][2]==0 and s['outcome'][0]==0 and s['outcome'][2]==1
    md=math.fsum(changes);exc=math.fsum(trial['matrix_exchange'])
    qt,qb,P,I,M,runon,epd,reva=trial['boundary_rates']
    merror=md-dt*(qb-qt-math.fsum(trial['matrix_root'])-math.fsum(trial['matrix_drains'])+math.fsum(trial['matrix_ssdi'])+exc)
    assert abs(merror)<=dt*s['controls'][6]
    domain=[]
    for j in range(nd):
        ex=math.fsum(trial['macro_exchange'][j::nd]);rapid=math.fsum(trial['macro_rapid']) if j==0 else 0
        rate=trial['macro_in_lat'][j]+trial['macro_in_vert'][j]-ex-rapid
        change=c['macro_domain'][j]-a['macro_domain'][j]
        envelope=64*eps*max(1,abs(a['macro_domain'][j]))
        assert a['macro_domain'][j]+dt*rate>=0
        assert abs(change-dt*rate)<=envelope
        assert abs(math.fsum(c['macro_compartment'][j::nd])-c['macro_domain'][j])<=envelope
        domain.append(dict(domain=j+1,change_cm=change,error_cm=change-dt*rate))
    pair=[sum(trial['macro_exchange'][j*nd:(j+1)*nd]) for j in range(n)]
    pairerr=max(abs(x-y) for x,y in zip(pair,trial['matrix_exchange']));assert pairerr<64*eps
    mp=math.fsum(x['change_cm'] for x in domain);pd=c['pond'][0]-a['pond'][0]
    surface_error=pd-dt*(P+I+M+runon-epd-reva+qt-math.fsum(trial['macro_in_lat'])-math.fsum(trial['macro_in_vert']))+trial['surface'][0]
    assert abs(surface_error)<=s['controls'][7]
    external=dt*(P+I+M+runon-epd-reva+qb-math.fsum(trial['matrix_root'])-math.fsum(trial['matrix_drains'])+math.fsum(trial['matrix_ssdi'])-math.fsum(trial['macro_rapid']))-trial['surface'][0]
    combined=md+mp+pd-external
    assert abs(combined-dt*total-surface_error)<64*eps*max(1,math.fsum(a['macro_domain']))
    return dict(dt=dt,iterations=int(s['outcome'][1]),local_residual=local,total_residual=total,
                independent_residual_difference=rem,matrix_change_cm=md,macro_change_cm=mp,
                matrix_balance_error_cm=merror,surface_balance_error_cm=surface_error,
                combined_balance_error_cm=combined,paired_exchange_error=pairerr,domains=domain)

results=[]
for opt in ['O2','O0']:
    identity=json.loads((R/(opt+'_IDENTITY.json')).read_text())
    for name,digest in identity['sources'].items():assert hashlib.sha256((R/name).read_bytes()).hexdigest()==digest
    t=R/'data'/opt/'B_TRIAL';d=R/'data'/opt/'B_DIRECT';r=R/'data'/opt/'B_RESTART_FINAL'
    f=lambda folder,name:fields(folder/(name+'.txt'))
    assert (t/'outcome.txt').read_text().strip()=='REAL_REJECT_SMALL_RETRY_AND_CONTINUED'
    assert (d/'outcome.txt').read_text().strip()=='DIRECT_SMALL_AND_CONTINUED'
    assert (r/'outcome.txt').read_text().strip()=='NATIVE_RESTART_ONE_STEP_EXECUTED'
    a=f(t,'origin');rb=f(t,'rollback_1');ret=f(t,'returned_1');s=f(t,'solver_1')
    assert a['controls'][:3]==[35796.9513533331,2e-5,0]
    assert s['outcome']==[4,31,1] and ret['controls'][-1]==1 and ret['policy'][1]==0
    restored=['h','hm1','theta','thetm1','dz','fraction','pond','matrix_stored','macro_total','macro_sat','macro_domain','macro_compartment','macro_volume','macro_bottom','clock','wet_wall','wet_wall_old']
    assert all(a[k]==rb[k] for k in restored)
    equal=['origin','accepted_solver_return','checkpoint','checkpoint_after_io','continuous_next_begin','continuous_next_return','continuous_after_step']
    for name in equal:assert (t/(name+'.txt')).read_bytes()==(d/(name+'.txt')).read_bytes(),(opt,name)
    for x,y in [('solver_2','solver_1'),('solver_3','solver_2')]:
        assert (t/(x+'.txt')).read_bytes()==(d/(y+'.txt')).read_bytes(),(opt,x,y)
    for name in ['candidate.end','candidate_text.end']:
        assert (t/name).read_bytes()==(d/name).read_bytes()
    assert (t/'checkpoint.txt').read_bytes()==(t/'checkpoint_after_io.txt').read_bytes()
    first=inventory(f(t,'begin_2'),f(t,'checkpoint'),f(t,'accepted_solver_return'),f(t,'solver_2'))
    follow=inventory(f(t,'continuous_next_begin'),f(t,'continuous_after_step'),f(t,'continuous_next_return'),f(t,'solver_3'))
    assert first['dt']==1e-5 and first['iterations']==7 and follow['iterations']==3
    own=hashlib.sha256((t/'candidate.end').read_bytes()).hexdigest()
    assert hashlib.sha256((r/'own.end').read_bytes()).hexdigest()==own
    cp=f(t,'checkpoint');ri=f(r,'restart_initialized');ra=f(r,'restart_after_step');ca=f(t,'continuous_after_step')
    assert cp['h']==ri['h'] and cp['theta']==ri['theta']
    assert max(ri['clock'])==0 and max(cp['clock'])>.02
    assert abs(cp['macro_total'][0]-ri['macro_total'][0])>.01
    warning=(r/'swap.wrn').read_text()
    assert 'I/O of macropore variables from file (SWINCO=3) not implemented yet!' in warning
    assert ca['controls'][0]!=ra['controls'][0]
    results.append(dict(optimization=opt,rejection=dict(dt=2e-5,actual_iterations=30,trace_loop_index=31,
        outcome=4,local_residual=max(map(abs,s['residual'])),total_residual=math.fsum(s['residual']),flux_factor=1),
        immediate_restored_fields=restored,immediate_trial_differences=delta(a,rb),
        retry_direct_pre_head_differences=delta(f(t,'begin_2'),f(d,'begin_1')),
        retry_direct_exact_stages=equal,retry_direct_solver_and_native_checkpoint_byte_exact=True,
        checkpoint_io_noninterference_exact=True,accepted_inventory=first,continuation_inventory=follow,
        native_restart=dict(gate='FAIL_PREEXISTING_UNSUPPORTED_MACRO_IO',own_end_sha256=own,
            matrix_heads_and_theta_exact_at_first_head=True,initialization_differences=delta(cp,ri),
            checkpoint_max_clock=max(cp['clock']),restart_max_clock=max(ri['clock']),
            checkpoint_time=cp['controls'][0],restart_time=ri['controls'][0],time_roundtrip_error_days=ri['controls'][0]-cp['controls'][0],
            continuous_first_dt=f(t,'solver_3')['controls'][1],restart_first_dt=f(r,'solver_1')['controls'][1],
            actual_native_first_step_executed=True,continuous_end_time=ca['controls'][0],restart_end_time=ra['controls'][0],
            after_step_equal_time_comparison='NOT_VALID_DIFFERENT_DT_AND_END_TIME',
            warning='Original reader explicitly states SWINCO3 macro I/O is not implemented')))

for profile in ['B_TRIAL','B_DIRECT','B_RESTART_FINAL']:
    for p in (R/'data/O2'/profile).glob('*.txt'):
        assert p.read_bytes()==(R/'data/O0'/profile/p.name).read_bytes(),str(p)
    for name in ['candidate.end','candidate_text.end','own.end']:
        p=R/'data/O2'/profile/name
        if p.exists():assert p.read_bytes()==(R/'data/O0'/profile/name).read_bytes()
ad=R/'data/O2/A_TRIAL'
assert (ad/'checkpoint_outcome.txt').read_text().strip()=='PATCH_LARGE'
assert fields(ad/'solver_1.txt')['outcome']==[0,5,1]
runs=[json.loads(p.read_text()) for p in R.glob('O[02]_*_RUN.json')]
assert len(runs)==7 and all(x['returncode']==0 and not x['censored'] and x['seconds']<20 for x in runs)
report=dict(work_unit='SWAP431-MACRO-B1-RETRY07',baseline='e9ade290b2861159f94afe4b347c15badad6ba02',
    decision='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',candidate='V1 plus unchanged CONTRACT06 one-line Darcy gate patch',
    actual_rejection_restore_direct_small_retry='PASS_ORIGINAL_CONTEXT_B',full_host_following_step='PASS_EXACT_DIRECT_RETRY',
    own_native_restart='FAIL_PREEXISTING_UNSUPPORTED_MACRO_IO',complete_restart_qualification=False,
    nondiscriminating_context_A='Patched dt .002 accepts in 5 iterations; no artificial rejection introduced',
    O0_O2_all_final_B_raw_vectors_and_own_files_byte_exact=True,final_routes=7,setup_failures_preserved=2,
    final_max_model_seconds=max(x['seconds'] for x in runs),final_total_model_seconds=sum(x['seconds'] for x in runs),
    model_cap_seconds=20,model_censored=0,additional_memory_patch=False,physical_patch_changed=False,
    official_reference_promoted=False,production_changed=False,results=results,
    exclusions=['Native macro restart remains unsupported and fails initialization equivalence',
        'No original dry-event or zero-head handoff qualification','Other hydraulic modes/tabulated hydraulics/variable air-entry layers unqualified',
        'No full trajectory qualification, reference promotion or general state architecture'],
    next_safe_step='Resolve the native macro restart support contract as a separately scoped change before claiming own-restart qualification; retain dry/event and zero-head exclusions. No broad campaign.')
save(R/'RESULT.json',report)
print(json.dumps({k:v for k,v in report.items() if k!='results'},indent=2))
