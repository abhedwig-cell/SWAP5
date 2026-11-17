"""Exact monthly/explicit-date age state and source successor authority."""
from pathlib import Path
import hashlib
import importlib.util
import json
import math
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
BASE='a97978f39b8ce89a4d7aaec64172d43bfef88288'
RUNTIME='f19bdf187a187e5d241fc3841eba9acfad63bc37'
UBUNTU='a376307776ea05bd975b6bf04a67e8c7baf7256b'
SEALED='bc03011bae1d4b3a7060cf16cf95c490d1ecf025'
PROOF='integration/f-ci/nomacro-complete01/'
SELF='tests/nomacro_scheduled_subsurface/age_schedule_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_age_schedule_verify.py'
ENTRY='tests/nomacro_scheduled_subsurface/age_calendar_verify.py'
AGE_TOL='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)'
POLICY='original-monthly-explicit-date-age-output-v1'
KINDS=('plain','surface','subsurface-interval')
MODES=('monthly','explicit','combined')
PROFILES={mode+'-'+kind+'-'+opt:(mode,kind,opt) for mode in MODES for kind in KINDS for opt in ('O0','O2')}
CONTROLS={mode+'-'+kind+'-'+opt for mode,kind in [('monthly','subsurface-interval'),('explicit','surface'),('combined','plain')] for opt in ('O0','O2')}
ATTACKS={'old002','old003','truncated','header-witness','shape','policy','negative-day','foreign-day','negative-counter','changed-counter','print-counter','zero-pointer','overflow-pointer','foreign-pointer','flag-domain','foreign-short-flag','nonfinite-value','value-witness','negative-period','foreign-age-clock'}
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('scheduled_age_output_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_schedule_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""


def require(ok,why):
    if not ok:raise ValueError(why)


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def tree(ref,prefix):return {r.split('\t',1)[1]:r.split('\t',1)[0] for r in git('ls-tree','-r',ref,'--',prefix).decode().splitlines()}
def sha(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
def bounded(value,limit=1e-10):return isinstance(value,(int,float)) and math.isfinite(value) and 0<=value<=limit
def exact(w):return all(w[k] is True for k in ('exact_physical','exact_sparse_five_csv','exact_complete_native','origin_unchanged'))
def old_exact(w,age=True):return all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) and (not age or w['all_four_age_csv_exact'] is True)


def validate(q):
    require(q['status']=='ORIGINAL_MONTHLY_EXPLICIT_AGE_SOURCE_STATE_OUTPUT_QUALIFIED' and (q['baseline'],q['runtime'],q['ubuntu'])==(BASE,RUNTIME,UBUNTU),'foreign original age schedule evidence')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['release_readiness']=='RC3_FIXED_NAMED_PROFILES_ONLY','unqualified schedule scope promotion')
    require(q['water_guard_cm']==1e-10 and q['chemical_mass_guard_changed'] is False and q['age_tolerance']==AGE_TOL and q['age_units']=='cm day','schedule units/guards changed')
    require(q['native_codec']=='S5AGE004' and q['daily_native_codec_preserved']=='S5AGE002' and q['regular_native_codec_preserved']=='S5AGE003' and q['policy']==POLICY,'schedule native/policy drift')
    require(q['scope']==dict(kinds=list(KINDS),modes=list(MODES),nprintday=1,initial_age_day=100,irrigation_age_day=0.,nodes=34,heat=1,snow=False,aquifer=False,macro=False,subdaily=False),'unqualified schedule domain')
    parent=json.loads((ROOT/PROOF/'AGE_CALENDAR_QUALIFICATION.json').read_text())
    require(q['physical_age_providers']==parent['physical_age_providers'] and q['receipt_provider_canonical_sha256']==parent['receipt_provider_canonical_sha256'] and q['regular_owner_canonical_sha256']==parent['calendar_source_canonical_sha256'],'schedule changed admitted physical/regular evaluator')
    require(q['source_canonical_sha256']==sha(ROOT/'app/hybrid_water/age_output_schedule.py') and q['regular_owner_canonical_sha256']==sha(ROOT/'app/hybrid_water/age_output_calendar.py') and q['receipt_provider_canonical_sha256']==sha(ROOT/'src/process/mod_original_output_receipt.f90'),'schedule production source differs')
    for key in ('platforms','builds','original_reference','controls','reader_controls','regular_preservation','inactive','daily_fixed_preservation'):
        require(set(q[key])=={'Windows','Ubuntu'},'schedule platform missing: '+key)
    for platform,run in q['platforms'].items():
        require(run['status']=='EIGHTEEN_ORIGINAL_AGE_SCHEDULE_FULL_O0_O2_SOURCE_OUTPUT_NATIVE_PASS' and set(run['profiles'])==set(PROFILES),'schedule complete runtime absent')
        require(run['water_guard_cm']==1e-10 and run['chemical_mass_guard_changed'] is False and run['whole_scientific_equivalence']=='NOT_QUALIFIED','schedule runtime science promoted')
        require(set(q['builds'][platform])==set(PROFILES),'schedule compiled context missing')
        for name,(mode,kind,opt) in PROFILES.items():
            r=run['profiles'][name];require(r['status']=='ORIGINAL_AGE_SCHEDULE_FULL_SOURCE_OUTPUT_NATIVE_PASS' and (r['mode'],r['kind'],r['optimization'])==(mode,kind,opt),'foreign scheduled age profile')
            for phase,days,windows in [('short',45,{(1,4),(3,6),(4,8),(30,34)}),('full',1096,{(1,4),(3,6),(4,8),(30,34),(199,201),(364,367),(530,532),(1094,1096)})]:
                t=r[phase];require(t['status']==phase.upper()+'_PASS' and t['days']==t['budgets']['days']==days and all(bounded(t['budgets'][k]) for k in ('max_water_cm','max_kernel_cm')),'schedule period incomplete/imbalanced')
                require(bounded(t['maximum_age_tolerance_fraction'],1),'schedule age budget exceeded')
                require(len(t['own'])==len(windows) and {(w['start'],w['end']) for w in t['own']}==windows and all(map(exact,t['own'])),'schedule month/year/terminal native missing')
                output=t['output'];require(output['original_sparse_cadence_retained'] is True and output['all_means_and_volumes_match_actual_daily_probe'] is True and 0<len(output['actual_dates'])<days,'schedule cadence/effluent units drift')
            build=q['builds'][platform][name];identity=build['identity'];age=identity['conserved_original_age'];schedule=age['output_schedule']
            require(build['project']['model']=='HYBRID_NOMACRO_WATER' and build['project']['nodes']==34 and build['project']['water_tolerance']==1e-10,'foreign schedule compiled model')
            require(age['providers']==q['physical_age_providers'] and age['native_codec']=='S5AGE004' and age['age_tolerance']==AGE_TOL and age['chemical_mass_guard_changed'] is False and 'output_calendar' not in age,'schedule physical/native identity differs')
            require(schedule==dict(policy=POLICY,native_codec='S5AGE004',mode=mode,swmonth=int(mode=='monthly'),swodat=int(mode!='monthly'),period=7 if mode=='combined' else 0,swres=0,nprintday=1,source_sha256=q['source_canonical_sha256'],regular_owner_sha256=q['regular_owner_canonical_sha256'],receipt_provider_sha256=q['receipt_provider_canonical_sha256'],original_integral_sha256='62e4d36693eb090eb7ba2c20871fce619ab4314cee75bb6961aa531cb734207a',undefined_allocation_tails_serialized=False),'actual original schedule policy differs')
            require('conserved_subsurface_solute' not in identity and 'conserved_scheduled_subsurface_solute' not in identity,'age schedule activated chemical source')
            if kind!='plain':require(identity['original_age_fixed_irrigation']['irrigation_age_day']==0. and identity['original_age_fixed_irrigation']['policy']=='original-fixed-young-water-age-zero-days-v1','schedule inflow age changed')
            for flags in (identity['donor_flags'],identity['kernel_flags']):require('-'+opt in flags and all(f in flags for f in ('-ffp-contract=off','-march=x86-64','-mtune=generic')),'schedule arithmetic drift')
        ref=q['original_reference'][platform]
        require(ref['status']=='EIGHTEEN_ORIGINAL_AGE_SCHEDULE_FULL_REFERENCE_EXECUTIONS_PASS' and set(ref['profiles'])==set(PROFILES) and ref['fresh_compile'] is False and ref['reference_parent']==parent['runtime'] and ref['builds']==parent['original_reference'][platform]['builds'],'unbound original schedule reference reuse')
        require(ref['compiler']==next(iter(q['builds'][platform].values()))['identity']['compiler'] and ref['whole_scientific_equivalence']=='NOT_QUALIFIED','original schedule compiler/science drift')
        for name,r in ref['profiles'].items():
            opt=PROFILES[name][2];require(r['days']==1096 and bounded(r['maximum_fraction_of_accepted_age_tolerance'],1) and r['tolerance_policy']==AGE_TOL and r['chemical_mass_guard_changed'] is False,'original schedule age ledger missing')
            require(r['executable_sha256']==ref['builds'][opt]['executable_sha256'] and r['input_sha256']==q['builds'][platform][name]['inputs'] and r['returncode'] in (0,100),'unbound original schedule execution/input')
            require(r['output']['original_sparse_cadence_retained'] is True and r['output']['all_means_and_volumes_match_actual_daily_probe'] is True,'original schedule effluent output missing')
            residual=r['maximum_observed_water_residual_cm'];require(bounded(residual,1) and r['original_water_balance_status']==('PASS' if residual<=1e-10 else 'NOT_QUALIFIED') and r['whole_scientific_equivalence']=='NOT_QUALIFIED','original schedule water science promoted')
        controls=q['controls'][platform];require(controls['status']=='ORIGINAL_AGE_SCHEDULE004_NATIVE_ACTIVE_POLICY_AND_ISOLATION_PASS' and set(controls['profiles'])==CONTROLS,'schedule native controls missing')
        for name,r in controls['profiles'].items():
            attacks=r['native_refusals'];require(len(attacks)==20 and {r['attack'] for r in attacks}==ATTACKS and all(r['status']=='REFUSED' for r in attacks),'schedule actual reader refusal missing')
            policies=r['policy_refusals'];require(len(policies)==3 and {r['field'] for r in policies}=={'policy','regular_owner_sha256','source_sha256'} and all(r['status']=='REFUSED' for r in policies),'schedule policy refusal missing')
            if PROFILES[name][1]=='plain':require(r['transactions'] is None,'unqualified plain schedule gift claim')
            else:
                t=r['transactions'];require(t['active_gift_day']==5 and t['independent_steps']==6 and all(t[k] is True for k in ('discard_replay_exact','disk_recovery_exact','committed_state_unchanged','origin_unchanged')),'schedule native transaction ownership lost')
                require(len(t['checks'])==2 and {r['attack'] for r in t['checks']}=={'water-receipt','age-production'} and all(r['status']=='REFUSED' for r in t['checks']),'schedule fabricated receipt accepted')
        readers=q['reader_controls'][platform];checks=readers['checks'];require(readers['status']=='ACTUAL_ORIGINAL_SCHEDULE_DATE_TABLE_READERS_REFUSED_INVALID_INPUT' and len(checks)==4 and {(r['optimization'],r['attack']) for r in checks}=={(o,a) for o in ('O0','O2') for a in ('missing-date-table','invalid-calendar-day')} and all(r['status']=='ORIGINAL_READER_REFUSED' for r in checks),'original date-table refusal missing')
        regular=q['regular_preservation'][platform];require(regular['status']=='FOURTEEN_REGULAR_AGE003_SOURCE_PROVIDER_YEAR_NATIVE_PRESERVED' and set(regular['profiles'])==set(parent['platforms'][platform]['profiles']) and regular['parent_runtime']==parent['runtime'],'regular003 preservation missing')
        for r in regular['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_all_csv_three_native_payloads_exact'] is True and r['coverage']['days']==368 and len(r['coverage']['own'])==2 and all(map(exact,r['coverage']['own'])),'regular003 source/state drift')
        inactive=q['inactive'][platform];require(inactive['status']=='FOUR_INACTIVE_FIXED_AGE_SOURCE_AND_ACTIVE_POND_NATIVE_EXACT' and set(inactive['profiles'])=={'0-O0','0-O2','100-O0','100-O2'},'daily002 preservation missing')
        for r in inactive['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_all_csv_four_native_payloads_exact'] is True and r['coverage']['days']==368 and len(r['coverage']['own'])==2 and all(map(old_exact,r['coverage']['own'])),'daily002 source/state drift')
        fixed=q['daily_fixed_preservation'][platform];require(fixed['status']=='EIGHT_DAILY_FIXED_AGE002_RENDERER_PROVIDER_PHYSICAL_CSV_NATIVE_PRESERVED' and set(fixed['profiles'])=={k+'-'+o for k in ('sprinkler','surface','subsurface','subsurface-interval') for o in ('O0','O2')},'fixed daily002 preservation missing')
        for r in fixed['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_all_csv_four_native_payloads_exact'] is True and r['coverage']['days']==8 and old_exact(r['coverage']['own']),'fixed daily002 source/state drift')
    off=q['age_off_preservation'];require(off['status']=='THIRTEEN_AGE_FIXED_OFF_CURRENT_PARENT_CONTEXTS_SOURCE_NATIVE_EXACT' and len(off['profiles'])==13,'scheduled age-off preservation missing')
    for r in off['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_csv_exact'] is True and len(r['coverage']['own'])>0 and all(old_exact(w,age=False) for w in r['coverage']['own']),'scheduled age-off source/state drift')
    cli=q['public_cli'];require(cli['status']=='PUBLIC_MONTHLY_AGE004_RUN_AND_MONTH_BOUNDARY_RESTART_PASS' and cli['warm_days']==35 and cli['window']==[30,34] and all(cli[k] is True for k in ('physical_exact','five_sparse_csv_exact','complete_native_exact')),'schedule public CLI absent')
    base=q['base_consumer'];require(base['merge']==BASE and base['exact_complete_tree'] is True and base['actual_detached_owner']['returncode']==0 and base['actual_detached_owner']['result']['status']=='CURRENT_REGULAR_AGE_CALENDAR_FIXED_AQUIFER_CHEMICAL_S_PULSE_R_ADMISSION_PASS','actual schedule canonical parent absent')
    inherited=q['unchanged_reference_inheritance'];require(inherited['status']=='EXACT_QUALIFIED_REGULAR_RENDERER_RECEIPT_AGE_PROVIDERS_AND_REFERENCE_REUSED' and inherited['parent_runtime']==parent['runtime'] and inherited['fresh_compile'] is False,'schedule reused component/reference unbound')
    require(q['workflow']['id']==44172278079 and q['workflow']['status']=='SUCCESS','schedule actual Linux gate absent')
    artifact=q['workflow']['artifact']
    require((artifact['id'],artifact['run'],artifact['bytes'],artifact['sha256'])==(14368607674,44172278079,211632209,'21c156a6ffca0024f1cd48412ae581cb89f5ac9ce6e53972e404c9d3707d5c32') and artifact['all_members_forward_verified'] is True and artifact['member_count']==len(artifact['members'])==22846,'schedule actual Linux artifact unbound')


def verify():
    import importlib.util
    spec=importlib.util.spec_from_file_location('original_age_clock_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_clock_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty original age schedule admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'schedule runtime differs from qualification')
    require(not git('diff',BASE,RUNTIME,'--','src','reference','tools','app/hybrid_water/age_output_calendar.py'),'schedule changed admitted physical/regular/reference owner')
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app').decode().splitlines())=={'app/hybrid_water/age_output_schedule.py','app/hybrid_water/experimental_project.py','app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py'},'unqualified age schedule dependency surface')
    require(set(git('diff','--name-only',RUNTIME,UBUNTU).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'schedule carrier changed science')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'literal regular age owner changed')
    require(set(git('diff','--name-only',RUNTIME,'HEAD','--','tests').decode().splitlines())<={SELF,TEST,ENTRY},'executed schedule controller changed')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'immutable schedule parent/seal changed: '+path)
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,PROOF+'AGE_SCHEDULE_MERGE_RECEIPT.json'},'unqualified post-seal schedule change')
    q=json.loads((ROOT/PROOF/'AGE_SCHEDULE_QUALIFICATION.json').read_text());validate(q)
    for platform,r in q['platforms'].items():
        for executed in (r,q['original_reference'][platform],q['regular_preservation'][platform],*r['profiles'].values()):require(not git('diff',executed['source_commit'],RUNTIME,'--','app','src','reference','tools'),'actual schedule execution source differs')
    require(not git('diff',q['age_off_preservation']['source_commit'],RUNTIME,'--','app','src','reference','tools'),'actual schedule off-preservation source differs')
    spec=importlib.util.spec_from_file_location('schedule_regular_parent',ROOT/ENTRY);parent=importlib.util.module_from_spec(spec);spec.loader.exec_module(parent);parent.validate(json.loads((ROOT/PROOF/'AGE_CALENDAR_QUALIFICATION.json').read_text()))
    for path,digest in q['controller_canonical_sha256'].items():require(sha(ROOT/path)==digest,'schedule executed controller differs')
    for path in sorted((ROOT/PROOF).glob('AGE_*_RAW_ARCHIVE.json')):
        r=json.loads(path.read_text());archive=ROOT/PROOF/r['archive']
        if path.name.startswith('AGE_SCHEDULE_'):require(q['archives'].get(path.name)==r,'schedule raw record differs from qualification')
        require(r['all_members_forward_verified'] is True and len(r['members'])==r['member_count'] and archive.stat().st_size==r['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==r['sha256'],'schedule raw identity changed')
        with zipfile.ZipFile(archive) as z:
            require({n for n in z.namelist() if not n.endswith('/')}==set(r['members']),'schedule raw member omitted')
            for name,digest in r['members'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'schedule raw member changed')
    forwarded={}
    for group in ('O0','O2','REGULAR','CONTEXT'):
        r=q['archives']['AGE_SCHEDULE_UBUNTU_'+group+'_RAW_ARCHIVE.json']
        require(r['origin_artifact_sha256']==q['workflow']['artifact']['sha256'],'foreign schedule portable raw source')
        for path,digest in r['members'].items():
            require(path.startswith('age-schedule-ubuntu/'),'foreign schedule portable member prefix')
            tail=path[len('age-schedule-ubuntu/'):];require(tail not in forwarded,'schedule portable member forwarded twice');forwarded[tail]=digest
    require(forwarded==q['workflow']['artifact']['members'],'actual schedule portable artifact omitted or changed')
    return dict(status='CURRENT_MONTHLY_EXPLICIT_AGE_REGULAR_FIXED_AQUIFER_CHEMICAL_S_PULSE_R_ADMISSION_PASS',runtime=RUNTIME,
                functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10,
                chemical_mass_guard_changed=False,age_units='cm day',native_codec='S5AGE004',daily_native_codec='S5AGE002',regular_native_codec='S5AGE003')


if __name__=='__main__':print(json.dumps(verify(),indent=2))
