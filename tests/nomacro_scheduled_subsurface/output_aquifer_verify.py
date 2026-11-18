"""Admission owner for actual aquifer output and native candidate receipts."""
from pathlib import Path
from functools import lru_cache
import hashlib
import importlib.util
import io
import json
import math
import struct
import subprocess
import sys
import tarfile
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
PROOF='integration/f-ci/nomacro-complete01/'
BASE='76c6251a2f3f6345428b26b1a9e03cf7e0bf917a'
RUNTIME='e01961fcc3af253e9b2293362be13641728cb4ba'
SEALED='a696a29fe530e1c519d3effff3bd130ac925713b'
ENTRY='tests/nomacro_scheduled_subsurface/direct_soil_age_verify.py'
SELF='tests/nomacro_scheduled_subsurface/output_aquifer_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_output_aquifer_verify.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('output_aquifer_admission',ROOT/'tests/nomacro_scheduled_subsurface/output_aquifer_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""

def require(ok,why):
    if not ok:raise ValueError(why)

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def tree(ref,path):return {s.split('\t',1)[1]:s.split('\t',1)[0] for s in git('ls-tree','-r',ref,'--',path).decode().splitlines()}
def sha(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
def bounded(v):return isinstance(v,(int,float)) and math.isfinite(v) and 0<=v<=1e-10

def raw_archive(record):
    if 'byte_parts' not in record:raw=(ROOT/PROOF/record['archive']).read_bytes()
    else:
        chunks=[];offset=0
        for part in record['byte_parts']:
            require(part['offset']==offset and Path(part['path']).name==part['path'],'foreign archive byte part')
            data=(ROOT/PROOF/part['path']).read_bytes();require(len(data)==part['bytes'] and hashlib.sha256(data).hexdigest()==part['sha256'],'changed immutable byte part');offset+=len(data);chunks.append(data)
        raw=b''.join(chunks)
    require(len(raw)==record['bytes'] and hashlib.sha256(raw).hexdigest()==record['sha256'],'actual producer archive changed')
    if 'origin_artifact' in record:require(record['origin_artifact']['digest']=='sha256:'+record['sha256'] and record['origin_artifact']['size_in_bytes']==len(raw) and record['actual_artifact_bytes_preserved'] is True,'actual portable artifact rebound')
    return raw

def validate(q):
    require((q['baseline'],q['runtime'],q['status'])==(BASE,RUNTIME,'BOUNDED_OUTPUT_AQUIFER_QUALIFIED_PENDING_ADMISSION'),'foreign output aquifer qualification')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['release_readiness'])==('PARTIAL','NOT_QUALIFIED','RC3_FIXED_NAMED_PROFILES_ONLY'),'whole scope promoted')
    require(q['water_guard_cm']==q['chemical_mass_guard_mg_cm2']==1e-10 and q['native_codec']=='S5IOQ001' and q['native_domain_bytes']==56 and q['conserved_cde_prefix_offset_bytes']==48,'physical guards or native ownership changed')
    require(q['scope']==dict(explicit_original_output=True,solute=1,aquifer=1,drainage=1,macro=0,snow=0,frost=0,detailed_weather=0,hysteresis=[0,1,2],output_formats=[0,1,2,3],cde_cadence='daily interval reset',physical_equations_changed=False),'unqualified process scope')
    for field in ('source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
        for path,digest in q[field].items():require(sha(ROOT/path)==digest,'actual source/controller changed: '+path)
    require(set(q['archives'])=={'OUTPUT_AQUIFER_'+s+'_RAW_ARCHIVE.json' for s in ('WINDOWS_O0','WINDOWS_O2','WINDOWS_CONTEXT','WINDOWS_PRESERVATION','UBUNTU_O0','UBUNTU_O2','UBUNTU_CONTRACTS')},'actual raw producer omitted')
    for platform in ('Windows','Ubuntu'):
        require(set(q['main'][platform])=={'O0','O2'},'optimization omitted')
        require(sum(q['preservation'][platform]['profiles'].values())==(71 if platform=='Windows' else 16),'preserved route omitted')
    require(q['base_consumer']['merge']==BASE and q['base_consumer']['exact_complete_tree'] is True and q['base_consumer']['actual_detached_owner']['returncode']==0,'actual preceding canonical owner missing')
    require(len(q['workflows'])==2 and all(w['status']=='SUCCESS' and w['merge'] is False for w in q['workflows'].values()),'portable contract not terminal')


def predecessor():
    old=json.loads((ROOT/PROOF/'DIRECT_SOIL_AGE_QUALIFICATION.json').read_text())
    paths={ENTRY,PROOF+'DIRECT_SOIL_AGE_QUALIFICATION.json',*old['source_sha256'],*old['controller_sha256'],*(PROOF+p for p in old['archives'])}
    for directory in ('app/hybrid_water','tools/solute','tests/nomacro_scheduled_subsurface','tests/nomacro_mixtures','reference/swap-4.3.1/patches'):
        paths|={p for p in tree(BASE,directory) if p.endswith('.py')}
    for path,digest in old['source_sha256'].items():require(hashlib.sha256(blob(BASE,path).replace(b'\r\n',b'\n')).hexdigest()==digest,'qualified predecessor source changed')
    with tempfile.TemporaryDirectory(prefix='s5-output-aquifer-parent-') as directory:
        snapshot=Path(directory).resolve();data=git('archive',BASE,'--',*sorted(paths))
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            for member in archive.getmembers():
                if member.isdir():continue
                target=snapshot/member.name;require(member.isfile() and target.resolve().is_relative_to(snapshot),'foreign predecessor source member');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.extractfile(member).read())
        script="import importlib.util,json,pathlib;root=pathlib.Path.cwd();spec=importlib.util.spec_from_file_location('qualified_direct_soil_age',root/"+repr(ENTRY)+");m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.validate(json.loads((root/"+repr(PROOF+'DIRECT_SOIL_AGE_QUALIFICATION.json')+").read_text()));print('LITERAL_DIRECT_SOIL_AGE_BASELINE_PASS')"
        p=subprocess.run([sys.executable,'-B','-c',script],cwd=snapshot,text=True,capture_output=True);require(p.returncode==0 and 'LITERAL_DIRECT_SOIL_AGE_BASELINE_PASS' in p.stdout,'literal qualified predecessor invalid: '+p.stderr)
    for r in old['archives'].values():require(hashlib.sha256((ROOT/PROOF/r['archive']).read_bytes()).hexdigest()==r['sha256'],'actual predecessor raw bytes changed')
    return 'LITERAL_QUALIFIED_DIRECT_SOIL_AGE_IMAGE_AND_ACTUAL_ARCHIVES_PASS'


def period(report,case,opt,phase,build,digest):
    days=1096 if phase=='full' else 10
    require(report['status']=='ORIGINAL_OUTPUT_AQUIFER_'+phase.upper()+'_COMPOUND_SOURCE_NATIVE_USER_FILES_PASS','period not qualified')
    require(tuple(report[k] for k in ('kind','output_format','hysteresis','irrigation','inline','salinity','groups','precision'))==case[:8] and report['optimization']==opt,'actual selected domain differs')
    require((report['functional_completion'],report['whole_scientific_equivalence'])==('PARTIAL','NOT_QUALIFIED'),'producer whole scope promoted')
    require(report['trajectory']['days']==report['trajectory']['budgets']['days']==days and report['trajectory']['build_sha256']==digest,'period censored/build rebound')
    require(all(bounded(report['trajectory']['budgets'][k]) for k in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')) and all(bounded(v) for v in report['maximum_residuals'].values()),'unchanged actual budget guards exceeded')
    require(report['output']==build['identity']['original_output'] and report['output']['native_codec']=='S5IOQ001','actual compiled output policy differs')
    require(build['project']['nodes']==34 and build['project']['water_tolerance']==1e-10 and build['identity']['aquifer_native_receipt']['physical_equations_changed'] is False,'compiled physical scope differs')
    windows={(2,4),(4,8),(6,10)}|({(199,201),(364,367),(530,532),(1094,1096)} if phase=='full' else set())
    require(len(report['own'])==len(windows) and {(w['start'],w['end']) for w in report['own']}==windows,'cold window omitted')
    for w in report['own']:
        require(all(w[k] is True for k in ('exact_physical','exact_complete_native','origin_unchanged')) and (case[1]==0 or bool(w['exact_user_output'])) and all(v['exact'] is True for v in w['exact_user_output'].values()),'cold physical/native/user output differs')
    require(set(report['native_domains'])=={'2','4','8',str(days)},'native domain observation omitted')
    for d in report['native_domains'].values():require(d['bytes']==56 and d['actual_private_swbr']==1 and d['exact_actual_domain'] is True and d['conserved_cde_prefix_offset_bytes']==48,'native domain/physical prefix differs')
    if case[3]!='none':require(all(abs(a-b)<=1e-10 for a,b in zip(report['actual_irrigation_mg_cm2'],(48.,72.))),'actual current chemical source omitted')


def verify():
    import importlib.util
    spec=importlib.util.spec_from_file_location('output_thermal_admission',ROOT/'tests/nomacro_scheduled_subsurface/output_thermal_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty aquifer admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'production differs from qualified actual source')
    q=json.loads((ROOT/PROOF/'OUTPUT_AQUIFER_QUALIFICATION.json').read_text());validate(q)
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==set(q['source_sha256']),'unqualified production surface')
    current=tree('HEAD','integration');mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')}
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'immutable evidence changed: '+path)
    docs={'docs/science/NOMACRO_ORIGINAL_OUTPUT_AQUIFER_20261118.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,*docs,PROOF+'OUTPUT_AQUIFER_MERGE_RECEIPT.json'},'unqualified post-seal change')
    require((ROOT/ENTRY).read_text().replace(HOOK,'',1).encode()==blob(BASE,ENTRY).replace(b'\r\n',b'\n'),'literal predecessor owner body changed')
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'actual model producer source differs')
    for w in q['workflows'].values():require(set(git('diff','--name-only',w['runtime'],w['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'portable carrier changes science')
    prior=predecessor();sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'));sys.path.insert(0,str(ROOT/'app/hybrid_water'))
    from output_aquifer_ci import CASES,CONTROLS
    from conserved_aquifer_solute import ledger
    require(len(CASES)==19 and sum(c[8] for c in CASES.values())==12 and len(CONTROLS)==8,'qualified cohort changed')
    archives={};reports=0;fulls=0
    for name,record in q['archives'].items():
        z=zipfile.ZipFile(io.BytesIO(raw_archive(record)));require(set(z.namelist())==set(record['members']),'actual raw members omitted')
        for path,digest in record['members'].items():require(hashlib.sha256(z.read(path)).hexdigest()==digest,'actual producer member changed')
        archives[name]=z
    def read(z,path):
        nonlocal reports
        reports+=1;return json.loads(z.read(path))
    for platform,opts in q['main'].items():
        for opt,location in opts.items():
            z=archives[location['archive']];prefix=location['prefix'];run=read(z,prefix+'RESULT.json');require(run['status']=='NINETEEN_AQUIFER_OUTPUT_SHORT_AND_TWELVE_FULL_COMPOUND_SOURCE_NATIVE_USER_FILES_PASS' and set(run['cases'])==set(CASES) and set(run['controls'])==set(CONTROLS),'actual main matrix incomplete')
            physical={};natives={}
            for key,case in CASES.items():
                item=run['cases'][key];sp=prefix+'short-'+key+'/'
                if platform=='Windows' and key=='box-csv3':sp='output-aquifer-receipt-refined-'+opt+'-v2/'
                build_bytes=z.read(sp+'build/BUILD.json');build=json.loads(build_bytes);digest=hashlib.sha256(build_bytes).hexdigest();reports+=1
                require(build['identity']['original_output']['source_sha256']==q['source_sha256']['app/hybrid_water/original_output_aquifer.py'] and build['identity']['original_output']['domain_source_sha256']==q['source_sha256']['app/hybrid_water/original_output_aquifer_domain.f90'] and build['identity']['aquifer_native_receipt']['source_sha256']==q['source_sha256']['app/hybrid_water/aquifer_native_receipt.py'],'actual compiled source policy rebound')
                require(read(z,sp+'RESULT.json')==item['short'],'actual short producer rebound');period(item['short'],case,opt,'short',build,digest)
                if not case[8]:continue
                fulls+=1;fp=prefix+'full-'+key+'/';report=read(z,fp+'RESULT.json');require(report==item['full'],'actual full producer rebound');period(report,case,opt,'full',build,digest)
                rows=[json.loads(s) for s in z.read(fp+'trajectory/daily.jsonl').splitlines()];require(len(rows)==1096 and [r['day'] for r in rows]==list(range(1,1097)) and all(r['committed'] is True for r in rows),'actual full period censored')
                previous=[rows[0]['aquifer_start_mg_cm2']/rows[0]['aquifer_state'][1],rows[0]['aquifer_state'][1],rows[0]['aquifer_start_mg_cm2'],0.,0.,0.,0.]
                for row in rows:
                    require(all(bounded(abs(row[k])) for k in ('independent_residual_cm','kernel_residual_cm','solute_independent_residual_mg_cm2')),'actual water/soil budget guard exceeded')
                    if 'integrated_guard_residual_cm' in row:require(bounded(abs(row['integrated_guard_residual_cm'])),'actual original Integral guard exceeded')
                    actual=ledger(previous,row['aquifer_state'],row['solute_start_mg_cm2'],row['solute_ledger_mg_cm2']);require(all(actual[k]==row[k] for k in actual),'actual aquifer ledger differs');previous=row['aquifer_state']
                physical[key]=hashlib.sha256(json.dumps([{k:v for k,v in r.items() if k not in ('column','revision')} for r in rows],sort_keys=True).encode()).hexdigest()
                for day in (4,8,10,201,367,532,1096):
                    with zipfile.ZipFile(io.BytesIO(z.read(fp+f'trajectory/accepted-column-1-day-{day}.zip'))) as cold:
                        raw=cold.read('macro.bin');hdr=struct.pack('<7i',1,34,0,1,1,case[2],1);require(raw[:8]==b'S5IOQ001' and raw.count(hdr+hdr)==1 and list(struct.unpack_from('<6dq',raw,48+8*36))==rows[day-1]['aquifer_state'],'actual complete native aquifer/domain differs');natives[key,day]=(hashlib.sha256(cold.read('result.end')).hexdigest(),hashlib.sha256(raw).hexdigest())
                if case[3]!='none':require(abs(rows[4]['solute_ledger_mg_cm2'][3]-48.)<=1e-10 and abs(rows[6]['solute_ledger_mg_cm2'][3]-72.)<=1e-10,'actual fixed chemical input ignored')
            require(physical['soil-csv0']==physical['soil-csv3'] and all(natives['soil-csv0',d]==natives['soil-csv3',d] for d in (4,8,10,201,367,532,1096)),'output format changes actual physics/native state')
            for key in CONTROLS:
                control=read(z,prefix+'controls-'+key+'/RESULT.json');require(control==run['controls'][key] and control['status']=='ORIGINAL_OUTPUT_AQUIFER_ACTUAL_NATIVE_ACTIVE_AND_POLICY_REFUSALS_PASS','actual controls rebound')
                for field,count in [('native_refusals',49),('policy_refusals',10),('receipt_policy_refusals',9),('fabricated_aquifer_refusals',7)]:require(len(control[field])==count and all('REFUSED' in r['status'] for r in control[field]),'actual rejection omitted')
                require(all(v is True for v in control['transactions'].values()),'valid external transactional state changed')
    for platform,location in q['context'].items():
        z=archives[location['archive']]
        for key,count in [('public',3),('reader',6)]:
            report=read(z,location[key]+'/RESULT.json');require('PASS' in report['status'],'actual public/reader contract not passed')
            require(len(report['profiles'] if key=='public' else report['reader_refusals'])==count,'public/reader case omitted')
            if key=='reader':require(len(report['descriptor_refusals'])==9,'unsupported output scope not refused')
        report=read(z,location['boundary']+'/RESULT.json');require('PASS' in report['status'] and set(report['profiles'])=={'O0','O2'},'true terminal source omitted')
        for p in report['profiles'].values():require(abs(p['first_day_source_mg_cm2']-48.)<=1e-10 and abs(p['terminal_day_source_mg_cm2']-72.)<=1e-10 and abs(p['total_source_mg_cm2']-120.)<=1e-10 and len(p['own'])==3,'true terminal chemical source differs')
        for prefix in location['components']:
            report=read(z,prefix+'/RESULT.json');require(report['status']=='ACTUAL_AQUIFER_NATIVE_RECEIPT_COMPONENT_TWENTY_REFUSALS_PASS' and report['actual_fortran_wire'] is True and len(report['refusals'])==20,'real wire component omitted')
    contexts=0
    for platform,location in q['preservation'].items():
        z=archives[location['archive']]
        for prefix,count in location['profiles'].items():
            report=read(z,prefix+'/RESULT.json');require(any(s in report['status'] for s in ('PASS','PRESERVED')) and len(report['profiles'])==count,'prior current route omitted');contexts+=count
            for key,p in report['profiles'].items():
                build_path=prefix+'/'+key+('/current-build/BUILD.json' if 'actual_default_aquifer_native_guard' in p else '/build/BUILD.json')
                require(read(z,build_path)==p['actual_build'],'actual preserved build metadata rebound')
                if 'actual_default_aquifer_native_guard' in p:
                    require(p['actual_default_aquifer_native_guard'] is True and p['ten_physical_days_exact'] is True and p['four_complete_native_endpoints_exact'] is True and len(p['fabricated_receipt_refusals'])==7,'actual canonical default aquifer not preserved/guarded')
                else:require(any(v is True for k,v in p.items() if 'exact' in k),'actual prior native/source observation omitted')
    require(fulls==48 and contexts==87,'actual full/preservation count differs')
    return dict(status='OUTPUT_AQUIFER_NATIVE_RECEIPT_ADMISSION_PASS',runtime=RUNTIME,predecessor=prior,actual_full_periods=fulls,actual_bound_reports=reports,actual_preserved_contexts=contexts,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')

if __name__=='__main__':print(json.dumps(verify(),indent=2))
