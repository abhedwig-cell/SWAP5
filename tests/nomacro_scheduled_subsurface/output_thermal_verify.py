"""Source-bound admission for original snow/thermal output and literal old state."""
from pathlib import Path,PureWindowsPath
from functools import lru_cache
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
BASE='dcd880bbc0b6ff62fd2a28c68b080ac0811090ac'
RUNTIME='9a06bc72d5a9e3507467da36f18bbca0484c3886'
SEALED='eeb51937f4fa20887bcbd1b38d443a78ed47b129'
ENTRY='tests/nomacro_scheduled_subsurface/output_aquifer_verify.py'
SELF='tests/nomacro_scheduled_subsurface/output_thermal_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_output_thermal_verify.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('output_thermal_admission',ROOT/'tests/nomacro_scheduled_subsurface/output_thermal_verify.py')
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
            require(part['offset']==offset and Path(part['path']).name==part['path'],'foreign thermal archive byte part')
            data=(ROOT/PROOF/part['path']).read_bytes();require(len(data)==part['bytes'] and hashlib.sha256(data).hexdigest()==part['sha256'],'changed immutable thermal byte part');offset+=len(data);chunks.append(data)
        raw=b''.join(chunks)
    require(len(raw)==record['bytes'] and hashlib.sha256(raw).hexdigest()==record['sha256'],'actual thermal producer archive changed')
    if 'origin_artifact' in record:require(record['origin_artifact']['digest']=='sha256:'+record['sha256'] and record['origin_artifact']['size_in_bytes']==len(raw) and record['actual_artifact_bytes_preserved'] is True,'actual portable thermal artifact rebound')
    return raw


def validate(q):
    require((q['baseline'],q['runtime'],q['status'])==(BASE,RUNTIME,'BOUNDED_ORIGINAL_THERMAL_OUTPUT_QUALIFIED_PENDING_ADMISSION'),'foreign thermal qualification')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['release_readiness'])==('PARTIAL','NOT_QUALIFIED','RC3_FIXED_NAMED_PROFILES_ONLY'),'whole thermal scope promoted')
    require(q['water_guard_cm']==q['chemical_mass_guard_mg_cm2']==1e-10 and q['native_codecs']==['S5ITW001','S5ITC001'] and q['native_domain_bytes']==80 and q['conserved_cde_prefix_offset_bytes']==48,'thermal guards/native ownership changed')
    require(q['scope']==dict(explicit_original_output=True,macro=0,snow=1,heat=1,heat_method=2,solute=[0,1],age=False,aquifer=0,drainage=[0,1],hysteresis=[0,1,2],frost='existing bounded water free/drained only',detailed_weather=0,cadence='dense NP1/PERIOD1',formats=[0,1,2,3],snow_stock='actual MOD_snow ssnow',snow_increment_slots=[2,3,13],physical_equations_changed=False),'unqualified thermal process domain')
    for field in ('source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
        for path,digest in q[field].items():require(sha(ROOT/path)==digest,'actual thermal source/controller changed: '+path)
    require(set(q['archives'])=={'OUTPUT_THERMAL_'+s+'_RAW_ARCHIVE.json' for s in ('WINDOWS_O0','WINDOWS_O2','WINDOWS_CONTEXT','WINDOWS_PRESERVATION','UBUNTU_O0','UBUNTU_O2','UBUNTU_CONTRACTS','UBUNTU_CONTRACTS_CONTINUATION')},'actual thermal raw producer omitted')
    for platform in ('Windows','Ubuntu'):require(set(q['main'][platform])=={'O0','O2'},'thermal optimization omitted')
    require(sum(q['preservation']['Windows']['profiles'].values())==87 and sum(q['preservation']['Ubuntu']['profiles'].values())+sum(q['preservation']['Ubuntu']['additional_profiles'].values())==20,'prior thermal route omitted')
    require(q['base_consumer']['merge']==BASE and q['base_consumer']['exact_complete_tree'] is True and q['base_consumer']['actual_detached_owner']['returncode']==0,'actual preceding aquifer canonical owner missing')
    recovery=dict(original_run=44269217155,original_producer_runtime=q['workflows']['matrix']['runtime'],corrected_controller='tests/nomacro_scheduled_subsurface/output_thermal_ci.py',only_changes=[['(4,8,23,34,35,201,367,532,1096)','(4,8,23,34,201,367,532,1096)'],['nine_complete_native_endpoints_exact','eight_complete_native_endpoints_exact']],actual_full_periods_per_optimization=14,actual_short_periods_per_optimization=17,actual_native_contexts_per_optimization=8,actual_unchanged_members_per_optimization=16388,revalidation_model_executions=0,old_artifact_bytes_unchanged=True,old_build_or_checkpoint_metadata_rebound=False)
    require(q['matrix_recovery']==recovery,'unqualified or rebound thermal matrix recovery')
    require(set(q['workflows'])=={'matrix','contracts','continuation'} and q['workflows']['continuation']['conclusion']=='success' and all(w['merge'] is False for w in q['workflows'].values()),'thermal actual continuation not terminal')
    for key,run,conclusion in [('matrix',44269217155,'failure: final harness requested unpublished full day35 only'),('contracts',44271536975,'failure: all revalidation/public/reader/16prior passed; final four-context command lacked optimization before model work'),('continuation',44272937180,'success')]:
        require(q['workflows'][key]['id']==run and q['workflows'][key]['conclusion']==conclusion,'actual workflow conclusion promoted/foreign')
    for suffix,key in [('UBUNTU_O0','matrix'),('UBUNTU_O2','matrix'),('UBUNTU_CONTRACTS','contracts'),('UBUNTU_CONTRACTS_CONTINUATION','continuation')]:
        record=q['archives']['OUTPUT_THERMAL_'+suffix+'_RAW_ARCHIVE.json'];workflow=q['workflows'][key]
        require(record['workflow_run']==workflow['id'] and record['carrier']==workflow['carrier'] and record['workflow_conclusion']==('success' if key=='continuation' else 'failure'),'actual portable artifact workflow provenance changed')



def predecessor():
    old=json.loads((ROOT/PROOF/'OUTPUT_AQUIFER_QUALIFICATION.json').read_text())
    paths={ENTRY,PROOF+'OUTPUT_AQUIFER_QUALIFICATION.json',*old['source_sha256'],*old['controller_sha256'],*old['frozen_predecessor_sources'],*old['frozen_predecessor_controllers']}
    for directory in ('app/hybrid_water','tools/solute','tests/nomacro_scheduled_subsurface','tests/nomacro_mixtures','reference/swap-4.3.1/patches'):
        paths|={p for p in tree(BASE,directory) if p.endswith('.py')}
    for path,digest in old['source_sha256'].items():require(hashlib.sha256(blob(BASE,path).replace(b'\r\n',b'\n')).hexdigest()==digest,'qualified literal aquifer source changed')
    with tempfile.TemporaryDirectory(prefix='s5-output-thermal-parent-') as directory:
        snapshot=Path(directory).resolve();data=git('archive',BASE,'--',*sorted(paths))
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            for member in archive.getmembers():
                if member.isdir():continue
                target=snapshot/member.name;require(member.isfile() and target.resolve().is_relative_to(snapshot),'foreign predecessor thermal source member');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.extractfile(member).read())
        script="import importlib.util,json,pathlib;root=pathlib.Path.cwd();spec=importlib.util.spec_from_file_location('qualified_aquifer_output',root/"+repr(ENTRY)+");m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.validate(json.loads((root/"+repr(PROOF+'OUTPUT_AQUIFER_QUALIFICATION.json')+").read_text()));print('LITERAL_AQUIFER_BASELINE_PASS')"
        p=subprocess.run([sys.executable,'-B','-c',script],cwd=snapshot,text=True,capture_output=True);require(p.returncode==0 and 'LITERAL_AQUIFER_BASELINE_PASS' in p.stdout,'literal qualified aquifer predecessor invalid: '+p.stderr)
    for r in old['archives'].values():raw_archive(r)
    return 'LITERAL_QUALIFIED_AQUIFER_IMAGE_AND_ACTUAL_UNCHANGED_ARCHIVE_BYTES_PASS'


def period(report,case,opt,phase,build,digest):
    days=1096 if phase=='full' else 35
    require(report['status']=='ORIGINAL_OUTPUT_THERMAL_'+phase.upper()+'_SNOW_COMPOUND_NATIVE_USER_FILES_PASS','thermal period not qualified')
    require(tuple(report[k] for k in ('kind','output_format','groups','precision'))==case[:4] and report['optimization']==opt,'actual thermal selected domain differs')
    require((report['functional_completion'],report['whole_scientific_equivalence'])==('PARTIAL','NOT_QUALIFIED'),'producer whole thermal scope promoted')
    require(report['trajectory']['days']==report['trajectory']['budgets']['days']==days and report['trajectory']['build_sha256']==digest,'thermal period censored/build rebound')
    require(all(bounded(report['trajectory']['budgets'][k]) for k in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')),'actual thermal budget guard exceeded')
    require(report['output']==build['identity']['original_output'] and report['output']['native_codec']==('S5ITC001' if case[0].startswith('chemical') else 'S5ITW001'),'compiled thermal output policy differs')
    require(report['output']['physical_equations_changed'] is False and report['output']['native_domain_bytes']==80 and report['output']['snow_stock']=='actual MOD_snow ssnow' and report['output']['snow_increment_slots']==[2,3,13],'actual snow stock/flux owner differs')
    require(build['project']['nodes']==34 and build['project']['water_tolerance']==1e-10,'compiled thermal physical shape/guard differs')
    require(report['snow_observation']['maximum_stock_cm']>0 and report['snow_observation']['sublimation_cm']>0 and all(math.isfinite(v) and v>=0 for v in report['snow_observation'].values()),'active actual snow omitted/nonfinite')
    windows={(2,4),(4,8),(19,23),(30,34)}|({(199,201),(364,367),(530,532),(1094,1096)} if phase=='full' else set())
    require(len(report['own'])==len(windows) and {(w['start'],w['end']) for w in report['own']}==windows,'thermal cold window omitted')
    for w in report['own']:require(all(w[k] is True for k in ('exact_physical','exact_complete_native','origin_unchanged')) and (case[1]==0 or bool(w['exact_user_output'])) and all(v['exact'] is True for v in w['exact_user_output'].values()),'thermal cold physical/native/user output differs')
    require(set(report['native_domains'])=={'2','4','8',str(days)},'actual thermal domain observation omitted')
    for d in report['native_domains'].values():require(d['bytes']==80 and d['actual_domain'] is True and d['thermal_history']=='literalcompleteheacon/heacap/tetop/tebot' and d['placement']=='aftercompletephysicalbeforecalendar','actual thermal native history/domain differs')
    if case[0] in ('chemical-snow-point','chemical-snow-interval'):require(all(abs(a-b)<=1e-10 for a,b in zip(report['actual_irrigation_mg_cm2'],(48.,72.))),'actual chemical snow source differs')


def verify():
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty thermal admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'thermal production differs from qualified actual source')
    q=json.loads((ROOT/PROOF/'OUTPUT_THERMAL_QUALIFICATION.json').read_text());validate(q)
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==set(q['source_sha256']),'unqualified thermal production surface')
    current=tree('HEAD','integration');mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')}
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'immutable thermal/predecessor evidence changed: '+path)
    docs={'docs/science/NOMACRO_ORIGINAL_OUTPUT_THERMAL_20261118.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,*docs,PROOF+'OUTPUT_THERMAL_MERGE_RECEIPT.json'},'unqualified thermal post-seal change')
    require((ROOT/ENTRY).read_text().replace(HOOK,'',1).encode()==blob(BASE,ENTRY).replace(b'\r\n',b'\n'),'literal predecessor aquifer owner body changed')
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'actual thermal model producer source differs')
    for w in q['workflows'].values():require(set(git('diff','--name-only',w['runtime'],w['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'thermal carrier changes science')
    repaired=blob(q['matrix_recovery']['original_producer_runtime'],q['matrix_recovery']['corrected_controller']).decode()
    for old,new in q['matrix_recovery']['only_changes']:require(repaired.count(old)==1,'foreign original thermal harness');repaired=repaired.replace(old,new,1)
    require(repaired==(ROOT/q['matrix_recovery']['corrected_controller']).read_text(),'thermal correction changes model execution beyond actual endpoint comparison')
    prior=predecessor();sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'));from output_thermal_ci import CASES,CONTROLS
    require(len(CASES)==17 and sum(c[4] for c in CASES.values())==14 and len(CONTROLS)==8,'qualified thermal cohort changed')
    archives={};reports=0;fulls=0
    for name,record in q['archives'].items():
        z=zipfile.ZipFile(io.BytesIO(raw_archive(record)));require(set(z.namelist())==set(record['members']),'actual thermal raw member omitted')
        for path,digest in record['members'].items():require(hashlib.sha256(z.read(path)).hexdigest()==digest,'actual thermal raw producer member changed')
        archives[name]=z
    def read(z,path):
        nonlocal reports
        reports+=1;return json.loads(z.read(path))
    for platform,opts in q['main'].items():
        for opt,location in opts.items():
            z=archives[location['archive']];prefix=location['prefix'];original=read(z,prefix+'RESULT.json');run=original
            if platform=='Ubuntu':
                rz=archives[location['revalidation_archive']];rp=location['revalidation_prefix'];receipt=read(rz,rp+'RESULT.json');old_bytes=z.read('RESULT.json');new_bytes=rz.read(rp+'REVALIDATED_MATRIX_RESULT.json');run=json.loads(new_bytes)
                require(original['status']=='FAILED' and original['error']=="FileNotFoundError(2, 'No such file or directory')" and original['format_independence']=={},'unknown portable thermal failure')
                require(rz.read(rp+'ORIGINAL_MATRIX_RESULT.json')==old_bytes and hashlib.sha256(old_bytes).hexdigest()==receipt['original_matrix_result_sha256'] and hashlib.sha256(new_bytes).hexdigest()==receipt['revalidated_matrix_result_sha256'],'portable thermal matrix receipt rebound')
                expected={p:d for p,d in q['archives'][location['archive']]['members'].items() if p not in ('RESULT.json','PROVIDER.json')}
                require(receipt['status']=='ACTUAL_COMPLETE_THERMAL_MATRIX_READ_ONLY_FORMAT_REVALIDATION_PASS' and receipt['model_executions']==0 and receipt['actual_unchanged_member_count']==16388 and receipt['actual_unchanged_members']==expected and receipt['individual_builds_sources_days_native_and_reports_unchanged'] is True,'actual portable models/build/native bytes changed or rerun')
                require(run['cases']==original['cases'] and run['controls']==original['controls'] and run['source_commit']==original['source_commit']==receipt['actual_model_source_commit'],'actual portable model reports rebound')
            require(run['status']=='SEVENTEEN_THERMAL_OUTPUT_SHORT_AND_FOURTEEN_FULL_SNOW_NATIVE_USER_FILES_PASS' and set(run['cases'])==set(CASES) and set(run['controls'])==set(CONTROLS),'actual thermal matrix incomplete')
            physical={};natives={}
            for key,case in CASES.items():
                item=run['cases'][key];sp=prefix+'short-'+key+'/'
                if platform=='Windows':sp=PureWindowsPath(item['short_root']).relative_to(PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/'
                build_bytes=z.read(sp+'build/BUILD.json');build=json.loads(build_bytes);digest=hashlib.sha256(build_bytes).hexdigest();reports+=1
                require(build['identity']['original_output']['source_sha256']==q['source_sha256']['app/hybrid_water/original_output_thermal.py'] and build['identity']['original_output']['domain_source_sha256']==q['source_sha256']['app/hybrid_water/original_output_thermal_domain.f90'],'actual compiled thermal source policy rebound')
                require(read(z,sp+'RESULT.json')==item['short'],'actual thermal short producer rebound');period(item['short'],case,opt,'short',build,digest)
                if not case[4]:continue
                fulls+=1;fp=prefix+'full-'+key+'/';report=read(z,fp+'RESULT.json');require(report==item['full'],'actual thermal full producer rebound');period(report,case,opt,'full',build,digest)
                rows=[json.loads(s) for s in z.read(fp+'trajectory/daily.jsonl').splitlines()];require(len(rows)==1096 and [r['day'] for r in rows]==list(range(1,1097)) and all(r['committed'] is True for r in rows),'actual thermal full period censored')
                for row in rows:
                    flow=row['external_flux_cm'];start=row['stock_start_cm'];end=row['stock_end_cm'];require(len(flow)==16 and len(start)==len(end)==6 and all(math.isfinite(v) for v in [*flow,*start,*end]),'actual snow water receipt shape/nonfinite')
                    water=math.fsum([*flow[:7],*(-v for v in flow[7:]),*start,*(-v for v in end)])
                    require(bounded(abs(water)) and bounded(abs(row['independent_residual_cm'])) and bounded(abs(row['kernel_residual_cm'])),'actual thermal water guard exceeded')
                    if 'integrated_guard_residual_cm' in row:require(bounded(abs(row['integrated_guard_residual_cm'])),'actual original thermal Integral guard exceeded')
                    if case[0].startswith('chemical'):
                        solute=row['solute_ledger_mg_cm2'];require(len(solute)==9 and all(math.isfinite(v) for v in solute),'actual snow chemical receipt shape/nonfinite')
                        end_solute,delta,rain,irrig,bottom,drain,decay,root,reported=solute;chemical=math.fsum([end_solute,-row['solute_start_mg_cm2'],-rain,-irrig,-bottom,drain,decay,root])
                        require(chemical==row['solute_independent_residual_mg_cm2'] and bounded(abs(chemical)) and bounded(abs(reported)) and end_solute==row['solute_end_mg_cm2'],'actual snow CDE stock/guard differs')
                observed=dict(maximum_stock_cm=max(r['stock_end_cm'][2] for r in rows),snow_rain_cm=sum(r['external_flux_cm'][1] for r in rows),gross_snow_cm=sum(r['external_flux_cm'][2] for r in rows),sublimation_cm=sum(r['external_flux_cm'][12] for r in rows))
                require(observed==report['snow_observation'],'actual original snow stock/increments differ')
                physical[key]=hashlib.sha256(json.dumps([{k:v for k,v in r.items() if k not in ('column','revision')} for r in rows],sort_keys=True).encode()).hexdigest()
                selected=report['output'];header=struct.pack('<10i',1,34,0,int(case[0].startswith('chemical')),selected['swhyst'],1,selected['swfrost'],selected['swdra'],1,2)
                for day in (4,8,23,34,201,367,532,1096):
                    with zipfile.ZipFile(io.BytesIO(z.read(fp+f'trajectory/accepted-column-1-day-{day}.zip'))) as cold:
                        raw=cold.read('macro.bin');require(raw[:8]==report['output']['native_codec'].encode() and raw.count(header+header)==1,'actual complete thermal native/domain differs')
                        if case[0].startswith('chemical'):require(struct.unpack_from('<d',raw,48+8*35)[0]==rows[day-1]['solute_end_mg_cm2'],'actual unchanged CDE physical stock prefix differs')
                        natives[key,day]=(hashlib.sha256(cold.read('result.end')).hexdigest(),hashlib.sha256(raw).hexdigest())
                for w in report['own']:
                    with zipfile.ZipFile(io.BytesIO(z.read(fp+f"trajectory/accepted-column-1-day-{w['end']}.zip"))) as warm,zipfile.ZipFile(io.BytesIO(z.read(fp+f"own-{w['start']}/accepted-column-1-day-{w['end']}.zip"))) as cold:
                        for member in ('result.end','macro.bin'):require(warm.read(member)==cold.read(member),'actual thermal cold native payload differs')
                if case[0] in ('chemical-snow-point','chemical-snow-interval'):require(abs(rows[4]['solute_ledger_mg_cm2'][3]-48.)<=1e-10 and abs(rows[6]['solute_ledger_mg_cm2'][3]-72.)<=1e-10,'actual fixed chemical snow input ignored')
            for left,right in [('water-csv0','water-csv3'),('chemical-csv0','chemical-csv3'),('frost-drained-csv0','frost-drained-csv3')]:require(physical[left]==physical[right] and all(natives[left,d]==natives[right,d] for d in (4,8,23,34,201,367,532,1096)),'output format changes actual thermal physics/native state')
            for key in CONTROLS:
                control=read(z,prefix+'controls-'+key+'/RESULT.json');require(control==run['controls'][key] and control['status']=='ORIGINAL_OUTPUT_THERMAL_ACTUAL_NATIVE_ACTIVE_AND_POLICY_REFUSALS_PASS','actual thermal controls rebound')
                require(len(control['native_refusals'])==(44 if CASES[key][0].startswith('chemical') else 39) and all(r['status']=='REFUSED' for r in control['native_refusals']) and len(control['policy_refusals'])==12 and all(r['status']=='REFUSED' for r in control['policy_refusals']) and all(v is True for v in control['transactions'].values()),'actual thermal rejection/transaction omitted')
    for platform,location in q['context'].items():
        z=archives[location['archive']]
        for key,count in [('public',3),('reader',6)]:
            report=read(z,location[key]+'/RESULT.json');require('PASS' in report['status'] and len(report['profiles'] if key=='public' else report['reader_refusals'])==count,'actual thermal public/reader contract omitted')
            if key=='reader':require(len(report['descriptor_refusals'])==9,'unsupported thermal cadence/process scope not refused')
        bz=archives[location.get('boundary_archive',location['archive'])];report=read(bz,location['boundary']+'/RESULT.json');require('PASS' in report['status'] and set(report['profiles'])=={'O0','O2'},'actual true terminal chemical snow source omitted')
        for p in report['profiles'].values():require(abs(p['first_day_source_mg_cm2']-48.)<=1e-10 and abs(p['terminal_day_source_mg_cm2']-72.)<=1e-10 and abs(p['total_source_mg_cm2']-120.)<=1e-10 and len(p['own'])==3,'actual terminal chemical snow source differs')
    contexts=0
    for platform,location in q['preservation'].items():
        pools=[(location['archive'],location['profiles'])]
        if 'additional_archive' in location:pools.append((location['additional_archive'],location['additional_profiles']))
        for archive,profiles in pools:
            z=archives[archive]
            for prefix,count in profiles.items():
                report=read(z,prefix+'/RESULT.json');require(any(s in report['status'] for s in ('PASS','PRESERVED')) and len(report['profiles'])==count,'actual prior thermal route omitted');contexts+=count
                for key,p in report['profiles'].items():
                    require(read(z,prefix+'/'+key+'/build/BUILD.json')==p['actual_build'],'actual preserved thermal build rebound')
                    require(any(v is True for k,v in p.items() if 'exact' in k),'actual preserved source/native observation omitted')
                    if 'fabricated_receipt_refusals' in p:require(len(p['fabricated_receipt_refusals'])==7 and all('REFUSED' in r['status'] for r in p['fabricated_receipt_refusals']) and all(v is True for v in p['transactions'].values()),'actual prior aquifer receipt guard changed')
    z=archives[q['baseline_comparisons']['archive']]
    for opt,prefix in q['baseline_comparisons']['prefixes'].items():
        report=read(z,prefix+'/RESULT.json');require(report['status']=='FOUR_ACTUAL_CANONICAL_THERMAL_PHYSICAL_NATIVE_RESET0_CONTEXTS_PASS' and report['baseline']==BASE and set(report['profiles'])=={'water-snow','water-hys2','chemical-snow','water-frost-drained'},'actual preceding canonical thermal comparison omitted')
        for key,p in report['profiles'].items():
            require(read(z,prefix+'/'+key+'/current-build/BUILD.json')==p['actual_build'] and p['physical_provider_inputs_exact'] is True and p['original_integral_task3_statements_exact'] is True and all(v==0 for v in p['maximum_actual_differences'].values()) and len(p['native'])==6 and len(p['own'])==3,'actual prior physical/Integral/zero-reset source comparison differs')
            for d in p['native'].values():require(d['complete_old_physical_prefix_exact'] is True and d['result_end_exact'] is True and d['new_output_domain_offset']==d['old_complete_native_bytes'],'actual complete old thermal payload not preserved')
    completion=read(archives[q['completion']['archive']],q['completion']['path']);require(completion['status']=='ACTUAL_THERMAL_MATRIX_PUBLIC_READER_PRIOR_AND_TERMINAL_CONTRACTS_COMPLETE_PASS' and completion['read_only_matrix_model_executions']==0 and completion['portable_prior_contexts']==20,'actual portable terminal contracts not closed')
    for name,record in completion['completed_actual_contract_reports'].items():
        source=archives['OUTPUT_THERMAL_UBUNTU_CONTRACTS_CONTINUATION_RAW_ARCHIVE.json'] if name in ('aquifer-preservation','boundary') else archives['OUTPUT_THERMAL_UBUNTU_CONTRACTS_RAW_ARCHIVE.json'];raw=source.read(name+'/RESULT.json');require(hashlib.sha256(raw).hexdigest()==record['sha256'] and json.loads(raw)['status']==record['status'],'actual inherited/completed contract receipt differs')
    require(fulls==56 and contexts==107,'actual thermal full/preservation count differs')
    return dict(status='ORIGINAL_THERMAL_OUTPUT_SNOW_NATIVE_ADMISSION_PASS',runtime=RUNTIME,predecessor=prior,actual_full_periods=fulls,actual_bound_reports=reports,actual_preserved_contexts=contexts,actual_prior_canonical_thermal_contexts=8,portable_revalidation_model_executions=0,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')

if __name__=='__main__':print(json.dumps(verify(),indent=2))
