"""Independent source, actual daily chemistry and private interval-state admission."""
from pathlib import Path,PureWindowsPath,PurePosixPath
from datetime import date,timedelta
import hashlib,io,json,math,struct,subprocess,sys,tarfile,tempfile,zipfile
from functools import lru_cache

ROOT=Path(__file__).resolve().parents[2]
PROOF='integration/f-ci/nomacro-complete01/'
BASE='c8b3029fee7a88af6c74ac93e58ce69b8de9f96e'
RUNTIME='0038a20fc2fb254bcd5f6079dcd24ae4dfe5d0af'
SEALED='8e0731453fa53588308c6c8c4d1c37c79c48386b'
ENTRY='tests/nomacro_scheduled_subsurface/cde_interval_verify.py'
SELF='tests/nomacro_scheduled_subsurface/cde_clock_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_cde_clock_verify.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('cde_clock_admission',ROOT/'tests/nomacro_scheduled_subsurface/cde_clock_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
CODECS=['S5CCC001','S5CCH001','S5CCS001']
SCOPE=dict(macro=0,solute=1,age=False,snow=[0,1],heat=1,thermal_method=2,hysteresis=[0,1,2],hydraulic_family=0,
 drainage=1,lower_boundary=[5,8],frost=0,aquifer=0,detailed_weather=0,nprintday=[1,1440],per_step=[False,True],
 reset=[0,1],calendars=['monthly','explicit-date','PERIOD0','PERIOD2..366'],formats=[0,1,2,3],et=[0,1],
 sources=['point','interval','surface','sprinkler'],physical_equations_changed=False,
 numerical_event_policy='actual-local-irrigation-and-end-day-existing-dtcrit-v1',existing_original_dtcrit=1e-8,literal_partitions='all NPD1 FLPRINTDTfalse current interval and dense CDE and all other process families')


def require(condition,message):
    if not condition:raise ValueError(message)

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def digest(raw):return hashlib.sha256(raw).hexdigest()
def sha(path):return digest(path.read_bytes().replace(b'\r\n',b'\n'))
def finite(v):return type(v) in (int,float) and math.isfinite(v)
def bounded(v):return finite(v) and abs(v)<=1e-10
def tree(ref,path):return {line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-r',ref,'--',path).decode().splitlines()}
def physical(data):return [{k:v for k,v in row.items() if k not in ('column','revision')} for row in data]
def rows(z,prefix):return [json.loads(line) for line in z.read(prefix+'daily.jsonl').splitlines()]
def read(z,path):return json.loads(z.read(path))


@lru_cache(maxsize=None)
def kernel_checkout_digest(path,target):
    raw=blob(RUNTIME,path)
    # BUILD records exact compiler-input bytes, unlike the normalized source seal.
    # Windows used core.autocrlf=true; Ubuntu compiled the literal Git LF blob.
    # Keep both original BUILD hashes and raw artifacts unchanged.
    if target=='x86_64-w64-mingw32':raw=raw.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')
    else:require(target=='x86_64-linux-gnu','foreign actual kernel checkout target')
    return digest(raw)


def raw_archive(record):
    if 'byte_parts' in record:
        chunks=[];offset=0
        for part in record['byte_parts']:
            require(part['offset']==offset and Path(part['path']).name==part['path'],'foreign CDE archive part')
            raw=(ROOT/PROOF/part['path']).read_bytes();require(len(raw)==part['bytes'] and digest(raw)==part['sha256'],'changed CDE archive part')
            chunks.append(raw);offset+=len(raw)
        raw=b''.join(chunks)
    else:raw=(ROOT/PROOF/record['archive']).read_bytes()
    require(len(raw)==record['bytes'] and digest(raw)==record['sha256'],'actual CDE raw archive changed')
    if 'origin_artifact' in record:require(record['origin_artifact']['digest']=='sha256:'+digest(raw) and record['origin_artifact']['size_in_bytes']==len(raw) and record['actual_artifact_bytes_preserved'] is True,'actual CDE artifact rebound')
    return raw


def validate(q):
    require((q['baseline'],q['runtime'],q['status'])==(BASE,RUNTIME,'BOUNDED_ORIGINAL_CDE_CLOCK_QUALIFIED_PENDING_ADMISSION'),'foreign CDE qualification')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['release_readiness'])==('PARTIAL','NOT_QUALIFIED','RC3_FIXED_NAMED_PROFILES_ONLY'),'whole CDE scope promoted')
    require(q['scope']==SCOPE and q['water_guard_cm']==q['chemical_mass_guard_mg_cm2']==1e-10 and q['native_codecs']==CODECS and q['process_domain_bytes']==[0,40,80],'CDE native/process/guard scope differs')
    for group in ('source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
        for path,value in q[group].items():require(sha(ROOT/path)==value,'actual CDE source/controller changed: '+path)
    require(q['base_consumer']['merge']==BASE and q['base_consumer']['exact_complete_tree'] is True and q['base_consumer']['actual_detached_owner']['returncode']==0,'actual predecessor metadata owner absent')
    require(set(q['main'])=={'Windows','Ubuntu'} and all(set(opts)=={'O0','O2'} for opts in q['main'].values()),'CDE platform/optimization omitted')
    require(all(v['conclusion']=='success' and v['runtime']==RUNTIME and v['merge'] is False for v in q['workflows'].values()),'selected CDE portable workflow incomplete')
    require(q['preservation']['Windows']['profiles']=={f'cde-clock-preserve-{family}-{opt}-v1':count for family,count in [('interval',4),('water',2),('dense',1)] for opt in ('O0','O2')}
        and q['preservation']['Ubuntu']['profiles']=={'interval':4,'water':2,'dense':1},'selected CDE seam preservation omitted')
    require(q['not_selected_impact']['status']=='NOT_SELECTED_IMPACT' and q['not_selected_impact']['fresh_pass_claim'] is False and set(q['not_selected_impact']['reasons'])=={'water_age_early_return','npd1_false_delegation','conditional_clock_link','literal_private_providers','unchanged_original_physics'},'unaffected old campaigns silently relabelled')


def predecessor():
    old=json.loads((ROOT/PROOF/'CDE_INTERVAL_QUALIFICATION.json').read_text(encoding='utf8'))
    paths={ENTRY,PROOF+'CDE_INTERVAL_QUALIFICATION.json',*old['source_sha256'],*old['controller_sha256'],*old['frozen_predecessor_sources'],*old['frozen_predecessor_controllers']}
    with tempfile.TemporaryDirectory(prefix='s5-cde-literal-parent-') as directory:
        snapshot=Path(directory).resolve();batches=[];batch=[];length=0
        for path in sorted(paths):
            if length+len(path)>12000:batches.append(batch);batch=[];length=0
            batch.append(path);length+=len(path)+3
        if batch:batches.append(batch)
        for batch in batches:
            with tarfile.open(fileobj=io.BytesIO(git('archive',BASE,'--',*batch))) as archive:
                for member in archive.getmembers():
                    if member.isdir():continue
                    target=snapshot/member.name;require(member.isfile() and target.resolve().is_relative_to(snapshot),'foreign literal CDE predecessor path')
                    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.extractfile(member).read())
        script="import importlib.util,json,pathlib;r=pathlib.Path.cwd();s=importlib.util.spec_from_file_location('literal',r/"+repr(ENTRY)+");m=importlib.util.module_from_spec(s);s.loader.exec_module(m);m.validate(json.loads((r/"+repr(PROOF+'CDE_INTERVAL_QUALIFICATION.json')+").read_text(encoding='utf8')));print('LITERAL_CANONICAL_CDE_INTERVAL_SOURCE_PASS')"
        result=subprocess.run([sys.executable,'-B','-c',script],cwd=snapshot,capture_output=True,text=True)
        require(result.returncode==0 and 'LITERAL_CANONICAL_CDE_INTERVAL_SOURCE_PASS' in result.stdout,'literal predecessor invalid: '+result.stderr)
    for record in old['archives'].values():raw_archive(record)
    return 'LITERAL_ACTUAL_CANONICAL_CDE_INTERVAL_IMAGE_AND_UNCHANGED_RAW_PRODUCERS_PASS'


def ledger(data,days):
    require(len(data)==days and [r['day'] for r in data]==list(range(data[0]['day'],data[0]['day']+days)) and all(r['committed'] is True for r in data),'CDE actual trajectory censored')
    for row in data:
        flow=row['external_flux_cm'];start=row['stock_start_cm'];end=row['stock_end_cm'];v=row['solute_ledger_mg_cm2']
        require(len(flow)==16 and len(start)==len(end)==6 and len(v)==9 and all(map(finite,[*flow,*start,*end,*v,*row['pressure_head_cm']])),'CDE physical receipt malformed')
        water=math.fsum([*flow[:7],*(-x for x in flow[7:]),*start,*(-x for x in end)])
        chemical=math.fsum([v[1],-v[2],-v[3],-v[4],v[5],v[6],v[7]])
        require(v[0]==row['solute_end_mg_cm2'] and v[1]==row['solute_end_mg_cm2']-row['solute_start_mg_cm2'],'CDE stock/delta ledger differs')
        require(all(bounded(x) for x in (water,chemical,v[8],row['independent_residual_cm'],row['kernel_residual_cm'],row['integrated_guard_residual_cm'],row['solute_independent_residual_mg_cm2'])),'actual unchanged CDE water/chemical guard exceeded')
    terms=[data[-1]['solute_end_mg_cm2'],-data[0]['solute_start_mg_cm2']]
    for row in data:
        v=row['solute_ledger_mg_cm2'];terms.extend([-v[2],-v[3],-v[4],v[5],v[6],v[7]])
    require(bounded(math.fsum(terms)),'integrated actual CDE flow mass guard exceeded')


def daily(z,prefix,data,n,report=None):
    values=[];counts=[]
    for line in z.read(prefix+'original/donor.stdout').decode('utf8').splitlines():
        if line.startswith('CDE_INTERVAL_DAILY_AUDIT '):values.append(list(map(float,line.split()[1:])))
        if line.startswith('CDE_INTERVAL_INCREMENT_COUNTS '):counts.append(list(map(int,line.split()[1:])))
    require(len(values)==len(counts)==len(data),'actual CDE daily observation omitted')
    for v,c,row in zip(values,counts,data):
        require(len(v)==17 and all(map(finite,v)) and len(c)==6 and all(type(x) is int and x>0 for x in c) and c[1]>=c[0] and c[3]==c[4]==c[5]==n*c[2],'actual CDE RHS observation malformed')
        require(v[:2]==[row['solute_start_mg_cm2'],row['solute_end_mg_cm2']] and v[2:9]==row['solute_ledger_mg_cm2'][2:9],'actual daily CDE receipt not bound to worker ledger')
        residual=math.fsum([v[1],-v[0],*(-x for x in v[2:5]),*v[5:8]])
        require(bounded(residual) and bounded(v[8]) and abs(residual-v[8])<=1e-13,'actual independent CDE daily receipt inconsistent')
    integrated=math.fsum([values[-1][1],-values[0][0],*(term for v in values for term in [-v[2],-v[3],-v[4],v[5],v[6],v[7]])])
    require(bounded(integrated),'integrated observed chemical residual exceeded')
    actual=dict(actual_days=len(data),actual_rows=values,actual_increment_counts=counts,integrated_actual_chemical_residual_mg_cm2=integrated)
    if report is not None:require(report==actual,'actual daily CDE audit report rebound')
    return actual


def calendar(raw,n):
    candidates=[];prefix=struct.pack('<2i',1,n);pos=raw.find(prefix)
    while pos>=0:
        if pos+160<=len(raw):
            h=struct.unpack_from('<20i',raw,pos);nr=h[3]
            if nr>100 and pos+160+16*nr+24+16*(20+n)==len(raw) and h==struct.unpack_from('<20i',raw,pos+80):candidates.append((pos,h,nr))
        pos=raw.find(prefix,pos+1)
    require(len(candidates)==1,'actual CDE complete calendar shape/witness/EOF differs')
    return candidates[0]


def native(raw,row,n,selected,epoch='2002-01-01'):
    hys=selected['swhyst'];snow=selected['swsnow'];require(raw[:8]==CODECS[2 if snow else int(hys>0)].encode(),'actual CDE codec differs')
    c,h,nr=calendar(raw,n);values=None
    if snow:
        domain=struct.pack('<10i',1,n,0,1,hys,1,0,1,1,2);head=struct.pack('<4i',1,n,1,7)
        require(raw.count(domain+domain)==raw.count(head+head)==1,'actual CDE Snow domain differs');d=raw.index(head+head)
        require(d==raw.index(domain+domain)+80 and d+88==c,'actual CDE Snow/domain/calendar placement differs')
        values=list(struct.unpack_from('<7d',raw,d+32));require(all(finite(x) and x>=0 for x in values),'actual CDE Snow totals invalid')
    elif hys:
        domain=struct.pack('<5i',1,n,0,hys,1);require(raw.count(domain+domain)==1 and raw[c-40:c]==domain+domain,'actual CDE hysteresis domain differs')
    require(h[:2]==(1,n) and (h[4],h[5],h[6],h[8],h[11],h[18],h[19])==(1,selected['nprintday'],row['day'],1 if selected['flprintdt'] else row['day']*selected['nprintday']+1,selected['swres'],1,int(selected['flprintdt']))
        and all(1<=x<=nr for x in h[9:11]) and all(x in (0,1) for x in h[12:20]),'actual CDE calendar policy/day differs')
    completed=date.fromisoformat(epoch)+timedelta(days=row['day']-1)
    expected_counter=min(row['day'],completed.timetuple().tm_yday) if selected['flprintdt'] and selected['swres'] else row['day'] if selected['flprintdt'] else 0
    require(h[7]==expected_counter,'actual original CDE period counter differs')
    first=raw[c+160:c+160+8*nr];require(first==raw[c+160+8*nr:c+160+16*nr],'actual CDE calendar values witness differs')
    cal=struct.unpack('<'+str(nr)+'d',first);require(all(map(math.isfinite,cal)) and cal[-1]>=0,'actual CDE calendar nonfinite/negative')
    require(nr>=6008 and all(1<=x<=3000 for x in h[9:11]),'actual original date table/pointer domain differs')
    balance=cal[-6008:-3008];interval=cal[-3008:-8];clock=selected['original_output_epoch']+row['day']
    expected=1 if 0<interval[0]<selected['original_output_epoch']-1e-8 else 1+sum(0<x<clock-1e-8 for x in interval)
    require(h[9]==1+sum(0<x<clock-1e-8 for x in balance),'actual original balance date pointer differs')
    initial_past=0<interval[0]<selected['original_output_epoch']-1e-8
    require(h[10]==1 if initial_past else h[10]<=expected if selected['flprintdt'] else h[10]==expected,'actual original pending calendar pointer differs')
    cp=c+160+16*nr;size=20+n
    require(struct.unpack_from('<3i',raw,cp)==struct.unpack_from('<3i',raw,cp+12)==(2,n,size),'actual CDE private-state domain differs')
    first=raw[cp+24:cp+24+8*size];require(first==raw[cp+24+8*size:],'actual CDE private values witness differs')
    state=struct.unpack('<'+str(size)+'d',first);require(all(map(math.isfinite,state)) and state[0]>=0 and state[-2]>=0,'actual private CDE interval state invalid')
    conserved=struct.unpack_from('<'+str(n+2)+'d',raw,48);require(all(finite(x) and x>=0 for x in conserved),'actual original conserved CDE state invalid')
    actual=conserved[-1];require(actual==row['solute_end_mg_cm2'] and actual-state[-2]==state[14],'actual private CDE anchor or physical SAMPRO rebound')
    return dict(domain_bytes=80 if snow else 40 if hys else 0,calendar_header=list(h),calendar_offset=c,global_day=row['day'],period_counter=h[7],cde_state_offset=cp,cde_state_values=list(state),actual_native_stock_mg_cm2=actual,actual_private_interval_anchor=state[-2],actual_private_rounderr=state[-1],snow_output_values=values)


def checkpoint(z,path,build,row,selected):
    with zipfile.ZipFile(io.BytesIO(z.read(path))) as cp:
        require(set(cp.namelist())=={'checkpoint.json','result.end','macro.bin'},'actual CDE checkpoint members differ')
        meta=read(cp,'checkpoint.json');require(meta['schema']=='swap5-hybrid-water-checkpoint-3' and meta['binding']==build['binding'] and meta['receipt']==row,'actual CDE checkpoint receipt/binding differs')
        for name,value in meta['files'].items():require(digest(cp.read(name))==value,'actual CDE native file receipt changed')
        raw=cp.read('macro.bin');return {name:cp.read(name) for name in ('result.end','macro.bin')},native(raw,row,build['project']['nodes'],selected,build['project']['start_date'])


def period(report,case,opt,phase,build,build_digest):
    mode,hys,fmt,reset,et,snow,source,rain,npd,perstep,_=case;days={'full':1096,'short':35,'limit':2}[phase];s=build['identity']['original_output']
    require(report['status']=='ACTUAL_CDE_CLOCK_'+phase.upper()+'_NATIVE_USER_OUTPUT_PASS'
      and (report['mode'],report['hysteresis'],report['format'],report['reset'],report['et'],report['snow'],report['source'],report.get('rain'),report['nprintday'],report['perstep'],report['optimization'])==(mode,hys,fmt,reset,et,snow,source,rain,npd,perstep,opt),'actual CDE clock period/domain differs')
    require(report['functional_completion']=='PARTIAL' and report['whole_scientific_equivalence']=='NOT_QUALIFIED' and report['requested_controls_preserved'] is True,'CDE clock scope promoted/controls changed')
    require(report['trajectory']['days']==report['trajectory']['budgets']['days']==days and report['trajectory']['build_sha256']==build_digest,'actual CDE clock period censored/build rebound')
    require(all(bounded(report['trajectory']['budgets'][k]) for k in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')),'actual clock budget exceeds unchanged guard')
    require(s==report['original_output'] and s['policy']=='original-cde-clock-output-and-observed-daily-flux-v1' and s['native_codec']==CODECS[2 if snow else int(hys>0)]
      and s['cde_interval_output'] is s['cde_clock_output'] is s['original_pending_dates_not_normalized'] is True and s['physical_equations_changed'] is False
      and s['clock_event_coincidence_policy']=='actual-local-irrigation-and-end-day-existing-dtcrit-v1' and s['clock_event_dtcrit']==1e-8
      and s['clock_event_closure_source_sha256']==sha(ROOT/'app/hybrid_water/cde_clock_events.f90')
      and s['calendar_initial_past_date_policy']==('original-initial-pending-one-and-perstep-nonfuture-pointer-v1' if perstep else 'original-initial-interval-pointer-remains-one-v1')
      and s['cde_output_state_version']==2 and s['cde_output_state_reals']==20+build['project']['nodes'] and s['cde_output_state_private_reals']==2
      and s['cde_daily_mass_guard_mg_cm2']==build['project']['water_tolerance']==1e-10
      and (s['swsnow'],s['swhyst'],s['swcsv'],s['swmonth'],s['swodat'],s['swres'],s['period'],s['nprintday'],s['flprintdt'])==(snow,hys,fmt,int(mode=='monthly'),int(mode=='explicit'),0 if mode=='monthly' else reset,1,npd,perstep),'compiled actual CDE clock policy differs')
    require(all('-'+opt in build['identity'][k] for k in ('donor_flags','kernel_flags')) and build['identity']['water_polish_policy']=='strict-water-always-polish-v1','clock numerical policy differs')
    windows={(1,2)} if phase=='limit' else {(2,4),(4,8),(19,23),(30,34)}
    if phase=='full':windows|={(199,201),(364,367),(530,532),(1094,1096)}
    require({(v['start'],v['end']) for v in report['cold']}==windows,'actual clock cold window omitted')
    require(all(v['exact_physical'] is v['exact_complete_native'] is v['origin_unchanged'] is True and all(f['exact'] is True for f in v['exact_user_output'].values()) for v in report['cold']),'actual clock cold result differs')
    require(len(report['actual_fixed_incoming_mg_cm2'])==2 and all(abs(x-y)<=1e-10 for x,y in zip(report['actual_fixed_incoming_mg_cm2'],[48.,72.])),'actual unchanged planned clock source dose differs')
    if rain is not None and phase!='limit':require(report['actual_rain_chemical_mg_cm2']>0,'selected positive rain absent')


def event_rows(z,prefix):
    result=[]
    for line in z.read(prefix+'original/donor.stdout').decode('utf8').splitlines():
        if not line.startswith('CDE_CLOCK_EVENT_CLOSURE '):continue
        v=list(map(float,line.split()[1:]));require(len(v)==7 and all(map(finite,v)) and v[4]==1e-8,'actual local clock event audit malformed')
        tcum,old_dt,old_limit,irrigation,crit,new_dt,new_limit=v
        target=irrigation if tcum<irrigation<1 else 1.;remaining=target-tcum
        require(remaining>0 and abs(old_limit-remaining)<=crit and new_limit==remaining,'actual local event cap not closed at original coincidence')
        require(new_dt==(remaining if abs(old_dt-remaining)<=crit else old_dt) and (new_dt!=old_dt or new_limit!=old_limit),'actual local candidate timestep closure differs')
        result.append(v)
    return result


def user_outputs(z,prefix,report,days,epoch,temporary):
    from original_output_files import records
    from cde_clock_runtime import timestamp
    from datetime import datetime
    actual={}
    for name,inventory in report['user_output'].items():
        path=temporary/('user'+Path(name).suffix);path.write_bytes(z.read(prefix+'trajectory/original/'+name));values=records(path)
        def stamp(row):return row[:19].decode('ascii').strip() if isinstance(row,bytes) else row.split(',')[0].strip()
        stamps=[stamp(v) for v in values];dates=[timestamp(s) for s in stamps]
        require(inventory==dict(records=len(values),stamps=stamps) and dates==sorted(dates) and dates[0]==datetime.fromisoformat(epoch),'actual original date-only output inventory differs')
        if days==1096:require(dates[-1]==datetime(2005,1,1),'actual CDE clock TEND output omitted')
        for w in report['cold']:
            start,end=w['start'],w['end'];path.write_bytes(z.read(prefix+f'own-{start}/original/'+name));cold=records(path)
            low=str(date.fromisoformat(epoch)+timedelta(days=start));high=str(date.fromisoformat(epoch)+timedelta(days=end))
            expected=[v for v in values[1:] if low+' 00:00:00'<stamp(v)<=high+' 00:00:00']
            require(bool(cold) and cold[1:]==expected and w['exact_user_output'][name]['continuation_records']==len(expected),'actual CDE sparse cold user records differ')
        actual[name]=values
    return actual


def preserved_period(key,item,data):
    # All selected current interval, water-clock and dense seams are35day drivers.
    days=35
    require(item['trajectory']['days']==len(data)==days and [row['day'] for row in data]==list(range(1,days+1)) and all(row['committed'] is True for row in data),'fresh seam trajectory censored')


def verify():
    import importlib.util
    spec=importlib.util.spec_from_file_location('age_perstep_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_perstep_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty CDE admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'CDE production differs from qualified source')
    q=json.loads((ROOT/PROOF/'CDE_CLOCK_QUALIFICATION.json').read_text(encoding='utf8'));validate(q)
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==set(q['source_sha256']),'unqualified CDE production surface')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,identity in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'immutable CDE/predecessor evidence changed: '+path)
    docs={'docs/science/NOMACRO_CDE_CLOCK_20261119.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,*docs,PROOF+'CDE_CLOCK_MERGE_RECEIPT.json'},'unqualified CDE post-seal change')
    require((ROOT/ENTRY).read_text(encoding='utf8').replace(HOOK,'',1).encode()==blob(BASE,ENTRY).replace(b'\r\n',b'\n'),'literal predecessor owner body changed')
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'actual CDE model producer source differs')
    for workflow in q['workflows'].values():require(set(git('diff','--name-only',workflow['runtime'],workflow['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'CDE carrier changes model source')
    prior=predecessor();archives={}
    for key,record in q['archives'].items():
        z=zipfile.ZipFile(io.BytesIO(raw_archive(record)));require(set(z.namelist())==set(record['members']),'actual CDE archive member omitted')
        for name,value in record['members'].items():require(digest(z.read(name))==value,'actual CDE producer member changed')
        archives[key]=z
    sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'));from cde_clock_ci import CASES,CONTROLS,PROVIDER_POISONS,LIMITS
    from perstep_domain_verify import build_files
    fulls=colds=refusals=policies=providers=preserved=epochs=epoch_cold=aliases=limits=limit_cold=year_refusals=0
    for platform,opts in q['main'].items():
        for opt,location in opts.items():
            z=archives[location['archive']];prefix=location['prefix'];run=read(z,prefix+'RESULT.json')
            require(run['status']=='TEN_CDE_CLOCK_SHORT_SIX_FULL_SIX_NATIVE_FOUR_LIMIT_CONTEXTS_PASS' and run['all_short_native_limit_gates_precede_full'] is True and set(run['cases'])==set(CASES) and set(run['controls'])==set(CONTROLS),'actual CDE main cohort censored')
            require(run['format_independence']==dict(all35_physical_chemical_days_exact=True,five_complete_native_payloads_exact=True),'actual CDE format physics changed')
            def locate(path):
                return PureWindowsPath(path).relative_to(PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/' if platform=='Windows' else PurePosixPath(path).relative_to(PurePosixPath(location['producer_root'])).as_posix()+'/'
            for key,case in CASES.items():
                item=run['cases'][key];bp=locate(item['build_root']);buildraw=z.read(bp+'BUILD.json');build=json.loads(buildraw);bd=digest(buildraw);build_files(z,bp,build)
                for name,value in build['inputs'].items():require(digest(z.read(locate(item['input_root'])+name))==value,'actual CDE input changed')
                for path,value in build['identity']['kernel_sources']:require(kernel_checkout_digest(path,build['identity']['target'])==value,'actual physical CDE kernel source changed: '+path)
                require(build['identity']['original_output']['source_sha256']==q['source_sha256']['app/hybrid_water/cde_clock_output.py'],'compiled CDE owner source differs')
                for phase in ('short','full'):
                    if phase=='full' and not case[-1]:continue
                    report=item[phase];pp=locate(item[phase+'_root']);period(report,case,opt,phase,build,bd);days=1096 if phase=='full' else 35
                    data=rows(z,pp+'trajectory/');ledger(data,days);daily(z,pp+'trajectory/',data,build['project']['nodes'],report['daily_chemical_receipts']);event_rows(z,pp+'trajectory/')
                    with tempfile.TemporaryDirectory(prefix='s5-cde-user-') as directory:user_outputs(z,pp,report,days,build['project']['start_date'],Path(directory))
                    require(data[4]['solute_ledger_mg_cm2'][3]==report['actual_fixed_incoming_mg_cm2'][0] and data[6]['solute_ledger_mg_cm2'][3]==report['actual_fixed_incoming_mg_cm2'][1],'actual incoming worker source rebound')
                    for day,inventory in report['native_domains'].items():
                        _,actual=checkpoint(z,pp+f'trajectory/accepted-column-1-day-{day}.zip',build,data[int(day)-1],build['identity']['original_output']);require(set(inventory)=={'calendar_offset','calendar_header','cde_state_offset','cde_state_values','actual_native_stock_mg_cm2','actual_private_interval_anchor','actual_private_rounderr'} and all(actual[k]==v for k,v in inventory.items()),'actual private clock native inventory rebound')
                    for window in report['cold']:
                        start,end=window['start'],window['end'];actual=rows(z,pp+f'own-{start}/');ledger(actual,end-start);daily(z,pp+f'own-{start}/',actual,build['project']['nodes'])
                        require(physical(actual)==physical(data[start:end]),'actual CDE cold physical trajectory differs')
                        warm,_=checkpoint(z,pp+f'trajectory/accepted-column-1-day-{end}.zip',build,data[end-1],build['identity']['original_output'])
                        cold,_=checkpoint(z,pp+f'own-{start}/accepted-column-1-day-{end}.zip',build,actual[-1],build['identity']['original_output']);require(warm==cold,'actual CDE complete cold native differs');colds+=1
                    if phase=='full':fulls+=1
                if key in CONTROLS:
                    control=run['controls'][key];report=read(z,locate(control['root'])+'RESULT.json');require(report==control['report'] and report['status']=='CDE_CLOCK_NATIVE_ACTIVE_POLICY_PROVIDER_PASS' and report['build_sha256']==bd,'actual CDE native control rebound')
                    require(len(report['native_refusals'])==(80 if case[5] else 56 if case[1] else 50) and len(report['policy_refusals'])==(72 if case[5] else 66),'actual CDE native/policy attack omitted')
                    require(all(v['status']=='REFUSED' for v in report['native_refusals']+report['policy_refusals']+report['actual_provider_refusals']) and all(v is True for v in report['transactions'].values()),'actual CDE invalid state/transaction accepted')
                    require(len(report['actual_provider_refusals'])==((7 if case[5] else 6) if key in PROVIDER_POISONS else 0),'actual CDE provider selection rebound')
                    cp=locate(control['root'])
                    for attack in report['native_refusals']:
                        ap=cp+'native/'+attack['attack']+'/'
                        diagnostic='\n'.join(z.read(name).decode('utf8') for name in z.namelist() if name.startswith(ap) and name.endswith('donor.stderr'))
                        require('ERROR STOP' in diagnostic and diagnostic.replace('\r\n','\n')==attack['diagnostic'].replace('\r\n','\n') and not any(name.startswith(ap) and Path(name).name.startswith('accepted-') and name.endswith('.zip') for name in z.namelist()),'actual invalid CDE native worker evidence differs')
                        try:native(z.read(ap+'origin/macro.bin'),rows(z,locate(item['short_root'])+'trajectory/')[3],build['project']['nodes'],build['identity']['original_output'],build['project']['start_date'])
                        except (ValueError,struct.error):pass
                        else:raise ValueError('Actual forged CDE native independently accepted: '+attack['attack'])
                    for attack in report['policy_refusals']:
                        bad=read(z,cp+'policy-'+attack['field']+'/BUILD.json');expected=json.loads(buildraw);expected['identity']['original_output'][attack['field']]='foreign';require(bad==expected,'actual CDE policy refusal producer changed')
                    for attack in report['actual_provider_refusals']:
                        ap=cp+'actual-provider-'+attack['provider']+'/'
                        require(attack['actual_original_metadata_unchanged'] is True and z.read(ap+'BUILD.json')==buildraw and digest(z.read(ap+attack['provider']))!=build['identity']['donor_generated'][attack['provider']],'actual CDE provider refusal not physical source mutation')
                    reference=rows(z,locate(item['short_root'])+'trajectory/');replay=[]
                    for trial,day in [('external/trial-1',5),('external/trial-2',5),('recovered/trial-1',6)]:
                        tp=cp+'active/'+trial+'/'
                        with zipfile.ZipFile(io.BytesIO(z.read(tp+f'accepted-column-1-day-{day}.zip'))) as nativezip:actualrow=read(nativezip,'checkpoint.json')['receipt']
                        require(physical([actualrow])==physical([reference[day-1]]),'actual CDE discard/replay/recovery physical receipt differs')
                        payload,_=checkpoint(z,tp+f'accepted-column-1-day-{day}.zip',build,actualrow,build['identity']['original_output']);daily(z,tp,[actualrow],build['project']['nodes'])
                        if day==5:replay.append(payload)
                    require(replay[0]==replay[1],'actual rejected CDE trial changed replay native state')
                    refusals+=len(report['native_refusals']);policies+=len(report['policy_refusals']);providers+=len(report['actual_provider_refusals'])
    for platform,opts in q['main'].items():
        for opt,location in opts.items():
            z=archives[location['archive']];run=read(z,location['prefix']+'RESULT.json');require(set(run['limits'])==set(LIMITS),'actual four clock limit domains omitted')
            def limit_path(value):
                return PureWindowsPath(value).relative_to(PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/' if platform=='Windows' else PurePosixPath(value).relative_to(PurePosixPath(location['producer_root'])).as_posix()+'/'
            for key,case in LIMITS.items():
                item=run['limits'][key];pp=limit_path(item['root']);report=read(z,pp+'RESULT.json');require(report==item['report'],'actual clock limit report rebound')
                bp=limit_path(report['build_root']);buildraw=z.read(bp+'BUILD.json');build=json.loads(buildraw);build_files(z,bp,build);period(report,case,opt,'limit',build,digest(buildraw))
                data=rows(z,pp+'trajectory/');ledger(data,2);daily(z,pp+'trajectory/',data,build['project']['nodes'],report['daily_chemical_receipts']);event_rows(z,pp+'trajectory/')
                for day in (1,2):checkpoint(z,pp+f'trajectory/accepted-column-1-day-{day}.zip',build,data[day-1],build['identity']['original_output'])
                actual=rows(z,pp+'own-1/');ledger(actual,1);daily(z,pp+'own-1/',actual,build['project']['nodes']);require(physical(actual)==physical(data[1:2]),'actual1440 limit cold differs')
                warm,_=checkpoint(z,pp+'trajectory/accepted-column-1-day-2.zip',build,data[1],build['identity']['original_output']);cold,_=checkpoint(z,pp+'own-1/accepted-column-1-day-2.zip',build,actual[0],build['identity']['original_output']);require(warm==cold,'actual1440 complete cold native differs')
                with tempfile.TemporaryDirectory(prefix='s5-cde-clock-limit-user-') as directory:user_outputs(z,pp,report,2,build['project']['start_date'],Path(directory))
                if 'retained_post_validation_failure' in report:
                    retained=report['retained_post_validation_failure'];raw=z.read(pp+retained['path']);old=json.loads(raw)
                    require(digest(raw)==retained['sha256'] and retained['no_model_or_build_reexecution'] is True and old['status']=='FAILED' and old['error']=='AssertionError()' and old['source_commit']==report['source_commit'] and old['trajectory']==report['trajectory'] and old['actual_rain_chemical_mg_cm2']==0 and report['bounded_rain_coverage']=='NO_RAIN_IN_SELECTED_TWO_DAY_FORCING_POSITIVE_RAIN_SELECTED_IN_35DAY_COHORT','actual dry-bound postvalidation failure hidden/rebound')
                limits+=1;limit_cold+=1
    # Context readers, epoch execution, public commands, alias workers and preservation are bound below.
    for location in q['contexts']:
        z=archives[location['archive']];prefix=location['prefix'];kind=location['kind'];report=read(z,prefix+'RESULT.json')
        if kind=='epoch':
            require(report['status']=='EIGHT_NONJANUARY_CDE_CLOCK_EPOCHS_BOTH_RESET_NATIVE_COLD_PASS' and len(report['cases'])==8,'actual CDE non-January cohort censored')
            for key,item in report['cases'].items():
                pp=prefix+key+'/actual/';buildraw=z.read(pp+'build/BUILD.json');build=json.loads(buildraw);build_files(z,pp+'build/',build);r=item['report'];case=('explicit',2,3,item['reset'],0,item['snow'],'interval' if item['snow'] else 'point',None,item['nprintday'],item['perstep'],False)
                period(r,case,location['optimization'],'short',build,digest(buildraw));data=rows(z,pp+'trajectory/');ledger(data,35);daily(z,pp+'trajectory/',data,build['project']['nodes'],r['daily_chemical_receipts'])
                with tempfile.TemporaryDirectory(prefix='s5-cde-epoch-user-') as directory:user_outputs(z,pp,r,35,item['epoch'],Path(directory))
                require(build['project']['start_date']==item['epoch'] and len(item['actual_native_counters'])==8,'actual CDE immutable epoch rebound')
                for inventory in item['actual_native_counters']:
                    day=inventory['day'];_,observed=checkpoint(z,pp+f'trajectory/accepted-column-1-day-{day}.zip',build,data[day-1],build['identity']['original_output'])
                    require(inventory['actual_private_anchor']==observed['actual_private_interval_anchor'] and inventory['actual_private_rounderr']==observed['actual_private_rounderr'] and inventory['actual_samini']==observed['cde_state_values'][0] and inventory['actual_sdstor']==observed['cde_state_values'][14] and inventory['period_counter']==observed['period_counter'],'actual epoch private state differs')
                for w in r['cold']:
                    start,end=w['start'],w['end'];actual=rows(z,pp+f'own-{start}/');ledger(actual,end-start);daily(z,pp+f'own-{start}/',actual,build['project']['nodes']);require(physical(actual)==physical(data[start:end]),'actual CDE epoch cold differs')
                    warm,_=checkpoint(z,pp+f'trajectory/accepted-column-1-day-{end}.zip',build,data[end-1],build['identity']['original_output']);cold,_=checkpoint(z,pp+f'own-{start}/accepted-column-1-day-{end}.zip',build,actual[-1],build['identity']['original_output']);require(warm==cold,'actual CDE epoch native differs');epoch_cold+=1
                epochs+=1
        elif kind=='alias':
            require(report['status']=='SIX_ACTUAL_NONZERO_CDE_CLOCK_ALIAS_FORGERIES_REFUSED' and {v['attack'] for v in report['checks']}=={'anchor-from-cumulative-samini','shifted-anchor','negative-anchor','nonfinite-anchor','nonfinite-rounderr','changed-interval-stock-delta'},'actual CDE alias attack omitted')
            for attack in report['checks']:
                require(attack['status']=='REFUSED' and abs(attack['actual_anchor']-attack['actual_samini'])>1 and 'ERROR STOP' in attack['diagnostic'],'actual nonzero interval alias accepted')
                ap=prefix+attack['attack']+'/';diagnostic='\n'.join(z.read(name).decode('utf8') for name in z.namelist() if name.startswith(ap) and name.endswith('donor.stderr'))
                require(diagnostic.replace('\r\n','\n')==attack['diagnostic'].replace('\r\n','\n') and not any(name.startswith(ap) and Path(name).name.startswith('accepted-') and name.endswith('.zip') for name in z.namelist()),'actual alias worker evidence differs');aliases+=1
        elif kind=='public':
            require(report['status']=='SIX_PUBLIC_CDE_CLOCK_SELF_CONTAINED_RESTART_CONTEXTS_PASS' and len(report['profiles'])==6,'actual public CDE cohort censored')
            for key,item in report['profiles'].items():
                require(item['physical_exact'] is item['complete_native_exact'] is item['origin_unchanged'] is True and item['warm']['returncode']==item['cold']['returncode']==0,'actual public CDE command failed')
                data=rows(z,prefix+key+'/warm/');actual=rows(z,prefix+key+'/cold/');ledger(data,35);ledger(actual,4);require(physical(actual)==physical(data[30:34]),'actual public CDE physical cold differs')
        elif kind=='year-controls':
            require(report['status']=='THIRTY_TWO_ACTUAL_CDE_CLOCK_POST_YEAR_COUNTER_FORGERIES_REFUSED' and len(report['cases'])==8,'actual postyear clock counter attacks censored')
            epoch_report=read(z,location['epoch_prefix']+'RESULT.json')
            for key,item in report['cases'].items():
                epoch=epoch_report['cases'][key];pp=location['epoch_prefix']+key+'/actual/';build=read(z,pp+'build/BUILD.json');source=z.read(pp+'trajectory/accepted-column-1-day-30.zip');require(digest(source)==item['source_sha256'] and len(item['checks'])==4,'actual postyear origin rebound')
                row=rows(z,pp+'trajectory/')[29]
                with zipfile.ZipFile(io.BytesIO(source)) as cp:original=cp.read('macro.bin')
                pos,header,_=calendar(original,build['project']['nodes'])
                for attack in item['checks']:
                    ap=prefix+key+'/'+attack['attack']+'/'
                    diagnostic='\n'.join(z.read(name).decode('utf8') for name in z.namelist() if name.startswith(ap) and name.endswith('donor.stderr'))
                    require(attack['status']=='REFUSED' and attack['day']==30 and attack['actual_counter']==header[7] and attack['forged_counter']!=header[7] and diagnostic.replace('\r\n','\n')==attack['diagnostic'].replace('\r\n','\n') and 'ERROR STOP' in diagnostic,'actual postyear counter worker differs')
                    require(not any(name.startswith(ap) and Path(name).name.startswith('accepted-') and name.endswith('.zip') for name in z.namelist()),'forged postyear worker published accepted state')
                    expected=bytearray(original)
                    for offset in (28,108):struct.pack_into('<i',expected,pos+offset,attack['forged_counter'])
                    actual=z.read(ap+'origin/macro.bin');require(actual==expected,'actual paired postyear counter mutation rebound')
                    try:native(actual,row,build['project']['nodes'],build['identity']['original_output'],epoch['epoch'])
                    except ValueError:pass
                    else:raise ValueError('Actual forged postyear clock counter independently accepted')
                    year_refusals+=1
        elif kind=='reader':require(report['status']=='SEVEN_CDE_CLOCK_READER_THIRTEEN_LITERAL_PARTITIONS_PASS' and len(report['reader_refusals'])==7 and len(report['literal_delegations'])==13,'actual original reader/partition cohort censored')
        elif kind=='component':
            require(report['status'] in ('ACTUAL_CDE_CLOCK_LOCAL_EVENT_COMPONENT_O0_O2_PASS','ACTUAL_CDE_CLOCK_LOCAL_EVENT_COMPONENT_PASS') and set(report['cases'])==({location['optimization']} if location.get('optimization') else {'O0','O2'}) and all(v['compile_returncode']==v['run_returncode']==0 for v in report['cases'].values()),'actual small production receipt incomplete')
            for opt,value in report['cases'].items():
                require(digest(z.read(prefix+opt+'/receipt.exe'))==value['executable_sha256'] and 'ACTUAL_CDE_CLOCK_LOCAL_EVENT_INTERFACE_PASS' in z.read(prefix+opt+'/run.stdout').decode('utf8'),'actual compiled local event driver output/binary differs')
        else:raise ValueError('Foreign CDE context kind')
    for location in q['preservation'].values():
        z=archives[location['archive']]
        for prefix,count in location['profiles'].items():
            report=read(z,prefix+'/RESULT.json');require('PASS' in report['status'] and len(report['profiles'])==count,'selected actual CDE seam preservation incomplete')
            for key,item in report['profiles'].items():
                require(item['all_physical_exact'] is item['actual_immutable_prior_member_hashes'] is True,'actual preserved CDE seam differs')
                pp=prefix+'/'+key+'/';build=read(z,pp+'build/BUILD.json');require(build==item['actual_build'],'actual fresh seam build differs');build_files(z,pp+'build/',build)
                for path,value in build['identity']['kernel_sources']:require(kernel_checkout_digest(path,build['identity']['target'])==value,'preserved actual physical kernel source differs: '+path)
                data=rows(z,pp+'trajectory/');preserved_period(key,item,data)
                for row in data:
                    water=math.fsum([*row['external_flux_cm'][:7],*(-v for v in row['external_flux_cm'][7:]),*row['stock_start_cm'],*(-v for v in row['stock_end_cm'])])
                    require(bounded(water) and bounded(row['independent_residual_cm']) and bounded(row['kernel_residual_cm']),'actual preserved seam water guard exceeded')
                preserved+=1
    observations=archives[q['observations_archive']]
    comparison=q['event_comparison'];require(comparison['status']=='ACTUAL_LOCAL_EVENT_CLOSURE_FIRST_1440_SOURCE_NATIVE_O0_O2_PASS' and comparison['scientific_claim'] is False,'actual event correction observation promoted')
    for opt,item in comparison['cases'].items():
        old=f'cde-clock-windows-{opt}-v1/limit-ordinary-subdaily/';location=q['main']['Windows'][opt];z=archives[location['archive']];new=f'cde-clock-limit-ordinary-subdaily-{opt}-v2/'
        a=read(observations,old+'build/BUILD.json');b=read(z,new+'build/BUILD.json')
        require(a['project']==b['project'] and a['inputs']==b['inputs'],'actual event correction changes forcing/project')
        for key in ('kernel_sources','kernel_flags','donor_flags'):require(a['identity'][key]==b['identity'][key],'event correction changes actual physical kernel/flags')
        require([key for key in a['identity']['donor_generated'] if a['identity']['donor_generated'][key]!=b['identity']['donor_generated'][key]]==['timecontrol.f90'] and set(b['identity']['donor_generated'])-set(a['identity']['donor_generated'])=={'cde_clock_events.f90'},'event correction changes other generated physics')
        left=read(observations,old+'RESULT.json');right=read(z,new+'RESULT.json');require(left['status']=='FAILED' and left['error']=='AssertionError()' and left['actual_fixed_incoming_mg_cm2']==item['old_actual_source_mg_cm2'] and right['actual_fixed_incoming_mg_cm2']==item['new_actual_source_mg_cm2'],'actual old/new source dose observation differs')
        require(any(abs(x-y)>1e-10 for x,y in zip(left['actual_fixed_incoming_mg_cm2'],[48.,72.])) and all(abs(x-y)<=1e-10 for x,y in zip(right['actual_fixed_incoming_mg_cm2'],[48.,72.])),'actual source event failure hidden or dose tolerance relaxed')
        require(event_rows(z,new+'trajectory/')==item['actual_local_event_closure_rows'] and bool(item['actual_local_event_closure_rows']),'actual local event observation rebound')
    for path,value in q['component_inheritance']['providers'].items():require(sha(ROOT/path)==value,'literal private CDE/receipt provider component changed')
    require(q['component_inheritance']['fresh_pass_claim'] is False,'old unchanged component relabelled fresh')
    require((fulls,colds,refusals,policies,providers,preserved,epochs,epoch_cold,aliases,limits,limit_cold,year_refusals)==(24,352,1608,1656,52,21,32,128,48,16,16,128),'actual CDE scientific/native denominator differs')
    return dict(status='ORIGINAL_CDE_CLOCK_LOCAL_EVENT_PRIVATE_STATE_NATIVE_ADMISSION_PASS',runtime=RUNTIME,predecessor=prior,actual_full_periods=fulls,actual_main_cold_windows=colds,actual_native_refusals=refusals,actual_policy_refusals=policies,actual_provider_refusals=providers,actual_preserved_contexts=preserved,actual_non_january_periods=epochs,actual_epoch_cold_windows=epoch_cold,actual_nonzero_private_alias_refusals=aliases,actual_1440_two_day_periods=limits,actual_1440_cold_windows=limit_cold,actual_postyear_counter_refusals=year_refusals,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')


if __name__=='__main__':print(json.dumps(verify(),indent=2))
