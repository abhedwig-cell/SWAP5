"""Independent source/raw admission of the bounded original implicit route.

No model execution, provider substitution or predecessor ROOT rebinding.
"""
from pathlib import Path,PureWindowsPath,PurePosixPath
import hashlib,io,json,re,struct,subprocess,sys,tarfile,tempfile,zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import implicit_conductivity_forensics as forensic
PROOF='integration/f-ci/nomacro-complete01/'
BASE='cce2561eb87e992f671d97a35baef84ddb8d91e0'
RUNTIME='5bdfcb3472a3b349d7de397573cb23be351346d6'
SEALED='b8a0dd9601c53d3bde218a37b0994c6db92c6dc7'
ENTRY='tests/nomacro_scheduled_subsurface/age_groundwater_verify.py'
SELF='tests/nomacro_scheduled_subsurface/implicit_conductivity_verify.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('implicit_conductivity_admission',ROOT/'tests/nomacro_scheduled_subsurface/implicit_conductivity_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
CASES={'water-head':(0,0,5,1,False,'explicit',3,1,True),
 'water-air-history':(0,1,8,2,True,'monthly',2,0,True),
 'water-groundwater':(0,0,1,5,False,'explicit',3,1,True),
 'water-groundwater-history':(0,2,1,2,False,'periodic',0,0,True),
 'cde-head':(1,0,5,3,True,'explicit',3,1,True),
 'cde-air-history':(1,1,8,2,False,'explicit',2,1,False),
 'cde-groundwater-history':(1,2,1,4,False,'daily',3,0,True),
 'water-head-numerical-pair':(0,0,5,2,False,'explicit',3,1,False)}
require=forensic.require
digest=lambda raw:hashlib.sha256(raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def sha(path):return digest(path.read_bytes().replace(b'\r\n',b'\n'))
def git_blob_id(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def tree(ref,path):return {line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-r',ref,'--',path).decode().splitlines()}
def read(z,name):return json.loads(z.read(name))
def rows(z,prefix):return [json.loads(line) for line in z.read(prefix+'daily.jsonl').splitlines()]
def physical(data):return [{k:v for k,v in row.items() if k not in ('column','revision')} for row in data]


def numerical_policy(raw,mean):
    require(type(mean) is int and 1<=mean<=6,'Original implicit mean domain differs')
    lines=raw.decode('cp1252').splitlines();heads=[i for i,line in enumerate(lines) if re.match(r'^\s*ORES\s+OSAT\b',line,re.I)];require(len(heads)==1,'Ambiguous actual original Mualem table');i=heads[0];names=lines[i].split('!',1)[0].upper().split();values=[]
    for line in lines[i+1:]:
        if re.match(r'^\s*\*\s*END OF TABLE',line,re.I):break
        text=line.split('!',1)[0].strip()
        if not text or text.startswith('*'):continue
        fields=[float(v.replace('d','e').replace('D','E')) for v in text.split()];require(len(fields)==len(names) and forensic.finite(fields),'Invalid actual original Mualem parameter row');row=dict(zip(names,fields));fit='KSATFIT' if 'KSATFIT' in row else 'KSAT';require(fit in row and row.get('KSATEXM',row[fit])<=row[fit],'Original unsupported examined-Ksat branch activated');values.append(row)
    require(values,'Empty actual original parameter table')
    return dict(policy='original-headcalc-implicit-mualem-exact-boundary-strict-retry-v1',SWKIMPL=1,SWKMEAN=mean,hydraulic_model=1,original_parameter_rows=values,examined_ksat_interpolation=False,physical_state_owner='existing-selected-owner',newton_failure_policy='original-implicit-nonconverged-trial-retry-v1',dtmin_retry_policy='below-input-minimum-only-after-actual-nonconvergence',clock_ulp_floor=8,boundary_jacobian_policy='original-implicit-exact-boundary-jacobian-v1',pond_event_policy='original-implicit-pond-depletion-event-v1',root_finalization_policy='original-implicit-complete-dry-end-final-root-evaluation-v2',pond_availability_policy='original-implicit-pond-evaporation-availability-v1',interception_partition_policy='original-implicit-exact-interception-partition-v1',saturation_derivative_policy='original-implicit-saturated-conductivity-derivative-v1',finite_newton_policy='original-implicit-finite-newton-rate-rollback-v1')


def raw_archive(record):
    pieces=[];offset=0
    for item in record.get('byte_parts',[dict(path=record.get('archive'),offset=0,bytes=record['bytes'],sha256=record['sha256'])]):
        require(item['path'] and Path(item['path']).name==item['path'] and item['offset']==offset,'Foreign original raw byte-part path/offset')
        raw=(ROOT/PROOF/item['path']).read_bytes();require(len(raw)==item['bytes'] and digest(raw)==item['sha256'],'Changed original raw byte part')
        if 'byte_parts' in record:require(len(raw)<=64*1024*1024,'Oversized raw byte part')
        pieces.append(raw);offset+=len(raw)
    raw=b''.join(pieces);require(len(raw)==record['bytes'] and digest(raw)==record['sha256'] and raw[:8192].count(b'\0')==record['prefix_nul_8192'],'Changed original raw archive identity')
    if 'origin_artifact' in record:require(record['origin_artifact']['digest']=='sha256:'+digest(raw) and record['origin_artifact']['size_in_bytes']==len(raw),'Original artifact bytes rebound')
    return raw


def predecessor():
    old=json.loads((ROOT/PROOF/'AGE_GROUNDWATER_QUALIFICATION.json').read_text(encoding='utf8'))
    paths={ENTRY,PROOF+'AGE_GROUNDWATER_QUALIFICATION.json',*old['source_sha256'],*old['controller_sha256'],*old['frozen_predecessor_sources'],*old['frozen_predecessor_controllers']}
    with tempfile.TemporaryDirectory(prefix='s5-implicit-literal-parent-') as folder:
        target=Path(folder).resolve();batch=[];batches=[];length=0
        for path in sorted(paths):
            if length+len(path)>12000:batches.append(batch);batch=[];length=0
            batch.append(path);length+=len(path)+3
        if batch:batches.append(batch)
        for batch in batches:
            with tarfile.open(fileobj=io.BytesIO(git('archive',BASE,'--',*batch))) as archive:
                for item in archive.getmembers():
                    if item.isdir():continue
                    path=target/item.name;require(item.isfile() and path.resolve().is_relative_to(target),'Foreign literal predecessor member');path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(archive.extractfile(item).read())
        script="import importlib.util,json,pathlib;r=pathlib.Path.cwd();s=importlib.util.spec_from_file_location('literal',r/"+repr(ENTRY)+");m=importlib.util.module_from_spec(s);s.loader.exec_module(m);m.validate(json.loads((r/"+repr(PROOF+'AGE_GROUNDWATER_QUALIFICATION.json')+").read_text(encoding='utf8')));print('LITERAL_CCE_SOURCE_PASS')"
        result=subprocess.run([sys.executable,'-B','-c',script],cwd=target,capture_output=True,text=True);require(result.returncode==0 and 'LITERAL_CCE_SOURCE_PASS' in result.stdout,'Changed literal predecessor: '+result.stderr)
    import age_groundwater_verify as prior
    for record in old['archives'].values():prior.raw_archive(record)
    return 'LITERAL_CCE_QUALIFIED_SOURCE_AND_UNCHANGED_RAW_EVIDENCE_INHERITED'


def locate(value,location):
    cls=PureWindowsPath if location['platform']=='Windows' else PurePosixPath
    return cls(value).relative_to(cls(location['producer_root'])).as_posix().rstrip('/')+'/'


def source_capsule(z,prefix):
    record=read(z,prefix+'RESULT.json');raw=z.read(prefix+record['archive'])
    require(record['status']=='ACTUAL_SOURCE_BYTES_PRESERVED_WITH_SEPARATE_GIT_AND_LF_IDENTITY' and len(raw)==record['bytes'] and digest(raw)==record['sha256'],'Changed actual producer source capsule')
    tree={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in git('ls-tree','-r',record['producer_head']).decode().splitlines()}
    with zipfile.ZipFile(io.BytesIO(raw)) as capsule:
        present={name for name,v in record['members'].items() if v.get('checkout')!='ABSENT'};require(set(capsule.namelist())==present,'Actual source capsule member omission')
        for name,item in record['members'].items():
            require(tree.get(name)==item['git_blob'],'Actual source capsule Git body rebound')
            if item.get('checkout')=='ABSENT':continue
            data=capsule.read(name);require(len(data)==item['bytes'] and digest(data)==item['sha256'] and data[:8192].count(b'\0')==item['prefix_nul_8192'],'Changed actual producer source bytes')
            require(item['git_blob'] in {git_blob_id(data),git_blob_id(data.replace(b'\r\n',b'\n'))},'Actual source body differs from its Git producer')
            if 'lf_normalized_sha256' in item:require(digest(data.replace(b'\r\n',b'\n'))==item['lf_normalized_sha256'],'Actual source LF body identity differs')
    require(not git('diff',record['producer_head'],RUNTIME,'--','app','src','reference','tools'),'Capsule model source differs from qualified model')
    return record['members']


def build_files(z,bp,ip,build,capsule,opt):
    from perstep_domain_verify import build_files as existing
    existing(z,bp,build)
    for name,value in build['inputs'].items():require(digest(z.read(ip+name))==value,'Changed actual original input')
    for name,value in build['identity']['kernel_sources']:require(capsule[name]['sha256']==value,'Actual compiled kernel source bytes differ from producer capsule')
    for field in ('donor_flags','kernel_flags'):require({'-'+opt,'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(build['identity'][field]),'Actual optimization/production arithmetic differs')
    for key,name in [('implicit_conductivity','implicit_conductivity'),('implicit_conductivity_retry','implicit_conductivity_retry'),('implicit_conductivity_jacobian','implicit_conductivity_jacobian'),('implicit_pond_event','implicit_pond_event'),('implicit_root_finalization','implicit_root_finalization'),('implicit_pond_availability','implicit_pond_availability'),('implicit_interception_partition','implicit_interception_partition'),('implicit_saturation_derivative','implicit_saturation_derivative'),('implicit_finite_newton','implicit_finite_newton')]:
        require(build['identity'][key]['source_sha256']==capsule['app/hybrid_water/'+name+'.py']['sha256'],'Actual numerical owner source bytes differ: '+key)
    require(build['identity']['implicit_root_finalization']['lookup_owner_sha256']==capsule['app/hybrid_water/micro_lookup_state.py']['sha256'],'Actual existing dry lookup owner source differs')


def actual_period(z,prefix,report,build,opt,selected,dz,phase):
    days={'short':35,'full':1096,'limit':2}[phase];require(report['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_'+phase.upper()+'_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS','Failed/censored actual period promoted')
    require(report['trajectory']['days']==report['trajectory']['budgets']['days']==days and report['parameters']['optimization']==opt and report['trajectory']['build_sha256']==digest(z.read(report['_build_prefix']+'BUILD.json')),'Actual period/build/optimization rebound')
    require(report['functional_completion']=='PARTIAL' and report['whole_scientific_equivalence']=='NOT_QUALIFIED','Whole implicit scientific scope promoted')
    data=rows(z,prefix+'trajectory/');require(len(data)==days,'Censored actual period');forensic.water(data);forensic.original_observations(z.read(prefix+'trajectory/original/donor.stdout'),data,build['project']['start_date'])
    if report['parameters']['solute']==1:
        from cde_clock_verify import ledger
        ledger(data,days)
    require(report['numerical_policy']=={k:v for k,v in build['identity']['implicit_conductivity'].items() if k!='source_sha256'},'Actual original numerical input/policy differs')
    windows={(1,2)} if phase=='limit' else {(2,4),(7,9),(30,34)}
    if phase=='full':windows|={(199,201),(364,367),(530,532),(1094,1096)}
    require({(v['start'],v['end']) for v in report['cold']}==windows,'Actual complete native cold window omitted')
    def checkpoints(pp,actual):
        for name in z.namelist():
            if name.startswith(pp+'accepted-column-1-day-') and name.endswith('.zip'):
                day=int(name.rsplit('-',1)[1][:-4]);row=next(v for v in actual if v['day']==day);forensic.general_checkpoint(z.read(name),build,row,selected,dz)
    checkpoints(prefix+'trajectory/',data)
    def outputs(pp):return {Path(name).name:forensic.output_records(z.read(name),name) for name in z.namelist() if name.startswith(pp) and '/' not in name[len(pp):] and Path(name).name in ('result_output.csv','result_output.bin')}
    def inventory(pp):return {Path(name).name for name in z.namelist() if name.startswith(pp) and '/' not in name[len(pp):] and (name.endswith('.csv') or name.endswith('_output.bin'))}
    warm_outputs=outputs(prefix+'trajectory/original/')
    for item in report['cold']:
        low,high=item['start'],item['end'];cp=prefix+f'own-{low}/';cold=rows(z,cp);require(physical(cold)==physical(data[low:high]),'Actual cold physical trajectory differs');forensic.water(cold);forensic.original_observations(z.read(cp+'original/donor.stdout'),cold,build['project']['start_date']);checkpoints(cp,cold)
        names=[prefix+f'trajectory/accepted-column-1-day-{high}.zip',cp+f'accepted-column-1-day-{high}.zip']
        with zipfile.ZipFile(io.BytesIO(z.read(names[0]))) as a,zipfile.ZipFile(io.BytesIO(z.read(names[1]))) as b:require(all(a.read(name)==b.read(name) for name in ('result.end','macro.bin')),'Complete actual cold native differs')
        require(item['exact_physical'] is item['exact_complete_native'] is item['origin_unchanged'] is True,'Actual native/physical/origin assertion differs')
        require(inventory(prefix+'trajectory/original/')==inventory(cp+'original/'),'Actual original user output file inventory differs')
        require(forensic.output_continuation(warm_outputs,outputs(cp+'original/'),selected,low,high,build['project']['start_date'])==item['exact_original_output'],'Actual original user output continuation differs')
    return len(report['cold'])


def verify():
    import importlib.util
    spec=importlib.util.spec_from_file_location('saltfarm_composition_admission',ROOT/'tests/saltfarm_newton/composition_admission.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
    require(SEALED!='PENDING_RAW_SEAL','Implicit raw qualification seal is not complete')
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'Dirty implicit admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'Unqualified implicit production source change')
    require(Path(forensic.__file__).resolve()==ROOT/'tests/nomacro_scheduled_subsurface/implicit_conductivity_forensics.py','Foreign implicit raw-evidence reader module')
    q=json.loads((ROOT/PROOF/'IMPLICIT_CONDUCTIVITY_QUALIFICATION.json').read_text(encoding='utf8'))
    require((q['baseline'],q['runtime'],q['status'])==(BASE,RUNTIME,'BOUNDED_IMPLICIT_WATER_CDE_QUALIFICATION_RECORD'),'Foreign implicit qualification scope')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['water_guard_cm']==q['chemical_mass_guard_mg_cm2']==1e-10 and q['age_admission'] is False and q['weighted_history_full_admission'] is False,'Implicit scientific/guard/blocked scope promoted')
    for group in ('source_sha256','controller_sha256'):
        require(q[group] and all(sha(ROOT/path)==value for path,value in q[group].items()),'Changed sealed implicit source/controller: '+group)
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==set(q['source_sha256']),'Unregistered implicit production change')
    mutable={PROOF+name for name in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,value in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==value,'Immutable implicit/predecessor evidence changed: '+path)
    allowed={SELF,ENTRY,'tests/nomacro_scheduled_subsurface/test_implicit_conductivity_verify.py',*mutable,PROOF+'IMPLICIT_CONDUCTIVITY_MERGE_RECEIPT.json','docs/science/NOMACRO_IMPLICIT_CONDUCTIVITY_20261119.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<=allowed,'Unqualified implicit post-seal change')
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'Actual model producer differs from qualified source')
    for value in q['workflows'].values():require(value['conclusion']=='success' and value['merge'] is False and set(git('diff','--name-only',value['runtime'],value['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'Portable carrier/source/conclusion differs')
    require((ROOT/ENTRY).read_text(encoding='utf8').count(HOOK)==1 and (ROOT/ENTRY).read_text(encoding='utf8').replace(HOOK,'',1).encode()==blob(BASE,ENTRY).replace(b'\r\n',b'\n'),'Literal predecessor body/hook differs')
    prior=predecessor();archives={}
    for key,record in q['archives'].items():
        z=zipfile.ZipFile(io.BytesIO(raw_archive(record)));require(set(z.namelist())==set(record['members']),'Original raw archive member omitted')
        for name,value in record['members'].items():require(digest(z.read(name))==value,'Changed original raw producer member')
        archives[key]=z
    return scientific(q,archives,prior)


def scientific(q,archives,prior):
    """The sealed manifest supplies locations, never physical expected values."""
    require(set(q['main'])==set(q['positive'])=={'Windows','Ubuntu'} and all(set(opts)=={'O0','O2'} for opts in q['main'].values()),'Actual platform/optimization coverage omitted')
    from age_groundwater_verify import geometry
    capsules={};contexts={};fulls=shorts=colds=native_refusals=policy_refusals=publics=limits=0
    def context(z,report,location,opt):
        bp=locate(report['build_root'],location);ip=locate(report['input_root'],location);build=read(z,bp+'BUILD.json')
        key=(location['archive'],location['capsule_prefix'])
        if key not in capsules:capsules[key]=source_capsule(z,location['capsule_prefix'])
        build_files(z,bp,ip,build,capsules[key],opt);raw=z.read(ip+'swap.swp');selected=dict(build['identity']['original_output'])
        def scalar(body,name):
            found=re.findall(rb'(?mi)^[ \t]*'+name.encode()+rb'[ \t]*=[ \t]*([^!\r\n]+)',body);require(len(found)==1,'Missing/ambiguous actual original numerical input: '+name)
            return float(found[0].strip().replace(b'd',b'e').replace(b'D',b'E'))
        for name,value in [('SWKIMPL',1),('SWSOPHY',0),('SWSNOW',0),('SWFROST',0),('SWHEA',1),('SWCALT',2),('SWBR',0),('SWMETDETAIL',0)]:require(scalar(raw,name)==value,'Unqualified actual original process input: '+name)
        for name,value in [('SWKMEAN',report['parameters']['kmean']),('SWSOLU',report['parameters']['solute']),('SWHYST',report['parameters']['hysteresis']),('SWBOTB',report['parameters']['bottom'])]:require(scalar(raw,name)==value,'Actual original reader selection differs: '+name)
        for name in ('maize.crp','potato.crp','grass.crp'):
            body=z.read(ip+name)
            for field,value in [('TOL_2',1e-10),('MYTOLX',1e-10),('TOLCONV',1e-9)]:require(scalar(body,field)==value,'Actual original scheduled crop precision differs')
        expected=numerical_policy(raw,report['parameters']['kmean']);require(report['numerical_policy']==expected and build['identity']['implicit_conductivity']==dict(expected,source_sha256=capsules[key]['app/hybrid_water/implicit_conductivity.py']['sha256']),'Actual numerical contract differs from original input and named corrections')
        for name,field in [('SWHYST','swhyst'),('SWDRA','swdra'),('SWCFBS','et')]:
            matches=re.findall(rb'(?mi)^\s*'+name.encode()+rb'\s*=\s*(\d+)',raw);require(len(matches)==1,'Ambiguous actual original selector');selected[field]=int(matches[0])
        actual=report['actual_original_numerical_inputs'];require((actual['MAXIT'],actual['MAXBACKTR'])==(100,10) and actual['scheduled_root_precisions']=={name:dict(TOL_2=1e-10,MYTOLX=1e-10,TOLCONV=1e-9) for name in ('maize.crp','potato.crp','grass.crp')},'Selected actual original numerical inputs differ')
        return bp,build,selected,geometry(raw,build['project']['nodes'])
    def period(z,pp,report,location,opt,phase):
        nonlocal fulls,shorts,colds,limits
        bp,build,selected,dz=context(z,report,location,opt);actual=read(z,pp+'RESULT.json');require(actual==report,'Actual original runtime report rebound');item=dict(report,_build_prefix=bp);colds+=actual_period(z,pp,item,build,opt,selected,dz,phase)
        if phase=='full':fulls+=1
        elif phase=='short':shorts+=1
        else:limits+=1
        return build,selected,dz
    for platform,opts in q['main'].items():
        for opt,location in opts.items():
            require(location['platform']==platform,'Actual platform location differs');z=archives[location['archive']];run=read(z,location['prefix']+'RESULT.json')
            require(run['status']=='EIGHT_IMPLICIT_WATER_CDE_SHORT_SIX_FULL_ALL_NATIVE_ACTIVE_POLICY_PASS' and set(run['cases'])==set(CASES) and run['all_selected_short_native_active_gates_precede_new_full_runs'] is True,'Actual main numerical cohort censored')
            expected_controls={name for name,case in CASES.items() if case[-1]};require(set(run['controls'])==expected_controls,'Actual native/transaction control domain omitted')
            for name,case in CASES.items():
                item=run['cases'][name];report=item['short'];p=report['parameters'];require(tuple(p[field] for field in ('solute','hysteresis','bottom','kmean','perstep','mode','format','reset'))==case[:-1],'Actual numerical case selector differs')
                for phase in ('short','full') if case[-1] else ('short',):
                    require(phase in item,'Missing selected complete period');build,selected,dz=period(z,locate(item[phase+'_root'],location),item[phase],location,opt,phase)
                contexts[platform,opt,name]=(z,item,build,selected,dz,location)
                if name not in expected_controls:continue
                control_location=run['controls'][name];cp=locate(control_location['root'],location);control=read(z,cp+'RESULT.json')
                require(control==control_location['report'] and control['status']=='IMPLICIT_CONDUCTIVITY_NUMERICAL_NATIVE_TRANSACTION_DOMAIN_PASS' and control['build_sha256']==digest(z.read(locate(item['build_root'],location)+'BUILD.json')),'Actual numerical controls rebound')
                require(len(control['native_refusals'])==(30 if name.startswith('water-groundwater') else 7) and len(control['descriptor_refusals'])==13 and all(control['transactions'].values()) and control['foreign_numerical_adoption']['status']=='REFUSED' and control['foreign_numerical_adoption']['origin_unchanged'] is True,'Actual native/domain/transaction controls omitted')
                for attack in control['native_refusals']:
                    ap=cp+'native-'+attack['attack']+'/';require(attack['status']=='REFUSED' and not any(v.startswith(ap) and Path(v).name.startswith('accepted-') for v in z.namelist()),'Corrupted actual native state published')
                    bad=z.read(ap+'origin/macro.bin');row=rows(z,locate(item['short_root'],location)+'trajectory/')[3]
                    try:forensic.general_native(bad,build,row,selected,dz)
                    except (ValueError,UnicodeError,IndexError,struct.error):pass
                    else:raise ValueError('Actual forged native independently accepted: '+name+'/'+attack['attack'])
                    native_refusals+=1
                require(all(v['status']=='REFUSED_BEFORE_WORKER' for v in control['policy_refusals']+control['numerical_owner_refusals']+control['descriptor_refusals']),'Actual policy/provider guard failure omitted');policy_refusals+=len(control['policy_refusals'])+len(control['numerical_owner_refusals'])
            require(run['actual_foreign_numerical_origin']['status']=='REFUSED' and run['actual_foreign_numerical_origin']['original_unchanged'] is True,'Actual foreign numerical origin accepted')
            location=q['positive'][platform][opt];z=archives[location['archive']];run=read(z,location['prefix']+'RESULT.json')
            require(run['status']=='THREE_POSITIVE_CHEMICAL_SHORT_TWO_FULL_IMPLICIT_CONDUCTIVITY_NATIVE_PASS' and set(run['cases'])=={'head','air-history','groundwater-history'} and run['all_new_full_runs_after_positive_short_gates'] is True,'Actual active chemistry domain censored')
            for name,item in run['cases'].items():
                require(all(item['metrics'][field]>0 for field in ('initial_stock','maximum_stock','actual_source','actual_decay')),'Inactive chemical input substituted')
                for phase in ('short','full') if name!='air-history' else ('short',):period(z,locate(item[phase+'_root'],location),item[phase],location,opt,phase)
    for location in q['limits']:
        z=archives[location['archive']];run=read(z,location['prefix']+'RESULT.json');require(run['status']=='TWO_ACTUAL_IMPLICIT_WATER_CDE_1440_NATIVE_LIMITS_PASS' and len(run['cases'])==2,'Actual maximum cadence domain censored')
        for item in run['cases'].values():
            report=item['report'];require(report['parameters']['nprintday']==1440,'Maximum cadence input changed');period(z,locate(item['root'],location),report,location,location['optimization'],'limit')
    for location in q['weighted_short']:
        z=archives[location['archive']];pp=location['prefix'];report=read(z,pp+'RESULT.json');require((report['parameters']['solute'],report['parameters']['hysteresis'],report['parameters']['kmean'])==(0,2,6),'Actual sixth mean short context substituted');period(z,pp,report,location,location['optimization'],'short')
    for location in q['public']:
        z=archives[location['archive']];run=read(z,location['prefix']+'RESULT.json');require(run['status']=='SIX_PUBLIC_IMPLICIT_WATER_CDE_COMPLETE_NATIVE_RESTART_CONTEXTS_PASS' and len(run['profiles'])==6,'Actual public contexts censored')
        for name,item in run['profiles'].items():
            old,item_source,build,selected,dz,source_location=contexts[location['platform'],location['optimization'],name];pp=location['prefix']+name+'/';warm=rows(z,pp+'warm/');cold=rows(z,pp+'cold/');original=rows(old,locate(item_source['short_root'],source_location)+'trajectory/')
            require(len(warm)==35 and physical(warm)==physical(original) and physical(cold)==physical(warm[30:34]) and item['physical_exact'] is item['complete_native_exact'] is item['origin_unchanged'] is True and item['warm']['returncode']==item['cold']['returncode']==0,'Actual public physical/native provenance differs');forensic.water(warm);forensic.water(cold)
            forensic.original_observations(z.read(pp+'warm/original/donor.stdout'),warm,build['project']['start_date']);forensic.original_observations(z.read(pp+'cold/original/donor.stdout'),cold,build['project']['start_date'])
            actual=z.read(pp+'cold/accepted-column-1-day-34.zip');forensic.general_checkpoint(actual,build,cold[-1],selected,dz)
            with zipfile.ZipFile(io.BytesIO(actual)) as a,zipfile.ZipFile(io.BytesIO(old.read(locate(item_source['short_root'],source_location)+'trajectory/accepted-column-1-day-34.zip'))) as b:require(all(a.read(v)==b.read(v) for v in ('result.end','macro.bin')),'Actual public complete native differs')
            output=lambda source:{Path(v).name:forensic.output_records(z.read(v),v) for v in z.namelist() if v.startswith(source) and '/' not in v[len(source):] and Path(v).name in ('result_output.csv','result_output.bin')}
            inventory=lambda source:{Path(v).name for v in z.namelist() if v.startswith(source) and '/' not in v[len(source):] and (v.endswith('.csv') or v.endswith('_output.bin'))}
            require(inventory(pp+'warm/original/')==inventory(pp+'cold/original/'),'Actual public output inventory differs')
            require(forensic.output_continuation(output(pp+'warm/original/'),output(pp+'cold/original/'),selected,30,34,build['project']['start_date'])==item['user_output_exact'],'Actual public user output differs');publics+=1
    check_status={'derivative':'REAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_DERIVATIVE_INTERFACE_PASS','mean':'REAL_ORIGINAL_HEADCALC_PRIVATE_MEAN_EIGHTEEN_DERIVATIVES_PASS','retry':'REAL_ORIGINAL_IMPLICIT_RETRY_SIX_CONTRACTS_THREE_REFUSALS_PASS','pond_event':'REAL_POND_EVENT_TWO_ACTUAL_THREE_INACTIVE_FIVE_REFUSALS_PASS','root':'REAL_ORIGINAL_MICRO_DISCONTINUITY_AND_CORRECTED_FINALIZATION_PASS','availability':'REAL_POND_AVAILABILITY_TWO_ACTUAL_FIVE_INACTIVE_FOUR_REFUSALS_PASS','interception':'REAL_ORIGINAL_INTERCEPTION_LOSS_AND_SEVEN_EXACT_PARTITIONS_PASS','saturation':'REAL_ORIGINAL_SATURATION_PLATEAU_DEFECT_AND_CORRECTION_SIX_INPUTS_PASS','dry_lookup':'REAL_ORIGINAL_NONHISTORY_COMPLETE_DRY_ENDPOINT_FIVE_INPUTS_PASS','age_blocker':'REPRODUCED_RETAINED_SURFACE_AGE_DRYOUT_STATE_BLOCKER_NOT_QUALIFIED','age_refusals':'THREE_ACTUAL_IMPLICIT_AGE_FRONT_DOOR_REFUSALS_EIGHT_LITERAL_WATER_CDE_BUNDLES_PASS','compatibility':'THREE_ACTUAL_IMPLICIT_CONDUCTIVITY_UNQUALIFIED_COMPATIBILITY_REFUSALS_PASS'}
    seen=set()
    for location in q['checks']:
        z=archives[location['archive']];pp=location['prefix'];kind=location['kind'];report=read(z,pp+'RESULT.json');key=(location['platform'],location['optimization'],kind);require(key not in seen and report['status']==check_status[kind],'Actual numerical/admission component omitted or substituted');seen.add(key)
        if kind=='age_refusals':
            require(len(report['refusals'])==len(report['literal_age_zero_delegations'])==3 and len(report['actual_water_cde_validations'])==8,'Actual AGE front-door/old-route coverage censored')
            for item in report['refusals']:require(item['public_returncode']!=0 and item['public_before_compilation'] is item['coupled_before_worker'] is item['origin_unchanged'] is True,'Unqualified AGE route reached worker or changed origin')
        elif kind=='compatibility':require(len(report['cases'])==3 and all(v['status']=='REFUSED_BEFORE_COMPILATION' and v['public_returncode']!=0 for v in report['cases'].values()),'Actual compatibility refusal missing')
        else:
            require(report['optimization']==location['optimization'] and report['floating_point_profile']==dict(id='gnu-x86_64-separate-ops-v1',flags=['-ffp-contract=off','-march=x86-64','-mtune=generic']),'Actual component optimization/arithmetic differs')
            capsule=capsules[location['archive'],location['capsule_prefix']]
            if 'driver_sha256' in report:require(any(item.get('sha256')==report['driver_sha256'] for name,item in capsule.items() if name.startswith('tests/nomacro_scheduled_subsurface/implicit') and name.endswith('_driver.f90')),'Actual component driver differs from its source producer')
            if 'fixture_sha256' in report:require(any(item.get('sha256')==report['fixture_sha256'] for name,item in capsule.items() if name.startswith('tests/nomacro_scheduled_subsurface/implicit') and name.endswith('_inputs.json')),'Actual component input fixture differs from its source producer')
            if 'executions' in report:
                require(len(report['executions'])==(1 if kind=='dry_lookup' else 2),'Actual original/corrected executions omitted')
                for execution in report['executions']:require(execution['returncode']==0 and digest(z.read(pp+execution['mode']+'.f90'))==execution['actual_source_sha256'] and execution['native_seconds']>0,'Actual compiled component source/execution differs')
            if kind=='age_blocker':require(report['returncode']==0 and 'ACTUAL_RETAINED_SURFACE_AGE_DRYOUT_REFUSAL_REPRODUCED' in report['stdout'],'Actual retained AGE blocker missing')
    require(seen=={(p,o,k) for p in ('Windows','Ubuntu') for o in ('O0','O2') for k in check_status},'Actual component/admission platform denominator differs')
    inherited=q['selector_zero_inheritance'];require(inherited['fresh_physical_pass_claim'] is False,'Unchanged explicit route relabelled as fresh physical PASS');z=archives[inherited['archive']];record=read(z,inherited['prefix']+inherited['aggregate']);require(record['status']=='SEVENTEEN_ACTUAL_PRIOR_SELECTOR_ZERO_DELEGATIONS_INHERIT_NO_MODEL_RUNS','Missing actual selector-zero delegation inheritance');delegations=0
    for family,item in record['families'].items():
        pp=PureWindowsPath(item['root']).relative_to(PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/';actual=read(z,pp+'RESULT.json');require(item['returncode']==0 and actual['status'].endswith('_LITERAL_DELEGATION_INHERITANCE'),'Literal old-route delegation failed')
        authority=json.loads((ROOT/PROOF/actual['qualification']).read_text(encoding='utf8'));original=authority['archives'][actual['immutable_prior_archive']]
        for value in actual['profiles'].values():
            previous=value['prior_profile_prefix']+'/';require(value['status']=='UNCHANGED_SWKIMPL0_ROUTE_INHERITS_PRIOR_QUALIFICATION' and value['model_executions']==0 and value['fresh_physical_pass_claim'] is False and value['actual_immutable_prior_member_hashes'] is True and len(value['literal_delegation'])==12,'Actual original source-zero inheritance differs')
            for name,field in [('build/BUILD.json','prior_build_sha256'),('RESULT.json','prior_report_sha256'),('trajectory/daily.jsonl','prior_daily_sha256')]:require(original['members'][previous+name]==value[field],'Actual inherited original raw member identity differs')
            delegations+=1
    require(delegations==17 and not git('diff',BASE,RUNTIME,'--','src','reference'),'Literal physical predecessors or selector-zero coverage differs')
    require((fulls,shorts,colds,limits,publics,native_refusals)==(32,48,376,8,24,352),'Actual bounded implicit period/native/public denominator differs')
    return dict(status='BOUNDED_ORIGINAL_IMPLICIT_WATER_CDE_SOURCE_RAW_NATIVE_ADMISSION_PASS',runtime=RUNTIME,predecessor=prior,actual_full_periods=fulls,actual_short_periods=shorts,actual_complete_native_cold_windows=colds,actual_limits=limits,actual_public_contexts=publics,actual_native_refusals=native_refusals,actual_policy_provider_refusals=policy_refusals,actual_original_components_and_admission_checks=len(seen),actual_prior_selector_zero_delegations=delegations,fresh_old_route_model_runs=0,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',implicit_age_admission=False,weighted_history_full_admission=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
