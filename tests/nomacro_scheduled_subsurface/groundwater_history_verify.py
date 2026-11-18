"""Actual source, complete native and conserved ledger admission for groundwater histories."""
from pathlib import Path,PureWindowsPath,PurePosixPath
import hashlib,io,json,math,struct,subprocess,sys,tarfile,tempfile,zipfile

ROOT=Path(__file__).resolve().parents[2]
PROOF='integration/f-ci/nomacro-complete01/'
BASE='c40636910a986feea35f19726af1aa6a68083011'
RUNTIME='27815211325bacfa4c2e9b3747a2734dfcdbc8e5'
SEALED='PENDING_HISTORY_SEAL'
ENTRY='tests/nomacro_scheduled_subsurface/groundwater_chemical_verify.py'
SELF='tests/nomacro_scheduled_subsurface/groundwater_history_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_groundwater_history_verify.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('groundwater_history_admission',ROOT/'tests/nomacro_scheduled_subsurface/groundwater_history_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
CODECS=['S5GHC001','S5GHC002','S5GHC003','S5GHC004','S5GTC001','S5GTC002','S5GTC003','S5GTC004','S5GTC005','S5GTC006']
SCOPE=dict(macro=0,solute=1,bottom=1,hydraulic_family=0,hysteresis=[0,1,2],snow=[0,1],at_least_one_history=True,
           frost=0,aquifer=0,detailed_weather=0,original_minimum_unsaturated_compartments=5,drainage=[0,1],
           original_output=[False,True],physical_equations_changed=False,hydraulic_carry='5*N+4; exact original-owned consistency witness for hysteresis1/2')

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
            require(part['offset']==offset and Path(part['path']).name==part['path'],'foreign history archive part')
            raw=(ROOT/PROOF/part['path']).read_bytes()
            require(len(raw)==part['bytes'] and digest(raw)==part['sha256'],'changed history archive part')
            chunks.append(raw);offset+=len(raw)
        raw=b''.join(chunks)
    else:raw=(ROOT/PROOF/record['archive']).read_bytes()
    require(len(raw)==record['bytes'] and digest(raw)==record['sha256'],'actual history archive changed')
    if 'origin_artifact' in record:
        require(record['origin_artifact']['digest']=='sha256:'+digest(raw) and record['origin_artifact']['size_in_bytes']==len(raw)
                and record['actual_artifact_bytes_preserved'] is True,'history artifact rebound')
    return raw

def validate(q):
    require((q['baseline'],q['runtime'],q['status'])==(BASE,RUNTIME,'BOUNDED_GROUNDWATER_HISTORY_QUALIFIED_PENDING_ADMISSION'),'foreign history qualification')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['release_readiness'])==('PARTIAL','NOT_QUALIFIED','RC3_FIXED_NAMED_PROFILES_ONLY'),'whole history scope promoted')
    require(q['water_guard_cm']==q['chemical_mass_guard_mg_cm2']==1e-10 and q['native_codecs']==CODECS
            and q['native_domain_bytes']==104 and q['conserved_cde_prefix_offset_bytes']==48 and q['scope']==SCOPE,'history native/process/guard scope changed')
    for group in ('source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
        for path,value in q[group].items():require(sha(ROOT/path)==value,'actual history source/controller changed: '+path)
    require(q['base_consumer']['merge']==BASE and q['base_consumer']['exact_complete_tree'] is True
            and q['base_consumer']['actual_detached_owner']['returncode']==0,'actual groundwater predecessor canonical owner absent')
    require(q['workflows']['main']['id']==44302590106 and q['workflows']['main']['conclusion']=='success'
            and q['workflows']['preservation']['conclusion']=='success'
            and q['workflows']['failed_preservation']['id']==44305221327 and q['workflows']['failed_preservation']['conclusion']=='failure','actual history workflows incomplete/failure censored')
    require(set(q['main'])=={'Windows','Ubuntu'} and all(set(opts)=={'O0','O2'} for opts in q['main'].values()),'history platform/optimization omitted')
    require(q['preservation']['Windows']['profiles']=={'groundwater-history-preserve-ordinary-O0-v1':5,'groundwater-history-preserve-ordinary-O2-v1':5,
        'groundwater-history-preserve-thermal-O0-v1':4,'groundwater-history-preserve-thermal-O2-v1':4,'groundwater-history-preserve-young-named-v1':11}
        and q['preservation']['Ubuntu']['profiles']=={'ordinary':5,'current-age':6,'direct-age':6,'aquifer':4},'scoped history preservation omitted')

def predecessor():
    old=json.loads((ROOT/PROOF/'GROUNDWATER_CHEMICAL_QUALIFICATION.json').read_text(encoding='utf8'))
    paths={ENTRY,PROOF+'GROUNDWATER_CHEMICAL_QUALIFICATION.json',*old['source_sha256'],*old['controller_sha256'],*old['frozen_predecessor_sources'],*old['frozen_predecessor_controllers']}
    # Literal predecessor uses real git rev-parse. Supply real object alternates;
    # archive bounded batches to respect Windows command-line limits.
    with tempfile.TemporaryDirectory(prefix='s5-history-parent-') as directory:
        snapshot=Path(directory).resolve();batches=[];batch=[];length=0
        for path in sorted(paths):
            if length+len(path)>12000:batches.append(batch);batch=[];length=0
            batch.append(path);length+=len(path)+3
        if batch:batches.append(batch)
        for batch in batches:
            with tarfile.open(fileobj=io.BytesIO(git('archive',BASE,'--',*batch))) as archive:
                for member in archive.getmembers():
                    if member.isdir():continue
                    target=snapshot/member.name;require(member.isfile() and target.resolve().is_relative_to(snapshot),'foreign history predecessor archive')
                    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.extractfile(member).read())
        subprocess.run(['git','init','--quiet',str(snapshot)],check=True,capture_output=True)
        common=Path(git('rev-parse','--git-common-dir').decode().strip())
        if not common.is_absolute():common=ROOT/common
        (snapshot/'.git/objects/info/alternates').write_text((common/'objects').resolve().as_posix()+'\n',encoding='utf8')
        script="import importlib.util,json,pathlib;r=pathlib.Path.cwd();s=importlib.util.spec_from_file_location('literal_groundwater',r/"+repr(ENTRY)+");m=importlib.util.module_from_spec(s);s.loader.exec_module(m);m.validate(json.loads((r/"+repr(PROOF+'GROUNDWATER_CHEMICAL_QUALIFICATION.json')+").read_text()));print('LITERAL_GROUNDWATER_BASELINE_PASS')"
        result=subprocess.run([sys.executable,'-B','-c',script],cwd=snapshot,capture_output=True,text=True)
        require(result.returncode==0 and 'LITERAL_GROUNDWATER_BASELINE_PASS' in result.stdout,'literal qualified groundwater predecessor invalid: '+result.stderr)
    for record in old['archives'].values():raw_archive(record)
    return 'LITERAL_QUALIFIED_GROUNDWATER_IMAGE_AND_ACTUAL_UNCHANGED_ARCHIVE_BYTES_PASS'

def period(report,case,opt,phase,build,build_digest):
    hys,snow,fmt,kind,extra,_=case;days=1096 if phase=='full' else 35
    require(report['status']=='ACTUAL_GROUNDWATER_CDE_HISTORY_'+phase.upper()+'_COMPOUND_NATIVE_USER_FILES_PASS'
        and (report['hysteresis'],report['snow'],report['format'],report['kind'],report['optimization'])==(hys,snow,fmt,kind,opt),'actual history period/domain differs')
    require(report['functional_completion']=='PARTIAL' and report['whole_scientific_equivalence']=='NOT_QUALIFIED','producer whole history scope promoted')
    require(report['trajectory']['days']==report['trajectory']['budgets']['days']==days and report['trajectory']['build_sha256']==build_digest,'actual history period censored/build rebound')
    require(all(bounded(report['trajectory']['budgets'][key]) for key in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')),'history mass guard exceeded')
    policy=build['identity']['groundwater_native_state'];n=build['project']['nodes'];original='--compatibility-output' not in extra
    def option(name,default):return int(extra[extra.index(name)+1]) if name in extra else default
    heat=option('--heat',1);drainage=option('--drainage',1);et=option('--et',0)
    codec=('S5GTC'+f'{2*hys+(1 if original else 2):03}') if snow else ('S5GHC'+f'{2*(hys-1)+(1 if original else 2):03}')
    require(policy['policy']=='original-prescribed-groundwater-complete-process-history-carry-v1'
        and policy['domain_bytes']==104 and policy['magic']==codec and policy['actual_domain']==[2,n,0,1,1,hys,snow,0,heat,2 if heat else 0,drainage,et,1]
        and report['native']==policy and build['project']['water_tolerance']==1e-10
        and build['identity']['lower_boundary_receipt']['effective_SWBOTB']==1
        and build['identity']['cde_native_receipt']['policy']=='original-cde-native-stock-receipt-consistency-v1','compiled history process policy differs')
    require(all('-'+opt in build['identity'][key] for key in ('donor_flags','kernel_flags')),'actual history optimization differs')
    windows={(2,4),(4,8),(19,23),(30,34)}|({(199,201),(364,367),(530,532),(1094,1096)} if phase=='full' else set())
    require({(r['start'],r['end']) for r in report['cold']}==windows,'history cold/year/terminal window omitted')
    for item in report['cold']:
        require(item['exact_physical'] is item['exact_complete_native'] is item['origin_unchanged'] is True
            and all(v['exact'] is True for v in item['exact_user_output'].values()),'actual history cold/native/user files differ')
    observed=report['process_observations'];require(observed['irrigation_mg_cm2']>0,'history chemical input inactive')
    if snow:require(observed['maximum_snow_cm']>0 and observed['sublimation_cm']>0,'history Snow process inactive')

def ledger(rows,days):
    require(len(rows)==days and [r['day'] for r in rows]==list(range(1,days+1)) and all(r['committed'] is True for r in rows),'actual history trajectory censored')
    for row in rows:
        flow=row['external_flux_cm'];start=row['stock_start_cm'];end=row['stock_end_cm'];solute=row['solute_ledger_mg_cm2']
        require(len(flow)==16 and len(start)==len(end)==6 and len(solute)==9 and all(math.isfinite(v) for v in [*flow,*start,*end,*solute]),'history water/chemical receipt malformed')
        water=math.fsum([*flow[:7],*(-v for v in flow[7:]),*start,*(-v for v in end)])
        chemical=math.fsum([solute[0],-row['solute_start_mg_cm2'],-solute[2],-solute[3],-solute[4],solute[5],solute[6],solute[7]])
        require(all(bounded(v) for v in (water,chemical,row['independent_residual_cm'],row['kernel_residual_cm'],row['integrated_guard_residual_cm'],row['solute_independent_residual_mg_cm2'],solute[-1])),'actual independent history water/chemical guard exceeded')
        require(solute[0]==row['solute_end_mg_cm2'],'actual history CDE stock differs')

def native(raw,row,policy):
    domain=policy['actual_domain'];n=domain[1];require(raw[:8]==policy['magic'].encode(),'history native codec differs')
    header=struct.pack('<13i',*domain);require(raw.count(header+header)==1,'history native domain differs')
    offset=raw.index(header+header)+104;size=8*(5*n+4);require(len(raw)>=offset+size,'history native truncated')
    values=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset)
    require(all(math.isfinite(v) for v in values) and all(v>=0 for v in values[n:5*n+2]) and values[-1]>=0,'history hydraulic carry invalid')
    require(list(values[:n])==row['pressure_head_cm'] and values[-2]==row['groundwater_cm'] and values[-1]==row['stock_end_cm'][0],'history native hydraulic carry differs from receipt')
    require(struct.unpack_from('<d',raw,48+8*(n+1))[0]==row['solute_end_mg_cm2'],'history native CDE stock differs')
    if domain[5]:
        block=raw[offset:offset+size];require(raw.count(block)==2 and raw.find(block)<offset,'original hydraulic owner and appended consistency witness differ')

def verify():
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty history admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'history production differs from qualified source')
    q=json.loads((ROOT/PROOF/'GROUNDWATER_HISTORY_QUALIFICATION.json').read_text(encoding='utf8'));validate(q)
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==set(q['source_sha256']),'unqualified history production surface')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'immutable history/predecessor evidence changed: '+path)
    docs={'docs/science/NOMACRO_GROUNDWATER_HISTORY_20261118.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,*docs,PROOF+'GROUNDWATER_HISTORY_MERGE_RECEIPT.json'},'unqualified history post-seal change')
    require((ROOT/ENTRY).read_text().replace(HOOK,'',1).encode()==blob(BASE,ENTRY).replace(b'\r\n',b'\n'),'literal predecessor groundwater owner body changed')
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'actual history model producer source differs')
    for workflow in q['workflows'].values():
        require(workflow['merge'] is False and set(git('diff','--name-only',workflow['runtime'],workflow['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'history carrier changes model source')
    prior=predecessor();archives={};reports=0;fulls=0;windows=0;refusals=0;report_refusals=0
    for key,record in q['archives'].items():
        z=zipfile.ZipFile(io.BytesIO(raw_archive(record)));require(set(z.namelist())==set(record['members']),'history raw member omitted')
        for name,value in record['members'].items():require(digest(z.read(name))==value,'history raw producer member changed')
        archives[key]=z
    def read(z,path):
        nonlocal reports
        reports+=1;return json.loads(z.read(path))
    sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'));from groundwater_history_ci import CASES,CONTROLS
    require(len(CASES)==16 and sum(c[-1] for c in CASES.values())==14 and len(CONTROLS)==12,'history cohort changed')
    for platform,opts in q['main'].items():
        for opt,location in opts.items():
            z=archives[location['archive']];run=read(z,location['prefix']+'RESULT.json')
            require(run['status']=='SIXTEEN_GROUNDWATER_HISTORY_SHORT_FOURTEEN_FULL_TWELVE_NATIVE_CONTEXTS_PASS'
                and set(run['cases'])==set(CASES) and set(run['controls'])==set(CONTROLS),'actual history matrix incomplete')
            def path(original):
                if platform=='Windows':return PureWindowsPath(original).relative_to(PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/'
                base=PurePosixPath(run['cases']['hys1-snow0-original']['short_root']).parent
                return str(PurePosixPath(original).relative_to(base))+'/'
            physical={};codecs=set()
            for key,case in CASES.items():
                item=run['cases'][key];bp=path(item['build_root']);raw=z.read(bp+'BUILD.json');build=json.loads(raw);bd=digest(raw);reports+=1
                policy=build['identity']['groundwater_native_state'];codecs.add(policy['magic'])
                require(digest(z.read(bp+'groundwater_history_native_state.f90').replace(b'\r\n',b'\n'))==q['source_sha256']['app/hybrid_water/groundwater_history_native_state.f90'],'actual compiled history reader differs')
                for phase in ('short','full'):
                    if phase=='full' and not case[-1]:continue
                    prefix=path(item[phase+'_root']);report=read(z,prefix+'RESULT.json');require(report==item[phase],'history period producer rebound')
                    period(report,case,opt,phase,build,bd);days=1096 if phase=='full' else 35
                    rows=[json.loads(line) for line in z.read(prefix+'trajectory/daily.jsonl').splitlines()];ledger(rows,days)
                    if phase=='full':fulls+=1
                    else:physical[key]=[{k:v for k,v in r.items() if k not in ('column','revision')} for r in rows]
                    if case[1]:require(max(r['stock_end_cm'][2] for r in rows)>0 and sum(r['external_flux_cm'][12] for r in rows)>0,'actual Snow stock/flux inactive')
                    for window in report['cold']:
                        start,end=window['start'],window['end'];windows+=1
                        actual=[json.loads(line) for line in z.read(prefix+f'own-{start}/daily.jsonl').splitlines()]
                        require([{k:v for k,v in r.items() if k not in ('column','revision')} for r in actual]==[{k:v for k,v in r.items() if k not in ('column','revision')} for r in rows[start:end]],'actual history cold physical rows differ')
                        with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'trajectory/accepted-column-1-day-{end}.zip'))) as warm,zipfile.ZipFile(io.BytesIO(z.read(prefix+f'own-{start}/accepted-column-1-day-{end}.zip'))) as cold:
                            for member in ('result.end','macro.bin'):require(warm.read(member)==cold.read(member),'actual history complete cold native differs')
                            native(warm.read('macro.bin'),rows[end-1],policy)
                    if '--source-boundaries' in case[4]:
                        require(bounded(rows[0]['solute_ledger_mg_cm2'][3]-48.),'actual history first chemical source ignored')
                        if phase=='full':require(bounded(rows[-1]['solute_ledger_mg_cm2'][3]-72.),'actual history true TEND chemical source ignored')
                    if '--chemistry' in case[4]:require(sum(r['solute_ledger_mg_cm2'][6] for r in rows)>0,'actual history decomposition omitted')
            require(codecs==set(CODECS),'actual history codec omitted')
            require(physical['hys2-snow1-original']==physical['hys2-snow1-csv0'] and physical['hys0-snow1-original']!=physical['hys2-snow1-original'],'actual history format/process activity assertion differs')
            for key,item in run['controls'].items():
                control=read(z,path(item['root'])+'RESULT.json');require(control==item['report'],'history control rebound')
                hys=CASES[key][0];original='--compatibility-output' not in CASES[key][4];count=(39 if hys else 37)-(0 if original else 3)
                require(control['status']=='GROUNDWATER_HISTORY_ACTUAL_NATIVE_ACTIVE_AND_REPORTED_REFUSALS_PASS' and len(control['native_refusals'])==count
                    and all(r['status']=='REFUSED' for r in control['native_refusals']),'history actual native refusal omitted');refusals+=count
                if hys:
                    for attack in ('divergent-original-hydraulic-copy','divergent-appended-hydraulic-copy'):
                        checks=[r for r in control['native_refusals'] if r['attack']==attack]
                        require(len(checks)==1 and 'Inconsistent groundwater history hydraulic witness' in checks[0]['diagnostic'],'actual hydraulic authority witness refusal omitted')
                active=control['transactions']
                require(all(active[k] is True for k in ('discard_no_day_advance','replay_exact','accept_exact','recovered_next_day_exact','origin_unchanged'))
                    and active['actual_active_source_mg_cm2']>0 and len(active['reported_refusals'])==2 and all(r['status']=='REFUSED_BEFORE_PREPARE' for r in active['reported_refusals']),'history transaction/receipt binding omitted');report_refusals+=2
    contexts=0
    for platform,location in q['preservation'].items():
        z=archives[location['archive']]
        for prefix,count in location['profiles'].items():
            report=read(z,prefix+'/RESULT.json');require(any(word in report['status'] for word in ('PASS','PRESERVED')) and len(report['profiles'])==count,'actual preserved history context omitted');contexts+=count
            for key,item in report['profiles'].items():
                require(read(z,prefix+'/'+key+'/build/BUILD.json')==item['actual_build'] and any(value is True for name,value in item.items() if 'exact' in name),'history preserved source/native/build rebound')
    for location in q['context']:
        z=archives[location['archive']]
        public=read(z,location['public']+'/RESULT.json');reader=read(z,location['reader']+'/RESULT.json')
        require('PASS' in public['status'] and len(public['profiles'])==3 and 'PASS' in reader['status'] and len(reader['reader_refusals'])==6
            and len(reader['descriptor_refusals'])==9 and len(reader['policy_refusals'])==15,'history public/original-reader/policy gate omitted')
    for location in q['components']:
        z=archives[location['archive']];component=read(z,location['native']+'/RESULT.json')
        require(component['status']=='ACTUAL_GROUNDWATER_HISTORY_NATIVE_COMPONENT_THIRTY_EIGHT_REFUSALS_PASS' and len(component['refusals'])==38
            and component['actual_fortran_wire'] is component['source_unchanged'] is True,'actual history native component omitted')
        for prefix in location['witness']:
            witness=read(z,prefix+'/RESULT.json')
            require(witness['status']=='ACTUAL_GROUNDWATER_HISTORY_DUPLICATE_NATIVE_DIAGNOSTIC_COMPLETE' and witness['published'] is False
                and witness['positive']['original_source_unchanged'] is True and witness['positive']['status']=='HYBRID_READY'
                and witness['divergent-original-copy']['status']=='REFUSED_INCONSISTENT_HYDRAULIC_WITNESS_BEFORE_READY'
                and witness['final_state_overridden_by_appended_copy'] is False,'actual corrected witness reader was not refused before ready')
        if 'before' in location:
            before=read(z,location['before']+'/RESULT.json');require(before['published'] is False and before['positive']['original_source_unchanged'] is True
                and before['divergent-original-copy']['status']=='HYBRID_READY' and before['final_state_overridden_by_appended_copy'] is True,'actual unadmitted reader defect censored')
        if 'cde' in location:
            cde=read(z,location['cde']+'/RESULT.json');probe=read(z,location['cde_probe']+'/RESULT.json')
            require(len(cde['refusals'])==19 and 'PASS' in cde['status'] and probe['published'] is False
                and probe['negative']['status']=='REFUSED_BEFORE_EXTERNAL_PREPARED_CANDIDATE','history real CDE stock gate omitted')
    failed=q['failed_preservation'];report=read(archives[failed['archive']],'ordinary/RESULT.json')
    require(report['status']=='FAILED' and "'dict' object is not callable" in report['error'] and set(report['profiles'])=={'within-csv3'},'actual preservation harness failure censored')
    require((fulls,windows,refusals,report_refusals,contexts)==(56,704,1784,96,50),'actual history science/native/preservation denominator differs')
    return dict(status='GROUNDWATER_CDE_COMPLETE_HISTORY_NATIVE_ADMISSION_PASS',runtime=RUNTIME,predecessor=prior,actual_full_periods=fulls,
        actual_cold_windows=windows,actual_native_refusals=refusals,actual_report_refusals=report_refusals,actual_preserved_contexts=contexts,
        actual_bound_reports=reports,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')

if __name__=='__main__':print(json.dumps(verify(),indent=2))
