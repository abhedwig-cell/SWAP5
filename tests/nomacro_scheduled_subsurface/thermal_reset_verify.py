"""Source-bound actual original Snow output calendar native/ledger admission."""
from pathlib import Path,PureWindowsPath,PurePosixPath
from datetime import date,timedelta
import hashlib,io,json,math,struct,subprocess,sys,tarfile,tempfile,zipfile

ROOT=Path(__file__).resolve().parents[2]
PROOF='integration/f-ci/nomacro-complete01/'
BASE='536a178591e8f887963dcf9981521077547aeba0'
RUNTIME='b9adbefdb6b9779f0ecd3fe8c8f637101649ac8c'
SEALED='PENDING_ACTUAL_RESET_SEAL'
ENTRY='tests/nomacro_scheduled_subsurface/thermal_step_verify.py'
SELF='tests/nomacro_scheduled_subsurface/thermal_reset_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_thermal_reset_verify.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('thermal_reset_admission',ROOT/'tests/nomacro_scheduled_subsurface/thermal_reset_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
SNOW_FIELDS=['cgsnow','cmelt','csnrai','csubl','isnrai','igsnow','isubl']
SCOPE=dict(macro=0,solute=0,age=False,snow=1,heat=1,thermal_method=2,hysteresis=[0,1,2],hydraulic_family=0,
    drainage=1,lower_boundary=[5,8],frost=0,aquifer=0,detailed_weather=0,nprintday=[1],original_nprintday_domain=[1,1440],per_step=True,original_date_gate=True,
    reset=[1],calendars=['explicit-date','PERIOD0','PERIOD2..366'],formats=[0,1,2,3],et=[0,1],physical_equations_changed=False)

def require(condition,message):
    if not condition:raise ValueError(message)

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def sha(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
def digest(raw):return hashlib.sha256(raw).hexdigest()
def finite(value):return type(value) in (int,float) and math.isfinite(value)
def bounded(value):return finite(value) and abs(value)<=1e-10
def tree(ref,path):return {line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-r',ref,'--',path).decode().splitlines()}

def raw_archive(record):
    if 'byte_parts' in record:
        chunks=[];offset=0
        for part in record['byte_parts']:
            require(part['offset']==offset and Path(part['path']).name==part['path'],'foreign Snow calendar archive part')
            raw=(ROOT/PROOF/part['path']).read_bytes();require(len(raw)==part['bytes'] and digest(raw)==part['sha256'],'changed Snow calendar archive part')
            chunks.append(raw);offset+=len(raw)
        raw=b''.join(chunks)
    else:raw=(ROOT/PROOF/record['archive']).read_bytes()
    require(len(raw)==record['bytes'] and digest(raw)==record['sha256'],'actual Snow calendar raw producer changed')
    if 'origin_artifact' in record:
        require(record['origin_artifact']['digest']=='sha256:'+digest(raw) and record['origin_artifact']['size_in_bytes']==len(raw)
            and record['actual_artifact_bytes_preserved'] is True,'Snow calendar artifact rebound')
    return raw

def validate(q):
    require((q['baseline'],q['runtime'],q['status'])==(BASE,RUNTIME,'BOUNDED_ORIGINAL_SNOW_FLPRINTDT_RESET_QUALIFIED_PENDING_ADMISSION'),'foreign Snow calendar qualification')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['release_readiness'])==('PARTIAL','NOT_QUALIFIED','RC3_FIXED_NAMED_PROFILES_ONLY'),'whole Snow/calendar scope promoted')
    require(q['scope']==SCOPE and q['water_guard_cm']==q['chemical_mass_guard_mg_cm2']==1e-10
        and q['native_codec']=='S5SRW001' and q['process_domain_bytes']==80 and q['snow_domain_bytes']==32 and q['snow_value_bytes']==56
        and q['snow_fields']==SNOW_FIELDS,'Snow native/process/guard scope changed')
    for group in ('source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
        for path,value in q[group].items():require(sha(ROOT/path)==value,'actual Snow calendar source/controller changed: '+path)
    require(q['base_consumer']['merge']==BASE and q['base_consumer']['exact_complete_tree'] is True
        and q['base_consumer']['actual_detached_owner']['returncode']==0,'actual preceding groundwater-history metadata owner absent')
    require(q['workflows']['main']['id']==44364299227 and q['workflows']['main']['conclusion']=='success'
        and q['workflows']['preservation']['id']==44363952246 and q['workflows']['preservation']['conclusion']=='success','actual Snow FLPRINTDT workflows incomplete')
    require(set(q['main'])=={'Windows','Ubuntu'} and all(set(opts)=={'O0','O2'} for opts in q['main'].values()),'Snow calendar platform/optimization omitted')
    require(q['preservation']['Windows']['profiles']=={'thermal-reset-preserve-groundwater-O0-v1':3,'thermal-reset-preserve-groundwater-O2-v1':3,
        'thermal-reset-preserve-calendar-O0-v1':4,'thermal-reset-preserve-calendar-O2-v1':4,
        'thermal-reset-preserve-clock-O0-v1':4,'thermal-reset-preserve-clock-O2-v1':4,
        'thermal-reset-preserve-step-O0-v1':4,'thermal-reset-preserve-step-O2-v1':4,
        'thermal-reset-preserve-thermal-O0-v1':4,'thermal-reset-preserve-thermal-O2-v1':4,'thermal-reset-preserve-young-named-v1':10,'thermal-reset-preserve-saltfarm-O0-v1':1,'thermal-reset-preserve-saltfarm-O2-v1':1}
        and q['preservation']['Ubuntu']['profiles']=={'groundwater':3,'current-age':6,'direct-age':6,'calendar':4,'clock':4,'step':4,'saltfarm-O0':1,'saltfarm-O2':1},'scoped Snow calendar preservation omitted')

def predecessor():
    old=json.loads((ROOT/PROOF/'THERMAL_STEP_QUALIFICATION.json').read_text(encoding='utf8'))
    paths={ENTRY,PROOF+'THERMAL_STEP_QUALIFICATION.json',*old['source_sha256'],*old['controller_sha256'],*old['frozen_predecessor_sources'],*old['frozen_predecessor_controllers']}
    with tempfile.TemporaryDirectory(prefix='s5-flprintdt-literal-parent-') as directory:
        snapshot=Path(directory).resolve();batches=[];batch=[];length=0
        for path in sorted(paths):
            if length+len(path)>12000:batches.append(batch);batch=[];length=0
            batch.append(path);length+=len(path)+3
        if batch:batches.append(batch)
        for batch in batches:
            with tarfile.open(fileobj=io.BytesIO(git('archive',BASE,'--',*batch))) as archive:
                for member in archive.getmembers():
                    if member.isdir():continue
                    target=snapshot/member.name;require(member.isfile() and target.resolve().is_relative_to(snapshot),'foreign FLPRINTDT predecessor source')
                    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.extractfile(member).read())
        script="import importlib.util,json,pathlib;r=pathlib.Path.cwd();s=importlib.util.spec_from_file_location('literal_subdaily',r/"+repr(ENTRY)+");m=importlib.util.module_from_spec(s);s.loader.exec_module(m);m.validate(json.loads((r/"+repr(PROOF+'THERMAL_STEP_QUALIFICATION.json')+").read_text(encoding='utf8')));print('LITERAL_CANONICAL_FLPRINTDT_SOURCE_PASS')"
        result=subprocess.run([sys.executable,'-B','-c',script],cwd=snapshot,capture_output=True,text=True)
        require(result.returncode==0 and 'LITERAL_CANONICAL_FLPRINTDT_SOURCE_PASS' in result.stdout,'literal qualified FLPRINTDT predecessor invalid: '+result.stderr)
    for record in old['archives'].values():raw_archive(record)
    return 'LITERAL_ACTUAL_CANONICAL_FLPRINTDT_IMAGE_AND_UNCHANGED_RAW_PRODUCERS_PASS'


def period(report,case,opt,phase,build,build_digest):
    mode,hys,fmt,reset,et,_=case;nprint=1;days=1096 if phase=='full' else 35
    require(report['status']=='ACTUAL_WATER_SNOW_FLPRINTDT_RESET_'+phase.upper()+'_NATIVE_USER_OUTPUT_PASS'
        and (report['mode'],report['hysteresis'],report['format'],report['reset'],report['et'],report['optimization'],report['nprintday'])==(mode,hys,fmt,reset,et,opt,nprint),'actual Snow calendar period/domain differs')
    require(report['functional_completion']=='PARTIAL' and report['whole_scientific_equivalence']=='NOT_QUALIFIED','producer whole Snow scope promoted')
    require(report['trajectory']['days']==report['trajectory']['budgets']['days']==days and report['trajectory']['build_sha256']==build_digest,'Snow period censored/build rebound')
    require(all(bounded(report['trajectory']['budgets'][k]) for k in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')),'Snow period mass guard exceeded')
    selected=build['identity']['original_output'];monthly=mode=='monthly';dates=mode=='explicit';period=5 if mode=='periodic' else 0
    require(selected==report['original_output'] and selected['policy']=='original-water-snow-flprintdt-annual-reset-v1'
        and selected['native_codec']=='S5SRW001' and selected['thermal_clock'] is True and selected['thermal_output'] is True
        and selected['thermal_calendar'] is True and selected['thermal_step'] is selected['thermal_reset'] is True
        and selected['annual_counter_policy']=='original-completed-day-min-global-and-year-ordinal-v1' and selected['soil_trial_guard_cm']==1e-10
        and selected['original_flprintdt_date_gated'] is selected['original_pending_dates_not_normalized'] is True
        and (selected['kind'],selected['swhyst'],selected['swcsv'],selected['swmonth'],selected['swodat'],selected['swres'],selected['period'],selected['requested_period'],selected['nprintday'],selected['flprintdt'])
            ==('water',hys,fmt,int(monthly),int(dates),0 if monthly else reset,1,period,nprint,True)
        and selected['snow_output_fields']==SNOW_FIELDS and selected['snow_output_domain_bytes']==32 and selected['snow_output_value_bytes']==56
        and selected['native_domain_bytes']==80 and selected['snow_stock']=='actual MOD_snow ssnow' and selected['snow_increment_slots']==[2,3,13]
        and selected['physical_equations_changed'] is False and build['project']['water_tolerance']==1e-10
        and build['identity']['lower_boundary_receipt']['effective_SWBOTB']==(8 if hys==2 else 5),'compiled Snow calendar process policy differs')
    require(all('-'+opt in build['identity'][key] for key in ('donor_flags','kernel_flags')),'actual Snow calendar optimization differs')
    require(build['identity']['water_polish_policy']=='strict-water-always-polish-v1','foreign composed Snow water polishing policy')
    windows={(2,4),(4,8),(19,23),(30,34)}|({(199,201),(364,367),(530,532),(1094,1096)} if phase=='full' else set())
    require({(r['start'],r['end']) for r in report['cold']}==windows,'Snow calendar cold/month/year/terminal window omitted')
    for item in report['cold']:
        require(item['exact_physical'] is item['exact_complete_native'] is item['origin_unchanged'] is True
            and all(v['exact'] is True for v in item['exact_user_output'].values()),'Snow cold physical/native/user output differs')
    require(report['requested_controls_preserved'] is True and report['snow']['maximum_stock_cm']>0 and report['snow']['sublimation_cm']>0,'actual Snow/control observation inactive')

def ledger(rows,days):
    require(len(rows)==days and [r['day'] for r in rows]==list(range(1,days+1)) and all(r['committed'] is True for r in rows),'Snow trajectory censored')
    for row in rows:
        flow=row['external_flux_cm'];start=row['stock_start_cm'];end=row['stock_end_cm']
        require(len(flow)==16 and len(start)==len(end)==6 and all(finite(v) for v in [*flow,*start,*end,*row['pressure_head_cm']]),'Snow physical receipt malformed')
        water=math.fsum([*flow[:7],*(-v for v in flow[7:]),*start,*(-v for v in end)])
        require(all(bounded(v) for v in (water,row['independent_residual_cm'],row['kernel_residual_cm'],row['integrated_guard_residual_cm'])),'actual independent Snow water guard exceeded')

def build_files(z,prefix,build):
    require(build['binding']['build']==build['identity'],'actual build/checkpoint policy identity differs')
    for name,value in build['identity']['donor_generated'].items():
        require(digest(z.read(prefix+name))==value,'actual generated Snow provider changed: '+name)
    for kind,name in [('donor','day_donor'),('kernel','day_kernel')]:
        paths=[prefix+name+suffix for suffix in ('','.exe') if prefix+name+suffix in z.namelist()]
        require(len(paths)==1 and digest(z.read(paths[0]))==build['executable_sha256'][kind],'actual compiled Snow executable changed: '+kind)

def native(raw,row,n,hys,selected,epoch='2002-01-01'):
    require(raw[:8]==b'S5SRW001','actual Snow calendar codec differs')
    domain=struct.pack('<10i',1,n,0,0,hys,1,0,1,1,2);require(raw.count(domain+domain)==1,'actual Snow process domain differs')
    snow=struct.pack('<4i',1,n,0,7);require(raw.count(snow+snow)==1,'actual seven Snow totals domain differs')
    pos=raw.index(snow+snow);require(pos==raw.index(domain+domain)+80,'actual Snow carry placement differs')
    require(len(raw)>=pos+88+160,'actual Snow/calendar native truncated')
    values=struct.unpack_from('<7d',raw,pos+32);require(all(math.isfinite(v) and v>=0 for v in values),'actual Snow totals nonfinite/negative')
    c=pos+88;header=struct.unpack_from('<20i',raw,c);witness=struct.unpack_from('<20i',raw,c+80);nreal=header[3]
    require(header==witness and header[:2]==(1,n) and nreal>100 and len(raw)==c+160+16*nreal,'actual original calendar header/witness/shape differs')
    require((header[4],header[5],header[6],header[11])==(selected['period'],selected['nprintday'],row['day'],selected['swres'])
        and all(flag in (0,1) for flag in header[12:20]),'actual original Snow calendar counter/domain differs')
    original=struct.unpack_from('<'+str(nreal)+'d',raw,c+160);copy=struct.unpack_from('<'+str(nreal)+'d',raw,c+160+8*nreal)
    require(original==copy and all(map(math.isfinite,original)) and original[-1]>=0,'actual original calendar values/witness differ')
    completed=date.fromisoformat(epoch)+timedelta(days=row['day']-1)
    expected=min(row['day'],completed.timetuple().tm_yday) if row['day'] else 0
    require(header[8]==1 and header[7]==expected and header[18:20]==(1,1),'actual Snow annual print counter/flags differ')
    return values


def output_clock(observed,stamps,days,epoch):
    from datetime import datetime
    require(observed['stamps']==stamps and observed['records']==len(stamps),'actual FLPRINTDT output inventory censored/rebound')
    initial=datetime.fromisoformat(epoch);actual=[]
    for stamp in stamps:
        d,t=stamp.split();hour,minute,second=map(int,t.split(':'))
        require(0<=hour<24 and 0<=minute<60 and 0<=second<=60,'foreign original rounded clock field')
        actual.append(datetime.fromisoformat(d)+timedelta(hours=hour,minutes=minute,seconds=second))
    require(bool(actual) and actual[0]==initial and actual==sorted(actual) and actual[-1]<=initial+timedelta(days=days),'actual original FLPRINTDT event clock differs')
    if days==1096:require(actual[-1]==initial+timedelta(days=days),'actual original FLPRINTDT TEND record omitted')


def soil_receipts(z,prefix,days,report=None):
    rows=[]
    for line in z.read(prefix+'original/donor.stdout').decode('utf8').splitlines():
        if not line.startswith('HYBRID_SNOW_SOIL_RECEIPT '):continue
        row=list(map(float,line.split()[1:]))
        require(len(row)==29 and all(map(finite,row)),'actual Snow soil receipt malformed')
        residual=math.fsum([*row[12:19],*(-v for v in row[19:28]),*row[6:12],*(-v for v in row[:6])])
        require(bounded(residual) and bounded(row[-1]) and abs(residual-row[-1])<=1e-13,'actual Snow soil guard/report exceeded')
        require(row[2:6]==row[8:12]==[0.0]*4,'foreign Snow/canopy soil stock')
        rows.append(row)
    require(len(rows)==days,'actual Snow soil day audit omitted')
    if report is not None:require(report['actual_days']==days and report['actual_rows']==rows
        and report['maximum_absolute_residual_cm']==max(abs(row[-1]) for row in rows),'actual Snow soil report rebound')


def verify():
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty Snow calendar admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'Snow calendar production differs from qualified source')
    q=json.loads((ROOT/PROOF/'THERMAL_RESET_QUALIFICATION.json').read_text(encoding='utf8'));validate(q)
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==set(q['source_sha256']),'unqualified Snow production surface')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'immutable Snow/predecessor evidence changed: '+path)
    docs={'docs/science/NOMACRO_THERMAL_RESET_20261118.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,*docs,PROOF+'THERMAL_RESET_MERGE_RECEIPT.json'},'unqualified Snow post-seal change')
    require((ROOT/ENTRY).read_text(encoding='utf8').replace(HOOK,'',1).encode()==blob(BASE,ENTRY).replace(b'\r\n',b'\n'),'literal predecessor groundwater-history owner body changed')
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'actual Snow model producer source differs')
    for workflow in q['workflows'].values():
        require(workflow['merge'] is False and set(git('diff','--name-only',workflow['runtime'],workflow['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'Snow calendar carrier changes model source')
    prior=predecessor();archives={};reports=0;fulls=0;windows=0;refusals=0;policies=0;providers=0
    for key,record in q['archives'].items():
        z=zipfile.ZipFile(io.BytesIO(raw_archive(record)));require(set(z.namelist())==set(record['members']),'actual Snow archive member omitted')
        for name,value in record['members'].items():require(digest(z.read(name))==value,'actual Snow archive producer member changed')
        archives[key]=z
    def read(z,path):
        nonlocal reports
        reports+=1;return json.loads(z.read(path))
    sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'));from thermal_reset_ci import CASES,CONTROLS
    from original_output_files import records
    require(len(CASES)==8 and sum(case[-1] for case in CASES.values())==4 and len(CONTROLS)==4,'actual Snow calendar cohort changed')
    physical=lambda rows:[{k:v for k,v in row.items() if k not in ('column','revision')} for row in rows]
    def rows(z,prefix):return [json.loads(line) for line in z.read(prefix+'daily.jsonl').splitlines()]
    main_data={};compiled_builds=set()
    with tempfile.TemporaryDirectory(prefix='s5-snow-user-records-') as directory:
        cache={};temporary=Path(directory)
        def user(z,path):
            key=(id(z),path)
            if key not in cache:
                target=temporary/(str(len(cache))+Path(path).suffix);target.write_bytes(z.read(path));cache[key]=records(target)
            return cache[key]
        def stamp(row):return row[:19].decode('ascii').strip() if isinstance(row,bytes) else row.split(',')[0].strip()
        def user_cold(z,warm,cold,names,start,end,epoch):
            low=str(date.fromisoformat(epoch)+timedelta(days=start));high=str(date.fromisoformat(epoch)+timedelta(days=end))
            for name in names:
                expected=[row for row in user(z,warm+name)[1:] if low+' 00:00:00'<stamp(row)<=high+' 00:00:00']
                actual=user(z,cold+name);require(bool(actual) and actual[1:]==expected,'actual sparse Snow cold user record differs')
        for platform,opts in q['main'].items():
            for opt,location in opts.items():
                z=archives[location['archive']];run=read(z,location['prefix']+'RESULT.json')
                require(run['status']=='EIGHT_WATER_SNOW_FLPRINTDT_RESET_SHORT_FOUR_FULL_FOUR_NATIVE_CONTEXTS_PASS'
                    and set(run['cases'])==set(CASES) and set(run['controls'])==set(CONTROLS)
                    and run['all_short_and_native_gates_precede_full'] is True,'actual Snow matrix incomplete/full precedes narrow gates')
                def path(original):
                    if platform=='Windows':return PureWindowsPath(original).relative_to(PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/'
                    base=PurePosixPath(run['cases']['explicit-hys2-binary']['short_root']).parent
                    return str(PurePosixPath(original).relative_to(base))+'/'
                short_data={}
                for key,case in CASES.items():
                    item=run['cases'][key];bp=path(item['build_root']);raw=z.read(bp+'BUILD.json');build=json.loads(raw);bd=digest(raw);reports+=1;compiled_builds.add(bd)
                    build_files(z,bp,build)
                    host=blob(RUNTIME,'app/hybrid_water/daily_host.py').replace(b'\r\n',b'\n')
                    require(build['identity']['host'] in (digest(host),digest(host.replace(b'\n',b'\r\n'))),'actual composed Snow host source differs')
                    require(digest(z.read(bp+'thermal_output_snow_calendar_state.f90').replace(b'\r\n',b'\n'))==q['frozen_predecessor_sources']['app/hybrid_water/thermal_output_snow_calendar_state.f90'],'actual compiled Snow state provider differs')
                    selected=build['identity']['original_output']
                    require(selected['source_sha256']==q['source_sha256']['app/hybrid_water/thermal_output_reset.py']
                        and selected['snow_output_source_sha256']==q['frozen_predecessor_sources']['app/hybrid_water/thermal_output_snow_calendar_state.f90'],'actual Snow compiled source identity differs')
                    for phase in ('short','full'):
                        if phase=='full' and not case[-1]:continue
                        prefix=path(item[phase+'_root']);report=read(z,prefix+'RESULT.json');require(report==item[phase],'actual Snow period producer rebound')
                        period(report,case,opt,phase,build,bd);days=1096 if phase=='full' else 35;data=rows(z,prefix+'trajectory/');ledger(data,days)
                        soil_receipts(z,prefix+'trajectory/',days,report['soil_receipts'])
                        require(max(row['stock_end_cm'][2] for row in data)>0 and sum(row['external_flux_cm'][12] for row in data)>0,'actual Snow stock/sublimation inactive')
                        if phase=='full':fulls+=1
                        else:
                            short_data[key]=physical(data);main_data[platform,opt,key]=(z,prefix,build,data)
                        require(set(report['user_output'])==(set() if not case[2] else {'result_output.bin' if case[2]==3 else 'result_output.csv'}),'actual Snow requested table set differs')
                        for name,observed in report['user_output'].items():
                            actual=user(z,prefix+'trajectory/original/'+name);stamps=[stamp(row) for row in actual]
                            output_clock(observed,stamps,days,build['project']['start_date'])
                            if phase=='full':require(stamps[-1]=='2005-01-01 00:00:00','actual subdaily TEND event missing')
                        for window in report['cold']:
                            start,end=window['start'],window['end'];windows+=1;actual=rows(z,prefix+f'own-{start}/')
                            soil_receipts(z,prefix+f'own-{start}/',end-start)
                            require(physical(actual)==physical(data[start:end]),'actual Snow cold physical rows differ')
                            with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'trajectory/accepted-column-1-day-{end}.zip'))) as warm,zipfile.ZipFile(io.BytesIO(z.read(prefix+f'own-{start}/accepted-column-1-day-{end}.zip'))) as cold:
                                for name in ('result.end','macro.bin'):require(warm.read(name)==cold.read(name),'actual Snow complete cold native differs')
                                native(warm.read('macro.bin'),data[end-1],build['project']['nodes'],case[1],selected,build['project']['start_date'])
                            user_cold(z,prefix+'trajectory/original/',prefix+f'own-{start}/original/',report['user_output'],start,end,build['project']['start_date'])
                        for day in (2,4,8,days):
                            with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'trajectory/accepted-column-1-day-{day}.zip'))) as checkpoint:
                                values=native(checkpoint.read('macro.bin'),data[day-1],build['project']['nodes'],case[1],selected,build['project']['start_date'])
                                require(list(values)==report['native_domains'][str(day)]['snow_output_values'],'actual reported seven Snow totals differ')
                require(short_data['explicit-hys2-binary']==short_data['explicit-hys2-none'],'actual Snow output format changes physics')
                left=path(run['cases']['explicit-hys2-binary']['short_root']);right=path(run['cases']['explicit-hys2-none']['short_root'])
                for day in (4,8,23,34,35):
                    with zipfile.ZipFile(io.BytesIO(z.read(left+f'trajectory/accepted-column-1-day-{day}.zip'))) as a,zipfile.ZipFile(io.BytesIO(z.read(right+f'trajectory/accepted-column-1-day-{day}.zip'))) as b:
                        for name in ('result.end','macro.bin'):require(a.read(name)==b.read(name),'actual Snow format changes complete native')
                for key,item in run['controls'].items():
                    control=read(z,path(item['root'])+'RESULT.json');require(control==item['report'],'actual Snow controls rebound')
                    require(control['status']=='WATER_SNOW_FLPRINTDT_RESET_SIXTY_THREE_NATIVE_ACTIVE_AND_POLICY_REFUSALS_PASS'
                        and len(control['native_refusals'])==63 and all(r['status']=='REFUSED' and 'ERROR STOP' in r['diagnostic'] for r in control['native_refusals']),'actual Snow native refusal omitted');refusals+=63
                    require(len(control['policy_refusals'])==27 and all(r['status']=='REFUSED' for r in control['policy_refusals']),'actual Snow policy refusal omitted');policies+=27
                    require(control['actual_provider_refusal']['status']=='REFUSED' and control['actual_provider_refusal']['actual_original_metadata_unchanged'] is True,'actual copied Snow provider not bound');providers+=1
                    require(all(control['transactions'][k] is True for k in ('discard_no_day_advance','replay_exact','accept_exact','recovered_next_day_exact','origin_unchanged')),'actual Snow transactions omitted')
        contexts=0
        for platform,location in q['preservation'].items():
            z=archives[location['archive']]
            for prefix,count in location['profiles'].items():
                report=read(z,prefix+'/RESULT.json');require(any(word in report['status'] for word in ('PASS','PRESERVED')) and len(report['profiles'])==count,'actual prior Snow-dispatch context omitted');contexts+=count
                for key,item in report['profiles'].items():
                    require(read(z,prefix+'/'+key+'/build/BUILD.json')==item['actual_build'] and any(value is True for field,value in item.items() if 'exact' in field),'actual preserved source/native/build rebound')
                if 'saltfarm' in prefix:
                    item=report['profiles']['saltfarm'];base=prefix+'/saltfarm/';build=item['actual_build'];opt=report['optimization']
                    require(report['status']=='ACTUAL_CANONICAL_SALTFARM_POLICY_FULL_SOURCE_NATIVE_USER_EXACT_PASS'
                        and build['identity']['water_polish_policy']=='strict-water-half-interior-polish-v1','actual canonical SaltFarm policy changed')
                    build_files(z,base+'build/',build)
                    authority=json.loads((ROOT/'integration/f-ci/saltfarm-newton-work01/PORTABLE.json').read_text(encoding='utf8'))
                    record=authority['archives'][platform];raw=(ROOT/'integration/f-ci/saltfarm-newton-work01'/record['file']).read_bytes()
                    require(digest(raw)==record['sha256']==report['actual_prior_raw_sha256'],'canonical SaltFarm prior producer changed')
                    with zipfile.ZipFile(io.BytesIO(raw)) as prior_salt:
                        old=json.loads(prior_salt.read('qualified-'+opt+'/BUILD.json'))
                        for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','water_polish_policy'):
                            require(build['identity'].get(field)==old['identity'].get(field),'actual canonical SaltFarm physical source/policy differs: '+field)
                        data=rows(z,base+'accept/full/');ledger(data,1461)
                        original=[json.loads(line) for line in prior_salt.read('accept-'+opt+'/full/daily.jsonl').splitlines()]
                        require(physical(data)==physical(original),'actual canonical SaltFarm1461day physical/chemical rows differ')
                        warm=user(z,base+'accept/full/original/result_output.csv')
                        require(warm==user(prior_salt,'accept-'+opt+'/full/original/result_output.csv'),'actual canonical SaltFarm data records differ')
                        for day in (109,111,365,367,453,455,1460,1461):
                            with zipfile.ZipFile(io.BytesIO(prior_salt.read('accept-'+opt+f'/full/accepted-column-1-day-{day}.zip'))) as oldzip,zipfile.ZipFile(io.BytesIO(z.read(base+f'accept/full/accepted-column-1-day-{day}.zip'))) as actual:
                                for member in ('result.end','macro.bin'):require(oldzip.read(member)==actual.read(member),'actual canonical SaltFarm native endpoint differs')
                        result=read(z,base+'accept/RESULT.json')
                        require(result['status']=='FULL_PASS' and result['days']==1461 and len(result['restarts'])==5,'actual canonical SaltFarm preservation censored')
                        for start,end in ((109,111),(365,367),(453,455),(1460,1461),(109,1461)):
                            target=base+f'accept/restart{start}-{end}/';actual=rows(z,target)
                            require(physical(actual)==physical(data[start:end]),'actual canonical SaltFarm own cold differs')
                            require(user(z,target+'original/result_output.csv')[-(end-start):]==warm[start+1:end+1],'actual canonical SaltFarm own cold user differs')
                            with zipfile.ZipFile(io.BytesIO(z.read(base+f'accept/full/accepted-column-1-day-{end}.zip'))) as full,zipfile.ZipFile(io.BytesIO(z.read(target+f'accepted-column-1-day-{end}.zip'))) as cold:
                                for member in ('result.end','macro.bin'):require(full.read(member)==cold.read(member),'actual canonical SaltFarm own cold native differs')
        for location in q['context']:
            z=archives[location['archive']];public=read(z,location['public']+'/RESULT.json');reader=read(z,location['reader']+'/RESULT.json')
            require(public['status']=='THREE_PUBLIC_WATER_SNOW_FLPRINTDT_RESET_SELF_CONTAINED_RESTART_CONTEXTS_PASS' and len(public['profiles'])==3,'actual independent Snow public gate missing')
            require(reader['status']=='SEVEN_ORIGINAL_CALENDAR_READER_TWELVE_SNOW_DESCRIPTOR_REFUSALS_PASS' and len(reader['reader_refusals'])==7 and len(reader['descriptor_refusals'])==12
                and reader['build_sha256'] in compiled_builds and all(r['status']=='REFUSED_BEFORE_HYBRID_READY' for r in reader['reader_refusals'])
                and all(r['status']=='REFUSED' for r in reader['descriptor_refusals']),'actual original Snow reader/domain gate missing')
            for name,item in public['profiles'].items():
                require(item['physical_exact'] is item['complete_native_exact'] is item['origin_unchanged'] is True
                    and all(v['exact'] is True for v in item['user_output_exact'].values()) and item['warm']['returncode']==item['cold']['returncode']==0,'actual public Snow continuation differs')
                main,mp,build,data=main_data[location['platform'],location['optimization'],name];prefix=location['public']+'/'+name+'/'
                require(physical(rows(z,prefix+'warm/'))==physical(data) and physical(rows(z,prefix+'cold/'))==physical(data[30:34]),'actual public Snow physical records differ')
                with zipfile.ZipFile(io.BytesIO(main.read(mp+'trajectory/accepted-column-1-day-34.zip'))) as a,zipfile.ZipFile(io.BytesIO(z.read(prefix+'cold/accepted-column-1-day-34.zip'))) as b:
                    for member in ('result.end','macro.bin'):require(a.read(member)==b.read(member),'actual public Snow complete native differs')
                user_cold(z,prefix+'warm/original/',prefix+'cold/original/',item['user_output_exact'],30,34,build['project']['start_date'])
        require(len(q['epochs'])==4 and {(v['platform'],v['optimization']) for v in q['epochs']}=={(p,o) for p in ('Windows','Ubuntu') for o in ('O0','O2')},'actual epoch platform omitted')
        epoch_periods=0;epoch_cold=0;year_refusals=0
        for location in q['epochs']:
            z=archives[location['archive']];ep=location['prefix'];yp=location['controls'];run=read(z,ep+'RESULT.json');controls=read(z,yp+'RESULT.json')
            require(run['status']=='TWO_NONJANUARY_ORIGINAL_EPOCHS_YEAR_RESET_ACTUAL_NATIVE_COLD_PASS' and set(run['cases'])=={'2002-12-15','2003-12-15'} and run['optimization']==location['optimization'],'actual original epoch period omitted')
            require(controls['status']=='EIGHT_ACTUAL_POST_YEAR_NATIVE_COUNTER_FORGERIES_REFUSED' and controls['optimization']==location['optimization'] and set(controls['cases'])==set(run['cases']),'actual post-year source/native refusal omitted')
            for epoch,item in run['cases'].items():
                prefix=ep+epoch+'/actual/';report=read(z,prefix+'RESULT.json');raw=z.read(prefix+'build/BUILD.json');build=json.loads(raw);bd=digest(raw)
                require(report==item['report'] and build['project']['start_date']==epoch and build['identity']['original_output']['source_sha256']==q['source_sha256']['app/hybrid_water/thermal_output_reset.py'],'actual epoch build/report rebound')
                build_files(z,prefix+'build/',build);period(report,('explicit',2,3,1,0,False),location['optimization'],'short',build,bd)
                data=rows(z,prefix+'trajectory/');ledger(data,35);soil_receipts(z,prefix+'trajectory/',35,report['soil_receipts']);epoch_periods+=1
                selected=build['identity']['original_output'];require(len(item['actual_native_counters'])==8,'actual epoch native inventory censored')
                for check in item['actual_native_counters']:
                    day=check['day'];completed=date.fromisoformat(epoch)+timedelta(days=day-1);expected=min(day,completed.timetuple().tm_yday)
                    require(check==dict(day=day,completed=completed.isoformat(),global_day=day,annual_counter=expected,expected=expected),'actual epoch native report differs')
                    with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'trajectory/accepted-column-1-day-{day}.zip'))) as checkpoint:native(checkpoint.read('macro.bin'),data[day-1],build['project']['nodes'],2,selected,epoch)
                for name,observed in report['user_output'].items():output_clock(observed,[stamp(row) for row in user(z,prefix+'trajectory/original/'+name)],35,epoch)
                for window in report['cold']:
                    start,end=window['start'],window['end'];epoch_cold+=1;actual=rows(z,prefix+f'own-{start}/');require(physical(actual)==physical(data[start:end]),'actual non-January cold rows differ');soil_receipts(z,prefix+f'own-{start}/',end-start)
                    with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'trajectory/accepted-column-1-day-{end}.zip'))) as warm,zipfile.ZipFile(io.BytesIO(z.read(prefix+f'own-{start}/accepted-column-1-day-{end}.zip'))) as cold:
                        for member in ('result.end','macro.bin'):require(warm.read(member)==cold.read(member),'actual non-January cold native differs')
                        native(cold.read('macro.bin'),data[end-1],build['project']['nodes'],2,selected,epoch)
                    user_cold(z,prefix+'trajectory/original/',prefix+f'own-{start}/original/',report['user_output'],start,end,epoch)
                control=controls['cases'][epoch];source=z.read(prefix+'trajectory/accepted-column-1-day-30.zip');require(digest(source)==control['source_sha256'],'actual post-year native origin rebound')
                require({v['attack'] for v in control['checks']}=={'global-counter','previous-year-counter','shifted-epoch-counter','zero-counter'} and len(control['checks'])==4,'actual annual counter attack omitted')
                for attack in control['checks']:
                    completed=date.fromisoformat(epoch)+timedelta(days=29);expected=min(30,completed.timetuple().tm_yday)
                    require(attack['status']=='REFUSED' and attack['day']==30 and attack['actual_counter']==expected and attack['forged_counter']!=expected and 'Inconsistent original Snow annual-reset day counter' in attack['diagnostic'],'actual forged post-year counter not refused');year_refusals+=1
                    ap=yp+epoch+'/'+attack['attack']+'/'
                    diagnostic=z.read(ap+'original/donor.stderr').decode('utf8').replace('\r\n','\n')
                    require(diagnostic==attack['diagnostic'].replace('\r\n','\n') and 'Inconsistent original Snow annual-reset day counter' in diagnostic,'actual forged-counter worker stderr differs')
                    require(not any(name.startswith(ap) and Path(name).name.startswith('accepted-') and name.endswith('.zip') for name in z.namelist()),'forged annual worker published accepted state')
                    raw=z.read(ap+'origin/macro.bin')
                    with zipfile.ZipFile(io.BytesIO(source)) as checkpoint:expected_raw=bytearray(checkpoint.read('macro.bin'))
                    snow=struct.pack('<4i',1,build['project']['nodes'],0,7);counter=expected_raw.index(snow+snow)+88
                    for offset in (28,108):struct.pack_into('<i',expected_raw,counter+offset,attack['forged_counter'])
                    require(raw==expected_raw,'actual forged annual origin has an unbound mutation')
                    try:native(raw,data[29],build['project']['nodes'],2,selected,epoch)
                    except ValueError:pass
                    else:raise ValueError('actual forged annual native origin independently accepted')
        require((epoch_periods,epoch_cold,year_refusals)==(8,32,32),'actual non-January epoch/forgery denominator differs')
        z=archives[q['retained_observations']['archive']]
        valid=read(z,'thermal-reset-baseline-original-reader-v1/RESULT.json')
        require(valid['original']['swap_ok'] is True and valid['original']['returncode']==100 and valid['scientific_claim'] is False
            and valid['original']['executable_sha256']=='c29480b2b76bac820d5c98cae59c1d09680d4e1bdfc5728932b4e1a72f37da71','actual original FLPRINTDT reset reader observation changed/promoted')
    require((fulls,windows,refusals,policies,providers,contexts)==(16,256,1008,432,16,79),'actual Snow calendar full/native/preservation denominator differs')
    return dict(status='ORIGINAL_SNOW_FLPRINTDT_ANNUAL_RESET_NATIVE_ADMISSION_PASS',runtime=RUNTIME,predecessor=prior,actual_full_periods=fulls,
        actual_cold_windows=windows,actual_native_refusals=refusals,actual_policy_refusals=policies,actual_copied_provider_refusals=providers,
        actual_preserved_contexts=contexts,actual_saltfarm_preserved_full_periods=4,actual_saltfarm_preserved_cold_windows=20,actual_non_january_periods=epoch_periods,actual_epoch_cold_windows=epoch_cold,actual_post_year_native_refusals=year_refusals,actual_bound_reports=reports,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')

if __name__=='__main__':print(json.dumps(verify(),indent=2))
