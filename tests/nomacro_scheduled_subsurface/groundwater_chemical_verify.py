"""Source-bound original prescribed-groundwater CDE and native admission."""
from pathlib import Path,PureWindowsPath,PurePosixPath
import hashlib
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
BASE='a787476a0f3db2490e75ff18afea097b82476332'
RUNTIME='c1da10c37'
SEALED='PENDING'
ENTRY='tests/nomacro_scheduled_subsurface/output_thermal_verify.py'
SELF='tests/nomacro_scheduled_subsurface/groundwater_chemical_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_groundwater_chemical_verify.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('groundwater_chemical_admission',ROOT/'tests/nomacro_scheduled_subsurface/groundwater_chemical_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""


def require(condition,message):
    if not condition:raise ValueError(message)


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def sha(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
def digest(raw):return hashlib.sha256(raw).hexdigest()
def bounded(value):return type(value) in (int,float) and math.isfinite(value) and abs(value)<=1e-10
def tree(ref,path):return {line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-r',ref,'--',path).decode().splitlines()}


def raw_archive(record):
    if 'byte_parts' in record:
        chunks=[];offset=0
        for part in record['byte_parts']:
            require(part['offset']==offset and Path(part['path']).name==part['path'],'foreign groundwater archive byte part')
            raw=(ROOT/PROOF/part['path']).read_bytes()
            require(len(raw)==part['bytes'] and digest(raw)==part['sha256'],'changed groundwater archive byte part')
            chunks.append(raw);offset+=len(raw)
        raw=b''.join(chunks)
    else:raw=(ROOT/PROOF/record['archive']).read_bytes()
    require(len(raw)==record['bytes'] and digest(raw)==record['sha256'],'actual groundwater raw producer changed')
    if 'origin_artifact' in record:
        require(record['origin_artifact']['digest']=='sha256:'+digest(raw) and record['origin_artifact']['size_in_bytes']==len(raw)
                and record['actual_artifact_bytes_preserved'] is True,'actual groundwater artifact rebound')
    return raw


def validate(q):
    require((q['baseline'],q['runtime'],q['status'])==(BASE,git('rev-parse',RUNTIME).decode().strip(),'BOUNDED_PRESCRIBED_GROUNDWATER_CDE_QUALIFIED_PENDING_ADMISSION'),'foreign groundwater qualification')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['release_readiness'])==('PARTIAL','NOT_QUALIFIED','RC3_FIXED_NAMED_PROFILES_ONLY'),'whole groundwater scope promoted')
    require(q['water_guard_cm']==q['chemical_mass_guard_mg_cm2']==1e-10 and q['native_codecs']==['S5GWC001','S5GWC002']
            and q['native_domain_bytes']==72 and q['conserved_cde_prefix_offset_bytes']==48,'groundwater guards/native ownership changed')
    require(q['scope']==dict(macro=0,solute=1,bottom=1,hydraulic_family=0,hysteresis=0,snow=0,frost=0,aquifer=0,detailed_weather=0,
            original_minimum_unsaturated_compartments=5,drainage=[0,1],original_output=[False,True],
            reaction='actual original Darcy interface plus prescribed saturated-tail storage and signed sink-source-root',
            physical_equations_changed=False),'unqualified groundwater process domain')
    for group in ('source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
        for path,value in q[group].items():require(sha(ROOT/path)==value,'actual groundwater source/controller changed: '+path)
    require(q['base_consumer']['merge']==BASE and q['base_consumer']['exact_complete_tree'] is True
            and q['base_consumer']['actual_detached_owner']['returncode']==0,'actual preceding thermal canonical owner absent')
    require(q['workflows']['main']['id']==44287500505 and q['workflows']['main']['conclusion']=='success'
            and q['workflows']['preservation']['conclusion']=='success','actual groundwater workflows incomplete')
    require(q['preservation_failed_path']['id']==44288440555 and q['preservation_failed_path']['model_trajectories']==0
            and q['preservation_failed_path']['conclusion']=='failure','original groundwater preservation failure censored')
    for platform in ('Windows','Ubuntu'):require(set(q['main'][platform])=={'O0','O2'},'groundwater optimization/platform omitted')
    require(sum(q['preservation']['Windows']['profiles'].values())==95 and sum(q['preservation']['Ubuntu']['profiles'].values())==20,'prior groundwater route omitted')


def predecessor():
    old=json.loads((ROOT/PROOF/'OUTPUT_THERMAL_QUALIFICATION.json').read_text(encoding='utf8'))
    paths={ENTRY,PROOF+'OUTPUT_THERMAL_QUALIFICATION.json',*old['source_sha256'],*old['controller_sha256'],*old['frozen_predecessor_sources'],*old['frozen_predecessor_controllers']}
    for directory in ('app/hybrid_water','tools/solute','tests/nomacro_scheduled_subsurface','tests/nomacro_mixtures','reference/swap-4.3.1/patches'):
        paths|={p for p in tree(BASE,directory) if p.endswith('.py')}
    with tempfile.TemporaryDirectory(prefix='s5-groundwater-parent-') as directory:
        snapshot=Path(directory).resolve()
        with tarfile.open(fileobj=io.BytesIO(git('archive',BASE,'--',*sorted(paths)))) as archive:
            for member in archive.getmembers():
                if member.isdir():continue
                target=snapshot/member.name;require(member.isfile() and target.resolve().is_relative_to(snapshot),'foreign groundwater predecessor source')
                target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.extractfile(member).read())
        script="import importlib.util,json,pathlib;r=pathlib.Path.cwd();s=importlib.util.spec_from_file_location('literal_thermal',r/"+repr(ENTRY)+");m=importlib.util.module_from_spec(s);s.loader.exec_module(m);m.validate(json.loads((r/"+repr(PROOF+'OUTPUT_THERMAL_QUALIFICATION.json')+").read_text()));print('LITERAL_THERMAL_BASELINE_PASS')"
        result=subprocess.run([sys.executable,'-B','-c',script],cwd=snapshot,capture_output=True,text=True)
        require(result.returncode==0 and 'LITERAL_THERMAL_BASELINE_PASS' in result.stdout,'literal qualified thermal predecessor invalid: '+result.stderr)
    for record in old['archives'].values():raw_archive(record)
    return 'LITERAL_QUALIFIED_THERMAL_IMAGE_AND_ACTUAL_UNCHANGED_ARCHIVE_BYTES_PASS'


def period(report,kind,opt,phase,build,build_digest):
    days=1096 if phase=='full' else 10
    require(report['status']=='ACTUAL_PRESCRIBED_GROUNDWATER_CDE_'+phase.upper()+'_NATIVE_USER_FILES_PASS'
            and report['kind']==kind and report['optimization']==opt,'actual groundwater period/domain differs')
    require(report['functional_completion']=='PARTIAL' and report['whole_scientific_equivalence']=='NOT_QUALIFIED','producer whole groundwater scope promoted')
    require(report['trajectory']['days']==report['trajectory']['budgets']['days']==days
            and report['trajectory']['build_sha256']==build_digest,'actual groundwater period censored/build rebound')
    require(all(bounded(report['trajectory']['budgets'][k]) for k in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')),'actual groundwater budget exceeded')
    require(build['project']['water_tolerance']==1e-10 and build['identity']['lower_boundary_receipt']['effective_SWBOTB']==1
            and build['identity']['lower_boundary_receipt']['policy']=='original-prescribed-groundwater-constraint-reaction-v1'
            and build['identity']['groundwater_native_state']['domain_bytes']==72
            and build['identity']['cde_native_receipt']['policy']=='original-cde-native-stock-receipt-consistency-v1','compiled groundwater policy differs')
    windows={(2,4),(7,9)}|({(199,201),(364,367),(530,532),(1094,1096)} if phase=='full' else set())
    require({(r['start'],r['end']) for r in report['cold']}==windows,'groundwater cold/year/terminal window omitted')
    for item in report['cold']:
        require(item['exact_physical'] is item['exact_complete_native'] is item['origin_unchanged'] is True
                and all(v['exact'] is True for v in item['exact_user_output'].values()),'actual groundwater cold/native/user files differ')


def ledger(rows,days):
    require(len(rows)==days and [r['day'] for r in rows]==list(range(1,days+1)) and all(r['committed'] is True for r in rows),'actual groundwater trajectory censored')
    for row in rows:
        flow=row['external_flux_cm'];start=row['stock_start_cm'];end=row['stock_end_cm'];solute=row['solute_ledger_mg_cm2']
        require(len(flow)==16 and len(start)==len(end)==6 and len(solute)==9 and all(math.isfinite(v) for v in [*flow,*start,*end,*solute]),'actual groundwater water/chemical receipt malformed')
        water=math.fsum([*flow[:7],*(-v for v in flow[7:]),*start,*(-v for v in end)])
        chemical=math.fsum([solute[0],-row['solute_start_mg_cm2'],-solute[2],-solute[3],-solute[4],solute[5],solute[6],solute[7]])
        require(all(bounded(v) for v in (water,chemical,row['independent_residual_cm'],row['kernel_residual_cm'],
                    row['integrated_guard_residual_cm'],row['solute_independent_residual_mg_cm2'],solute[-1])),'actual independent groundwater water/chemical guard exceeded')
        require(solute[0]==row['solute_end_mg_cm2'],'actual groundwater CDE stock differs')


def native(raw,row,n,codec):
    require(raw[:8]==codec.encode(),'actual groundwater native codec differs')
    header=struct.pack('<9i',1,n,0,1,1,0,0,0,1)
    require(raw.count(header+header)==1,'actual groundwater native domain differs')
    offset=raw.index(header+header)+72;values=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset)
    require(all(math.isfinite(v) for v in values) and all(v>=0 for v in values[n:5*n+2]) and values[-1]>=0,'actual groundwater hydraulic carry invalid')
    require(list(values[:n])==row['pressure_head_cm'] and values[-2]==row['groundwater_cm'] and values[-1]==row['stock_end_cm'][0],
            'actual groundwater native carry differs from physical receipt')
    require(struct.unpack_from('<d',raw,48+8*(n+1))[0]==row['solute_end_mg_cm2'],'actual groundwater native CDE stock differs')


def verify():
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty groundwater admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'groundwater production differs from actual qualified source')
    q=json.loads((ROOT/PROOF/'GROUNDWATER_CHEMICAL_QUALIFICATION.json').read_text(encoding='utf8'));validate(q)
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==set(q['source_sha256']),'unqualified groundwater production surface')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'immutable groundwater/predecessor evidence changed: '+path)
    docs={'docs/science/NOMACRO_PRESCRIBED_GROUNDWATER_CHEMICAL_20261118.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,*docs,PROOF+'GROUNDWATER_CHEMICAL_MERGE_RECEIPT.json'},'unqualified groundwater post-seal change')
    require((ROOT/ENTRY).read_text().replace(HOOK,'',1).encode()==blob(BASE,ENTRY).replace(b'\r\n',b'\n'),'literal predecessor thermal owner body changed')
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'actual groundwater model producer source differs')
    for workflow in q['workflows'].values():
        require(workflow['merge'] is False and set(git('diff','--name-only',workflow['runtime'],workflow['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'groundwater carrier changes model source')
    prior=predecessor();archives={};fulls=0;reports=0;cold_windows=0
    for key,record in q['archives'].items():
        z=zipfile.ZipFile(io.BytesIO(raw_archive(record)));require(set(z.namelist())==set(record['members']),'actual groundwater raw member omitted')
        for name,value in record['members'].items():require(digest(z.read(name))==value,'actual groundwater producer member changed')
        archives[key]=z
    def read(z,path):
        nonlocal reports
        reports+=1;return json.loads(z.read(path))
    sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'));from groundwater_chemical_ci import CASES
    require(len(CASES)==8 and sum(c[3] for c in CASES.values())==7,'qualified groundwater cohort changed')
    for platform,opts in q['main'].items():
        for opt,location in opts.items():
            z=archives[location['archive']];run=read(z,location['prefix']+'RESULT.json')
            require(run['status']=='EIGHT_GROUNDWATER_CDE_SHORT_SEVEN_FULL_AND_THREE_NATIVE_TRANSACTION_CONTEXTS_PASS'
                    and set(run['cases'])==set(CASES) and set(run['controls'])=={'crossing-csv3','crossing-default','crossing-sorption-decay'},'actual groundwater matrix incomplete')
            def path(original):
                if platform=='Windows':return PureWindowsPath(original).relative_to(PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/'
                base=PurePosixPath(run['cases']['within-csv3']['short_root']).parent
                return str(PurePosixPath(original).relative_to(base))+'/'
            physical={}
            for key,case in CASES.items():
                item=run['cases'][key];sp=path(item['short_root']);bp=path(item['build_root'])
                raw=z.read(bp+'BUILD.json');build=json.loads(raw);build_digest=digest(raw);reports+=1
                for source in ('mod_prescribed_groundwater_reaction.f90','groundwater_native_state.f90'):
                    canonical='src/process/'+source if source.startswith('mod_') else 'app/hybrid_water/'+source
                    require(digest(z.read(bp+source).replace(b'\r\n',b'\n'))==q['source_sha256'][canonical],'actual compiled groundwater component differs')
                for phase in ('short','full'):
                    if phase=='full' and not case[3]:continue
                    prefix=sp if phase=='short' else path(item['full_root']);report=read(z,prefix+'RESULT.json')
                    require(report==item[phase],'actual groundwater period producer rebound');period(report,case[0],opt,phase,build,build_digest)
                    days=10 if phase=='short' else 1096
                    rows=[json.loads(line) for line in z.read(prefix+'trajectory/daily.jsonl').splitlines()];ledger(rows,days)
                    if phase=='full':fulls+=1
                    else:physical[key]=[{k:v for k,v in r.items() if k not in ('column','revision')} for r in rows]
                    for window in report['cold']:
                        start,end=window['start'],window['end'];cold_windows+=1
                        actual=[json.loads(line) for line in z.read(prefix+f'own-{start}/daily.jsonl').splitlines()]
                        require([{k:v for k,v in r.items() if k not in ('column','revision')} for r in actual]==[{k:v for k,v in r.items() if k not in ('column','revision')} for r in rows[start:end]],'actual groundwater cold physical rows differ')
                        with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'trajectory/accepted-column-1-day-{end}.zip'))) as warm,zipfile.ZipFile(io.BytesIO(z.read(prefix+f'own-{start}/accepted-column-1-day-{end}.zip'))) as cold:
                            for member in ('result.end','macro.bin'):require(warm.read(member)==cold.read(member),'actual groundwater complete cold native differs')
                            native(warm.read('macro.bin'),rows[end-1],build['project']['nodes'],build['identity']['groundwater_native_state']['magic'])
                    if key=='crossing-boundaries':
                        require(bounded(rows[0]['solute_ledger_mg_cm2'][3]-48.),'actual groundwater first-day source ignored')
                        if phase=='full':require(bounded(rows[-1]['solute_ledger_mg_cm2'][3]-72.),'actual groundwater true terminal source ignored')
                    if key=='crossing-sorption-decay':require(sum(r['solute_ledger_mg_cm2'][6] for r in rows)>0,'actual groundwater decomposition omitted')
            require(physical['crossing-csv0']==physical['crossing-csv3'],'output format changes groundwater physics')
            require(min(r['bottom_outward_cm'] for r in physical['crossing-csv3'])<0<max(r['bottom_outward_cm'] for r in physical['crossing-csv3']),
                    'actual groundwater signed crossing exchange omitted')
            for key,item in run['controls'].items():
                control=read(z,path(item['root'])+'RESULT.json');require(control==item['report'],'actual groundwater controls rebound')
                require(control['status']=='PRESCRIBED_GROUNDWATER_ACTUAL_NATIVE_ACTIVE_AND_REPORTED_REFUSALS_PASS'
                        and len(control['native_refusals'])==(29 if key=='crossing-default' else 31)
                        and all(c['status']=='REFUSED' for c in control['native_refusals']),'actual groundwater native refusal omitted')
                active=control['transactions']
                require(all(active[k] is True for k in ('discard_no_day_advance','replay_exact','accept_exact','recovered_next_day_exact','origin_unchanged'))
                        and active['actual_active_source_mg_cm2']>0 and len(active['reported_refusals'])==2
                        and all(r['status']=='REFUSED_BEFORE_PREPARE' for r in active['reported_refusals']),'actual groundwater transactions/receipt binding omitted')
    contexts=0
    for platform,location in q['preservation'].items():
        z=archives[location['archive']]
        for prefix,count in location['profiles'].items():
            report=read(z,prefix+'/RESULT.json');require(any(word in report['status'] for word in ('PASS','PRESERVED')) and len(report['profiles'])==count,'actual preserved groundwater context omitted');contexts+=count
            for key,item in report['profiles'].items():
                require(read(z,prefix+'/'+key+'/build/BUILD.json')==item['actual_build'],'actual preserved groundwater build rebound')
                require(any(value is True for name,value in item.items() if 'exact' in name),'actual preserved groundwater source/native result omitted')
    for location in q['context']:
        z=archives[location['archive']]
        for key,count in (('public',3),('reader',6)):
            report=read(z,location[key]+'/RESULT.json');require('PASS' in report['status'] and len(report['profiles'] if key=='public' else report['reader_refusals'])==count,'actual groundwater public/input gate omitted')
            if key=='reader':require(len(report['descriptor_refusals'])==7 and len(report['policy_refusals'])==12,'actual groundwater unsupported scope/policy accepted')
    require(fulls==28 and contexts==115 and cold_windows==232,'actual groundwater full/native/preservation denominator differs')
    return dict(status='PRESCRIBED_GROUNDWATER_CDE_NATIVE_RECEIPT_ADMISSION_PASS',runtime=git('rev-parse',RUNTIME).decode().strip(),predecessor=prior,
                actual_full_periods=fulls,actual_bound_reports=reports,actual_cold_windows=cold_windows,actual_preserved_contexts=contexts,
                functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')


if __name__=='__main__':print(json.dumps(verify(),indent=2))
