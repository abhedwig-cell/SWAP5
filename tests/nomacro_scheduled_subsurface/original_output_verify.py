"""Bounded original-output successor with actual producer and source binding."""
from pathlib import Path
import hashlib
import importlib.util
import io
from functools import lru_cache
import json
import math
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
PROOF='integration/f-ci/nomacro-complete01/'
BASE='b9400bff64a5b21596995aca9eb045f974a52b21'
RUNTIME='98b5b0337a87cadbc4861e67056ec87c51237d47'
SEALED='c8ff9c67d75ca9be94f72924b8f38998782504af'
ENTRY='tests/nomacro_scheduled_subsurface/age_clock_verify.py'
SELF='tests/nomacro_scheduled_subsurface/original_output_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_original_output_verify.py'
POLICY='original-user-output-controls-v1'
AGE_TOL='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)'
CASES=('cde-solbal-csv3','age-csv3','water-nprint2','water-csv2','water-csv3','water-default-precision','water-csv0-omitted','water-nprint3','water-monthly','age-perstep-monthly','age-perstep-explicit','cde-csv0','cde-solbal-csv1','cde-solbal-csv2','age-csv0','age-csv2')
NATIVE={'water':'S5IOW001','cde':'S5IOC001','age':'S5IOA001'}
CONTEXTS=('water-nprint3','cde-solbal-csv3','age-csv3','age-perstep-monthly')
CONTROLLERS={'original_binary_output.py','original_cde_output_component.py','original_output_baseline.py','original_output_ci.py','original_output_controls.py','original_output_files.py','original_output_matrix.py','original_output_preserve.py','original_output_public.py','original_output_reader.py','original_vector_output.py'}
WORKFLOWS={'matrix':(44212855459,'67a7d88d5553b1ff0c1315fc20b8e67455fce0c3'),'preservation':(44214100995,'54590d52fe9d2139f4039ca0b6f1e99692aa6375'),'public_reader':(44215748326,'018460d6961896d8d261c493df022f72f1b77a65')}
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('original_output_admission',ROOT/'tests/nomacro_scheduled_subsurface/original_output_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""


def require(ok,why):
    if not ok:raise ValueError(why)


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def tree(ref,path):return {r.split('\t',1)[1]:r.split('\t',1)[0] for r in git('ls-tree','-r',ref,'--',path).decode().splitlines()}
def sha(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
def bounded(value,limit):return isinstance(value,(float,int)) and math.isfinite(value) and 0<=value<=limit


@lru_cache(maxsize=1)
def predecessor():return json.loads((ROOT/PROOF/'AGE_CLOCK_QUALIFICATION.json').read_text())


@lru_cache(maxsize=1)
def archive_records():return {p.name:json.loads(p.read_text()) for p in (ROOT/PROOF).glob('ORIGINAL_*_RAW_ARCHIVE.json')}


@lru_cache(maxsize=1)
def original_vector_catalog():
    path=ROOT/'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py'
    spec=importlib.util.spec_from_file_location('qualified_original_vector_catalog',path);patch=importlib.util.module_from_spec(spec);spec.loader.exec_module(patch)
    record=archive_records()['ORIGINAL_VECTOR_OUTPUT_COMPONENT_RAW_ARCHIVE.json']
    with zipfile.ZipFile(ROOT/PROOF/record['archive']) as z:source=z.read('O0-original-build/swap_csv_output.f90')
    return [list(row) for row in patch.catalog(source.decode('cp1252').replace('\r\n','\n'))]


def expected(case):
    kind='cde' if case.startswith('cde') else 'age' if case.startswith('age') else 'water'
    fmt=int(case[-1]) if '-csv' in case and case[-1] in '023' else 1
    if case=='water-csv0-omitted':fmt=0
    if case=='cde-solbal-csv1':fmt=1
    monthly=int('monthly' in case);dates=int('explicit' in case);perstep='perstep' in case
    nprint=2 if case=='water-nprint2' else 3 if case=='water-nprint3' else 1
    requested=0 if monthly or dates else 1
    groups=None if not fmt else 'WATBAL,GWL,SOLBAL,S_CONC,Q' if case.startswith('cde-solbal') else 'GWL' if case=='water-default-precision' else 'WATBAL,GWL'
    return dict(kind=kind,swcsv=fmt,nprintday=nprint,swmonth=monthly,swodat=dates,swres=0,requested_period=requested,period=1 if nprint>1 or perstep else requested,flprintdt=perstep,groups=groups,num_decimals=None if not fmt else 5 if case=='water-default-precision' else 12)


def selection(q,actual,case):
    selected=expected(case)
    require({k:actual[k] for k in selected}==selected,'foreign original output selectors: '+case)
    require(actual['policy']==POLICY and actual['native_codec']==NATIVE[selected['kind']],'foreign original output codec/policy')
    for key,target in [('source_sha256','source_canonical_sha256'),('calendar_owner_sha256','regular_owner_canonical_sha256'),('clock_owner_sha256','clock_owner_canonical_sha256'),('receipt_provider_sha256','receipt_provider_canonical_sha256')]:require(actual[key]==q[target],'foreign original output source identity')
    require(actual['original_integral_sha256']=='62e4d36693eb090eb7ba2c20871fce619ab4314cee75bb6961aa531cb734207a' and actual['original_output_epoch']==37256,'foreign original output epoch/increments')
    require(actual['cde_output_state_sha256']==(q['cde_state_canonical_sha256'] if selected['kind']=='cde' else None),'foreign CDE output owner')
    for key,kind,active in [('vector_catalog_correction_sha256','VECTOR',selected['swcsv']!=0),('binary_correction_sha256','BINARY',selected['swcsv']==3)]:
        require(actual[key]==(sha(ROOT/f'reference/swap-4.3.1/patches/NOMACRO-{kind}-OUTPUT-01/source.py') if active else None),'foreign original reference output correction')
    require(actual['preserves_requested_groups_and_precision'] is True and actual['undefined_allocation_tails_serialized'] is False,'original output controls/tails changed')


def files(w):
    return all(v['exact'] is True and isinstance(v['continuation_records'],int) and v['continuation_records']>=0 for v in w.values())


def validate(q):
    require((q['baseline'],q['runtime'])==(BASE,RUNTIME),'foreign original output source reference')
    require(q['status']=='BOUNDED_ORIGINAL_OUTPUT_SOURCE_STATE_USER_FILES_QUALIFIED_PENDING_ADMISSION','unqualified original output evidence')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['release_readiness'])==('PARTIAL','NOT_QUALIFIED','RC3_FIXED_NAMED_PROFILES_ONLY'),'original output evidence promoted')
    require(q['policy']==POLICY and q['water_guard_cm']==q['chemical_mass_guard_mg_cm2']==1e-10 and q['age_tolerance']==AGE_TOL and q['age_units']=='cm day','original output conservation policy changed')
    scope=dict(formats=[0,1,2,3],native_codecs=NATIVE,original_output_default=False,monthly=True,explicit_dates=True,subdaily=[2,3],perstep_reset=0,cde_cadence='daily-reset-only',active_macro=False,snow=False,aquifer=False,frost=False,hysteresis=False,physical_providers_changed=False)
    require(q['scope']==scope,'unqualified original output physical domain')
    require(q['source_canonical_sha256']==sha(ROOT/'app/hybrid_water/original_output.py') and q['cde_state_canonical_sha256']==sha(ROOT/'app/hybrid_water/original_cde_output_state.f90'),'changed actual original output owner')
    parent=predecessor()
    for key,old in [('physical_age_providers','physical_age_providers'),('regular_owner_canonical_sha256','regular_owner_canonical_sha256'),('schedule_owner_canonical_sha256','schedule_owner_canonical_sha256'),('clock_owner_canonical_sha256','source_canonical_sha256'),('receipt_provider_canonical_sha256','receipt_provider_canonical_sha256')]:require(q[key]==parent[old],'changed admitted physical/calendar provider')
    require(q['base_consumer']['merge']==BASE and q['base_consumer']['exact_complete_tree'] is True and q['base_consumer']['actual_detached_owner']['returncode']==0,'actual canonical predecessor not verified')
    for key in ('platforms','builds','controls','preservation','public_cli','reader_controls','format_independence','age_bounds','source_events'):require(set(q[key])=={'Windows','Ubuntu'},'original output platform missing: '+key)
    producers={run['source_commit'] for p in q['platforms'].values() for run in p.values()}
    producers|={record[phase]['source_commit'] for p in q['platforms'].values() for run in p.values() for record in run['cases'].values() for phase in ('short','full')}
    require(len(producers)==len(q['source_producer_refs'])==5 and producers==set(q['source_producer_refs']),'actual original output producer reference omitted')
    for platform in ('Windows','Ubuntu'):
        require(set(q['platforms'][platform])=={'O0','O2'} and set(q['builds'][platform])=={c+'-'+o for c in CASES for o in ('O0','O2')},'original output compiled context omitted')
        age_keys={c+'-'+o for c in CASES if expected(c)['kind']=='age' for o in ('O0','O2')};require(set(q['age_bounds'][platform])==age_keys,'age output guard observations omitted')
        for name,bound in q['age_bounds'][platform].items():require(bound['days']==1096 and bound['units']=='cm day' and bounded(bound['maximum_accepted_tolerance_fraction'],1),'actual age balance policy exceeded')
        require(set(q['source_events'][platform])=={c+'-'+o for c in CASES if c.startswith('cde-solbal') for o in ('O0','O2')},'active CDE output source missing')
        for event in q['source_events'][platform].values():require(event['day']==5 and event['initial_stock_mg_cm2']>0 and event['stock_before_gift_mg_cm2']>0 and abs(event['actual_gift_mg_cm2']-48)<=1e-10 and event['strict_budget_pass'] is True,'active chemical output event missing')
        for opt in ('O0','O2'):
            run=q['platforms'][platform][opt];require(run['status']=='SIXTEEN_ORIGINAL_OUTPUT_FULL_SOURCE_NATIVE_USER_OUTPUT_PASS' and run['optimization']==opt and set(run['cases'])==set(CASES),'original output trajectory missing')
            require(run['whole_scientific_equivalence']=='NOT_QUALIFIED' and run['functional_completion']=='PARTIAL','original output run promoted')
            for case,item in run['cases'].items():
                selected=expected(case);build=q['builds'][platform][case+'-'+opt];identity=build['identity']
                require(build['project']['model']=='HYBRID_NOMACRO_WATER' and build['project']['nodes']==34 and build['project']['water_tolerance']==1e-10,'foreign original output model')
                for phase in ('short','full'):
                    r=item[phase];selection(q,r['original_output'],case)
                    days=1096 if phase=='full' else 35 if selected['swmonth'] or selected['swodat'] else 10
                    require(r['status']=='ORIGINAL_OUTPUT_'+phase.upper()+'_NATIVE_SOURCE_PASS' and r['case']==case and r['optimization']==opt and r['functional_completion']=='PARTIAL' and r['whole_scientific_equivalence']=='NOT_QUALIFIED','foreign original output period')
                    require(r['requested_controls_preserved'] is True and r['trajectory']['days']==r['trajectory']['budgets']['days']==days,'original output calendar forced/period censored')
                    for key in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2'):require(bounded(r['trajectory']['budgets'][key],1e-10),'original output mass exceeded')
                    windows={(2,4),(days-3,days-1)}
                    if selected['swmonth'] or selected['swodat']:windows.add((30,34))
                    if phase=='full':windows|={(199,201),(364,367),(530,532),(1094,1096)}
                    require(len(r['own'])==len(windows) and {(w['start'],w['end']) for w in r['own']}==windows,'original output own window missing')
                    for w in r['own']:
                        require(all(w[k] is True for k in ('exact_physical','exact_complete_native','origin_unchanged')) and files(w['exact_user_output']),'original user output/native continuation differs')
                        name='result_output.bin' if selected['swcsv']==3 else 'result_output.csv'
                        require((name in w['exact_user_output'])==(selected['swcsv']!=0),'original output format silently changed')
                require(identity['original_output']==item['full']['original_output']==item['short']['original_output'],'actual build output policy differs')
                if selected['kind']=='age':require(identity['conserved_original_age']['native_codec']=='S5IOA001' and identity['conserved_original_age']['original_output']==identity['original_output'] and identity['conserved_original_age']['providers']==q['physical_age_providers'],'foreign age physical/output provider')
            control=q['controls'][platform][opt];require(control['status']=='ORIGINAL_OUTPUT_NATIVE_ACTIVE_POLICY_PASS' and control['contexts']==4 and set(control['profiles'])=={c+'-'+opt for c in CONTEXTS},'actual output reader contexts missing')
            for name,c in control['profiles'].items():
                require(len(c['native_refusals'])==(29 if name.startswith('cde') else 24) and all(a['status']=='REFUSED' and 'ERROR STOP' in a['diagnostic'] for a in c['native_refusals']),'actual output native refusal missing')
                require(len({a['attack'] for a in c['native_refusals']})==len(c['native_refusals']),'duplicate native attack')
                require(len(c['policy_refusals'])==5 and all(a['status']=='REFUSED' for a in c['policy_refusals']),'foreign output policy accepted')
                require(all(c['transactions'][k] is True for k in ('discard_no_day_advance','replay_exact','accept_exact','recovered_next_day_exact','origin_unchanged')),'output external transaction state drift')
            component=q['components']['integral'][platform][opt];require(component['status']=='ACTUAL_ORIGINAL_TRIAL_RECEIPT_EXACT_NONMUTATION_42_PASS' and component['cases']==42,'actual original increment/stock component missing')
        require(set(q['format_independence'][platform])=={k+'-'+o for k in ('water','cde','age') for o in ('O0','O2')},'format independence context missing')
        for record in q['format_independence'][platform].values():require(record['all1096_physical_rows_exact'] is True and record['five_complete_native_endpoints_exact'] is True,'format/precision changed physical state')
        p=q['preservation'][platform];require(p['default']['status']=='TWELVE_DEFAULT_005_004_003_SOURCE_PROVIDER_YEAR_NATIVE_CONTEXTS_PRESERVED' and len(p['default']['profiles'])==12,'default output preservation missing')
        for record in p['default']['profiles'].values():
            require(all(record[k] is True for k in ('source_provider_inputs_exact','all368_physical_and_user_output_exact','four_complete_native_endpoints_exact')) and record['coverage']['days']==368 and len(record['own'])==2,'default source/state preservation changed')
            require(all(w['exact_physical'] is True and w['exact_complete_native'] is True and w['origin_unchanged'] is True for w in record['own']),'default cold state differs')
            require('original_output' not in record['actual_build']['identity'],'default compatibility activated new output')
        require(p['daily002']['status']=='EIGHT_DAILY_FIXED_AGE002_RENDERER_PROVIDER_PHYSICAL_CSV_NATIVE_PRESERVED' and len(p['daily002']['profiles'])==8,'daily002 preserved contexts missing')
        for record in p['daily002']['profiles'].values():require(record['generated_provider_inputs_exact'] is True and record['physical_all_csv_four_native_payloads_exact'] is True and record['coverage']['own']['exact_native'] is True,'daily002 source/native drift')
        public=q['public_cli'][platform];require(public['status']=='THREE_PUBLIC_ORIGINAL_OUTPUT_FLAG_AND_COMPLETE_COLD_NATIVE_PASS' and set(public['profiles'])=={'water-nprint3','cde-solbal-csv3','age-perstep-monthly'},'public original-output route missing')
        for record in public['profiles'].values():require(all(record[k] is True for k in ('actual_public_flag','exact_physical','exact_complete_native')) and files(record['exact_original_user_output']) and record['warm']['returncode']==record['cold']['returncode']==0,'public output/native drift')
        reader=q['reader_controls'][platform];require(reader['status']=='FOUR_ORIGINAL_OMITTED_MONTHLY_CONTROLS_NATIVE_AND_SIXTEEN_INPUT_REFUSALS_PASS' and len(reader['profiles'])==4 and len(reader['invalid'])==16 and all(r['status']=='REFUSED' for r in reader['invalid']),'original output reader domain missing')
        for record in reader['profiles'].values():require(record['status']=='ORIGINAL_OUTPUT_SHORT_NATIVE_SOURCE_PASS' and record['original_output']['swcsv']==0 and record['original_output']['swmonth']==1 and record['trajectory']['days']==35 and len(record['own'])==3 and all(w['exact_complete_native'] is True for w in record['own']),'omitted monthly controls not native-safe')
        binary=q['components']['binary'][platform];require(binary['status']=='ORIGINAL_BINARY_SCRATCH_LIFETIME_CORRECTION_O0_O2_REAL4_ROUNDTRIP_PASS_NOT_ACTIVE_IN_SWAP5' and set(binary['profiles'])=={'O0','O2'},'original binary correction unqualified')
        require(binary['original_source_sha256']=='a1b1b261ec05153d2075099c04cc6bb656f657344d4c1ceb5c9e43d0fd225355' and binary['corrected_source_sha256']=='94a50f29f199a441942ed8c719b77480e4fcab3d0886c3021fab764f1d51a3bb','foreign original binary reference source')
        for r in binary['profiles'].values():require(r['roundtrip']['records']==5 and all(r['roundtrip'][k] is True for k in ('actual_original_API','original_unallocated_lifetime_observed','corrected_ascii_five_rows_exact','real4_values_exact','dates_exact','probe_did_not_change_payload')),'actual original binary correction/REAL4 proof missing')
        vector=q['components']['vector'][platform];require(vector['status']=='ORIGINAL_VECTOR_CATALOG_O0_O2_EXACT_TABLE_SCALAR_PRESERVATION_AND_VECTOR_SERIALIZATION_PASS_NOT_ACTIVE' and len(vector['catalog_rows'])==58 and all(len(row)==5 for row in vector['catalog_rows']),'actual original vector catalog proof missing')
        manifest=json.loads((ROOT/'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/manifest.json').read_text())
        require(vector['catalog_rows']==original_vector_catalog() and vector['original_source_sha256']==manifest['original_canonical_sha256'] and vector['corrected_source_sha256']==manifest['corrected_canonical_sha256'],'foreign original vector reference catalog/source')
        for r in vector['profiles'].values():require(all(r[k] is True for k in ('original_vector_refused','corrected_58_catalog_records_five_attributes_exact','scalar_output_unchanged','five_vector_ASCII_and_REAL4_source_values_exact','probe_payload_unchanged')),'vector table/value correction not exact')
        cde=q['components']['cde_state'][platform];require(cde['status']=='DAILY_CDE_OUTPUT_STATE_O0_O2_EXACT_STAGED_RESTORE_AND_28_REFUSALS_PASS','actual original CDE storage proof missing')
        require(cde['source_sha256']==q['cde_state_canonical_sha256'],'foreign actual CDE output storage source')
        for r in cde['profiles'].values():require(r['native_refusals']==14 and all(r[k] is True for k in ('staged_read_nonmutation','bit_exact_live_restore','repeated_apply_noop','actual_original_storage')),'CDE output restore nontransactional')
    require(set(q['workflows'])==set(WORKFLOWS),'portable selected run missing')
    for key,(run,carrier) in WORKFLOWS.items():require(q['workflows'][key]['id']==run and q['workflows'][key]['carrier']==carrier and q['workflows'][key]['status']=='SUCCESS','portable run not terminal qualified')
    require(len(q['archives'])==14,'actual original output archive omitted')
    for name,record in q['archives'].items():
        actual=archive_records()[name];require(record==actual and record['all_members_forward_verified'] is True and record['member_count']==len(record['members']) and record['bytes']>0,'foreign/incomplete original output raw record')
    require({Path(p).name for p in q['controller_canonical_sha256']}==CONTROLLERS,'executed original output controller omitted')
    for path,digest in q['controller_canonical_sha256'].items():require(sha(ROOT/path)==digest,'executed original output controller changed')
    return True


def reports(q):
    result={};build_digests={};daily={}
    def add(archive,name,value):
        require((archive,name) not in result,'duplicate original output producer binding');result[(archive,name)]=value
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            full='ORIGINAL_OUTPUT_'+('WINDOWS_FULL_' if platform=='Windows' else 'UBUNTU_')+opt+'_RAW_ARCHIVE.json'
            short='ORIGINAL_OUTPUT_WINDOWS_SHORT_'+opt+'_RAW_ARCHIVE.json' if platform=='Windows' else full
            prefix='original-output-windows-'+opt+'/' if platform=='Windows' else ''
            run=q['platforms'][platform][opt];add(full,prefix+'RESULT.json',run)
            add(full,prefix+'actual-integral-component/RESULT.json',q['components']['integral'][platform][opt])
            controls=Path(run['components']['controls'].replace('\\','/')).name
            add(full,prefix+controls+'/RESULT.json',q['controls'][platform][opt])
            for case,r in run['cases'].items():
                name=case+'-'+opt;sp='original-output-final-short-'+name+'/' if platform=='Windows' else 'short-'+name+'/'
                add(short,sp+'RESULT.json',r['short']);add(short,sp+'build/BUILD.json',q['builds'][platform][name])
                add(full,prefix+'full-'+name+'/RESULT.json',r['full'])
                daily[(full,prefix+'full-'+name+'/trajectory/daily.jsonl')]=(platform,name)
        raw='ORIGINAL_OUTPUT_'+platform.upper()+'_PRESERVATION_RAW_ARCHIVE.json'
        prefix='original-output-default-preserve/' if platform=='Windows' else 'default/'
        add(raw,prefix+'RESULT.json',q['preservation'][platform]['default'])
        for name,r in q['preservation'][platform]['default']['profiles'].items():add(raw,prefix+name+'/build/BUILD.json',r['actual_build'])
        prefix='original-output-daily002-preserve/' if platform=='Windows' else 'daily002/'
        add(raw,prefix+'RESULT.json',q['preservation'][platform]['daily002'])
        for name,r in q['preservation'][platform]['daily002']['profiles'].items():build_digests[(raw,prefix+name+'-build/BUILD.json')]=(r['coverage']['build_sha256'],platform)
        raw='ORIGINAL_OUTPUT_'+platform.upper()+'_PUBLIC_READER_RAW_ARCHIVE.json'
        prefix='original-output-public-v2/' if platform=='Windows' else 'public/'
        add(raw,prefix+'RESULT.json',q['public_cli'][platform])
        prefix='original-output-reader/' if platform=='Windows' else 'reader/'
        add(raw,prefix+'RESULT.json',q['reader_controls'][platform])
        for name,r in q['reader_controls'][platform]['profiles'].items():
            case,opt=name.rsplit('-',1);add(raw,prefix+case+'/'+opt+'/RESULT.json',r)
            build_digests[(raw,prefix+case+'/'+opt+'/build/BUILD.json')]=(r['trajectory']['build_sha256'],platform)
        for key,windows,folder in [('binary','ORIGINAL_BINARY_OUTPUT_COMPONENT_RAW_ARCHIVE.json','binary-component'),('vector','ORIGINAL_VECTOR_OUTPUT_COMPONENT_RAW_ARCHIVE.json','vector-component'),('cde_state','ORIGINAL_CDE_OUTPUT_COMPONENT_RAW_ARCHIVE.json','cde-output-component')]:
            raw=windows if platform=='Windows' else 'ORIGINAL_OUTPUT_UBUNTU_O0_RAW_ARCHIVE.json';name='RESULT.json' if platform=='Windows' else folder+'/RESULT.json';add(raw,name,q['components'][key][platform])
    return result,build_digests,daily


def verify():
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty original output admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'original output production differs from qualified source')
    require(not git('diff',BASE,RUNTIME,'--','src','app/hybrid_water/age_output_calendar.py','app/hybrid_water/age_output_schedule.py','app/hybrid_water/age_output_clock.py'),'original output changed admitted physical/calendar provider')
    allowed={'app/hybrid_water/'+n for n in ('daily_coupling.py','daily_host.py','experimental_project.py','original_cde_output_state.f90','original_output.py')}|{'tools/solute/run_water.py'}|{'reference/swap-4.3.1/patches/NOMACRO-'+k+'-OUTPUT-01/'+n for k in ('BINARY','VECTOR') for n in ('manifest.json','source.py')}
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==allowed,'unqualified original output production surface')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'original output changed literal preceding owner')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'original output immutable evidence changed: '+path)
    docs={'docs/science/NOMACRO_ORIGINAL_OUTPUT_CONTROL_20261118.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,*docs,PROOF+'ORIGINAL_OUTPUT_MERGE_RECEIPT.json'},'unqualified original output post-seal change')
    tests={SELF,TEST,ENTRY}
    require(set(git('diff','--name-only',SEALED,'HEAD','--','tests').decode().splitlines())<=tests,'original output executed test controller changed')
    q=json.loads((ROOT/PROOF/'ORIGINAL_OUTPUT_QUALIFICATION.json').read_text());validate(q)
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'original output actual producer production differs')
    for run in q['workflows'].values():
        require(set(git('diff','--name-only',run['runtime'],run['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'original output portable carrier changed science')
        require(not git('diff',run['runtime'],RUNTIME,'--','app','src','reference','tools'),'original output portable production differs')
    spec=importlib.util.spec_from_file_location('original_output_predecessor',ROOT/ENTRY);parent=importlib.util.module_from_spec(spec);spec.loader.exec_module(parent);parent.validate(json.loads((ROOT/PROOF/'AGE_CLOCK_QUALIFICATION.json').read_text()))
    expected,build_digests,daily=reports(q);observed=set();observed_builds=set();physical={};native={};age_seen=set();event_seen=set()
    sys.path.insert(0,str(ROOT/'app/hybrid_water'));from conserved_original_age import ledger
    for record_name,r in q['archives'].items():
        archive=ROOT/PROOF/r['archive'];require(archive.stat().st_size==r['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==r['sha256'],'actual original output raw archive differs')
        if record_name.startswith('ORIGINAL_OUTPUT_UBUNTU_'):
            require(r['actual_artifact_bytes_preserved'] is True and r['origin_artifact']['digest']=='sha256:'+r['sha256'] and r['origin_artifact']['size_in_bytes']==r['bytes'],'actual portable original output artifact differs')
        with zipfile.ZipFile(archive) as z:
            require({n for n in z.namelist() if not n.endswith('/')}==set(r['members']),'actual original output raw member omitted')
            for name,digest in r['members'].items():
                data=z.read(name);require(hashlib.sha256(data).hexdigest()==digest,'actual original output raw member changed');key=(record_name,name)
                if key in expected:require(json.loads(data)==expected[key],'original output differs from actual producer report: '+name);observed.add(key)
                if key in build_digests:
                    expected_digest,platform=build_digests[key];require(hashlib.sha256(data).hexdigest()==expected_digest,'original output actual measured preservation/reader build differs')
                    identity=json.loads(data)['identity'];qualified=next(iter(q['builds'][platform].values()))['identity'];require(all(identity[k]==qualified[k] for k in ('host','experimental_input_adapter')),'original output measured build used different host/adapter');observed_builds.add(key)
                if key in daily:
                    platform,profile=daily[key];rows=[json.loads(s) for s in data.splitlines()];require(len(rows)==1096 and all(row['committed'] is True for row in rows),'actual original output trajectory censored/rejected')
                    prior=None;fraction=0.
                    for row in rows:
                        require(all(bounded(abs(row[k]),1e-10) for k in ('independent_residual_cm','kernel_residual_cm')),'actual original output water guard exceeded')
                        if 'solute_independent_residual_mg_cm2' in row:require(bounded(abs(row['solute_independent_residual_mg_cm2']),1e-10),'actual original output chemical guard exceeded')
                        if 'age_state_cm_day' in row:
                            if prior is None:prior=[row['age_start_cm_day'],0.,row['age_start_cm_day']]+[0.]*8
                            actual=ledger(prior,row['age_state_cm_day']);require(all(actual[k]==row[k] for k in actual),'actual original output age ledger/policy differs');prior=row['age_state_cm_day']
                            fraction=max(fraction,*(abs(row[k])/row['age_tolerance_cm_day'] for k in ('age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day')))
                    physical[(platform,profile)]=hashlib.sha256(json.dumps([{k:v for k,v in row.items() if k not in ('column','revision')} for row in rows],sort_keys=True,separators=(',',':')).encode()).hexdigest()
                    if prior is not None:require(fraction==q['age_bounds'][platform][profile]['maximum_accepted_tolerance_fraction'],'actual age bound summary differs');age_seen.add((platform,profile))
                    if profile.startswith('cde-solbal'):
                        event=q['source_events'][platform][profile];require(event['initial_stock_mg_cm2']==rows[0]['solute_start_mg_cm2'] and event['actual_gift_mg_cm2']==rows[4]['solute_ledger_mg_cm2'][3] and event['stock_before_gift_mg_cm2']==rows[4]['solute_start_mg_cm2'],'actual CDE source gift differs');event_seen.add((platform,profile))
                    prefix=name[:-len('daily.jsonl')]
                    for day in (4,201,367,532,1096):
                        with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'accepted-column-1-day-{day}.zip'))) as checkpoint:native[(platform,profile,day)]=tuple(hashlib.sha256(checkpoint.read(k)).hexdigest() for k in ('result.end','macro.bin'))
    require(observed==set(expected) and observed_builds==set(build_digests),'original output actual producer report/build omitted')
    require(age_seen=={(p,n) for p,d in q['age_bounds'].items() for n in d} and event_seen=={(p,n) for p,d in q['source_events'].items() for n in d},'actual original output age/source receipts omitted')
    for platform,records in q['format_independence'].items():
        for group,r in records.items():
            opt=group.rsplit('-',1)[1];profiles=[case+'-'+opt for case in r['profiles']]
            require(len({physical[(platform,name)] for name in profiles})==1,'actual format changed physical trajectory')
            for day in (4,201,367,532,1096):require(len({native[(platform,name,day)] for name in profiles})==1,'actual format changed complete native state')
    return dict(status='CURRENT_ORIGINAL_OUTPUT_WATER_CDE_AGE_SOURCE_STATE_USER_FILES_ADMISSION_PASS',runtime=RUNTIME,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10,chemical_mass_guard_mg_cm2=1e-10,age_units='cm day',native_codecs=NATIVE,actual_bound_reports=len(observed),actual_measured_legacy_reader_builds=len(observed_builds))


if __name__=='__main__':print(json.dumps(verify(),indent=2))
