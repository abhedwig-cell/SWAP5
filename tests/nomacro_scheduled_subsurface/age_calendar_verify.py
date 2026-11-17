"""Source-bound original regular-age calendar successor admission authority."""
from pathlib import Path
import hashlib
import importlib.util
import json
import math
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
BASE='b2b05ae110366dae062663bd97c63d4187cdcd8d'
RUNTIME='75f4bf12f71286e0021877e9285df43beb6be01d'
UBUNTU='9321cc995ceaa327cab10b5ad0044fbb47fb0152'
SEALED='PENDING_ACTUAL_PORTABLE_QUALIFICATION'
PROOF='integration/f-ci/nomacro-complete01/'
SELF='tests/nomacro_scheduled_subsurface/age_calendar_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_age_calendar_verify.py'
ENTRY='tests/nomacro_scheduled_subsurface/age_fixed_verify.py'
AGE_TOL='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)'
POLICY='original-regular-age-output-independent-daily-receipt-v1'
SPECS=[(kind,period,0,opt) for kind in ('plain','surface','subsurface-interval') for period in (3,7) for opt in ('O0','O2')]+[('plain',7,1,opt) for opt in ('O0','O2')]
PROFILES={f'p{p}-{k}-r{r}-{o}':(k,p,r,o) for k,p,r,o in SPECS}
CONTROL_PROFILES={f'p{p}-{k}-r{r}-{o}' for k,p,r in [('surface',3,0),('subsurface-interval',7,0),('plain',7,1)] for o in ('O0','O2')}
ATTACKS={'old-codec','truncated','header-witness','shape','policy','negative-day','foreign-day','negative-counter','overflow-counter','print-counter','zero-pointer','overflow-pointer','foreign-pointer','flag-domain','foreign-short-flag','nonfinite-value','value-witness','negative-period','foreign-age-clock'}
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('regular_age_calendar_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_calendar_verify.py')
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


def validate(q):
    require(q['status']=='ORIGINAL_REGULAR_AGE_CALENDAR_SOURCE_STATE_OUTPUT_QUALIFIED' and (q['baseline'],q['runtime'],q['ubuntu'])==(BASE,RUNTIME,UBUNTU),'foreign regular age calendar evidence')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['release_readiness']=='RC3_FIXED_NAMED_PROFILES_ONLY','unqualified calendar scope promotion')
    require(q['water_guard_cm']==1e-10 and q['chemical_mass_guard_changed'] is False and q['age_tolerance']==AGE_TOL and q['age_units']=='cm day','calendar units/guards changed')
    require(q['native_codec']=='S5AGE003' and q['daily_native_codec_preserved']=='S5AGE002' and q['policy']==POLICY,'calendar native/policy changed')
    scope=q['scope'];require(scope==dict(kinds=['plain','surface','subsurface-interval'],periods=[3,7],nprintday=1,swodat=0,swmonth=0,swres=[0,1],initial_age_day=100,irrigation_age_day=0.,nodes=34,heat=1,snow=False,aquifer=False,macro=False),'unqualified calendar domain')
    require(q['receipt_provider_canonical_sha256']==sha(ROOT/'src/process/mod_original_output_receipt.f90') and q['calendar_source_canonical_sha256']==sha(ROOT/'app/hybrid_water/age_output_calendar.py'),'calendar production source changed')
    parent=json.loads((ROOT/PROOF/'AGE_FIXED_QUALIFICATION.json').read_text())
    require(q['physical_age_providers']==parent['provider_canonical_sha256'],'calendar changed physical age evaluator')
    for key in ('platforms','builds','original_reference','controls','inactive','daily_fixed_preservation','components'):
        require(set(q[key])=={'Windows','Ubuntu'},'calendar platform missing: '+key)
    for platform,run in q['platforms'].items():
        require(run['status']=='FOURTEEN_PERIODIC_AGE_FULL_O0_O2_SOURCE_OUTPUT_NATIVE_PASS' and set(run['profiles'])==set(PROFILES),'calendar complete runtime missing')
        require(run['water_guard_cm']==1e-10 and run['chemical_mass_guard_changed'] is False and run['whole_scientific_equivalence']=='NOT_QUALIFIED','calendar runtime science promoted')
        require(set(q['builds'][platform])==set(PROFILES),'calendar build missing')
        for name,(kind,period,reset,opt) in PROFILES.items():
            r=run['profiles'][name]
            require(r['status']=='REGULAR_AGE_CALENDAR_FULL_SOURCE_OUTPUT_NATIVE_PASS' and (r['kind'],r['period'],r['swres'],r['optimization'])==(kind,period,reset,opt),'foreign calendar profile')
            for phase,days,windows in [('short',10,{(1,4),(3,6),(4,8)}),('full',1096,{(1,4),(3,6),(4,8),(199,201),(364,367),(530,532),(1094,1096)})]:
                t=r[phase]
                require(t['status']==phase.upper()+'_PASS' and t['days']==t['budgets']['days']==days and all(bounded(t['budgets'][k]) for k in ('max_water_cm','max_kernel_cm')),'calendar period incomplete/imbalanced')
                require(bounded(t['maximum_age_tolerance_fraction'],1),'calendar age balance exceeded')
                require(len(t['own'])==len(windows) and {(w['start'],w['end']) for w in t['own']}==windows and all(map(exact,t['own'])),'calendar exact interval/year/terminal native missing')
                output=t['output'];require(output['original_sparse_cadence_retained'] is True and output['all_means_and_volumes_match_actual_daily_probe'] is True and 0<len(output['actual_dates'])<days,'calendar cadence/effluent units drift')
            build=q['builds'][platform][name];identity=build['identity'];age=identity['conserved_original_age'];calendar=age['output_calendar']
            require(build['project']['model']=='HYBRID_NOMACRO_WATER' and build['project']['nodes']==34 and build['project']['water_tolerance']==1e-10,'foreign calendar compiled model')
            require(age['providers']==q['physical_age_providers'] and age['native_codec']=='S5AGE003' and age['age_tolerance']==AGE_TOL and age['chemical_mass_guard_changed'] is False,'calendar age provider/native drift')
            require(calendar==dict(policy=POLICY,native_codec='S5AGE003',period=period,nprintday=1,swres=reset,source_sha256=q['calendar_source_canonical_sha256'],receipt_provider_sha256=q['receipt_provider_canonical_sha256'],original_integral_sha256='62e4d36693eb090eb7ba2c20871fce619ab4314cee75bb6961aa531cb734207a',undefined_allocation_tails_serialized=False),'actual calendar source/state policy differs')
            require('conserved_subsurface_solute' not in identity and 'conserved_scheduled_subsurface_solute' not in identity,'calendar activated chemical source')
            if kind!='plain':require(identity['original_age_fixed_irrigation']['irrigation_age_day']==0. and identity['original_age_fixed_irrigation']['policy']=='original-fixed-young-water-age-zero-days-v1','calendar input age drift')
            for flags in (identity['donor_flags'],identity['kernel_flags']):require('-'+opt in flags and all(f in flags for f in ('-ffp-contract=off','-march=x86-64','-mtune=generic')),'calendar arithmetic drift')
        ref=q['original_reference'][platform]
        require(ref['status']=='FOURTEEN_ORIGINAL_PERIODIC_AGE_FULL_SOURCE_LEDGER_OUTPUT_EXECUTIONS_PASS' and set(ref['profiles'])==set(PROFILES) and ref['whole_scientific_equivalence']=='NOT_QUALIFIED','calendar original reference missing/promoted')
        for name,r in ref['profiles'].items():
            opt=PROFILES[name][3]
            require(r['days']==1096 and bounded(r['maximum_fraction_of_accepted_age_tolerance'],1) and r['tolerance_policy']==AGE_TOL and r['chemical_mass_guard_changed'] is False,'calendar original age budget absent')
            require(r['executable_sha256']==ref['builds'][opt]['executable_sha256'] and r['input_sha256']==q['builds'][platform][name]['inputs'],'calendar unbound actual original reference')
            require(r['output']['original_sparse_cadence_retained'] is True and r['output']['all_means_and_volumes_match_actual_daily_probe'] is True,'original calendar output absent')
            residual=r['maximum_observed_water_residual_cm'];require(bounded(residual,1) and r['original_water_balance_status']==('PASS' if residual<=1e-10 else 'NOT_QUALIFIED') and r['whole_scientific_equivalence']=='NOT_QUALIFIED','original calendar water limitation misrepresented')
        controls=q['controls'][platform]
        require(controls['status']=='CALENDAR_NATIVE_READERS_ACTIVE_TRANSACTIONS_REFUSALS_AND_ISOLATION_PASS' and set(controls['profiles'])==CONTROL_PROFILES,'calendar controls missing')
        for name,r in controls['profiles'].items():
            attacks=r['native_refusals'];require(len(attacks)==19 and {v['attack'] for v in attacks}==ATTACKS and all(v['status']=='REFUSED' for v in attacks),'calendar actual native refusal absent')
            if PROFILES[name][0]=='plain':require(r['transactions'] is None,'unqualified plain gift claim')
            else:
                t=r['transactions'];require(t['active_gift_day']==5 and t['independent_steps']==6 and all(t[k] is True for k in ('discard_replay_exact','disk_recovery_exact','committed_state_unchanged','origin_unchanged')),'calendar transaction/native ownership lost')
                require(len(t['checks'])==2 and {r['attack'] for r in t['checks']}=={'water-receipt','age-production'} and all(r['status']=='REFUSED' for r in t['checks']),'calendar fabricated receipt accepted')
        inactive=q['inactive'][platform];require(inactive['status']=='FOUR_INACTIVE_FIXED_AGE_SOURCE_AND_ACTIVE_POND_NATIVE_EXACT' and set(inactive['profiles'])=={'0-O0','0-O2','100-O0','100-O2'},'calendar daily age context missing')
        for r in inactive['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_all_csv_four_native_payloads_exact'] is True and r['coverage']['days']==368,'calendar daily age source/native drift')
        fixed=q['daily_fixed_preservation'][platform];require(fixed['status']=='EIGHT_DAILY_FIXED_AGE002_RENDERER_PROVIDER_PHYSICAL_CSV_NATIVE_PRESERVED' and set(fixed['profiles'])=={k+'-'+o for k in ('sprinkler','surface','subsurface','subsurface-interval') for o in ('O0','O2')},'calendar daily fixed age missing')
        for r in fixed['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_all_csv_four_native_payloads_exact'] is True and r['coverage']['days']==8,'calendar daily fixed age source/native drift')
        component=q['components'][platform];require(component['status']=='PASS' and len(component['records'])==2 and {r['optimization'] for r in component['records']}=={0,2} and all(r['case']=='original_output_receipt' and r['compiler_requests']==3 for r in component['records']),'calendar small production receipt contract absent')
    off=q['age_off_preservation'];require(off['status']=='THIRTEEN_AGE_FIXED_OFF_CURRENT_PARENT_CONTEXTS_SOURCE_NATIVE_EXACT' and len(off['profiles'])==13,'calendar age-off context missing')
    for r in off['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_csv_exact'] is True,'calendar age-off source drift')
    cli=q['public_cli'];require(cli['status']=='PUBLIC_PERIODIC_AGE_RUN_AND_COLD_NATIVE_PASS' and cli['warm_days']==10 and cli['window']==[4,8] and all(cli[k] is True for k in ('physical_exact','five_sparse_csv_exact','complete_native_exact')),'calendar public CLI missing')
    base=q['base_consumer'];require(base['merge']==BASE and base['exact_complete_tree'] is True and base['actual_detached_owner']['returncode']==0 and base['actual_detached_owner']['result']['status']=='CURRENT_FIXED_YOUNG_AGE_COMPOSED_CHEMICAL_AQUIFER_S_PULSE_R_ADMISSION_PASS','calendar actual canonical parent absent')
    require(q['workflow']['id']==44163300199 and q['workflow']['status']=='SUCCESS','calendar actual Linux gate missing')


def verify():
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty regular age calendar admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'calendar runtime differs from qualification')
    require(not git('diff',BASE,RUNTIME,'--','reference','tools'),'calendar changed prior reference/public driver')
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app').decode().splitlines())=={'app/hybrid_water/age_output_calendar.py','app/hybrid_water/experimental_project.py','app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py'},'unqualified calendar application surface')
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','src').decode().splitlines())=={'src/process/mod_original_output_receipt.f90'},'calendar changed physical production evaluator')
    require(set(git('diff','--name-only',RUNTIME,UBUNTU).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'calendar carrier changed science')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'literal fixed age owner changed')
    require(set(git('diff','--name-only',RUNTIME,'HEAD','--','tests').decode().splitlines())<={SELF,TEST,ENTRY},'executed calendar controller changed')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'immutable calendar parent/sealed evidence changed: '+path)
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,PROOF+'AGE_CALENDAR_MERGE_RECEIPT.json'},'unqualified post-seal calendar change')
    q=json.loads((ROOT/PROOF/'AGE_CALENDAR_QUALIFICATION.json').read_text());validate(q)
    for platform,r in q['platforms'].items():
        for executed in (r,q['original_reference'][platform],*r['profiles'].values()):require(not git('diff',executed['source_commit'],RUNTIME,'--','app','src','reference','tools'),'actual calendar execution source differs')
    require(not git('diff',q['age_off_preservation']['source_commit'],RUNTIME,'--','app','src','reference','tools'),'actual calendar preservation source differs')
    spec=importlib.util.spec_from_file_location('calendar_fixed_parent',ROOT/ENTRY);parent=importlib.util.module_from_spec(spec);spec.loader.exec_module(parent);parent.validate(json.loads((ROOT/PROOF/'AGE_FIXED_QUALIFICATION.json').read_text()))
    for path,digest in q['controller_canonical_sha256'].items():require(sha(ROOT/path)==digest,'calendar executed controller changed')
    for path in sorted((ROOT/PROOF).glob('AGE_*_RAW_ARCHIVE.json')):
        r=json.loads(path.read_text());archive=ROOT/PROOF/r['archive']
        require(r['all_members_forward_verified'] is True and len(r['members'])==r['member_count'] and archive.stat().st_size==r['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==r['sha256'],'calendar raw identity changed')
        with zipfile.ZipFile(archive) as z:
            require({n for n in z.namelist() if not n.endswith('/')}==set(r['members']),'calendar raw member omitted')
            for name,digest in r['members'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'calendar raw member changed')
    return dict(status='CURRENT_REGULAR_AGE_CALENDAR_FIXED_AQUIFER_CHEMICAL_S_PULSE_R_ADMISSION_PASS',runtime=RUNTIME,
                functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10,
                chemical_mass_guard_changed=False,age_units='cm day',native_codec='S5AGE003',daily_native_codec='S5AGE002')


if __name__=='__main__':print(json.dumps(verify(),indent=2))
