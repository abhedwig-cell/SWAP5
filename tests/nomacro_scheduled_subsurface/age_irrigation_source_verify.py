"""Source-bound current fixed irrigation age admission and inherited baseline."""
from pathlib import Path
from functools import lru_cache
import hashlib
import importlib.util
import io
import json
import math
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
PROOF='integration/f-ci/nomacro-complete01/'
BASE='04031746ef5b2c9735fad89c1a2754c42cdc1ce6'
RUNTIME='a5cedc906d91e9c020d407dfa5ae739336e0e7a8'
SEALED='51f64e62f3b2c046bd3ea9f5f7e2b65cb0193e4e'
ENTRY='tests/nomacro_scheduled_subsurface/output_hysteresis_verify.py'
SELF='tests/nomacro_scheduled_subsurface/age_irrigation_source_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_age_irrigation_source_verify.py'
AGE_TOL='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)'
BASE_CODES=('S5AGE002','S5AGE003','S5AGE004','S5AGE005','S5IOA001','S5IHA001')
CODES=('S5AI0002','S5AI0003','S5AI0004','S5AI0005','S5AIO001','S5AIH001')
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('age_irrigation_source_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_irrigation_source_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""


def require(ok,why):
    if not ok:raise ValueError(why)


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def sha(p):return hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
def tree(ref,path):return {r.split('\t',1)[1]:r.split('\t',1)[0] for r in git('ls-tree','-r',ref,'--',path).decode().splitlines()}
def bounded(v):return isinstance(v,(int,float)) and math.isfinite(v) and 0<=v<=1e-10
def amount(actual,expected):return math.isfinite(actual) and abs(actual-expected)<=8192*sys.float_info.epsilon*max(1,abs(actual),abs(expected))
def files(records):return all(r['exact'] is True and isinstance(r['continuation_records'],int) and r['continuation_records']>=0 for r in records.values())


@lru_cache(maxsize=1)
def archive_records():return {p.name:json.loads(p.read_text()) for p in (ROOT/PROOF).glob('AGE_IRRIGATION_SOURCE_*_RAW_ARCHIVE.json')}


def cases():
    sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
    from age_irrigation_source_ci import CASES,CONTROLS
    return CASES,CONTROLS


def layout(case):
    kind,calendar,fmt,hys,original,inline,age,events,full=case
    return 7 if original and hys else 6 if original else 5 if calendar in ('np3','annual') else 4 if calendar=='monthly' else 3 if calendar=='regular' else 2


def policy(q,r,case):
    index=layout(case)-2
    expected=dict(policy='original-fixed-current-irrigation-age-days-v1',irrigation_types=[0,1],units='days',source='actual current original CIRR',native_static_parameters_preserved=True,subsurface=False,native_codec=CODES[index],base_native_codec=BASE_CODES[index],original_event_carry='complete original irrigation owner',physical_age_providers_changed=False,age_tolerance=AGE_TOL)
    require(all(r[k]==v for k,v in expected.items()),'foreign current irrigation age source policy')
    for key,path in [('source_sha256','app/hybrid_water/age_irrigation_source.py'),('domain_source_sha256','app/hybrid_water/age_irrigation_source_domain.f90'),('correction_sha256','reference/swap-4.3.1/patches/NOMACRO-AGE-IRRIGATION-SOURCE-01/source.py')]:require(r[key]==q['source_sha256'][path],'foreign actual current-age source owner')


def period(q,r,case,opt,phase,build,digest):
    kind,calendar,fmt,hys,original,inline,age,events,full=case;days=1096 if phase=='full' else 35 if 'monthly' in calendar else 10
    require(r['status']=='AGE_IRRIGATION_SOURCE_'+phase.upper()+'_CURRENT_FORCING_NATIVE_OUTPUT_PASS' and (r['kind'],r['calendar'],r['output_format'],r['hysteresis'],r['original_output'],r['inline'],r['age_day'],r['events'])==case[:8] and r['optimization']==opt,'current-age source period/selector missing')
    require((r['functional_completion'],r['whole_scientific_equivalence'])==('PARTIAL','NOT_QUALIFIED'),'current-age source scope promoted')
    policy(q,r['age_irrigation_source'],case)
    require(r['trajectory']['days']==r['trajectory']['budgets']['days']==days and r['trajectory']['build_sha256']==digest,'current-age period censored/foreign build')
    for key in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2'):require(bounded(r['trajectory']['budgets'][key]),'water/chemical guard changed/exceeded')
    require(r['age_units']=='cm day' and amount(r['actual_event_age_cm_day'],2.4*age),'incoming age amount/units differ')
    if events=='varying':require(amount(r['actual_second_age_cm_day'],72.),'varying current irrigation age ignored')
    windows={(2,4),(4,8),(6,10)}
    if 'monthly' in calendar:windows.add((30,34))
    if phase=='full':windows|={(199,201),(364,367),(530,532),(1094,1096)}
    require(len(r['own'])==len(windows) and {(w['start'],w['end']) for w in r['own']}==windows,'missing current-age native window')
    for w in r['own']:require(all(w[k] is True for k in ('exact_physical','exact_complete_native','origin_unchanged')) and files(w['exact_user_output']),'current-age cold physical/native/output differs')
    require(set(r['native_domains'])=={'2','4','8',str(days)},'current-age domain observation missing')
    for d in r['native_domains'].values():require(d['bytes']==56 and d['offset']>48 and d['exact_actual_flags'] is True,'current-age native source domain changed')
    require(build['identity']['original_age_fixed_irrigation']==r['age_irrigation_source'] and build['identity']['conserved_original_age']['irrigation_source']==r['age_irrigation_source'] and build['identity']['conserved_original_age']['native_codec']==CODES[layout(case)-2],'compiled current-age policy differs')
    require(build['identity']['conserved_original_age']['providers']==q['physical_age_providers'],'changed actual physical age provider')
    require(build['project']['nodes']==34 and build['project']['water_tolerance']==1e-10 and build['project']['model']=='HYBRID_NOMACRO_WATER','foreign current-age project')
    if original:require(build['identity']['original_output']['native_codec']==CODES[layout(case)-2] and build['identity']['original_output']['irrigation_source']==r['age_irrigation_source'],'source/output native identities differ')


def validate(q):
    require((q['baseline'],q['runtime'])==(BASE,RUNTIME) and q['status']=='BOUNDED_CURRENT_FIXED_IRRIGATION_AGE_SOURCE_QUALIFIED_PENDING_ADMISSION','unqualified/foreign current-age evidence')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['release_readiness'])==('PARTIAL','NOT_QUALIFIED','RC3_FIXED_NAMED_PROFILES_ONLY'),'current-age whole scope promoted')
    require(q['water_guard_cm']==q['chemical_mass_guard_mg_cm2']==1e-10 and q['age_units']=='cm day' and q['age_tolerance']==AGE_TOL,'current-age conservation policy changed')
    scope=dict(default_source_flag=False,irrigation_types=[0,1],incoming_age_range_day=[0,1000],macro=False,snow=False,frost=False,aquifer=False,detailed_weather=False,subsurface=False,physical_age_providers_changed=False,static_native_parameters_preserved=True,input_shape_reconstructed=True,native_domain_bytes=56)
    require(q['scope']==scope,'unqualified current-age physical/input domain')
    for path,digest in q['source_sha256'].items():require(sha(ROOT/path)==digest,'changed actual current-age source: '+path)
    require(q['base_consumer']['merge']==BASE and q['base_consumer']['exact_complete_tree'] is True and q['base_consumer']['actual_detached_owner']['returncode']==0,'actual preceding canonical not verified')
    specs,controls=cases();require(len(specs)==14 and sum(c[8] for c in specs.values())==10 and len(controls)==7,'qualified source cohort changed')
    for key in ('platforms','builds','build_sha256','controls','original_components','reference_components','domain_components','public_cli','reader_controls'):require(set(q[key])=={'Windows','Ubuntu'},'current-age platform omitted: '+key)
    for platform in ('Windows','Ubuntu'):
        require(set(q['platforms'][platform])=={'O0','O2'},'current-age optimization omitted')
        for opt in ('O0','O2'):
            run=q['platforms'][platform][opt];require(run['status']=='FOURTEEN_CURRENT_AGE_SOURCE_SHORT_AND_TEN_FULL_NATIVE_STATE_USER_OUTPUT_PASS' and set(run['cases'])==set(specs) and run['optimization']==opt,'current-age full cohort incomplete')
            require(set(q['builds'][platform][opt])==set(specs),'actual source build omitted')
            for key,case in specs.items():
                item=run['cases'][key];build=q['builds'][platform][opt][key];digest=q['build_sha256'][platform][opt][key]
                period(q,item['short'],case,opt,'short',build,digest)
                require(('full' in item)==case[8],'unselected/censored current-age full period')
                if case[8]:period(q,item['full'],case,opt,'full',build,digest)
            actual=q['controls'][platform][opt];require(set(actual)==set(controls) and actual==run['controls'],'typed current-age control omitted')
            for key,r in actual.items():
                require(r['status']=='FIXED_CURRENT_AGE_NATIVE_INPUT_IDENTITY_AND_VARYING_EXTERNAL_TRANSACTIONS_PASS' and r['build_sha256']==q['build_sha256'][platform][opt][key],'native input identity/transaction control failed')
                require(len(r['native_refusals'])==25 and len(r['policy_refusals'])==7 and all(x['status']=='REFUSED' for x in r['native_refusals']+r['policy_refusals']),'malformed future/current age source accepted')
                require(len(r['transactions'])==7 and all(x is True for x in r['transactions'].values()),'varying source external transaction/recovery failed')
        original=q['original_components'][platform];require(original['status']=='ORIGINAL_FIXED_AGE_CAPTURE_O0_O2_COUNTEREXAMPLE_AND_NONMUTATING_DIAGNOSTIC_PASS_NOT_ACTIVE' and original['SWAP5_activation'] is False,'actual original capture defect not observed')
        reference=q['reference_components'][platform];require(reference['status']=='PLAIN_ORIGINAL_CURRENT_AGE_SOURCE_O0_O2_EIGHT_PROFILES_EXACT_TO_REAL_DIAGNOSTIC_NOT_ACTIVE' and reference['SWAP5_activation'] is False,'plain corrected original source not bound')
        for opt in ('O0','O2'):
            require(set(original['profiles'][opt]['comparisons'])=={'surface','sprinkler'},'original source irrigation kind omitted')
            for kind,r in original['profiles'][opt]['comparisons'].items():require(kind in ('surface','sprinkler') and all(r[k] is True for k in ('original_ignores_nonzero_fixed_age','diagnostic_nonmutation','zero_age_refresh_preserved','actual_current_source_positive','refreshed_profile_changes')) and amount(r['actual_source_cm_day'],48.),'original capture counterexample/correction failed')
            require(len(original['profiles'][opt]['runs'])==12 and len(reference['profiles'][opt]['cases'])==4,'original source actual executions omitted')
            for key,r in reference['profiles'][opt]['cases'].items():require(r['exact_to_actual_refreshed_diagnostic'] is True and r['zero_age_original_preserved']==key.endswith('-0') and r['nonzero_profile_changes']==key.endswith('-20'),'original source probe mutates corrected profile')
        domain=q['domain_components'][platform];require(domain['status']=='AGE_IRRIGATION_SOURCE_DOMAIN_O0_O2_TWELVE_LAYOUTS_120_NATIVE_AND_FOURTEEN_AGE_SHAPE_REFUSALS_PASS','current-age native module component failed')
        for opt,r in domain['profiles'].items():
            require(r['actual_original_storage'] is True and len(r['contexts'])==6 and len(r['invalid_live'])==6 and all(x['returncode']!=0 for x in r['invalid_live']),'actual module native scope/refusals missing')
            for c in r['contexts'].values():require(all(c[k] is True for k in ('exact_fifty_six_byte_headers','stream_position_exact','live_flags_unchanged')) and len(c['refusals'])==9 and all(x['returncode']!=0 for x in c['refusals']),'module source domain accepted/mutated')
            require(len(r['input_shapes'])==4 and all(x['returncode']!=0 for x in r['input_shapes'].values()),'foreign source shape registered')
            require(len(r['age_values'])==6 and all((v['returncode']==0)==(k in ('age-zero','age-positive','age-upper')) for k,v in r['age_values'].items()),'source age range/nonfinite accepted')
        public=q['public_cli'][platform];require(public['status']=='THREE_PUBLIC_CURRENT_AGE_SOURCE_FLAG_COMPLETE_COLD_NATIVE_PASS' and len(public['profiles'])==3,'public source command missing')
        for r in public['profiles'].values():require(all(r[k] is True for k in ('actual_public_flag','exact_physical','exact_complete_native','source_checkpoint_unchanged')) and r['warm']['returncode']==r['cold']['returncode']==0 and files(r['exact_user_output']),'public current-age native differs')
        reader=q['reader_controls'][platform];require(reader['status']=='SIX_REAL_FIXED_AGE_READER_AND_SEVEN_DESCRIPTOR_REFUSALS_PASS' and len(reader['reader_refusals'])==6 and len(reader['descriptor_refusals'])==7 and all(r['status']=='REFUSED_BEFORE_HYBRID_READY' for r in reader['reader_refusals']) and all(r['status']=='REFUSED' for r in reader['descriptor_refusals']) and reader['young_default_refusal']['status']=='REFUSED_BEFORE_HYBRID_READY','actual original reader/default young guard failed')
    for opt,r in q['preservation']['Windows']['output_hysteresis'].items():
        require(r['status']=='TEN_ORDINARY_AND_HYSTERESIS_COMPATIBILITY_CONTEXTS_EXACT_PASS' and len(r['profiles'])==10,'old output/hysteresis context missing')
        for c in r['profiles'].values():require(all(c[k] is True for k in ('generated_provider_exact','all_physical_exact','complete_native_exact')),'old output/hysteresis source/native changed')
    young=q['preservation']['Windows']['young_named'];require(young['status']=='EIGHT_YOUNG_FIXED_AND_THREE_NAMED_FLAG_FALSE_CONTEXTS_PRESERVED' and len(young['profiles'])==11,'young/named default context missing')
    for c in young['profiles'].values():require(all(c[k] is True for k in ('original_route_exact','generated_provider_inputs_exact','physical_user_output_exact')) and c['complete_native_endpoints_exact'],'young/named default source/native changed')
    portable=q['preservation']['Ubuntu'];require(portable['status']=='FOUR_PORTABLE_PRIOR_OUTPUT_HYSTERESIS_CONTEXTS_SOURCE_FLAG_FALSE_EXACT_PASS' and len(portable['profiles'])==4,'portable prior scope omitted')
    for c in portable['profiles'].values():require(all(c[k] is True for k in ('source_provider_inputs_exact','all_physical_exact','four_complete_native_endpoints_exact')),'portable old source/native changed')
    require(q['boundary']['status']=='FIRST_AND_TRUE_TERMINAL_DAY_AGE_GIFTS_O0_O2_COMPLETE_NATIVE_PASS','initial/terminal age boundary missing')
    for r in q['boundary']['profiles'].values():require(amount(r['first_day_source_cm_day'],48.) and amount(r['terminal_cumulative_source_cm_day'],120.) and len(r['own'])==3 and all(w['exact_complete_native'] is True for w in r['own']),'initial/terminal source/state differs')
    require(q['archives']==archive_records() and len(q['archives'])==7,'actual current-age raw evidence changed/omitted')
    require(set(q['workflows'])=={'matrix','contracts'} and all(r['status']=='SUCCESS' and r['id']==(44236392888 if k=='matrix' else 44238067805) for k,r in q['workflows'].items()),'portable source workflow not successful')
    require(len(q['daily_paths'])==40 and len(q['report_paths'])==q['actual_report_count']>220,'actual current-age producer bindings omitted')


def predecessor():
    """Validate the unchanged prior proof on its real qualified source image.

    The old validator intentionally hashes its three old dispatch files. Those
    are now changed and separately preserved. Materialize only its pinned source
    inputs and JSON records, never rebind its old receipts to current files.
    """
    old=json.loads((ROOT/PROOF/'OUTPUT_HYSTERESIS_QUALIFICATION.json').read_text())
    paths={ENTRY,PROOF+'OUTPUT_HYSTERESIS_QUALIFICATION.json',*old['source_sha256'],*(PROOF+p for p in old['archives'])}
    for path,digest in old['source_sha256'].items():require(hashlib.sha256(blob(BASE,path).replace(b'\r\n',b'\n')).hexdigest()==digest,'pinned qualified predecessor source changed')
    with tempfile.TemporaryDirectory(prefix='s5-age-source-parent-') as directory:
        snapshot=Path(directory).resolve();require(snapshot.parent==Path(tempfile.gettempdir()).resolve() and snapshot.name.startswith('s5-age-source-parent-'),'unsafe predecessor snapshot path')
        for path in paths:
            target=snapshot/path;require(target.resolve().is_relative_to(snapshot),'foreign predecessor snapshot member');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(blob(BASE,path))
        spec=importlib.util.spec_from_file_location('qualified_literal_hysteresis_predecessor',snapshot/ENTRY);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);module.validate(old)
    for r in old['archives'].values():require(hashlib.sha256((ROOT/PROOF/r['archive']).read_bytes()).hexdigest()==r['sha256'],'immutable predecessor artifact bytes changed')
    return 'LITERAL_QUALIFIED_PREDECESSOR_IMAGE_AND_ACTUAL_ARCHIVES_PASS'


def verify():
    import importlib.util
    spec=importlib.util.spec_from_file_location('direct_soil_age_admission',ROOT/'tests/nomacro_scheduled_subsurface/direct_soil_age_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty current-age admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    allowed={'app/hybrid_water/'+n for n in ('daily_host.py','daily_coupling.py','experimental_project.py','age_irrigation_source.py','age_irrigation_source_domain.f90')}|{'tools/solute/run_water.py'}|{'reference/swap-4.3.1/patches/NOMACRO-AGE-IRRIGATION-SOURCE-01/'+n for n in ('source.py','manifest.json')}
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==allowed,'unqualified current-age production surface')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'current-age production differs from qualified runtime')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'changed literal hysteresis predecessor owner')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'immutable source/predecessor evidence changed: '+path)
    docs={'docs/science/NOMACRO_AGE_IRRIGATION_SOURCE_20261118.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,*docs,PROOF+'AGE_IRRIGATION_SOURCE_MERGE_RECEIPT.json'},'unqualified current-age post-seal change')
    q=json.loads((ROOT/PROOF/'AGE_IRRIGATION_SOURCE_QUALIFICATION.json').read_text());validate(q);prior=predecessor()
    for path,digest in q['controller_sha256'].items():require(sha(ROOT/path)==digest,'changed executed current-age controller')
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'actual current-age producer source differs')
    for r in q['workflows'].values():require(set(git('diff','--name-only',r['runtime'],r['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'source carrier changed physics')
    sys.path.insert(0,str(ROOT/'app/hybrid_water'));from conserved_original_age import ledger
    specs,_=cases();observed=set();physical={};native={};zero_rows={};zero_native={}
    for record,r in q['archives'].items():
        archive=ROOT/PROOF/r['archive'];require(archive.stat().st_size==r['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==r['sha256'],'actual current-age archive changed')
        if record.startswith('AGE_IRRIGATION_SOURCE_UBUNTU_'):require(r['actual_artifact_bytes_preserved'] is True and r['origin_artifact']['digest']=='sha256:'+r['sha256'] and r['origin_artifact']['size_in_bytes']==r['bytes'],'portable actual source artifact changed')
        with zipfile.ZipFile(archive) as z:
            require(set(z.namelist())==set(r['members']),'current-age raw member omitted')
            for path,digest in r['members'].items():
                data=z.read(path);require(hashlib.sha256(data).hexdigest()==digest,'current-age raw member changed');key=record+'|'+path
                if key in q['report_paths']:
                    expected=q;pointer=q['report_paths'][key]
                    for part in pointer:expected=expected[part]
                    require(json.loads(data)==expected,'current-age claim differs from actual producer: '+path);observed.add(key)
                    if pointer[0]=='builds':require(hashlib.sha256(data).hexdigest()==q['build_sha256'][pointer[1]][pointer[2]][pointer[3]],'actual measured source build differs')
                if key in q['zero_paths']:
                    opt=q['zero_paths'][key];zero_rows[opt]=[json.loads(s) for s in data.splitlines()]
                    prefix=path[:-len('daily.jsonl')]
                    for day in (2,4,8):
                        with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'accepted-column-1-day-{day}.zip'))) as a:zero_native[(opt,day)]=(a.read('result.end'),a.read('macro.bin'))
                if key not in q['daily_paths']:continue
                platform,opt,case=q['daily_paths'][key];rows=[json.loads(s) for s in data.splitlines()];require(len(rows)==1096 and [r['day'] for r in rows]==list(range(1,1097)) and all(r['committed'] is True for r in rows),'actual source period censored')
                previous=None
                for row in rows:
                    require(all(bounded(abs(row[k])) for k in ('independent_residual_cm','kernel_residual_cm')),'actual source water guard exceeded')
                    if 'integrated_guard_residual_cm' in row:require(bounded(abs(row['integrated_guard_residual_cm'])),'actual original Integral guard exceeded')
                    if previous is None:previous=[row['age_start_cm_day'],0.,row['age_start_cm_day']]+[0.]*8
                    actual=ledger(previous,row['age_state_cm_day']);require(all(actual[k]==row[k] for k in actual),'actual age source ledger/policy differs');previous=row['age_state_cm_day']
                require(amount(rows[4]['age_ledger_cm_day'][2],48.) and amount(rows[6]['age_ledger_cm_day'][2],72.),'actual current event ages not applied')
                physical[(platform,opt,case)]=hashlib.sha256(json.dumps([{k:v for k,v in row.items() if k not in ('column','revision')} for row in rows],sort_keys=True).encode()).hexdigest();prefix=path[:-len('daily.jsonl')];schema=specs[case];header=struct.pack('<7i',1,34,0,2,1,schema[3],layout(schema))
                for day in (4,8,10,201,367,532,1096):
                    with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'accepted-column-1-day-{day}.zip'))) as a:
                        raw=a.read('macro.bin');require(raw[:8]==CODES[layout(schema)-2].encode() and raw.endswith(header+header),'actual current-age codec/domain differs');native[(platform,opt,case,day)]=(hashlib.sha256(a.read('result.end')).hexdigest(),hashlib.sha256(raw).hexdigest())
    require(observed==set(q['report_paths']) and len(physical)==40,'actual source producer/build/full period missing')
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            require(physical[(platform,opt,'surface-output0')]==physical[(platform,opt,'surface-output3')],'actual output format changes current-age physics')
            for day in (4,8,10,201,367,532,1096):require(native[(platform,opt,'surface-output0',day)]==native[(platform,opt,'surface-output3',day)],'actual source output format changes native state')
    old_record=json.loads((ROOT/PROOF/'AGE_FIXED_WINDOWS_RAW_ARCHIVE.json').read_text())
    with zipfile.ZipFile(ROOT/PROOF/old_record['archive']) as z:
        for opt in ('O0','O2'):
            old=[json.loads(s) for s in z.read(f'age-fixed/sprinkler-{opt}-full/daily.jsonl').splitlines()][:10];clean=lambda rows:[{k:v for k,v in row.items() if k not in ('column','revision')} for row in rows]
            require(clean(zero_rows[opt])==clean(old),'zero incoming age changes old physical trajectory')
            for day in (2,4,8):
                phase='short' if day==8 else 'full'
                with zipfile.ZipFile(io.BytesIO(z.read(f'age-fixed/sprinkler-{opt}-{phase}/accepted-column-1-day-{day}.zip'))) as a:
                    end,raw=zero_native[(opt,day)];require(end==a.read('result.end') and raw[8:-56]==a.read('macro.bin')[8:],'zero source changes complete predecessor payload')
    return dict(status='CURRENT_FIXED_IRRIGATION_AGE_SOURCE_STATE_OUTPUT_ADMISSION_PASS',runtime=RUNTIME,predecessor=prior,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',actual_bound_reports=len(observed),actual_full_periods=len(physical),native_codecs=CODES,age_units='cm day',age_tolerance=AGE_TOL)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
