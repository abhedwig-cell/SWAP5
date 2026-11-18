"""Source-bound direct soil age source/state/output admission owner."""
from pathlib import Path
from functools import lru_cache
import hashlib
import importlib.util
import io
import json
import math
import subprocess
import sys
import tarfile
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
PROOF='integration/f-ci/nomacro-complete01/'
BASE='e3cb491d15b9d079062285c397cfba552ab0a86d'
RUNTIME='26724ce758cb1dfb22e7e722046fae724fa6bd61'
SEALED='e4a31277c44c7db576f5eb28777b7dca6c71b300'
ENTRY='tests/nomacro_scheduled_subsurface/age_irrigation_source_verify.py'
SELF='tests/nomacro_scheduled_subsurface/direct_soil_age_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_direct_soil_age_verify.py'
AGE_TOL='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)'
CODES=('S5DI0002','S5DI0003','S5DI0004','S5DI0005','S5DIO001','S5DIH001')
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('direct_soil_age_admission',ROOT/'tests/nomacro_scheduled_subsurface/direct_soil_age_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""


def require(ok,why):
    if not ok:raise ValueError(why)


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
@lru_cache(maxsize=None)
def sha(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
def tree(ref,path):return {r.split('\t',1)[1]:r.split('\t',1)[0] for r in git('ls-tree','-r',ref,'--',path).decode().splitlines()}
def bounded(v):return isinstance(v,(int,float)) and math.isfinite(v) and 0<=v<=1e-10
def amount(actual,expected):return math.isfinite(actual) and abs(actual-expected)<=8192*sys.float_info.epsilon*max(1,abs(actual),abs(expected))
def files(records):return bool(records) and all(r['exact'] is True and isinstance(r['continuation_records'],int) and r['continuation_records']>=0 for r in records.values())
def layout(case):return 7 if case[4] and case[3] else 6 if case[4] else 5 if case[1] in ('np3','annual') else 4 if case[1]=='monthly' else 3 if case[1]=='regular' else 2


@lru_cache(maxsize=1)
def archive_records():return {p.name:json.loads(p.read_text()) for p in (ROOT/PROOF).glob('DIRECT_SOIL_AGE_*_RAW_ARCHIVE.json')}


def cases():
    sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
    from direct_soil_age_ci import CASES,CONTROLS
    return CASES,CONTROLS


def period(q,r,case,opt,phase,build,digest):
    kind,calendar,fmt,hys,original,inline,age,events,full=case;days=1096 if phase=='full' else 35 if 'monthly' in calendar else 10
    require(r['status']=='DIRECT_SOIL_AGE_SOURCE_'+phase.upper()+'_CURRENT_FORCING_NATIVE_OUTPUT_PASS' and (r['kind'],r['calendar'],r['output_format'],r['hysteresis'],r['original_output'],r['inline'],r['age_day'],r['events'])==case[:8] and r['optimization']==opt,'foreign/censored direct source period')
    require((r['functional_completion'],r['whole_scientific_equivalence'])==('PARTIAL','NOT_QUALIFIED'),'direct source whole scope promoted')
    policy=r['age_direct_soil_source']
    expected=dict(policy='original-fixed-direct-soil-age-transport-then-input-v1',irrigation_types=[0,1,2],units='days',source='actual original current CIRR and compartment qssdi',native_static_parameters_preserved=True,subsurface=True,source_order='literal transport then direct input each microstep',age_state_fields=12,direct_state_bytes=24,physical_age_providers_changed=False,age_tolerance=AGE_TOL,native_codec=CODES[layout(case)-2])
    require(all(policy[k]==v for k,v in expected.items()),'foreign direct source policy/units/native shape')
    for field,path in [('source_sha256','app/hybrid_water/age_direct_soil_source.py'),('ledger_sha256','app/hybrid_water/direct_soil_age.py'),('state_sha256','app/hybrid_water/direct_soil_age_state.f90'),('provider_sha256','src/process/mod_direct_soil_age_substep.f90')]:require(policy[field]==q['source_sha256'][path],'foreign actual direct source owner')
    require(r['trajectory']['days']==r['trajectory']['budgets']['days']==days and r['trajectory']['build_sha256']==digest,'censored period/foreign direct source build')
    for key in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2'):require(bounded(r['trajectory']['budgets'][key]),'water/chemical guard weakened/exceeded')
    require(r['age_units']=='cm day' and amount(r['actual_event_age_cm_day'],2.4*age),'direct source units/input differ')
    if events=='varying':require(amount(r['actual_second_age_cm_day'],72.),'current varying second gift ignored')
    windows={(2,4),(4,8),(6,10)}
    if 'monthly' in calendar:windows.add((30,34))
    if phase=='full':windows|={(199,201),(364,367),(530,532),(1094,1096)}
    require(len(r['own'])==len(windows) and {(w['start'],w['end']) for w in r['own']}==windows,'direct source cold window omitted')
    for w in r['own']:require(all(w[k] is True for k in ('exact_physical','exact_complete_native','origin_unchanged')) and files(w['exact_user_output']),'direct source cold physical/native/output differs')
    require(set(r['native_domains'])=={'2','4','8',str(days)},'direct source native observation omitted')
    for d in r['native_domains'].values():require(d['bytes']==80 and d['offset']>48 and d['exact_actual_flags'] is True and math.isfinite(d['direct_cumulative_cm_day']) and d['direct_cumulative_cm_day']>=0,'direct source native owner/domain differs')
    require(build['identity']['original_age_fixed_irrigation']==policy and build['identity']['conserved_original_age']['irrigation_source']==policy and build['identity']['conserved_original_age']['native_codec']==CODES[layout(case)-2] and build['identity']['conserved_original_age']['age_state_fields']==12,'compiled direct source policy/state differs')
    require(build['identity']['conserved_original_age']['providers']==q['physical_age_providers'],'literal age provider changed')
    require(build['project']['nodes']==34 and build['project']['water_tolerance']==1e-10 and build['project']['model']=='HYBRID_NOMACRO_WATER','foreign direct source project')
    if original:require(build['identity']['original_output']['native_codec']==CODES[layout(case)-2] and build['identity']['original_output']['irrigation_source']==policy,'direct source/output identities differ')


def validate(q):
    require((q['baseline'],q['runtime'],q['status'])==(BASE,RUNTIME,'BOUNDED_DIRECT_SOIL_AGE_SOURCE_QUALIFIED_PENDING_ADMISSION'),'unqualified/foreign direct source evidence')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['release_readiness'])==('PARTIAL','NOT_QUALIFIED','RC3_FIXED_NAMED_PROFILES_ONLY'),'whole direct source scope promoted')
    require(q['water_guard_cm']==q['chemical_mass_guard_mg_cm2']==1e-10 and q['age_units']=='cm day' and q['age_tolerance']==AGE_TOL,'conservation units/guards changed')
    expected=dict(default_source_flag=False,irrigation_types=[0,1,2],incoming_age_range_day=[0,1000],macro=False,snow=False,frost=False,aquifer=False,detailed_weather=False,subsurface=True,physical_age_providers_changed=False,static_native_parameters_preserved=True,input_shape_reconstructed=True,age_state_fields=12,native_domain_bytes=80,source_order='literal transport then direct input each microstep')
    require(q['scope']==expected,'unqualified direct source physical/process/state domain')
    for path,digest in {**q['source_sha256'],**q['controller_sha256'],**q['frozen_predecessor_controllers']}.items():require(sha(ROOT/path)==digest,'changed actual direct source/controller: '+path)
    require(q['base_consumer']['merge']==BASE and q['base_consumer']['exact_complete_tree'] is True and q['base_consumer']['actual_detached_owner']['returncode']==0,'preceding actual canonical owner missing')
    specs,controls=cases();require(len(specs)==17 and sum(c[8] for c in specs.values())==11 and len(controls)==8,'selected direct source cohort changed')
    for key in ('platforms','builds','build_sha256','controls','original_components','source_components','public_cli','reader_controls','preservation'):require(set(q[key])=={'Windows','Ubuntu'},'direct source platform omitted: '+key)
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            run=q['platforms'][platform][opt];require(run['status']=='SEVENTEEN_DIRECT_SOIL_AGE_SHORT_AND_ELEVEN_FULL_NATIVE_STATE_USER_OUTPUT_PASS' and set(run['cases'])==set(specs) and run['optimization']==opt,'direct source full cohort incomplete')
            require(set(q['builds'][platform][opt])==set(specs),'actual direct source build omitted')
            for key,case in specs.items():
                item=run['cases'][key];build=q['builds'][platform][opt][key];digest=q['build_sha256'][platform][opt][key]
                period(q,item['short'],case,opt,'short',build,digest)
                require(('full' in item)==case[8],'unselected/censored direct full period')
                if case[8]:period(q,item['full'],case,opt,'full',build,digest)
            require(run['format_independence']==dict(all1096_physical_exact=True,seven_complete_native_endpoints_exact=True),'format-dependent source physics/native')
            actual=q['controls'][platform][opt];require(set(actual)==set(controls) and actual==run['controls'],'direct source native control family omitted')
            for key,r in actual.items():
                require(r['status']=='DIRECT_SOIL_AGE_NATIVE_EXTERNAL_ROLLBACK_AND_ALTERED_LEDGER_REFUSALS_PASS' and r['build_sha256']==q['build_sha256'][platform][opt][key],'direct source control bound to foreign build')
                require(len(r['native'])==19 and all(x['status']=='REFUSED' for x in r['native']),'malformed direct source native accepted')
                t=r['transactions'];require(all(t[k] is True for k in ('first_gift_discard_unchanged','replay_exact','accept_exact','recovery_exact','varying_second_gift_exact','second_gift_discard_replay_exact','origin_unchanged')) and {r['index'] for r in t['altered_ledger_refusals']}=={0,2,3,5,11} and len(t['altered_ledger_refusals'])==5,'direct source rejected trial/receipt changed accepted state')
        original=q['original_components'][platform];require(original['status']=='ORIGINAL_SSDI_AGE_O0_O2_32_EXECUTIONS_DEFECT_AND_CORRECTION_PASS_NOT_ACTIVE' and original['SWAP5_activation'] is False,'actual original SSDI source defect not proved')
        for opt in ('O0','O2'):
            require(len(original['profiles'][opt]['runs'])==16 and len(original['profiles'][opt]['builds'])==4 and set(original['profiles'][opt]['comparisons'])=={'subsurface','subsurface-interval'},'actual original source executions omitted')
            for r in original['profiles'][opt]['comparisons'].values():require(all(r[k] is True for k in ('original_ignored_age','original_cirr_zero','nonmutating_probe_exact','zero_corrected_exact','positive_corrected_changes','plain_corrected_equals_probe')) and amount(r['actual_water_cm'],2.4) and amount(r['corrected_input_cm_day'],48.),'original source correction/nonmutation differs')
        component=q['source_components'][platform];require(component['status']=='DIRECT_SOIL_AGE_COMPONENT_O0_O2_PASS_NOT_ACTIVATED_NOT_ADMITTED' and set(component['optimization'])=={'O0','O2'},'real composed provider component missing')
        for path,digest in component['source_sha256'].items():require(digest==q['source_sha256'][path],'component calls foreign age source/driver')
        for r in component['optimization'].values():
            require(r['status']=='REAL_FOUR_OBJECT_SOURCE_TRANSPORT_CONSERVATION_REJECTION_CONVERGENCE_PASS' and r['ledger_refusals']==7,'component source/shape/rejection failed')
            values=list(map(float,r['stdout'].split()[1:]));require(len(values)==3 and 0<values[2]<.6*values[1] and 0<values[1]<.6*values[0],'actual transport/input split fails refinement')
        public=q['public_cli'][platform];require(public['status']=='THREE_PUBLIC_DIRECT_SOIL_AGE_SOURCE_FLAG_COMPLETE_COLD_NATIVE_PASS' and len(public['profiles'])==3,'actual direct source user command omitted')
        for r in public['profiles'].values():require(all(r[k] is True for k in ('actual_public_flag','exact_physical','exact_complete_native','source_checkpoint_unchanged')) and r['warm']['returncode']==r['cold']['returncode']==0 and files(r['exact_user_output']),'public direct source restart/output differs')
        reader=q['reader_controls'][platform];require(reader['status']=='SIX_REAL_DIRECT_SOIL_AGE_READER_AND_NINE_DESCRIPTOR_REFUSALS_PASS' and len(reader['reader_refusals'])==6 and len(reader['descriptor_refusals'])==9 and all(r['status']=='REFUSED_BEFORE_HYBRID_READY' for r in reader['reader_refusals']) and all(r['status']=='REFUSED' for r in reader['descriptor_refusals']),'real original direct source input/policy accepted')
        if platform=='Ubuntu':require(reader['young_default_refusal']['status']=='REFUSED_BEFORE_HYBRID_READY','old default young source guard changed')
    for opt in ('O0','O2'):
        old=q['preservation']['Windows']['output_hysteresis'][opt];require(old['status']=='TEN_ORDINARY_AND_HYSTERESIS_COMPATIBILITY_CONTEXTS_EXACT_PASS' and len(old['profiles'])==10,'existing output/hysteresis scope omitted')
        for r in old['profiles'].values():require(all(r[k] is True for k in ('generated_provider_exact','all_physical_exact','complete_native_exact')),'old output source/native changed')
        prior=q['preservation']['Windows']['current_age'][opt];require(prior['status']=='EIGHT_PRIOR_CURRENT_AGE_SOURCE_FAMILIES_DIRECT_FLAG_FALSE_EXACT_PASS' and len(prior['profiles'])==8,'prior surface source family omitted')
        for r in prior['profiles'].values():require(all(r[k] is True for k in ('generated_provider_inputs_exact','all_physical_exact','four_complete_native_endpoints_exact')) and r['metadata_projection'].startswith('none:'),'prior actual surface source/native changed/rebound')
        zero=q['zero_projection'][opt];require(zero['status']=='ACTUAL_ZERO_DIRECT_SOIL_SOURCE_IMMUTABLE_YOUNG_PHYSICAL_AND_NATIVE_PROJECTION_PASS' and zero['all_ten_physical_days_exact'] is True and zero['prior_raw_unchanged'] is True and zero['complete_old_payload_exact']==[2,4,8],'zero source changes old actual state')
    young=q['preservation']['Windows']['young_named'];require(young['status']=='EIGHT_YOUNG_FIXED_AND_THREE_NAMED_FLAG_FALSE_CONTEXTS_PRESERVED' and len(young['profiles'])==11,'young/named default scope missing')
    for r in young['profiles'].values():require(all(r[k] is True for k in ('original_route_exact','generated_provider_inputs_exact','physical_user_output_exact')) and r['complete_native_endpoints_exact'],'young/named default source/native differs')
    for key,status,count in [('output_hysteresis','FOUR_PORTABLE_PRIOR_OUTPUT_HYSTERESIS_CONTEXTS_SOURCE_FLAG_FALSE_EXACT_PASS',4),('current_age','SIX_PORTABLE_PRIOR_CURRENT_AGE_SOURCE_FAMILIES_DIRECT_FLAG_FALSE_EXACT_PASS',6)]:
        portable=q['preservation']['Ubuntu'][key];require(portable['status']==status and len(portable['profiles'])==count,'portable prior source scope omitted')
        for r in portable['profiles'].values():require(all(r[k] is True for k in ('source_provider_inputs_exact','all_physical_exact','four_complete_native_endpoints_exact')),'portable prior source/native changed')
    require(q['boundary']['status']=='FIRST_AND_TRUE_TERMINAL_DAY_DIRECT_SOIL_AGE_GIFTS_O0_O2_COMPLETE_NATIVE_PASS','actual first/TEND boundary omitted')
    for r in q['boundary']['profiles'].values():require(amount(r['first_day_source_cm_day'],48.) and amount(r['terminal_cumulative_source_cm_day'],120.) and len(r['own'])==3 and all(w['exact_complete_native'] is True for w in r['own']),'actual first/TEND source/state differs')
    require(q['archives']==archive_records() and len(q['archives'])==7,'actual direct source raw evidence changed/omitted')
    require(set(q['workflows'])=={'matrix','contracts'} and all(r['status']=='SUCCESS' and r['id']==(44246149974 if k=='matrix' else 44247509054) for k,r in q['workflows'].items()),'direct source portable run incomplete')
    require(len(q['daily_paths'])==44 and len(q['report_paths'])==q['actual_report_count']>280,'actual direct source producer/full period omitted')


def predecessor():
    old=json.loads((ROOT/PROOF/'AGE_IRRIGATION_SOURCE_QUALIFICATION.json').read_text())
    paths={ENTRY,PROOF+'AGE_IRRIGATION_SOURCE_QUALIFICATION.json',*old['source_sha256'],*old['controller_sha256'],*(PROOF+p for p in old['archives'])}
    # Import the old validator in an isolated interpreter with its literal
    # bounded source/import closure. No old proof is rebound to current source.
    for directory in ('app/hybrid_water','tools/solute','tests/nomacro_scheduled_subsurface','tests/nomacro_mixtures','reference/swap-4.3.1/patches'):
        paths|={p for p in tree(BASE,directory) if p.endswith('.py')}
    for path,digest in old['source_sha256'].items():require(hashlib.sha256(blob(BASE,path).replace(b'\r\n',b'\n')).hexdigest()==digest,'qualified predecessor source differs')
    with tempfile.TemporaryDirectory(prefix='s5-direct-age-parent-') as directory:
        snapshot=Path(directory).resolve();require(snapshot.parent==Path(tempfile.gettempdir()).resolve() and snapshot.name.startswith('s5-direct-age-parent-'),'unsafe predecessor source snapshot')
        data=git('archive',BASE,'--',*sorted(paths))
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            for member in archive.getmembers():
                if member.isdir():continue
                target=snapshot/member.name;require(member.isfile() and target.resolve().is_relative_to(snapshot),'foreign predecessor source member');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.extractfile(member).read())
        script="import importlib.util,json,pathlib;root=pathlib.Path.cwd();spec=importlib.util.spec_from_file_location('qualified_original_current_age',root/"+repr(ENTRY)+");m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.validate(json.loads((root/"+repr(PROOF+'AGE_IRRIGATION_SOURCE_QUALIFICATION.json')+").read_text()));print('LITERAL_CURRENT_AGE_BASELINE_PASS')"
        p=subprocess.run([sys.executable,'-B','-c',script],cwd=snapshot,text=True,capture_output=True)
        require(p.returncode==0 and 'LITERAL_CURRENT_AGE_BASELINE_PASS' in p.stdout,'literal qualified predecessor invalid: '+p.stderr)
    for r in old['archives'].values():require(hashlib.sha256((ROOT/PROOF/r['archive']).read_bytes()).hexdigest()==r['sha256'],'actual predecessor raw bytes changed')
    return 'LITERAL_QUALIFIED_CURRENT_AGE_IMAGE_AND_ACTUAL_ARCHIVES_PASS'


def bound_claims(q,reports):
    require(set(reports)==set(q['report_paths']),'actual report binding omitted/forged')
    for key,actual in reports.items():
        expected=q
        for part in q['report_paths'][key]:expected=expected[part]
        require(actual==expected,'direct source claim differs from actual producer: '+key)


def verify():
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty direct source admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    allowed={'app/hybrid_water/'+n for n in ('daily_host.py','daily_coupling.py','experimental_project.py','age_direct_soil_source.py','direct_soil_age.py','direct_soil_age_state.f90')}|{'src/process/mod_direct_soil_age_substep.f90','tools/solute/run_water.py'}
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==allowed,'unqualified direct source production surface')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'direct source differs from qualified production')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'changed literal preceding source owner')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'immutable direct/predecessor evidence changed: '+path)
    docs={'docs/science/NOMACRO_SUBSURFACE_AGE_SOURCE_20261118.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,*docs,PROOF+'DIRECT_SOIL_AGE_MERGE_RECEIPT.json'},'unqualified direct source post-seal change')
    q=json.loads((ROOT/PROOF/'DIRECT_SOIL_AGE_QUALIFICATION.json').read_text());validate(q);prior=predecessor()
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'actual direct source producer differs')
    for r in q['workflows'].values():require(set(git('diff','--name-only',r['runtime'],r['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'direct source carrier changes science')
    sys.path.insert(0,str(ROOT/'app/hybrid_water'));from direct_soil_age import ledger
    specs,_=cases();reports={};physical={};native={};zero_rows={};zero_native={}
    for record,r in q['archives'].items():
        archive=ROOT/PROOF/r['archive'];require(archive.stat().st_size==r['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==r['sha256'],'actual direct source archive changed')
        if record.startswith('DIRECT_SOIL_AGE_UBUNTU_'):require(r['actual_artifact_bytes_preserved'] is True and r['origin_artifact']['digest']=='sha256:'+r['sha256'] and r['origin_artifact']['size_in_bytes']==r['bytes'],'portable actual artifact bytes changed')
        with zipfile.ZipFile(archive) as z:
            require(set(z.namelist())==set(r['members']),'direct source raw member omitted')
            for path,digest in r['members'].items():
                data=z.read(path);require(hashlib.sha256(data).hexdigest()==digest,'direct source raw member changed');key=record+'|'+path
                if key in q['report_paths']:reports[key]=json.loads(data)
                if key in q['zero_paths']:
                    opt=q['zero_paths'][key];zero_rows[opt]=[json.loads(s) for s in data.splitlines()];prefix=path[:-len('daily.jsonl')]
                    for day in (2,4,8):
                        with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'accepted-column-1-day-{day}.zip'))) as a:zero_native[(opt,day)]=(a.read('result.end'),a.read('macro.bin'))
                if key not in q['daily_paths']:continue
                platform,opt,case=q['daily_paths'][key];rows=[json.loads(s) for s in data.splitlines()];require(len(rows)==1096 and [r['day'] for r in rows]==list(range(1,1097)) and all(r['committed'] is True for r in rows),'actual direct source full period censored')
                previous=None
                for row in rows:
                    require(all(bounded(abs(row[k])) for k in ('independent_residual_cm','kernel_residual_cm')),'actual direct source water guard exceeded')
                    if 'integrated_guard_residual_cm' in row:require(bounded(abs(row['integrated_guard_residual_cm'])),'actual original Integral guard exceeded')
                    if previous is None:previous=[row['age_start_cm_day'],0.,row['age_start_cm_day']]+[0.]*9
                    actual=ledger(previous,row['age_state_cm_day']);require(all(actual[k]==row[k] for k in actual),'actual direct source accepted ledger differs');previous=row['age_state_cm_day']
                    require(row['age_state_cm_day'][5]==0.,'actual direct soil source leaked into pond ledger')
                require(amount(rows[4]['age_direct_soil_input_cm_day'],48.) and amount(rows[6]['age_direct_soil_input_cm_day'],72.) and amount(rows[-1]['age_state_cm_day'][11],202.),'actual full direct source current ages ignored/misrouted')
                physical[(platform,opt,case)]=hashlib.sha256(json.dumps([{k:v for k,v in row.items() if k not in ('column','revision')} for row in rows],sort_keys=True).encode()).hexdigest()
                schema=specs[case];import struct
                header=struct.pack('<7i',1,34,0,2,1,schema[3],layout(schema));prefix=path[:-len('daily.jsonl')]
                for day in (4,8,10,201,367,532,1096):
                    with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'accepted-column-1-day-{day}.zip'))) as a:
                        raw=a.read('macro.bin');left,cumulative,right=struct.unpack('<2id2i',raw[-24:])[:2],struct.unpack_from('<d',raw,-16)[0],struct.unpack_from('<2i',raw,-8)
                        require(raw[:8]==CODES[layout(schema)-2].encode() and raw[-80:-24]==header+header and left==right==(1,34) and cumulative==rows[day-1]['age_state_cm_day'][11],'actual direct source native state/domain differs')
                        native[(platform,opt,case,day)]=(hashlib.sha256(a.read('result.end')).hexdigest(),hashlib.sha256(raw).hexdigest())
    bound_claims(q,reports);require(len(physical)==44,'actual direct source full period omitted')
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            require(physical[(platform,opt,'point-output0')]==physical[(platform,opt,'point-output3')],'actual direct source output format changes physics')
            for day in (4,8,10,201,367,532,1096):require(native[(platform,opt,'point-output0',day)]==native[(platform,opt,'point-output3',day)],'actual direct source output format changes native state')
    old_record=json.loads((ROOT/PROOF/'AGE_FIXED_WINDOWS_RAW_ARCHIVE.json').read_text());require(hashlib.sha256((ROOT/PROOF/old_record['archive']).read_bytes()).hexdigest()==old_record['sha256'],'actual immutable zero-source reference changed')
    with zipfile.ZipFile(ROOT/PROOF/old_record['archive']) as z:
        for opt in ('O0','O2'):
            old=[json.loads(s) for s in z.read(f'age-fixed/subsurface-interval-{opt}-full/daily.jsonl').splitlines()][:10];clean=lambda rows:[{k:v for k,v in row.items() if k not in ('column','revision')} for row in rows];projected=[]
            for row in zero_rows[opt]:
                row=dict(row);require(row.pop('age_direct_soil_input_cm_day')==row['age_state_cm_day'][-1]==row['age_ledger_cm_day'][-1]==0.,'zero direct source invented amount');row['age_state_cm_day']=row['age_state_cm_day'][:-1];row['age_ledger_cm_day']=row['age_ledger_cm_day'][:-1];projected.append(row)
            require(clean(projected)==clean(old),'zero direct source changes actual old physical trajectory')
            for day in (2,4,8):
                phase='short' if day==8 else 'full'
                with zipfile.ZipFile(io.BytesIO(z.read(f'age-fixed/subsurface-interval-{opt}-{phase}/accepted-column-1-day-{day}.zip'))) as a:
                    end,raw=zero_native[(opt,day)];require(end==a.read('result.end') and raw[8:-80]==a.read('macro.bin')[8:],'zero direct source changes complete old native payload')
    return dict(status='DIRECT_SOIL_AGE_SOURCE_STATE_OUTPUT_ADMISSION_PASS',runtime=RUNTIME,predecessor=prior,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',actual_bound_reports=len(reports),actual_full_periods=len(physical),native_codecs=CODES,age_units='cm day',age_tolerance=AGE_TOL)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
