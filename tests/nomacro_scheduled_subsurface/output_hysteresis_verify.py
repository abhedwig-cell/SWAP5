"""Actual source/state/output admission for the bounded hysteresis successor."""
from pathlib import Path
import hashlib
import importlib.util
import io
import json
import math
import struct
import subprocess
import sys
import zipfile
from functools import lru_cache

ROOT=Path(__file__).resolve().parents[2]
PROOF='integration/f-ci/nomacro-complete01/'
BASE='4b33ac69f93386658c34d03461b85c014e181d0f'
RUNTIME='4aaf71629ea0bff04d2fc7fc329c6718aff54478'
SEALED='40a81d4b0330d85c6820cb5ec1069f6a9d61038a'
ENTRY='tests/nomacro_scheduled_subsurface/original_output_verify.py'
SELF='tests/nomacro_scheduled_subsurface/output_hysteresis_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_output_hysteresis_verify.py'
CASES=[(kind,mode,fmt,'daily') for kind in ('water','cde','age') for mode in (1,2) for fmt in (0,3)]+[('water',2,3,'np3'),('age',1,1,'np3'),('water',1,1,'monthly'),('age',2,2,'perstep-monthly')]
NATIVE={'water':'S5IHW001','cde':'S5IHC001','age':'S5IHA001'}
AGE_TOL='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('output_hysteresis_admission',ROOT/'tests/nomacro_scheduled_subsurface/output_hysteresis_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""


def require(ok,why):
    if not ok:raise ValueError(why)


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def sha(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
def tree(ref,path):return {r.split('\t',1)[1]:r.split('\t',1)[0] for r in git('ls-tree','-r',ref,'--',path).decode().splitlines()}
def name(case):
    kind,mode,fmt,calendar=case
    return f'{kind}-hys{mode}-csv{fmt}'+('' if calendar=='daily' else '-'+calendar)


def files(items):return all(v['exact'] is True and isinstance(v['continuation_records'],int) and v['continuation_records']>=0 for v in items.values())
def bounded(value):return isinstance(value,(int,float)) and math.isfinite(value) and 0<=value<=1e-10


@lru_cache(maxsize=1)
def archive_records():return {p.name:json.loads(p.read_text()) for p in (ROOT/PROOF).glob('OUTPUT_HYSTERESIS_*_RAW_ARCHIVE.json')}


def selectors(q,actual,case):
    kind,mode,fmt,calendar=case;monthly=int('monthly' in calendar);perstep=calendar=='perstep-monthly';np=3 if calendar=='np3' else 1
    expected=dict(kind=kind,swhyst=mode,swcsv=fmt,nprintday=np,swmonth=monthly,swodat=0,swres=0,requested_period=0 if monthly else 1,period=1 if np>1 or perstep else 0 if monthly else 1,flprintdt=perstep,groups=None if not fmt else 'WATBAL,GWL,SOLBAL,S_CONC,Q' if kind=='cde' else 'WATBAL,GWL',num_decimals=12 if fmt else None)
    require({k:actual[k] for k in expected}==expected,'foreign hysteresis output selectors')
    require(actual['policy']=='original-output-hysteresis-carry-v1' and actual['native_codec']==NATIVE[kind],'foreign hysteresis output policy/codec')
    targets={'source_sha256':'app/hybrid_water/original_output_hysteresis.py','domain_source_sha256':'app/hybrid_water/original_output_hysteresis_domain.f90','ordinary_owner_sha256':'app/hybrid_water/original_output.py','calendar_owner_sha256':'app/hybrid_water/age_output_calendar.py','clock_owner_sha256':'app/hybrid_water/age_output_clock.py','receipt_provider_sha256':'src/process/mod_original_output_receipt.f90'}
    for key,path in targets.items():require(actual[key]==q['source_sha256'][path],'foreign hysteresis source identity: '+key)
    require(actual['original_hysteresis_sha256']=='e6f5e4744e0a393a9e890abc0aaedaead91fe0128d84c9a7f8864b381c4c2fb8' and actual['original_integral_sha256']=='62e4d36693eb090eb7ba2c20871fce619ab4314cee75bb6961aa531cb734207a' and actual['original_output_epoch']==37256,'foreign original process provider/epoch')
    for key,active,path in [('cde_output_state_sha256',kind=='cde','app/hybrid_water/original_cde_output_state.f90'),('vector_catalog_correction_sha256',fmt!=0,'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py'),('binary_correction_sha256',fmt==3,'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py')]:require(actual[key]==(q['source_sha256'][path] if active else None),'foreign composed original output owner')
    require(actual['preserves_requested_groups_and_precision'] is True and actual['undefined_allocation_tails_serialized'] is False and actual['conserved_cde_prefix_offset_bytes']==(48 if kind=='cde' else None),'hysteresis output state domain changed')


def period(q,r,case,opt,phase,build,build_digest):
    kind,mode,fmt,calendar=case;days=1096 if phase=='full' else 35 if 'monthly' in calendar else 10
    require(r['status']=='ORIGINAL_OUTPUT_HYSTERESIS_'+phase.upper()+'_SOURCE_NATIVE_PASS' and (r['kind'],r['hysteresis_mode'],r['output_format'],r['calendar'],r['optimization'])==(*case,opt),'missing hysteresis trajectory')
    require(r['functional_completion']=='PARTIAL' and r['whole_scientific_equivalence']=='NOT_QUALIFIED','hysteresis scope promoted')
    selectors(q,r['original_output'],case)
    require(r['trajectory']['days']==r['trajectory']['budgets']['days']==days and r['trajectory']['build_sha256']==build_digest,'hysteresis period censored/foreign build')
    for key in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2'):require(bounded(r['trajectory']['budgets'][key]),'hysteresis mass guard exceeded')
    windows={(2,4),(4,8)}
    if 'monthly' in calendar:windows.add((30,34))
    if phase=='full':windows|={(199,201),(364,367),(530,532),(1094,1096)}
    require(len(r['own'])==len(windows) and {(w['start'],w['end']) for w in r['own']}==windows,'missing hysteresis native window')
    for w in r['own']:
        require(all(w[k] is True for k in ('exact_physical','exact_complete_native','origin_unchanged')) and files(w['exact_user_output']),'hysteresis native/user output differs')
        require(('result_output.bin' if fmt==3 else 'result_output.csv') in w['exact_user_output'] if fmt else not any(k.startswith('result_output') for k in w['exact_user_output']),'requested output format changed')
    require(set(r['actual_hysteresis_history'])==set(r['native_domains'])=={'2','4','8',str(days)},'hysteresis state observations missing')
    for day,h in r['actual_hysteresis_history'].items():
        require(h['mode']==mode and h['nodes']==34 and all(len(h[k])==34 for k in ('index','delp','fhyst','hm1','h')),'foreign scanning history')
        require(all(v in (-1,1) for v in h['index']) and all(math.isfinite(v) for k in ('delp','fhyst','hm1','h') for v in h[k]),'invalid scanning state')
        d=r['native_domains'][day];require(d['bytes']==40 and d['offset']>=48 and d['exact_actual_flags'] is True,'hysteresis domain/prefix changed')
    require(any(any(v!=1 for v in h['fhyst']) for h in r['actual_hysteresis_history'].values()),'inactive scanning fixture')
    if kind=='cde':require(abs(r['active_chemical_source_mg_cm2']-48)<=1e-10 and r['conserved_cde_prefix_at48'] is True,'inactive chemical hysteresis composition')
    require(build['identity']['original_output']==r['original_output'],'actual hysteresis build policy differs')


def validate(q):
    require((q['baseline'],q['runtime'])==(BASE,RUNTIME) and q['status']=='BOUNDED_ORIGINAL_OUTPUT_HYSTERESIS_QUALIFIED_PENDING_ADMISSION','foreign/unqualified hysteresis source')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['release_readiness'])==('PARTIAL','NOT_QUALIFIED','RC3_FIXED_NAMED_PROFILES_ONLY'),'hysteresis whole scope promoted')
    require(q['water_guard_cm']==q['chemical_mass_guard_mg_cm2']==1e-10 and q['age_units']=='cm day' and q['age_tolerance']==AGE_TOL,'hysteresis conservation policy changed')
    require(q['scope']==dict(hysteresis_modes=[1,2],formats=[0,1,2,3],macro=False,snow=False,frost=False,aquifer=False,detailed_weather=False,analytical_hydraulics=True,original_output_default=False,physical_providers_changed=False,cde_cadence='daily-reset-only',perstep_reset=0),'unqualified hysteresis process domain')
    for path,digest in q['source_sha256'].items():require(sha(ROOT/path)==digest,'changed qualified hysteresis source: '+path)
    require(q['base_consumer']['merge']==BASE and q['base_consumer']['exact_complete_tree'] is True and q['base_consumer']['actual_detached_owner']['returncode']==0,'actual canonical predecessor not verified')
    for key in ('platforms','builds','controls','receipt_components','domain_components','public_cli','reader_controls'):require(set(q[key])=={'Windows','Ubuntu'},'hysteresis platform missing: '+key)
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            run=q['platforms'][platform][opt];require(run['status']=='SIXTEEN_HYSTERESIS_ORIGINAL_OUTPUT_FULL_SOURCE_NATIVE_USER_OUTPUT_PASS' and run['optimization']==opt and set(run['cases'])=={name(c) for c in CASES},'missing hysteresis matrix')
            require(set(q['builds'][platform][opt])==set(run['cases']),'hysteresis build omitted')
            for case in CASES:
                key=name(case);build=q['builds'][platform][opt][key];identity=build['identity'];require(build['project']['nodes']==34 and build['project']['water_tolerance']==1e-10 and build['project']['model']=='HYBRID_NOMACRO_WATER','foreign hysteresis model')
                for phase in ('short','full'):period(q,run['cases'][key][phase],case,opt,phase,build,q['build_sha256'][platform][opt][key])
                if case[0]=='age':require(identity['conserved_original_age']['native_codec']==NATIVE['age'] and identity['conserved_original_age']['providers']==q['physical_age_providers'],'changed physical age provider')
            c=q['controls'][platform][opt];require(c['status']=='HYSTERESIS_OUTPUT_NATIVE_ACTIVE_POLICY_PASS' and c['contexts']==len(c['profiles'])==4,'missing hysteresis native/active controls')
            require(sum(len(r['native_refusals']) for r in c['profiles'].values())==137,'native hysteresis refusals omitted')
            for r in c['profiles'].values():
                require(len(r['policy_refusals'])==8 and all(a['status']=='REFUSED' for a in r['native_refusals']+r['policy_refusals']),'invalid native/policy accepted')
                require(all(v is True for v in r['transactions'].values()) and len(r['transactions'])==5,'hysteresis transaction/recovery failed')
            c=q['receipt_components'][platform][opt];require(c['status']=='ACTUAL_ORIGINAL_TRIAL_RECEIPT_EXACT_NONMUTATION_42_PASS' and c['cases']==42 and c['optimization']==opt,'actual original water receipt failed')
        d=q['domain_components'][platform];require(d['status']=='ORIGINAL_HYSTERESIS_DOMAIN_O0_O2_TWELVE_CONTEXTS_92_REFUSALS_PASS','hysteresis domain component failed')
        for opt in ('O0','O2'):
            r=d['profiles'][opt];require(r['actual_original_storage'] is True and len(r['contexts'])==6 and len(r['invalid_live_domains'])==4,'original module storage closure omitted')
            for context in r['contexts'].values():require(all(context[k] is True for k in ('exact_forty_byte_header','stream_position_exact','live_flags_unchanged')) and len(context['native_refusals'])==7 and all(x['returncode']!=0 for x in context['native_refusals']),'component domain accepted/mutated')
            require(all(x['returncode']!=0 for x in r['invalid_live_domains']),'invalid live domain accepted')
        p=q['public_cli'][platform];require(p['status']=='THREE_PUBLIC_HYSTERESIS_OUTPUT_FLAG_AND_COMPLETE_COLD_NATIVE_PASS' and len(p['profiles'])==3,'public hysteresis continuation missing')
        for r in p['profiles'].values():require(all(r[k] is True for k in ('actual_public_flag','exact_physical','exact_complete_native')) and r['warm']['returncode']==r['cold']['returncode']==0 and files(r['exact_original_user_output']),'public hysteresis continuation failed')
        r=q['reader_controls'][platform];require(r['status']=='FOUR_HYSTERESIS_OMITTED_MONTHLY_CONTROLS_NATIVE_AND_TWENTY_INPUT_REFUSALS_PASS' and len(r['profiles'])==4 and len(r['invalid'])==20 and all(x['status']=='REFUSED' for x in r['invalid']),'historical omitted/invalid inputs failed')
        for x in r['profiles'].values():require(x['status']=='ORIGINAL_OUTPUT_HYSTERESIS_SHORT_SOURCE_NATIVE_PASS' and len(x['own'])==3 and all(w['exact_complete_native'] is True for w in x['own']),'omitted calendar restart failed')
    require(set(q['preservation'])=={'O0','O2'},'default preservation optimization omitted')
    for opt,r in q['preservation'].items():
        require(r['status']=='TEN_ORDINARY_AND_HYSTERESIS_COMPATIBILITY_CONTEXTS_EXACT_PASS' and len(r['profiles'])==10,'existing output/hysteresis context omitted')
        for p in r['profiles'].values():require(all(p[k] is True for k in ('generated_provider_exact','all_physical_exact','complete_native_exact')) and len(p['own'])==2 and all(w['exact_physical'] is True and w['exact_complete_native'] is True for w in p['own']),'qualified default output changed')
    require(set(q['baselines'])=={'O0','O2'},'original hysteresis baseline omitted')
    for r in q['baselines'].values():
        require(r['status']=='SIX_HYSTERESIS_COMPATIBILITY_SHORT_NATIVE_AND_ORIGINAL_OUTPUT_REFUSALS_OBSERVED' and len(r['profiles'])==6,'baseline original hysteresis cases omitted')
        for p in r['profiles'].values():require(p['active_scanning_observed'] is True and len(p['own'])==2 and all(w['exact_physical'] is True and w['exact_complete_native'] is True for w in p['own']),'original hysteresis compatibility history not observed')
    for key,r in q['workflows'].items():require(r['status']=='SUCCESS' and r['id']==(44226733764 if key=='matrix' else 44227558877),'portable hysteresis workflow failed')
    require(set(q['workflows'])=={'matrix','public_reader'},'portable selected workflow omitted')
    require(len(q['archives'])==7 and all(len(r['members'])==r['member_count']>0 and r['all_members_forward_verified'] is True for r in q['archives'].values()),'raw hysteresis evidence omitted')
    require(q['archives']==archive_records() and len(q['report_paths'])==242 and len(q['daily_paths'])==64,'actual producer/archive bindings changed')


def verify():
    import importlib.util
    spec=importlib.util.spec_from_file_location('age_irrigation_source_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_irrigation_source_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty hysteresis admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    allowed={'app/hybrid_water/'+n for n in ('daily_coupling.py','daily_host.py','experimental_project.py','original_output_hysteresis.py','original_output_hysteresis_domain.f90')}
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==allowed,'unqualified hysteresis production surface')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'hysteresis production differs from qualified runtime')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'changed literal original-output predecessor')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'changed immutable hysteresis/predecessor evidence: '+path)
    docs={'docs/science/NOMACRO_ORIGINAL_OUTPUT_HYSTERESIS_20261118.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,*docs,PROOF+'OUTPUT_HYSTERESIS_MERGE_RECEIPT.json'},'unqualified hysteresis post-seal change')
    q=json.loads((ROOT/PROOF/'OUTPUT_HYSTERESIS_QUALIFICATION.json').read_text());validate(q)
    spec=importlib.util.spec_from_file_location('literal_original_output_predecessor',ROOT/ENTRY);parent=importlib.util.module_from_spec(spec);spec.loader.exec_module(parent);parent.validate(json.loads((ROOT/PROOF/'ORIGINAL_OUTPUT_QUALIFICATION.json').read_text()))
    for path,digest in q['controller_sha256'].items():require(sha(ROOT/path)==digest,'changed executed hysteresis controller')
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'actual hysteresis producer source differs')
    for r in q['workflows'].values():require(set(git('diff','--name-only',r['runtime'],r['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'portable carrier changed model')
    sys.path.insert(0,str(ROOT/'app/hybrid_water'));from conserved_original_age import ledger
    sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'));from output_hysteresis_baseline import history
    observed=set();physical={};native={}
    for record_name,r in q['archives'].items():
        archive=ROOT/PROOF/r['archive'];require(archive.stat().st_size==r['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==r['sha256'],'raw hysteresis archive changed')
        if record_name.startswith('OUTPUT_HYSTERESIS_UBUNTU_'):require(r['actual_artifact_bytes_preserved'] is True and r['origin_artifact']['digest']=='sha256:'+r['sha256'] and r['origin_artifact']['size_in_bytes']==r['bytes'],'portable actual artifact changed')
        with zipfile.ZipFile(archive) as z:
            require(set(z.namelist())==set(r['members']),'raw hysteresis member omitted')
            for path,digest in r['members'].items():
                data=z.read(path);require(hashlib.sha256(data).hexdigest()==digest,'raw hysteresis member changed')
                key=record_name+'|'+path
                if key in q['report_paths']:
                    expected=q
                    for part in q['report_paths'][key]:expected=expected[part]
                    require(json.loads(data)==expected,'hysteresis claim differs from actual producer: '+path);observed.add(key)
                    pointer=q['report_paths'][key]
                    if pointer[0]=='builds':require(hashlib.sha256(data).hexdigest()==q['build_sha256'][pointer[1]][pointer[2]][pointer[3]],'actual measured hysteresis build differs')
                if key not in q['daily_paths']:continue
                platform,opt,case=q['daily_paths'][key];rows=[json.loads(line) for line in data.splitlines()];require(len(rows)==1096 and [row['day'] for row in rows]==list(range(1,1097)) and all(row['committed'] is True for row in rows),'actual hysteresis trajectory censored')
                prior=None
                for row in rows:
                    require(all(bounded(abs(row[k])) for k in ('independent_residual_cm','kernel_residual_cm')),'actual hysteresis water guard exceeded')
                    if 'integrated_guard_residual_cm' in row:require(bounded(abs(row['integrated_guard_residual_cm'])),'actual original Integral receipt guard exceeded')
                    if 'solute_independent_residual_mg_cm2' in row:require(bounded(abs(row['solute_independent_residual_mg_cm2'])),'actual hysteresis chemical guard exceeded')
                    if 'age_state_cm_day' in row:
                        if prior is None:prior=[row['age_start_cm_day'],0.,row['age_start_cm_day']]+[0.]*8
                        actual=ledger(prior,row['age_state_cm_day']);require(all(actual[k]==row[k] for k in actual),'actual accepted age ledger/policy differs');prior=row['age_state_cm_day']
                physical[(platform,opt,case)]=hashlib.sha256(json.dumps([{k:v for k,v in row.items() if k not in ('column','revision')} for row in rows],sort_keys=True).encode()).hexdigest()
                item=q['platforms'][platform][opt]['cases'][case];kind=item['full']['kind'];mode=item['full']['hysteresis_mode'];prefix=path[:-len('daily.jsonl')]
                for day in (4,8,201,367,532,1096):
                    with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'accepted-column-1-day-{day}.zip'))) as checkpoint:
                        raw=checkpoint.read('macro.bin');end=checkpoint.read('result.end');header=struct.pack('<5i',1,34,0,mode,{'water':0,'cde':1,'age':2}[kind]);require(raw[:8]==NATIVE[kind].encode() and raw.count(header+header)==1 and raw.index(header+header)>=48,'actual native hysteresis domain differs')
                        if day in (4,8,1096):require(history(end)==item['full']['actual_hysteresis_history'][str(day)],'actual original scanning carry differs')
                        native[(platform,opt,case,day)]=(hashlib.sha256(raw).hexdigest(),hashlib.sha256(end).hexdigest())
                if kind=='cde':require(rows[0]['solute_start_mg_cm2']>0 and abs(rows[4]['solute_ledger_mg_cm2'][3]-48)<=1e-10,'actual chemical source inactive')
    require(observed==set(q['report_paths']) and len(physical)==64,'actual hysteresis producer/build/full period omitted')
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            for kind in ('water','cde','age'):
                for mode in (1,2):
                    a=name((kind,mode,0,'daily'));b=name((kind,mode,3,'daily'));require(physical[(platform,opt,a)]==physical[(platform,opt,b)],'actual output format changes physics')
                    for day in (4,8,201,367,532,1096):require(native[(platform,opt,a,day)]==native[(platform,opt,b,day)],'actual format changes complete accepted state')
    return dict(status='CURRENT_ORIGINAL_OUTPUT_HYSTERESIS_SOURCE_STATE_USER_FILES_ADMISSION_PASS',runtime=RUNTIME,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',actual_bound_reports=len(observed),actual_full_periods=len(physical),native_codecs=NATIVE)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
