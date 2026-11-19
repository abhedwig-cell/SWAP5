"""Literal canonical implicit-route preservation plus fresh SaltFarm composition."""
from pathlib import Path
import contextlib,hashlib,importlib.util,io,json,runpy,subprocess,sys,tempfile,zipfile
ROOT=Path(__file__).resolve().parents[2]
BASE='b24dd2b7ac353300eaa5a18d11fdcbeaba8b23f1'
RUNTIME='78e02a97517be08ae9fdaa5b885b1fe584e4dec2'
PROOF='integration/f-ci/saltfarm-guard-cost05/'
ENTRY='tests/nomacro_scheduled_subsurface/implicit_conductivity_verify.py'
SELF='tests/saltfarm_newton/composition_admission.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('saltfarm_composition_admission',ROOT/'tests/saltfarm_newton/composition_admission.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
spec=importlib.util.spec_from_file_location('direct_literal',ROOT/'tests/saltfarm_newton/direct_admission.py');direct=importlib.util.module_from_spec(spec);spec.loader.exec_module(direct)
git=direct.git;blob=direct.blob;require=direct.require;normalized=direct.normalized
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def literal_guards():
    require(normalized((ROOT/ENTRY).read_bytes()).replace(HOOK.encode(),b'',1)==normalized(blob(BASE,ENTRY)),'literal implicit owner rewritten')
    old='tests/nomacro_scheduled_subsurface/age_groundwater_verify.py'
    require(normalized((ROOT/old).read_bytes())==normalized(blob(BASE,old)),'canonical AGE dispatch changed')
    return direct.nonselected_projection(baseline=BASE,runtime=RUNTIME)

def validate(q):
    expected=dict(status='CANONICAL_IMPLICIT_AND_DIRECT_SALTFARM_COMPOSITION_QUALIFIED',baseline=BASE,runtime=RUNTIME,pr=1758,full_periods=4,cold_windows=20,water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10,whole_scientific_equivalence='NOT_QUALIFIED',RC3_changed=False)
    require(all(q.get(k)==v for k,v in expected.items()),'composition source/scope/guard differs')

def source_guard():
    require(not git('diff','HEAD','--','app','src','reference','tools','tests','.github','integration'),'dirty composition surface')
    require(all('__pycache__/' in p and p.endswith('.pyc') for p in git('ls-files','--others','--exclude-standard','--','app','src','reference','tools').decode().splitlines()),'untracked composition source')
    for ref in (BASE,RUNTIME,direct.NATIVE):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'unqualified composed production')
    expected={'app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py','app/hybrid_water/direct_day_kernel.py','app/hybrid_water/direct_day_kernel.f90','tools/solute/run_water.py'}
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==expected,'unqualified canonical composition delta')
    for p in ('app/hybrid_water/direct_day_kernel.py','app/hybrid_water/direct_day_kernel.f90'):require(blob(RUNTIME,p)==blob(direct.NATIVE,p),'native bridge or lifecycle changed')
    current=direct.tree('HEAD','integration')
    for p,v in direct.tree(BASE,'integration').items():require(current.get(p)==v,'canonical integration evidence rewritten: '+p)
    for p,v in direct.tree(direct.RUNTIME,PROOF).items():require(current.get(p)==v,'sealed SaltFarm evidence rewritten: '+p)
    allowed={ENTRY,SELF,'tests/saltfarm_newton/direct_admission.py','tests/saltfarm_newton/test_direct_admission.py','tests/saltfarm_newton/test_composition_admission.py','docs/science/SALTFARM_DIRECT_KERNEL05.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    changed=set(git('diff','--name-only',RUNTIME,'HEAD').decode().splitlines())
    require(all(p in allowed or p.startswith(PROOF+'COMPOSITION_') or p==PROOF+'MERGE_RECEIPT.json' for p in changed),'foreign post-composition change')
    literal_guards();direct.audit_current_seal()

def legacy_decoder():
    """Execute the untouched original decoder at its exact recorded text bytes."""
    with tempfile.TemporaryDirectory(prefix='s5-composed-literal-proof-',dir=ROOT.parent) as folder:
        snapshot=Path(folder);target=snapshot/PROOF;target.mkdir(parents=True)
        for name,digest in direct.audit_current_seal().items():
            src=ROOT/PROOF/name;dst=target/name
            if src.suffix=='.zip':dst.hardlink_to(src)
            else:dst.write_bytes(direct.sealed_representation(src.read_bytes(),digest,name))
        (target/'SEAL.json').write_bytes((ROOT/PROOF/'SEAL.json').read_bytes())
        prior=snapshot/'integration/f-ci/saltfarm-newton-work01/WINDOWS_CURRENT.zip';prior.parent.mkdir(parents=True);prior.hardlink_to(ROOT/'integration/f-ci/saltfarm-newton-work01/WINDOWS_CURRENT.zip')
        with contextlib.redirect_stdout(io.StringIO()):decoder=runpy.run_path(str(target/'verify.py'),run_name='__main__')
    return decoder

def verify():
    q=json.loads((ROOT/PROOF/'COMPOSITION_QUALIFICATION.json').read_text());validate(q);source_guard()
    for test in ('test_direct_admission.py','test_composition_admission.py'):
        result=subprocess.run([sys.executable,'-B',str(ROOT/'tests/saltfarm_newton'/test)],capture_output=True,text=True,timeout=30)
        require(result.returncode==0,'composition negative controls failed: '+result.stderr)
    audit_raw=(ROOT/PROOF/'COMPOSITION_BASELINE_AUDIT.json').read_bytes()
    require(sha(normalized(audit_raw))==q['canonical_audit_sha256'],'canonical actual owner receipt changed')
    audit=json.loads(audit_raw);prior=json.loads(audit['actual_detached_owner']['stdout'])
    require(audit['head']==BASE and audit['exact_complete_tree'] is True and audit['actual_detached_owner']['returncode']==0 and audit['fresh_model_execution_claim'] is False,'canonical actual admission not demonstrated')
    require(prior['status']=='BOUNDED_ORIGINAL_IMPLICIT_WATER_CDE_SOURCE_RAW_NATIVE_ADMISSION_PASS' and prior['actual_full_periods']==32 and prior['actual_complete_native_cold_windows']==376 and prior['whole_scientific_equivalence']=='NOT_QUALIFIED','canonical implicit qualification censored')
    d=legacy_decoder()
    for platform in ('Windows','Ubuntu'):
        record=q['archives'][platform];raw=(ROOT/PROOF/record['archive']).read_bytes()
        require(len(raw)==record['bytes'] and sha(raw)==record['sha256'],'composition raw archive changed')
        with zipfile.ZipFile(io.BytesIO(raw)) as z,zipfile.ZipFile(ROOT/PROOF/('WINDOWS.zip' if platform=='Windows' else 'UBUNTU.zip')) as old:
            data={}
            for opt in ('O0','O2'):
                p='accept-'+opt;data[opt]=d['cold'](z,p,p+'/restart{a}-{b}')
                previous=('current-accept-' if platform=='Windows' else 'accept-')+opt+'/full'
                require(d['physical'](data[opt])==d['physical'](d['rows'](old,previous)) and d['csv'](z,p+'/full')==d['csv'](old,previous),'composed full physical/output trajectory changed')
                for day in (109,111,365,367,453,455,1460,1461):require(d['native'](z,p+'/full',day)[0]==d['native'](old,previous,day)[0],'composed complete native endpoint changed')
                report=json.loads(z.read(p+'/RESULT.json'));require(report['status']=='FULL_PASS' and report['days']==1461 and report['source_commit']==RUNTIME,'composed producer source or full report differs')
                build=json.loads(z.read('qualified-'+opt+'/BUILD.json'))
                native=build['identity']['direct_day_kernel'];require(native['protocol']=='swap5-direct-day-kernel-1','composed native transport missing')
                for key,name in [('bridge_sha256','direct_day_kernel.f90'),('host_sha256','direct_day_kernel.py')]:
                    actual=z.read('actual-source/'+name) if platform=='Windows' else blob(RUNTIME,'app/hybrid_water/'+name)
                    require(native[key]==sha(actual),'composed bridge source differs')
                for day in (109,111,365,367,453,455,1460,1461):require(d['native'](z,p+'/full',day)[1]['binding']['build']==build['identity'],'composed native build identity differs')
                old_build=('current-' if platform=='Windows' else 'qualified-')+opt+'/'
                generated={name[len('qualified-'+opt+'/'):]:z.read(name) for name in z.namelist() if name.startswith('qualified-'+opt+'/') and name.endswith('.f90')}
                original={name[len(old_build):]:old.read(name) for name in old.namelist() if name.startswith(old_build) and name.endswith('.f90')}
                require(generated==original,'composed generated Fortran differs from admitted physics')
                transaction=json.loads(z.read('transactions/RESULT.json'))[opt]
                require(all(transaction[k] is True for k in ('discard_replay_exact','independent_columns_exact','continuous_day454_exact','origin_unchanged','foreign_policy_refused')),'composed coupling transaction failed')
            require(d['physical'](data['O0'])==d['physical'](data['O2']),'composed optimization differs')
    return dict(status='CANONICAL_IMPLICIT_AND_DIRECT_SALTFARM_COMPOSITION_ADMISSION_PASS',baseline=BASE,runtime=RUNTIME,inherited_implicit_actual_full_periods=32,inherited_implicit_exact_cold_windows=376,fresh_saltfarm_full_periods=4,fresh_saltfarm_exact_cold_windows=20,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL',water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10,RC3_changed=False)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
