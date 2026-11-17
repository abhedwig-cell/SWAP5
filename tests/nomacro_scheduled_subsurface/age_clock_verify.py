"""Bounded005 output-clock successor; admission remains disabled until sealing."""
from pathlib import Path
import ast
import hashlib
import importlib.util
import json
import math
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
BASE='b6dc588ef283fc141cb2d6b942c29912ba6bde96'
RUNTIME='4a3bdf387ce50c1e497f22eaeeb8c4005c6e9f24'
UBUNTU='8844c39e63c4ea1739b8faea959c27fc0c528718'
SEALED='UNSEALED_NOT_QUALIFIED'
PROOF='integration/f-ci/nomacro-complete01/'
SELF='tests/nomacro_scheduled_subsurface/age_clock_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_age_clock_verify.py'
ENTRY='tests/nomacro_scheduled_subsurface/age_schedule_verify.py'
AGE_TOL='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)'
POLICY='original-bound-output-epoch-age-clock-v1'
TRIAL='original-integral-clone-absolute-day-water-guard-v1'
PROFILES={f'{mode}{n}-{kind}-{opt}':(mode,n,kind,opt)
          for mode,n,kinds in [('subdaily',2,('plain','surface','subsurface-interval')),
                               ('subdaily',3,('plain','surface','subsurface-interval')),
                               ('annual',1,('plain','subsurface-interval'))]
          for kind in kinds for opt in ('O0','O2')}
CONTROLS={f'{mode}-{kind}-{opt}' for mode,kind in [('subdaily2','surface'),('subdaily3','subsurface-interval'),('annual1','plain')] for opt in ('O0','O2')}
ATTACKS={'old002','old003','old004','truncated','header-witness','shape','policy','negative-day','foreign-day','negative-counter','changed-counter','print-counter','zero-pointer','overflow-pointer','foreign-pointer','flag-domain','foreign-short-flag','nonfinite-value','value-witness','negative-period','foreign-age-clock'}
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('original_age_clock_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_clock_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""


def require(ok,why):
    if not ok:raise ValueError(why)


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def tree(ref,prefix):return {r.split('\t',1)[1]:r.split('\t',1)[0] for r in git('ls-tree','-r',ref,'--',prefix).decode().splitlines()}
def sha(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
def bounded(v,limit=1e-10):return isinstance(v,(int,float)) and math.isfinite(v) and 0<=v<=limit
def exact(w):return all(w[k] is True for k in ('exact_physical','exact_original_five_csv','exact_complete_native','origin_unchanged'))
def sparse(w):return all(w[k] is True for k in ('exact_physical','exact_sparse_five_csv','exact_complete_native','origin_unchanged'))
def old_exact(w):return all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged','all_four_age_csv_exact'))


def output(r,mode,n,days,reference=False):
    if mode=='annual':
        require(r['original_sparse_cadence_retained'] is True and r['all_means_and_volumes_match_actual_daily_probe'] is True and 0<len(r['actual_dates'])<days,'annual original output missing')
    elif reference:
        require(r['all_daily_mean_and_volume_fields_match_full_precision_probe'] is True and r['original_age_rows']==days and r['original_age_interval_days']==1./n,'original subdaily age interval drift')
        require(isinstance(r['original_primary_rows'],int) and r['original_primary_rows']>0,'original primary rows absent')
        exact_cadence=not r['missing_nominal_timestamps'] and not r['extra_original_timestamps'] and r['original_primary_rows']==days*n+1
        require(r['original_cadence_status']==('PASS' if exact_cadence else 'NOT_QUALIFIED'),'original event discrepancy promoted')
    else:
        require(r['all_daily_mean_and_volume_fields_match_full_precision_probe'] is True and r['original_primary_subdaily_and_age_daily_cadences_retained'] is True,'subdaily age values/cadences missing')
        require(r['primary_rows']==n*days+1 and r['age_profile_rows']==days and r['actual_final_age_output_interval_days']==1./n and r['age_output_interval']=='original output interval sampled by the actual age writer at day end','subdaily global output clock differs')
        require(r['original_datetime_formatter_status']=='INHERITED_FORMAT_LIMITATION_RETAINED' and isinstance(r['original_seconds60_formatter_rows'],int) and 0<=r['original_seconds60_formatter_rows']<=r['primary_rows'],'seconds60 format limitation hidden')


def validate(q):
    require(q['status']=='ORIGINAL_SUBDAILY_ANNUAL_AGE_CLOCK_SOURCE_STATE_OUTPUT_QUALIFIED' and (q['baseline'],q['runtime'],q['ubuntu'])==(BASE,RUNTIME,UBUNTU),'foreign005 qualification')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['release_readiness']=='RC3_FIXED_NAMED_PROFILES_ONLY','unqualified005 promotion')
    require(q['water_guard_cm']==1e-10 and q['chemical_mass_guard_changed'] is False and q['age_tolerance']==AGE_TOL and q['age_units']=='cm day','005 units or guards changed')
    require(q['native_codec']=='S5AGE005' and q['policy']==POLICY and q['trial_receipt_policy']==TRIAL,'005 state/numerical policy drift')
    parent=json.loads((ROOT/PROOF/'AGE_SCHEDULE_QUALIFICATION.json').read_text())
    require(q['physical_age_providers']==parent['physical_age_providers'] and q['receipt_provider_canonical_sha256']==parent['receipt_provider_canonical_sha256'],'005 changed physical provider')
    require(q['regular_owner_canonical_sha256']==parent['regular_owner_canonical_sha256'] and q['schedule_owner_canonical_sha256']==parent['source_canonical_sha256'],'005 changed prior calendar owner')
    require(q['source_canonical_sha256']==sha(ROOT/'app/hybrid_water/age_output_clock.py'),'005 source differs')
    require(q['original_watstor_canonical_sha256']=='71d5e7c93fecfe444f0862532f1db3bbfbef1ca0c552e673e45340216e27589c','005 original stock owner changed')
    require(q['scope']==dict(subdaily_frequencies=[2,3],subdaily_kinds=['plain','surface','subsurface-interval'],annual_kinds=['plain','subsurface-interval'],initial_age_day=100,irrigation_age_day=0.,nodes=34,heat=1,snow=False,aquifer=False,macro=False,flprintdt=False),'005 scope drift')
    for key in ('platforms','builds','components','original_reference','controls','reader_controls','schedule_preservation','regular_preservation','inactive','daily_fixed_preservation'):
        require(set(q[key])=={'Windows','Ubuntu'},'005 platform missing: '+key)
    for platform,run in q['platforms'].items():
        require(run['status']=='SIXTEEN_ORIGINAL_AGE_CLOCK_FULL_O0_O2_SOURCE_OUTPUT_NATIVE_PASS' and set(run['profiles'])==set(PROFILES),'005 runtime profiles missing')
        require(run['water_guard_cm']==1e-10 and run['whole_scientific_equivalence']=='NOT_QUALIFIED','005 runtime promoted')
        require(set(q['builds'][platform])==set(PROFILES),'005 compiled contexts missing')
        for name,(mode,n,kind,opt) in PROFILES.items():
            r=run['profiles'][name]
            require(r['status']=='ORIGINAL_AGE_OUTPUT_CLOCK_FULL_SOURCE_OUTPUT_NATIVE_PASS' and (r['mode'],r['nprint'],r['kind'],r['optimization'])==(mode,n,kind,opt),'foreign005 profile')
            require(r['water_guard_cm']==1e-10 and r['whole_scientific_equivalence']=='NOT_QUALIFIED','005 profile promoted')
            for phase,days in [('short',371 if mode=='annual' else 10),('full',1096)]:
                t=r[phase];windows={(1,4),(3,6),(4,8)}
                if mode=='annual' or phase=='full':windows.add((364,367))
                if phase=='full':windows|={(30,34),(199,201),(530,532),(1094,1096)}
                require(t['status']==phase.upper()+'_PASS' and t['days']==t['budgets']['days']==days and all(bounded(t['budgets'][k]) for k in ('max_water_cm','max_kernel_cm')),'005 incomplete/imbalanced period')
                require(bounded(t['maximum_age_tolerance_fraction'],1),'005 age balance exceeded')
                require(len(t['own'])==len(windows) and {(w['start'],w['end']) for w in t['own']}==windows and all(map(exact,t['own'])),'005 restart state/output missing')
                output(t['output'],mode,n,days)
            b=q['builds'][platform][name];identity=b['identity'];age=identity['conserved_original_age'];clock=age['output_clock']
            require(b['project']['model']=='HYBRID_NOMACRO_WATER' and b['project']['nodes']==34 and b['project']['water_tolerance']==1e-10,'foreign005 model')
            require(age['providers']==q['physical_age_providers'] and age['native_codec']=='S5AGE005' and age['age_tolerance']==AGE_TOL and age['chemical_mass_guard_changed'] is False,'005 physical/native identity changed')
            expected=dict(policy=POLICY,native_codec='S5AGE005',mode=mode,nprintday=n,requested_period=1 if mode=='subdaily' else 0,period=1 if mode=='subdaily' else 0,swmonth=0,swodat=0,swres=0,flprintdt=False,original_output_epoch=37256,initialization_epoch='physical-tstart-before-calendar-state-apply',source_sha256=q['source_canonical_sha256'],regular_owner_sha256=q['regular_owner_canonical_sha256'],schedule_owner_sha256=q['schedule_owner_canonical_sha256'],original_timecontrol_sha256='88b3d17865169672767b2d53460a625e191a6f6527067261e41bd99fd98e7c84',receipt_provider_sha256=q['receipt_provider_canonical_sha256'],original_integral_sha256='62e4d36693eb090eb7ba2c20871fce619ab4314cee75bb6961aa531cb734207a',original_watstor_sha256=q['original_watstor_canonical_sha256'],trial_receipt_policy=TRIAL if mode=='subdaily' else None,undefined_allocation_tails_serialized=False)
            require(clock==expected,'005 compiled clock policy differs')
            require(identity['time_step_policy']=='original-adaptive-day-seed-v1','005 numerical execution policy differs')
            if kind!='plain':require(identity['original_age_fixed_irrigation']['irrigation_age_day']==0. and identity['original_age_fixed_irrigation']['policy']=='original-fixed-young-water-age-zero-days-v1','005 young water age differs')
            for flags in (identity['donor_flags'],identity['kernel_flags']):require('-'+opt in flags and all(v in flags for v in ('-ffp-contract=off','-march=x86-64','-mtune=generic')),'005 arithmetic differs')
        components=q['components'][platform];require(set(components)=={'O0','O2'},'005 actual receipt component missing')
        for r in components.values():require(r['status']=='ACTUAL_ORIGINAL_TRIAL_RECEIPT_EXACT_NONMUTATION_42_PASS' and r['cases']==42 and len(r['linked_objects'])>=1,'005 real Integral component absent')
        ref=q['original_reference'][platform]
        require(ref['compiler']==next(iter(q['builds'][platform].values()))['identity']['compiler'] and ref['whole_scientific_equivalence']=='NOT_QUALIFIED','005 original compiler/science changed')
        require(ref['status']=='SIXTEEN_ORIGINAL_AGE_CLOCK_FULL_REFERENCE_EXECUTIONS_PASS' and set(ref['profiles'])==set(PROFILES) and ref['fresh_compile'] is False and ref['reference_parent']==parent['original_reference'][platform]['reference_parent'] and ref['builds']==parent['original_reference'][platform]['builds'],'005 original reference unbound')
        for name,r in ref['profiles'].items():
            mode,n,kind,opt=PROFILES[name]
            require(r['days']==1096 and bounded(r['maximum_fraction_of_accepted_age_tolerance'],1) and r['tolerance_policy']==AGE_TOL and r['chemical_mass_guard_changed'] is False,'005 original age ledger absent')
            require(r['executable_sha256']==ref['builds'][opt]['executable_sha256'] and r['input_sha256']==q['builds'][platform][name]['inputs'] and r['returncode'] in (0,100),'005 original input/executable drift')
            output(r['output'],mode,n,1096,reference=True)
            residual=r['maximum_observed_water_residual_cm'];require(bounded(residual,1) and r['original_water_balance_status']==('PASS' if residual<=1e-10 else 'NOT_QUALIFIED') and r['whole_scientific_equivalence']=='NOT_QUALIFIED','005 original water science promoted')
        controls=q['controls'][platform];require(controls['status']=='ORIGINAL_AGE_CLOCK005_NATIVE_ACTIVE_POLICY_AND_ISOLATION_PASS' and set(controls['profiles'])==CONTROLS,'005 actual native contexts absent')
        for name,r in controls['profiles'].items():
            attacks=r['native_refusals'];require(len(attacks)==21 and {x['attack'] for x in attacks}==ATTACKS and all(x['status']=='REFUSED' for x in attacks),'005 native attack admitted')
            policies=r['policy_refusals'];require(len(policies)==5 and {x['field'] for x in policies}=={'policy','regular_owner_sha256','source_sha256','original_watstor_sha256','trial_receipt_policy'} and all(x['status']=='REFUSED' for x in policies),'005 foreign policy admitted')
            if PROFILES[name][2]=='plain':require(r['transactions'] is None,'005 unqualified gift claim')
            else:
                t=r['transactions'];require(t['active_gift_day']==5 and t['independent_steps']==6 and all(t[k] is True for k in ('discard_replay_exact','disk_recovery_exact','committed_state_unchanged','origin_unchanged')),'005 trial ownership lost')
                require(len(t['checks'])==2 and {x['attack'] for x in t['checks']}=={'water-receipt','age-production'} and all(x['status']=='REFUSED' for x in t['checks']),'005 fabricated receipt accepted')
        reader=q['reader_controls'][platform]
        require(reader['status']=='EIGHT_ACTUAL_MONTHLY_INACTIVE_OMISSIONS_AND_TEN_CLOCK_INPUT_REFUSALS_PASS' and len(reader['omissions'])==8 and len(reader['invalid'])==10 and all(x['status']=='REFUSED' for x in reader['invalid']),'005 input refusal missing')
        for r in reader['omissions'].values():require(r['generated_provider_exact'] is True and r['physical35days_all_csv_two_native_exact'] is True and r['codec']=='S5AGE004' and r['coverage']['days']==35 and sparse(r['coverage']['own']),'005 monthly inactive input changed science/native')
        for key,parentkey,status,count in [('schedule_preservation','platforms','EIGHTEEN_SCHEDULE_AGE004_SOURCE_PROVIDER_YEAR_NATIVE_PRESERVED',18),('regular_preservation','regular_preservation','FOURTEEN_REGULAR_AGE003_SOURCE_PROVIDER_YEAR_NATIVE_PRESERVED',14)]:
            preserved=q[key][platform];require(preserved['status']==status and len(preserved['profiles'])==count and set(preserved['profiles'])==set(parent[parentkey][platform]['profiles']),'005 prior calendar preservation absent')
            for r in preserved['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_all_csv_three_native_payloads_exact'] is True and r['coverage']['days']==368 and len(r['coverage']['own'])==2 and all(map(sparse,r['coverage']['own'])),'005 prior calendar drift')
        inactive=q['inactive'][platform];require(inactive['status']=='FOUR_INACTIVE_FIXED_AGE_SOURCE_AND_ACTIVE_POND_NATIVE_EXACT' and len(inactive['profiles'])==4,'005 daily002 absent')
        for r in inactive['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_all_csv_four_native_payloads_exact'] is True and r['coverage']['days']==368 and len(r['coverage']['own'])==2 and all(map(old_exact,r['coverage']['own'])),'005 daily002 drift')
        fixed=q['daily_fixed_preservation'][platform];require(fixed['status']=='EIGHT_DAILY_FIXED_AGE002_RENDERER_PROVIDER_PHYSICAL_CSV_NATIVE_PRESERVED' and len(fixed['profiles'])==8,'005 fixed002 absent')
        for r in fixed['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_all_csv_four_native_payloads_exact'] is True and r['coverage']['days']==8 and old_exact(r['coverage']['own']),'005 fixed002 drift')
    off=q['age_off_preservation'];require(off['status']=='THIRTEEN_AGE_FIXED_OFF_CURRENT_PARENT_CONTEXTS_SOURCE_NATIVE_EXACT' and len(off['profiles'])==13,'005 age-off preservation absent')
    for r in off['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_csv_exact'] is True and all(w['exact_physical'] and w['exact_csv'] and w['exact_native'] and w['origin_unchanged'] for w in r['coverage']['own']),'005 age-off drift')
    cli=q['public_cli'];require(cli['status']=='PUBLIC_SUBDAILY_AGE005_RUN_AND_COLD_RESTART_PASS' and cli['warm_days']==10 and cli['window']==[4,8] and cli['nprintday']==3 and all(cli[k] is True for k in ('physical_exact','five_original_csv_exact','complete_native_exact')),'005 public CLI absent')
    base=q['base_consumer'];require(base['merge']==BASE and base['exact_complete_tree'] is True and base['actual_detached_owner']['returncode']==0 and base['actual_detached_owner']['result']['status']=='CURRENT_MONTHLY_EXPLICIT_AGE_REGULAR_FIXED_AQUIFER_CHEMICAL_S_PULSE_R_ADMISSION_PASS','005 actual canonical parent absent')
    artifact=q['workflow']['artifact'];require(q['workflow']['id']==44192970110 and artifact['id']==14377848736 and artifact['run']==44192970110 and artifact['bytes']==277875449 and artifact['sha256']=='2bae080196e82bf8291dfe8efb9e9ae72b9133ca3a4fc62c946b0ccf380beb56','005 portable run/archive differs')
    require(q['workflow']['status']=='SUCCESS' and artifact['all_members_forward_verified'] is True and artifact['member_count']==len(artifact['members']),'005 portable artifact incomplete')


def unchanged_selection(ref):
    before=blob(ref,'app/hybrid_water/age_output_clock.py').decode();after=blob(RUNTIME,'app/hybrid_water/age_output_clock.py').decode()
    def functions(text):return {n.name:ast.get_source_segment(text,n) for n in ast.parse(text).body if isinstance(n,ast.FunctionDef)}
    a,b=functions(before),functions(after)
    require(all(a[name]==b[name] for name in ('selection','age_identity')),'005 inherited nonselected routing changed')
    require(set(git('diff','--name-only',ref,RUNTIME,'--','app','src','reference','tools').decode().splitlines())<={'app/hybrid_water/age_output_clock.py'},'005 inherited prior context dependency changed')


def raw_reports(q):
    """Bind the semantic qualification back to the actual archived producers."""
    expected={}
    for platform in ('Windows','Ubuntu'):
        prefix='age-clock-ubuntu/' if platform=='Ubuntu' else ''
        for name,r in q['platforms'][platform]['profiles'].items():
            opt=PROFILES[name][3]
            folder=prefix+('matrix-'+opt if platform=='Ubuntu' else 'age-clock-final-matrix-'+opt)+'/'+name+'/'
            expected[folder+'RESULT.json']=r
            expected[folder+'build/BUILD.json']=q['builds'][platform][name]
        for opt in ('O0','O2'):
            folder=prefix+('receipt-'+opt if platform=='Ubuntu' else 'age-clock-absolute-receipt-'+opt)
            expected[folder+'/RESULT.json']=q['components'][platform][opt]
        for key,win,linux in [('original_reference','age-clock-final-reference','reference'),('controls','age-clock-final-controls','controls'),('reader_controls','age-clock-reader','reader'),('schedule_preservation','age-clock-schedule004-preserve','schedule004-preserve'),('regular_preservation','age-clock-regular003-preserve','regular003-preserve'),('inactive','age-clock-inactive','inactive'),('daily_fixed_preservation','age-clock-daily-fixed002-preserve','daily-fixed-preserve')]:
            expected[prefix+(linux if platform=='Ubuntu' else win)+'/RESULT.json']=q[key][platform]
    expected['age-clock-off-preserve/RESULT.json']=q['age_off_preservation']
    expected['AGE_CLOCK_FINAL_PUBLIC_CLI.json']=q['public_cli']
    return expected


def verify():
    require(SEALED!='UNSEALED_NOT_QUALIFIED','005 admission is not sealed')
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty005 admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'005 production differs from qualification')
    require(not git('diff',BASE,RUNTIME,'--','src','reference','tools','app/hybrid_water/age_output_calendar.py','app/hybrid_water/age_output_schedule.py'),'005 changed admitted physical/reference/calendar source')
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app').decode().splitlines())=={'app/hybrid_water/age_output_clock.py','app/hybrid_water/experimental_project.py','app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py'},'005 unqualified application surface')
    require(set(git('diff','--name-only',RUNTIME,UBUNTU).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'005 carrier changed science')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'005 literal schedule owner changed')
    require(set(git('diff','--name-only',RUNTIME,'HEAD','--','tests').decode().splitlines())<={SELF,TEST,ENTRY},'005 executed controller changed')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'005 immutable evidence changed: '+path)
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,PROOF+'AGE_CLOCK_MERGE_RECEIPT.json'},'005 unqualified post-seal change')
    q=json.loads((ROOT/PROOF/'AGE_CLOCK_QUALIFICATION.json').read_text());validate(q)
    spec=importlib.util.spec_from_file_location('clock_schedule_parent',ROOT/ENTRY);parent=importlib.util.module_from_spec(spec);spec.loader.exec_module(parent);parent.validate(json.loads((ROOT/PROOF/'AGE_SCHEDULE_QUALIFICATION.json').read_text()))
    for platform,run in q['platforms'].items():
        for r in run['profiles'].values():require(not git('diff',r['source_commit'],RUNTIME,'--','app','src','reference','tools'),'005 executed profile source differs')
        for key in ('schedule_preservation','regular_preservation','inactive','daily_fixed_preservation'):unchanged_selection(q[key][platform]['source_commit'])
    unchanged_selection(q['age_off_preservation']['source_commit'])
    for path,digest in q['controller_canonical_sha256'].items():require(sha(ROOT/path)==digest,'005 executed controller differs')
    reports=raw_reports(q);observed=set()
    for path in sorted((ROOT/PROOF).glob('AGE_*_RAW_ARCHIVE.json')):
        r=json.loads(path.read_text());archive=ROOT/PROOF/r['archive']
        if path.name.startswith('AGE_CLOCK_'):require(q['archives'].get(path.name)==r,'005 raw record differs')
        require(r['all_members_forward_verified'] is True and len(r['members'])==r['member_count'] and archive.stat().st_size==r['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==r['sha256'],'005 raw identity changed')
        with zipfile.ZipFile(archive) as z:
            require({n for n in z.namelist() if not n.endswith('/')}==set(r['members']),'005 raw member omitted')
            for name,digest in r['members'].items():
                data=z.read(name);require(hashlib.sha256(data).hexdigest()==digest,'005 raw member changed')
                if name in reports:
                    require(name not in observed and json.loads(data)==reports[name],'005 qualification differs from actual producer report: '+name)
                    observed.add(name)
    require(observed==set(reports),'005 actual producer report omitted')
    forwarded={}
    for name,r in q['archives'].items():
        if not name.startswith('AGE_CLOCK_UBUNTU_'):continue
        require(r['origin_artifact_sha256']==q['workflow']['artifact']['sha256'],'005 foreign portable raw')
        for path,digest in r['members'].items():
            require(path.startswith('age-clock-ubuntu/'),'005 foreign portable prefix')
            tail=path[len('age-clock-ubuntu/'):];require(tail not in forwarded,'005 portable member forwarded twice');forwarded[tail]=digest
    require(forwarded==q['workflow']['artifact']['members'],'005 portable member omitted/changed')
    return dict(status='CURRENT_SUBDAILY_ANNUAL_MONTHLY_AGE_SOURCE_STATE_OUTPUT_ADMISSION_PASS',runtime=RUNTIME,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10,chemical_mass_guard_changed=False,age_units='cm day',native_codec='S5AGE005')
