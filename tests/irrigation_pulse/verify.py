"""Bounded current-source admission of PR1697, retaining the sealed R authority."""
from pathlib import Path
import hashlib,json,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[2]
BASE='a9044fdab7e333058c6a4dab34884e56e33c35a9'
RUNTIME='70f1c669e'
FULL_SEAL='30efbecfb7e37587019b64ccd6860d5d6a88fbdf'
COMPOSED_SEAL='8b3c5956d7068e86b7e7b19dd4f3395e5009ed4a'
PROOF='integration/irrigation-pulse-time01/'
ENTRY='tests/hupsel51/verify_successor.py'
HOOK='''    import importlib.util
    spec=importlib.util.spec_from_file_location('pulse_admission',ROOT/'tests/irrigation_pulse/verify.py')
    pulse=importlib.util.module_from_spec(spec);spec.loader.exec_module(pulse)
    return pulse.verify()
'''
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def require(test,message):
    if not test:raise ValueError(message)
def blob(ref,path):return git('show',ref+':'+path)
def native(windows,expected):
    require({(v['start'],v['end']) for v in windows}==expected,'missing exact native window')
    require(all(all(v.get(k) is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for v in windows),'inexact or overwritten native window')
def validate(q,composed):
    require(q['status']=='WINDOWS_UBUNTU_LOCAL_IRRIGATION_PULSE_O0_O2_FULL_NATIVE_BALANCE_PASS' and q['full_trajectories']==8 and q['full_model_days']==8768 and q['full_native_windows']==48,'incomplete full qualification')
    require(q['water_guard_cm']==q['solute_guard_mg_cm2']==1e-10 and q['tolerances_changed'] is False,'changed tolerance')
    require(q['science']=='NOT_QUALIFIED' and q['default_policy_changed'] is False,'science or default promoted')
    require(q['policy']=='original-adaptive-irrigation-pulse-v1' and q['substeps_per_active_pulse']==2048,'foreign pulse policy')
    require(set(q['platforms'])=={'WINDOWS','UBUNTU'},'missing platform')
    for platform in q['platforms'].values():
        r,f=platform['result'],platform['finish']
        require(r['water_guard_cm']==r['solute_guard_mg_cm2']==1e-10 and not r['tolerances_changed'] and r['science']=='NOT_QUALIFIED','platform guards/science changed')
        require(f['status']=='FULL_LITERAL_REFERENCE_PULSE_TRANSACTION_AND_PAIRED_COST_PASS','missing reference/transaction completion')
        require(set(r['cases'])=={'water-surface-history','chemical-surface-history'},'missing physical configuration')
        for key,item in r['cases'].items():
            checks=f['cases'][key]
            require(checks['literal_executed_inputs_exact'] and checks['cross_policy_checkpoint_refused'] and checks['days1through4_exact_to_baseline'],'input/policy/prefix drift')
            ref=checks['reference'];require(ref['status']=='COMPLETE_DIAGNOSTIC_REFERENCE' and ref['original_rows']==ref['swap5_rows']==1097 and ref['scientific_equivalence']=='NOT_QUALIFIED' and not ref['tolerances_changed'],'incomplete or promoted reference')
            for opt in ('O0','O2'):
                v=item[opt]['full'];b=v['budgets']
                require(v['status']=='FULL_PASS' and v['days']==b['days']==1096,'incomplete period')
                require(all(0<=b[n]<=1e-10 for n in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')),'failed mass guard')
                require(0<v['model_seconds']<30,'model cost cap exceeded')
                native(v['own'],{(2,4),(4,6),(199,201),(365,367),(530,532),(1094,1096)})
                c=checks[opt];require(all(c[k] for k in ('independent_origins','inconsistent_mass_refused','external_discard_replay_exact','external_disk_recovery','pulse_discard_replay_and_recovery_exact')) and c['pulse_metadata_refusals']==3 and len(c['native_refusals'])==4,'missing rollback/isolation/refusal')
    require(composed['status']=='ACTUAL_R_PULSE_COMPOSITION_GENERATED_INPUT_CLOSURE_AND_NATIVE_EXACT' and composed['canonical_base']==BASE and composed['source'].startswith(RUNTIME),'wrong composition/source')
    require(set(composed['profiles'])=={k+'-'+o for k in ('water-surface-history','chemical-surface-history') for o in ('O0','O2')},'missing composed profile')
    for v in composed['profiles'].values():
        require(v['all_emitted_dependencies_and_inputs_exact'] and v['prefix_exact_to_qualified_full'] and v['generated'] and v['prefix']['days']==201,'unproven dependency inheritance')
        native(v['prefix']['own'],{(4,6),(199,201)})
def verify():
    import importlib.util
    spec=importlib.util.spec_from_file_location('scheduled_ssdi_admission',ROOT/'tests/nomacro_scheduled_subsurface/verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
    git('merge-base','--is-ancestor',BASE,'HEAD');git('merge-base','--is-ancestor',FULL_SEAL,'HEAD');git('merge-base','--is-ancestor',COMPOSED_SEAL,'HEAD')
    require(not git('diff','HEAD','--','src','app','reference','tools','tests','.github','integration'),'dirty qualified surface')
    require(not git('diff',RUNTIME,'HEAD','--','src','app','reference','tools','tests/nomacro_drainage','tests/nomacro_time_event','tests/nomacro_frost','tests/nomacro_pond_history','tests/nomacro_mixtures','tests/irrigation_pulse/run.py','tests/irrigation_pulse/component.py','tests/irrigation_pulse/component.f90','tests/irrigation_pulse/finish.py','tests/irrigation_pulse/compose.py'),'runtime differs from qualified composition')
    paths=set(git('diff','--name-only',BASE,'HEAD').decode().splitlines())
    allowed={'app/hybrid_water/'+p for p in ('daily_host.py','daily_coupling.py','experimental_project.py','irrigation_pulse_time.py')}|{ENTRY,'.github/workflows/irrigation-pulse-time.yml'}
    require(all(p in allowed or p.startswith((PROOF,'tests/irrigation_pulse/')) for p in paths),'unqualified delta outside pulse owner')
    require(blob('HEAD',ENTRY).decode().replace(HOOK,'',1)==blob(BASE,ENTRY).decode() and blob('HEAD',ENTRY).decode().count(HOOK)==1,'historical R admission body changed')
    post=set(git('diff','--name-only',COMPOSED_SEAL,'HEAD').decode().splitlines())
    require(post<={ENTRY,'tests/irrigation_pulse/verify.py','tests/irrigation_pulse/test_verify.py',PROOF+'ADMISSION.json',PROOF+'MERGE.json',PROOF+'ADMISSION_RECOVERY.md','.github/workflows/irrigation-pulse-time.yml'},'unsealed post-composition delta')
    def sealed(ref,name):
        path=PROOF+name;require(blob('HEAD',path)==blob(ref,path),'sealed proof changed: '+name);return json.loads((ROOT/path).read_text())
    q=sealed(FULL_SEAL,'QUALIFICATION.json');composed=sealed(COMPOSED_SEAL,'COMPOSITION.json');validate(q,composed)
    previous=sealed(COMPOSED_SEAL,'R_BASELINE_CONSUMER.json')
    require(previous['source']==BASE and len(previous['records'])==2 and all(v['returncode']==0 for v in previous['records']),'actual R consumer not verified')
    require(json.loads(previous['records'][1]['stdout'])['current_R_full_days']==17536,'R prior qualification missing')
    old=sealed(COMPOSED_SEAL,'UNSELECTED_R.json');require(old['status']=='EXACT_LITERAL_UNSELECTED_R_CODE_PRESERVED' and old['base']==BASE and len(old['records'])==3 and all(v['unselected_body_exact_to_R'] for v in old['records'].values()),'unselected R body changed')
    hosted=sealed(FULL_SEAL,'HOSTED.json');require(hosted['completion_run']==44048454336 and hosted['completion_conclusion']=='success' and hosted['initial_conclusion']=='failure' and hosted['dependency_diff_verified'],'hosted source/control completion changed')
    archives=sealed(FULL_SEAL,'ARCHIVES.json')+[sealed(COMPOSED_SEAL,'RAW_COMPOSED.json')]
    for a in archives:
        path=ROOT/PROOF/a['archive'];require(hashlib.sha256(path.read_bytes()).hexdigest()==a['sha256'],'raw archive identity')
        with zipfile.ZipFile(path) as z:
            require(len(z.namelist())==len(set(z.namelist())) and json.loads(z.read('MANIFEST.json'))==a['members'],'raw inventory')
            for n,h in a['members'].items():require(hashlib.sha256(z.read(n)).hexdigest()==h,'raw member: '+n)
    return dict(status='CURRENT_R_PLUS_LOCAL_PULSE_ADMISSION_PASS',runtime=git('rev-parse',RUNTIME).decode().strip(),inherited_full_days=8768,full_native_windows=48,fresh_composed_native_windows=8,prior_R_full_days=17536,default_policy_changed=False,whole_scientific_equivalence='NOT_QUALIFIED',tolerances_changed=False)
if __name__=='__main__':print(json.dumps(verify(),indent=2))
