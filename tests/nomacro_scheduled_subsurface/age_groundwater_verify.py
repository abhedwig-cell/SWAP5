"""Independent original AGE perstep source, actual flux and private native proof."""
from pathlib import Path,PureWindowsPath,PurePosixPath
from datetime import date,datetime,timedelta
from functools import lru_cache
import csv,hashlib,io,json,math,re,struct,subprocess,sys,tarfile,tempfile,zipfile

ROOT=Path(__file__).resolve().parents[2]
PROOF='integration/f-ci/nomacro-complete01/'
BASE='ae88b7a53eb4ea66168b5728cb21c674989be95c'
RUNTIME='11ef02b1eb6d6a6e49655219229a01a8a60748de'
SEALED='9a95176a9ee5b34e5cdf3772fc3a6b5069d93388'
ENTRY='tests/nomacro_scheduled_subsurface/age_perstep_verify.py'
SELF='tests/nomacro_scheduled_subsurface/age_groundwater_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_age_groundwater_verify.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('age_groundwater_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_groundwater_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
CODECS=['S5GAO001','S5GAH001']
AGE_POLICY='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)'
SCOPE=dict(macro=0,solute=2,age=True,young_water=True,age_irrigation_source=False,age_direct_soil_source=False,
 snow=0,heat=1,thermal_method=2,hysteresis=[0,1,2],hydraulic_family=0,drainage=[0,1],lower_boundary=1,frost=0,aquifer=0,detailed_weather=0,
 nprintday=[1,1440],per_step=[False,True],reset=[0,1],calendars=['monthly','explicit-date','PERIOD0','PERIOD1..366'],formats=[0,1,2,3],et=[0,1],sources=['point','interval','surface','sprinkler'],
 boundary_files=[False,True],levels=['within','below','crossing'],physical_equations_changed=False,
 hydraulic_state='actual h/theta/k/kmean/dimoca/gwl/volact and complete paired process domain; accepted receipt before worker and publication',
 private_reset_flags='actual saved logical representations equal calendar13/14',literal_partitions='nonAGE/nonSWBOTB1/explicit corrected incoming AGE source policies remain outside new family')


def require(ok,message='actual original AGE proof differs'):
    if not ok:raise ValueError(message)

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def digest(raw):return hashlib.sha256(raw).hexdigest()
def sha(path):return digest(path.read_bytes().replace(b'\r\n',b'\n'))
def finite(v):return type(v) in (int,float) and math.isfinite(v)
def bounded(v):return finite(v) and abs(v)<=1e-10
def tolerance(*v):return 8192*sys.float_info.epsilon*max(1.,*map(abs,v))
def tree(ref,path):return {v.split('\t',1)[1]:v.split('\t',1)[0] for v in git('ls-tree','-r',ref,'--',path).decode().splitlines()}
def read(z,path):return json.loads(z.read(path))
def rows(z,path):return [json.loads(v) for v in z.read(path+'daily.jsonl').splitlines()]
def physical(data):return [{k:v for k,v in r.items() if k not in ('column','revision')} for r in data]


@lru_cache(maxsize=None)
def kernel_checkout_digest(path,target):
    raw=blob(RUNTIME,path)
    if target=='x86_64-w64-mingw32':raw=raw.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')
    else:require(target=='x86_64-linux-gnu','foreign actual compiler target')
    return digest(raw)


def raw_archive(record):
    if 'byte_parts' in record:
        chunks=[];offset=0
        for part in record['byte_parts']:
            require(part['offset']==offset and Path(part['path']).name==part['path'],'foreign AGE archive byte part')
            raw=(ROOT/PROOF/part['path']).read_bytes();require(len(raw)==part['bytes'] and digest(raw)==part['sha256'],'changed AGE archive byte part');chunks.append(raw);offset+=len(raw)
        raw=b''.join(chunks)
    else:raw=(ROOT/PROOF/record['archive']).read_bytes()
    require(len(raw)==record['bytes'] and digest(raw)==record['sha256'],'original AGE raw archive changed')
    if 'origin_artifact' in record:require(record['origin_artifact']['digest']=='sha256:'+digest(raw) and record['origin_artifact']['size_in_bytes']==len(raw) and record['actual_artifact_bytes_preserved'] is True,'original AGE artifact rebound')
    return raw


def validate(q):
    require(q['status']=='BOUNDED_ORIGINAL_AGE_GROUNDWATER_QUALIFIED_PENDING_ADMISSION' and q['runtime']==RUNTIME and q['scope']==SCOPE,'AGE scope/runtime promoted or changed')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['release_readiness']=='RC3_QUALIFIED_FIXED_NAMED_PROFILES_ONLY','whole AGE science/release promoted')
    require(q['water_guard_cm']==1e-10 and q['chemical_mass_guard_mg_cm2']==1e-10 and q['age_tolerance']==AGE_POLICY and q['age_units']=='cm day' and q['native_codecs']==CODECS and q['process_domain_bytes']==[104,144],'unchanged AGE guards/units/domain differ')
    for group in ('source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
        require(q[group] and all(sha(ROOT/path)==value for path,value in q[group].items()),'changed sealed AGE source/controller: '+group)
    require(set(q['main'])=={'Windows','Ubuntu'} and all(set(v)=={'O0','O2'} for v in q['main'].values()) and set(q['preservation'])=={'Windows','Ubuntu'},'actual AGE platform denominator censored')
    require(len(q['archives'])==8 and all(v['all_members_forward_verified'] is True for v in q['archives'].values()),'actual original AGE archive denominator differs')
    require(q['not_selected_impact']['status']=='NOT_SELECTED_IMPACT' and q['not_selected_impact']['fresh_pass_claim'] is False and set(q['not_selected_impact']['reasons'])=={'non_age_early_return','non_groundwater_delegation','explicit_age_source_refusal','literal_physical_providers','unchanged_original_physics'},'unaffected campaigns relabelled fresh')


def predecessor():
    old=json.loads((ROOT/PROOF/'AGE_PERSTEP_QUALIFICATION.json').read_text(encoding='utf8'))
    paths={ENTRY,PROOF+'AGE_PERSTEP_QUALIFICATION.json',*old['source_sha256'],*old['controller_sha256'],*old['frozen_predecessor_sources'],*old['frozen_predecessor_controllers']}
    with tempfile.TemporaryDirectory(prefix='s5-age-perstep-parent-') as directory:
        snapshot=Path(directory).resolve();batches=[];batch=[];length=0
        for path in sorted(paths):
            if length+len(path)>12000:batches.append(batch);batch=[];length=0
            batch.append(path);length+=len(path)+3
        if batch:batches.append(batch)
        for batch in batches:
            with tarfile.open(fileobj=io.BytesIO(git('archive',BASE,'--',*batch))) as archive:
                for member in archive.getmembers():
                    if member.isdir():continue
                    target=snapshot/member.name;require(member.isfile() and target.resolve().is_relative_to(snapshot),'foreign literal predecessor path');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.extractfile(member).read())
        script="import importlib.util,json,pathlib;r=pathlib.Path.cwd();s=importlib.util.spec_from_file_location('literal',r/"+repr(ENTRY)+");m=importlib.util.module_from_spec(s);s.loader.exec_module(m);m.validate(json.loads((r/"+repr(PROOF+'AGE_PERSTEP_QUALIFICATION.json')+").read_text(encoding='utf8')));print('LITERAL_CANONICAL_AGE_PERSTEP_SOURCE_PASS')"
        p=subprocess.run([sys.executable,'-B','-c',script],cwd=snapshot,capture_output=True,text=True);require(p.returncode==0 and 'LITERAL_CANONICAL_AGE_PERSTEP_SOURCE_PASS' in p.stdout,'literal canonical predecessor invalid: '+p.stderr)
    for record in old['archives'].values():raw_archive(record)
    return 'LITERAL_ACTUAL_CANONICAL_AGE_PERSTEP_IMAGE_AND_UNCHANGED_RAW_PRODUCERS_PASS'


def ledger(data,days,initial=None):
    require(len(data)==days and days>0 and [r['day'] for r in data]==list(range(data[0]['day'],data[0]['day']+days)) and all(r['committed'] is True for r in data),'actual AGE trajectory censored')
    previous=initial
    for row in data:
        flow=row['external_flux_cm'];start=row['stock_start_cm'];end=row['stock_end_cm'];state=row['age_state_cm_day'];v=row['age_ledger_cm_day'];eff=row['age_effluent']
        require(len(flow)==16 and len(start)==len(end)==6 and len(state)==11 and len(v)==8 and len(eff)==24 and all(map(finite,[*flow,*start,*end,*state,*v,*eff,*row['pressure_head_cm']])),'actual AGE receipt malformed')
        water=math.fsum([*flow[:7],*(-x for x in flow[7:]),*start,*(-x for x in end)])
        require(all(bounded(x) for x in (water,row['independent_residual_cm'],row['kernel_residual_cm'],row['integrated_guard_residual_cm'])),'unchanged actual water guard exceeded')
        require(all(state[i]>=0 for i in (0,1,2,3,4,5,8,9,10)) and abs(state[0]+state[1]-state[2])<=tolerance(*state[:3]) and state[5]==0,'actual young-water AGE inventory/source invalid')
        require(state[2]==row['age_end_cm_day'],'actual reported AGE end stock differs')
        require(all(v>=0 for v in eff[:16]),'negative actual AGE export')
        for w,amount,mean in zip(eff[:8],eff[8:16],eff[16:]):
            require((amount==0 and mean==-9999) if w==0 else abs(amount/w-mean)<=tolerance(mean),'actual AGE export mean/volume differs')
        if previous is not None:
            require(len(previous)==11 and all(map(finite,previous)) and previous[2]==row['age_start_cm_day'],'actual AGE initial/warm stock differs')
            delta=[math.fsum([state[i],-previous[i]]) for i in range(3,11)];require(delta==v and all(state[i]>=previous[i] for i in (3,4,5,8,9,10)),'actual cumulative AGE flux receipt differs')
            prod,pondprod,external,drain,bottom,root,runoff,infil=v
            residuals=[math.fsum([state[0],-previous[0],-prod,-infil,-bottom,drain,root]),math.fsum([state[1],-previous[1],-pondprod,-external,infil,runoff]),math.fsum([state[2],-previous[2],-prod,-pondprod,-external,-bottom,drain,root,runoff])]
            limit=tolerance(*previous[:3],*state[:3],*v)
            require(limit==row['age_tolerance_cm_day'] and all(abs(x)<=limit for x in residuals) and residuals==[row[k] for k in ('age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day')],'actual unchanged AGE balance/tolerance differs')
        previous=state


def audit(z,prefix,data,epoch=None):
    states=[];effluents=[];state=None;effluent=None;ready_clock=None;previous=None
    for line in z.read(prefix+'original/donor.stdout').decode('utf8').splitlines():
        if line.startswith('HYBRID_AGE_CUMULATIVE '):
            values=list(map(float,line.split()[1:]));require(len(values)==11 and all(map(finite,values)) and all(values[i]>=0 for i in (0,1,2,3,4,5,8,9,10)) and values[5]==0 and abs(math.fsum([values[0],values[1],-values[2]]))<=tolerance(*values[:3]),'actual intermediate groundwater AGE observation malformed')
            if previous is not None:
                flows=[math.fsum([values[i],-previous[i]]) for i in range(3,11)];prod,pondprod,external,drain,bottom,root,runoff,infil=flows
                require(all(values[i]>=previous[i] for i in (3,4,5,8,9,10)),'actual intermediate groundwater AGE cumulative source/loss moved backward')
                residuals=[math.fsum([values[0],-previous[0],-prod,-infil,-bottom,drain,root]),math.fsum([values[1],-previous[1],-pondprod,-external,infil,runoff]),math.fsum([values[2],-previous[2],-prod,-pondprod,-external,-bottom,drain,root,runoff])]
                require(all(abs(v)<=tolerance(*previous[:3],*values[:3],*flows) for v in residuals),'actual intermediate groundwater AGE unchanged balance exceeded')
            previous=values;state=values;effluent=None
        elif line.startswith('HYBRID_AGE_EFFLUENT ') and state is not None:
            effluent=list(map(float,line.split()[1:]));require(len(effluent)==24 and all(map(finite,effluent)) and all(v>=0 for v in effluent[:16]),'actual intermediate groundwater AGE exports malformed')
            for water,amount,mean in zip(effluent[:8],effluent[8:16],effluent[16:]):require((amount==0 and mean==-9999) if water==0 else abs(amount/water-mean)<=tolerance(mean),'actual intermediate groundwater AGE export units differ')
        elif line.startswith('HYBRID_READY '):
            require(ready_clock is None and state is not None and effluent is not None,'actual initial groundwater AGE observation omitted');ready_clock=float(line.split()[1]);states.append(state);effluents.append(effluent);state=effluent=None
            if epoch is not None:require(ready_clock==(date.fromisoformat(epoch)-date(1900,1,1)).days+data[0]['day'],'actual immutable groundwater AGE initial clock differs')
        elif line.startswith('AGE_DAILY_RECEIPT '):
            require(ready_clock is not None and state is not None and effluent is not None and len(states)<=len(data),'actual daily groundwater AGE frame omitted');parts=line.split();index=len(states)-1
            require(int(parts[1])==data[index]['day'] and float(parts[2])==ready_clock+index+1,'actual daily groundwater AGE receipt clock differs');states.append(state);effluents.append(effluent);state=effluent=None
    require(ready_clock is not None and state is None and len(states)==len(effluents)==len(data)+1,'actual daily groundwater AGE observations omitted')
    require(states[1:]==[row['age_state_cm_day'] for row in data] and effluents[1:]==[row['age_effluent'] for row in data],'actual worker groundwater AGE observations rebound')
    ledger(data,len(data),states[0]);return states[0]

def geometry(raw,n):
    text=raw.decode('cp1252');require(re.search(r'(?mi)^\s*SWDISCRVERT\s*=\s*0\s*(?:!.*)?$',text) is not None,'unqualified actual geometry conversion')
    match=re.search(r'(?mi)^\s*ISUBLAY\s+ISOILLAY\s+HSUBLAY\s+NCOMP\s*\n(.*?)^\* End of table',text,re.S);require(match is not None,'actual original static grid omitted')
    dz=[]
    for line in match[1].splitlines():
        parts=line.split('!')[0].split()
        if not parts:continue
        require(len(parts)==4,'foreign actual static grid row');height=float(parts[2]);count=int(parts[3]);require(finite(height) and height>0 and count>0,'invalid actual static grid');dz.extend([height/count]*count)
    require(len(dz)==n,'actual static node grid differs');return dz


def calendar(raw,n):
    candidates=[];prefix=struct.pack('<2i',1,n);pos=raw.find(prefix)
    while pos>=0:
        if pos+160<=len(raw):
            h=struct.unpack_from('<20i',raw,pos);nr=h[3];tail=24*n+8*(25+h[2])+20+128
            if nr>100 and 1<=h[2]<=5 and pos+160+16*nr+tail==len(raw) and h==struct.unpack_from('<20i',raw,pos+80):candidates.append((pos,h,nr))
        pos=raw.find(prefix,pos+1)
    require(len(candidates)==1,'actual complete AGE calendar/private shape/witness/EOF differs');return candidates[0]


def native(raw,row,n,selected,epoch='2002-01-01',dz=None):
    hys=selected['swhyst'];require(raw[:8]==CODECS[int(hys>0)].encode(),'actual AGE groundwater codec differs')
    day=row['day'];clock=(date.fromisoformat(epoch)-date(1900,1,1)).days+1
    nodes,stored,step,canopy=struct.unpack_from('<i3d',raw,8);require(nodes==n and stored==clock+day and finite(step) and 0<step<=1 and finite(canopy) and canopy>=0 and selected['original_output_epoch']==clock,'actual AGE groundwater physical/immutable clock differs')
    c,h,nr=calendar(raw,n);domain=struct.pack('<13i',3,n,0,2,1,hys,0,0,1,2,selected['swdra'],selected['et'],1)
    require(raw.count(domain+domain)==1,'actual paired AGE groundwater process domain differs');gp=raw.index(domain+domain);offset=gp+104
    require(offset+8*(5*n+4)==c,'actual complete AGE groundwater hydraulic shape/placement differs')
    water=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset)
    require(all(map(finite,water)) and all(v>=0 for v in water[n:5*n+2]) and water[-1]>=0,'actual AGE groundwater hydraulic state nonfinite/negative')
    require(list(water[:n])==row['pressure_head_cm'] and water[-2]==row['groundwater_cm'] and water[-1]==row['stock_end_cm'][0],'actual AGE groundwater hydraulic state differs from accepted receipt')
    if dz is not None:require(len(dz)==n and abs(math.fsum(w*d for w,d in zip(water[n:2*n],dz))-water[-1])<=1e-10,'actual AGE groundwater hydraulic water inventory differs')
    if hys:
        hd=struct.pack('<5i',1,n,0,hys,2);require(raw.count(hd+hd)==1 and raw[gp-40:gp]==hd+hd,'actual AGE groundwater hysteresis domain differs')
    completed=date.fromisoformat(epoch)+timedelta(days=day-1);effective=selected['period'];counter=min(day,completed.timetuple().tm_yday) if selected['swres'] and effective else day
    if not selected['flprintdt'] and effective:counter%=effective
    printing=day*selected['nprintday']+1 if selected['nprintday']>1 and not selected['flprintdt'] else 1
    require((h[4],h[5],h[6],h[7],h[8],h[11],h[18],h[19])==(effective,selected['nprintday'],day,counter,printing,selected['swres'],int(selected['nprintday']>1 or selected['flprintdt']),int(selected['flprintdt'])) and all(x in (0,1) for x in h[12:20]) and all(1<=x<=3000 for x in h[9:11]),'actual AGE groundwater calendar policy/day/counter differs')
    first=raw[c+160:c+160+8*nr];require(first==raw[c+160+8*nr:c+160+16*nr],'actual AGE groundwater calendar value witness differs');cal=struct.unpack('<'+str(nr)+'d',first);require(all(map(finite,cal)) and cal[-1]>=0 and nr>=6008,'actual AGE groundwater calendar value nonfinite/negative')
    balance=cal[-6008:-3008];interval=cal[-3008:-8];expected=1+sum(0<x<clock+day-1e-8 for x in interval)
    require(h[9]==1+sum(0<x<clock+day-1e-8 for x in balance),'actual AGE groundwater balance date pointer differs')
    require(h[10]==1 if 0<interval[0]<clock-1e-8 else h[10]<=expected if selected['flprintdt'] else h[10]==expected,'actual original pending AGE groundwater interval pointer differs')
    start=c+160+16*nr;body=struct.unpack_from('<'+str(3*n+25+h[2]+16)+'d',raw,start);require(all(map(finite,body)),'actual native groundwater AGE nonfinite')
    bulk,means,output=body[:n],body[n:2*n],body[2*n:3*n];require(all(v>=0 for v in (*bulk,*means,*output,*body[3*n:3*n+3])) and means==output,'actual native groundwater AGE vector domain/output alias differs')
    require(all(abs(b-w*a)<=tolerance(b,w*a) for b,w,a in zip(bulk,water[n:2*n],means)),'actual native groundwater AGE mass/concentration/water relation differs')
    require(body[3*n+3:3*n+6]==(0.,0.,0.) and list(body[3*n+6:3*n+14])==row['age_state_cm_day'][3:],'actual native groundwater AGE forcing/cumulative state rebound')
    totals=struct.unpack_from('<3d',raw,len(raw)-44);require(list(totals)==row['age_state_cm_day'][:3] and body[3*n]==totals[1],'actual native groundwater AGE conserved total differs')
    limit=tolerance(*totals);require(abs(math.fsum([totals[0],totals[1],-totals[2]]))<=limit and abs(row['stock_end_cm'][1]*body[3*n+2]-body[3*n])<=limit,'actual native groundwater AGE pond/total consistency differs')
    if dz is not None:require(all(b<=1e12/d for b,d in zip(bulk,dz)) and abs(math.fsum(b*d for b,d in zip(bulk,dz))-totals[0])<=limit,'actual native groundwater AGE weighted soil inventory differs')
    exports=struct.unpack_from('<16d',raw,len(raw)-172);require(all(v>=0 for v in exports) and list(exports)==row['age_effluent'][:16],'actual private groundwater AGE export inventory differs')
    private_day=struct.unpack_from('<i',raw,len(raw)-20)[0];private_period=struct.unpack_from('<d',raw,len(raw)-16)[0];flags=struct.unpack_from('<2i',raw,len(raw)-8)
    require(private_day==day and private_period==cal[-1] and flags==h[12:14],'actual private groundwater AGE clock/reset flags differ from calendar')
    return dict(calendar_offset=c,calendar_header=list(h),groundwater_domain_offset=gp,groundwater_values_offset=offset,actual_hydraulic_values=list(water),age_state_offset=start,actual_native_total=list(totals),actual_private_day=private_day,actual_private_period=private_period,actual_private_flags=list(flags))

def checkpoint(z,path,build,row,selected,dz):
    with zipfile.ZipFile(io.BytesIO(z.read(path))) as cp:
        require(set(cp.namelist())=={'checkpoint.json','result.end','macro.bin'},'actual AGE checkpoint members differ');meta=read(cp,'checkpoint.json')
        require(meta['schema']=='swap5-hybrid-water-checkpoint-3' and meta['binding']==build['binding'] and meta['receipt']==row,'actual native AGE receipt/binding differs')
        for name,value in meta['files'].items():require(digest(cp.read(name))==value,'actual native AGE file hash differs')
        return {name:cp.read(name) for name in ('result.end','macro.bin')},native(cp.read('macro.bin'),row,build['project']['nodes'],selected,build['project']['start_date'],dz)


def period(report,case,opt,phase,build,build_digest):
    hys,step,mode,fmt,reset,npd,source,et,level,drain,bbc,_=case;days={'short':35,'full':1096,'limit':2}[phase];p=report['parameters'];s=build['identity']['original_output']
    require(report['status']=='ACTUAL_ORIGINAL_AGE_GROUNDWATER_'+phase.upper()+'_PHYSICAL_NATIVE_OUTPUT_PASS' and tuple(p[k] for k in ('hysteresis','perstep','mode','format','reset','nprintday','optimization'))==(hys,step,mode,fmt,reset,npd,opt) and p.get('source','point')==source and p.get('et',0)==et and p.get('level_kind','crossing')==level and p.get('drainage',1)==drain and p.get('boundary_file',False)==bbc and p.get('phase','short')==phase,'actual AGE groundwater period/parameter differs')
    require(report['functional_completion']=='PARTIAL' and report['whole_scientific_equivalence']=='NOT_QUALIFIED' and report['trajectory']['days']==report['trajectory']['budgets']['days']==days and report['trajectory']['build_sha256']==build_digest,'actual AGE groundwater period censored/build rebound')
    require(all(bounded(report['trajectory']['budgets'][k]) for k in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')) and 0<=report['maximum_age_tolerance_fraction']<=1 and abs(report['actual_fixed_input_cm']-2.4)<=1e-10,'actual unchanged groundwater AGE/source/water guard exceeded')
    require(s==report['original_output'] and s['policy']=='original-young-age-prescribed-groundwater-state-v1' and s['native_codec']==CODECS[int(hys>0)] and s['source_sha256']==sha(ROOT/'app/hybrid_water/age_groundwater_output.py'),'actual groundwater AGE compiled owner differs')
    requested=5 if mode=='periodic' else 0;effective=1 if step or npd>1 else requested
    require((s['kind'],s['swsnow'],s['swhea'],s['swcalt'],s['swfrost'],s['swdra'],s['swhyst'],s['swcsv'],s['nprintday'],s['swmonth'],s['swodat'],s['swres'],s['requested_period'],s['period'],s['flprintdt'],s['et'])==('age',0,1,2,0,drain,hys,fmt,npd,int(mode=='monthly'),int(mode=='explicit'),0 if mode=='monthly' else reset,requested,effective,step,et),'actual original groundwater AGE selector/calendar differs')
    require(s['age_groundwater_output'] is s['preserves_requested_groups_and_precision'] is s['original_flprintdt_date_gated'] is True and s['physical_equations_changed'] is s['undefined_allocation_tails_serialized'] is False,'actual groundwater AGE source/ownership policy differs')
    require(s['native_domain']==[3,build['project']['nodes'],0,2,1,hys,0,0,1,2,drain,et,1] and s['native_domain_bytes']==104 and s['hysteresis_domain_bytes']==(40 if hys else 0) and s['hydraulic_doubles']=='5*actual_nodes+4','actual complete groundwater AGE domain differs')
    state=blob(BASE,'app/hybrid_water/groundwater_history_native_state.f90').replace(b'\r\n',b'\n')
    for old,new in [(b'hybrid_groundwater_history_native_state',b'hybrid_age_groundwater_native_state'),(b'groundwater_history_native_checkpoint',b'age_groundwater_native_checkpoint'),(b'swsolu/=1',b'swsolu/=2'),(b'(swhyst==0.and.swsnow==0)',b'(swhea/=1.or.swcalt/=2)'),(b'swsnow<0.or.swsnow>1',b'swsnow/=0'),(b'expected=[2,n,',b'expected=[3,n,')]:require(old in state,'literal frozen typed state anchor differs');state=state.replace(old,new)
    encoded=state.replace(b'\n',b'\r\n') if build['identity']['target']=='x86_64-w64-mingw32' else state
    g=build['identity']['groundwater_native_state'];require(g['policy']==s['policy'] and g['actual_domain']==s['native_domain'] and g['domain_bytes']==104 and g['magic']==s['native_codec'] and g['provider_filename']=='age_groundwater_native_state.f90' and g['provider_sha256']==s['state_generated_sha256']==digest(state) and digest(encoded)==build['identity']['donor_generated']['age_groundwater_native_state.f90'] and g['source_sha256']==s['source_sha256'],'actual generated groundwater AGE typed state provider differs')
    require(s['trial_receipt_policy']=='literal-original-integral-clone-actual-groundwater-reaction-and-storage-v1' and s['trial_water_guard_cm']==build['project']['water_tolerance']==1e-10 and s['age_providers']['age_tolerance']==AGE_POLICY,'unchanged actual groundwater AGE trial policy differs')
    for field,path in [('reaction_provider_sha256','src/process/mod_prescribed_groundwater_reaction.f90'),('receipt_provider_sha256','src/process/mod_original_output_receipt.f90'),('state_template_sha256','app/hybrid_water/groundwater_history_native_state.f90')]:require(s[field]==sha(ROOT/path),'literal actual groundwater AGE provider differs')
    require(all('-'+opt in build['identity'][k] for k in ('donor_flags','kernel_flags')) and build['identity']['water_polish_policy']=='strict-water-always-polish-v1','actual groundwater AGE compiler/water policy differs')
    windows={(1,2)} if phase=='limit' else {(2,4),(7,9),(30,34)}
    if phase=='full':windows|={(199,201),(364,367),(530,532),(1094,1096)}
    if p.get('epoch'):windows.add((15,19))
    require({(w['start'],w['end']) for w in report['cold']}==windows and all(w['exact_physical'] is w['exact_complete_native'] is w['origin_unchanged'] is True and all(f['exact'] is True for f in w['exact_original_output'].values()) for w in report['cold']),'actual groundwater AGE cold windows omitted/different')

def preserved_period(key,item,data):
    days=10 if key in ('age-hys1-csv3','within-csv3','crossing-default') else 35
    require(item['trajectory']['days']==len(data)==days and [r['day'] for r in data]==list(range(1,days+1)) and all(r['committed'] is True for r in data) and item['all_physical_exact'] is item['actual_immutable_prior_member_hashes'] is True,'actual preserved AGE/CDE period censored')


def user_outputs(z,prefix,report,data,build,temporary):
    from original_output_files import records
    s=build['identity']['original_output'];epoch=build['project']['start_date'];start=date.fromisoformat(epoch);days=len(data);clock=(start-date(1900,1,1)).days+1
    names=['result.ageProfile.csv','result.ageeffluent.csv','result.ageeffluentqdrain.csv','result.ageeffluentwater.csv']
    if s['swcsv']:names.append('result_output.bin' if s['swcsv']==3 else 'result_output.csv')
    with zipfile.ZipFile(io.BytesIO(z.read(prefix+'trajectory/accepted-column-1-day-2.zip'))) as cp:wire=cp.read('macro.bin')
    c,h,nr=calendar(wire,build['project']['nodes']);cal=struct.unpack_from('<'+str(nr)+'d',wire,c+160)
    date_days=lambda seq:{round(v-clock)+1 for v in seq if v>0 and 1<=round(v-clock)+1<=days}
    balance=date_days(cal[-6008:-3008]);interval=date_days(cal[-3008:-8]);mandatory=set(balance);allowed=balance|interval
    if s['flprintdt']:
        # Literal original gate is abs(outdatint-t1900+dt)<1e-3.
        # With0<dt<=1 this can print on the requested day or its preceding day.
        allowed|={day-1 for day in interval if day>1}
    if not s['flprintdt']:
        periodic=set()
        if s['period']:
            for day in range(1,days+1):
                completed=start+timedelta(days=day-1);counter=min(day,completed.timetuple().tm_yday) if s['swres'] else day
                if counter%s['period']==0:periodic.add(day)
        mandatory|=periodic
        if not (0<cal[-3008]<clock-1e-8):mandatory|=interval
        allowed|=periodic
    if days==1096:
        mandatory.add(days);allowed.add(days)
    actual={};age_days=None;short=s['flprintdt'] or s['nprintday']>1
    def stamp(v):return v[:19].decode('ascii').strip() if isinstance(v,bytes) else v.split(',')[0].strip()
    for name in names:
        path=temporary/('original'+Path(name).suffix);path.write_bytes(z.read(prefix+'trajectory/original/'+name));values=records(path);actual[name]=values
        if name.startswith('result.age'):
            written=[int(next(csv.reader([v]))[2]) for v in values];require(written==sorted(set(written)) and mandatory<=set(written)<=allowed,'actual original groundwater AGE event cadence differs')
            if age_days is None:age_days=written
            require(written==age_days,'actual groundwater AGE files have different global clocks')
            for line,day in zip(values,written):
                parts=next(csv.reader([line]));v=list(map(float,parts[3:]));require(all(map(finite,v)) and date.fromisoformat(parts[0].strip())==start+timedelta(days=day-1),'actual original groundwater AGE file stamp/value malformed')
                if name=='result.ageProfile.csv':
                    require(len(v)==build['project']['nodes'] and all(x>=0 for x in v),'actual groundwater AGE node profile differs')
                    cpname=prefix+f'trajectory/accepted-column-1-day-{day}.zip'
                    if cpname in z.namelist():
                        with zipfile.ZipFile(io.BytesIO(z.read(cpname))) as cp:raw=cp.read('macro.bin')
                        pos,_,nreal=calendar(raw,build['project']['nodes']);age_start=pos+160+16*nreal;cml=struct.unpack_from('<'+str(build['project']['nodes'])+'d',raw,age_start+16*build['project']['nodes']);require(v==[float(format(x,'.3E')) for x in cml],'actual groundwater AGE user profile differs from complete native CML')
                else:
                    eff=data[day-1]['age_effluent'];wanted=eff[16:] if name=='result.ageeffluent.csv' else eff[:8] if name=='result.ageeffluentwater.csv' else eff[3:8];observed=v[1:] if name=='result.ageeffluent.csv' else v
                    require(observed==[float(format(x,'.3E')) for x in wanted],'actual original groundwater AGE means/volumes differ from worker observation')
        else:
            require(values and stamp(values[0])==(epoch+' 00:00:00' if short else (start-timedelta(days=1)).isoformat()) and [stamp(v) for v in values]==sorted(stamp(v) for v in values),'actual original groundwater AGE primary clock differs')
            if days==1096:require(stamp(values[-1])==('2005-01-01 00:00:00' if short else '2004-12-31'),'actual original groundwater AGE primary TEND record missing')
        for w in report['cold']:
            low=w['start'];high=w['end'];path.write_bytes(z.read(prefix+f'own-{low}/original/'+name));cold=records(path)
            if name.startswith('result.age'):expected=[v for v in values if low<int(next(csv.reader([v]))[2])<=high];observed=cold
            else:
                lo=(start+timedelta(days=low)).isoformat()+(' 00:00:00' if short else '');hi=(start+timedelta(days=high)).isoformat()+(' 00:00:00' if short else '');expected=[v for v in values[1:] if (lo<stamp(v)<=hi if short else lo<=stamp(v)<hi)];require(bool(cold),'actual original groundwater cold initialization missing');observed=cold[1:]
            require(observed==expected and w['exact_original_output'][name]['continuation_records']==len(expected),'actual groundwater AGE cold original user records differ')
    return actual

def verify():
    import importlib.util
    spec=importlib.util.spec_from_file_location('saltfarm_direct_admission',ROOT/'tests/saltfarm_newton/direct_admission.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty AGE admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'AGE production differs from qualified source')
    q=json.loads((ROOT/PROOF/'AGE_GROUNDWATER_QUALIFICATION.json').read_text(encoding='utf8'));validate(q)
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==set(q['source_sha256']),'unqualified AGE production surface')
    mutable={PROOF+name for name in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for ref in (BASE,SEALED):
        for path,value in tree(ref,'integration').items():
            if path not in mutable:require(current.get(path)==value,'immutable AGE/predecessor evidence changed: '+path)
    docs={'docs/science/NOMACRO_AGE_PERSTEP_20261119.md','docs/science/NOMACRO_AGE_GROUNDWATER_20261119.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<={SELF,TEST,ENTRY,*mutable,*docs,PROOF+'AGE_GROUNDWATER_MERGE_RECEIPT.json'},'unqualified AGE post-seal change')
    require((ROOT/ENTRY).read_text(encoding='utf8').replace(HOOK,'',1).encode()==blob(BASE,ENTRY).replace(b'\r\n',b'\n'),'literal canonical predecessor owner body changed')
    for ref in q['source_producer_refs']:require(not git('diff',ref,RUNTIME,'--','app','src','reference','tools'),'actual AGE model producer source differs')
    for v in q['workflows'].values():require(set(git('diff','--name-only',v['runtime'],v['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'AGE carrier changes production')
    prior=predecessor();archives={}
    for key,record in q['archives'].items():
        z=zipfile.ZipFile(io.BytesIO(raw_archive(record)));require(set(z.namelist())==set(record['members']),'actual AGE raw archive member omitted')
        for name,value in record['members'].items():require(digest(z.read(name))==value,'actual AGE raw producer member changed')
        archives[key]=z
    sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
    from age_groundwater_ci import CASES,PILOTS,LIMITS
    CONTROLS=set(PILOTS)
    from perstep_domain_verify import build_files
    fulls=colds=natives=policies=providers=limits=limit_cold=epochs=epoch_cold=years=publics=preserved=0
    main_cases={}
    def locate(path,platform,producer=None):
        return (PureWindowsPath(path).relative_to(PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')) if platform=='Windows' else PurePosixPath(path).relative_to(PurePosixPath(producer))).as_posix()+'/'
    for platform,opts in q['main'].items():
        for opt,location in opts.items():
            z=archives[location['archive']];run=read(z,location['prefix']+'RESULT.json');require(run['status']=='EIGHT_AGE_GROUNDWATER_SHORT_SIX_FULL_THREE_NATIVE_TWO_LIMIT_CONTEXTS_PASS' and run['all_short_native_limit_gates_precede_full'] is True and set(run['cases'])==set(CASES) and set(run['controls'])==set(CONTROLS) and set(run['limits'])==set(LIMITS),'actual AGE cohort censored')
            def path(value):return locate(value,platform,location.get('producer_root'))
            for key,case in CASES.items():
                item=run['cases'][key];bp=path(item['build_root']);buildraw=z.read(bp+'BUILD.json');build=json.loads(buildraw);build_files(z,bp,build);bd=digest(buildraw)
                for name,value in build['inputs'].items():require(digest(z.read(path(item['input_root'])+name))==value,'actual AGE input changed')
                for name,value in build['identity']['kernel_sources']:require(kernel_checkout_digest(name,build['identity']['target'])==value,'actual AGE physical kernel source differs: '+name)
                dz=geometry(z.read(path(item['input_root'])+'swap.swp'),build['project']['nodes']);main_cases[platform,opt,key]=(z,item,build,dz,location)
                for phase in ('short','full'):
                    if phase not in item:continue
                    report=item[phase];pp=path(item[phase+'_root']);period(report,case,opt,phase,build,bd);data=rows(z,pp+'trajectory/');audit(z,pp+'trajectory/',data,build['project']['start_date'])
                    with tempfile.TemporaryDirectory(prefix='s5-age-files-') as directory:user_outputs(z,pp,report,data,build,Path(directory))
                    require(abs(math.fsum(r['external_flux_cm'][3]+r['external_flux_cm'][5] for r in data)-2.4)<=1e-10,'actual original planned AGE water dose differs')
                    for w in report['cold']:
                        low,high=w['start'],w['end'];cold=rows(z,pp+f'own-{low}/');audit(z,pp+f'own-{low}/',cold,build['project']['start_date']);require(physical(cold)==physical(data[low:high]),'actual AGE own physical differs')
                        warm,_=checkpoint(z,pp+f'trajectory/accepted-column-1-day-{high}.zip',build,data[high-1],build['identity']['original_output'],dz);actual,_=checkpoint(z,pp+f'own-{low}/accepted-column-1-day-{high}.zip',build,cold[-1],build['identity']['original_output'],dz);require(warm==actual,'actual complete AGE own native differs');colds+=1
                    if phase=='full':fulls+=1
                if key in CONTROLS:
                    location_control=run['controls'][key];cp=path(location_control['root']);control=read(z,cp+'RESULT.json');require(control==location_control['report'] and control['status']=='AGE_GROUNDWATER_NATIVE_PRIVATE_ACTIVE_POLICY_PROVIDER_PASS' and control['build_sha256']==bd,'actual AGE controls rebound')
                    require(len(control['native_refusals'])==(81 if case[0] else 75) and len(control['policy_refusals'])==47 and all(v is True for v in control['transactions'].values()),'actual AGE control/transaction denominator differs')
                    source_rows=rows(z,path(item['short_root'])+'trajectory/')
                    for attack in control['native_refusals']:
                        ap=cp+'native/'+attack['attack']+'/';diagnostic='\n'.join(z.read(name).decode('utf8') for name in z.namelist() if name.startswith(ap) and name.endswith('donor.stderr'))
                        before=attack['error'] in ('Foreign original AGE groundwater native domain','Incomplete original AGE groundwater hydraulic state','Invalid original AGE groundwater hydraulic state','Actual AGE groundwater hydraulic state differs from receipt')
                        require(attack['status']=='REFUSED' and (before or 'ERROR STOP' in diagnostic) and diagnostic.replace('\r\n','\n')==attack['diagnostic'].replace('\r\n','\n') and not any(name.startswith(ap) and Path(name).name.startswith('accepted-') and name.endswith('.zip') for name in z.namelist()),'actual groundwater AGE native accepted/published')
                        if before:require(not any(name.startswith(ap) and name.endswith('donor.stdout') for name in z.namelist()) and attack['refusal_owner']=='actual receipt before worker','actual groundwater AGE preworker refusal rebound')
                        try:native(z.read(ap+'origin/macro.bin'),source_rows[3],build['project']['nodes'],build['identity']['original_output'],build['project']['start_date'],dz)
                        except (ValueError,struct.error):pass
                        else:raise ValueError('Actual forged groundwater AGE native independently accepted: '+attack['attack'])
                        natives+=1
                    for attack in control['policy_refusals']:
                        bad=read(z,cp+'policy-'+attack['field']+'/BUILD.json');expected=json.loads(buildraw);expected['identity']['original_output'][attack['field']]='foreign';require(attack['status']=='REFUSED' and bad==expected,'actual AGE policy mutation rebound');policies+=1
                    ap=cp+'actual-compiled-provider/';require(z.read(ap+'BUILD.json')==buildraw,'actual groundwater AGE provider metadata changed')
                    for field in ('actual_provider_refusal','actual_hydraulic_provider_refusal'):
                        attack=control[field];name=attack['provider'];original=z.read(bp+name);changed=z.read(ap+name)
                        require(attack['status']=='REFUSED' and changed.startswith(original) and changed!=original and digest(changed.replace(b'\r\n',b'\n'))!=build['identity']['donor_generated'][name],'actual groundwater AGE compiled-provider mutation omitted')
                        if field=='actual_hydraulic_provider_refusal':require(name=='age_groundwater_native_state.f90' and attack['error']=='Foreign actual original AGE groundwater state provider','actual groundwater AGE typed provider not checked')
                        providers+=1
                    replay=[]
                    for trial,day in [('external/trial-1',5),('external/trial-2',5),('recovered/trial-1',6)]:
                        tp=cp+'active/'+trial+'/'
                        with zipfile.ZipFile(io.BytesIO(z.read(tp+f'accepted-column-1-day-{day}.zip'))) as az:receipt=read(az,'checkpoint.json')['receipt']
                        require(physical([receipt])==physical([source_rows[day-1]]),'actual AGE replay receipt differs');payload,_=checkpoint(z,tp+f'accepted-column-1-day-{day}.zip',build,receipt,build['identity']['original_output'],dz)
                        if day==5:replay.append(payload)
                    require(replay[0]==replay[1],'actual AGE rejected trial changed complete replay native')
            for key,case in LIMITS.items():
                item=run['limits'][key];pp=path(item['root']);report=read(z,pp+'RESULT.json');bp=path(report['build_root']) if report.get('build_root') else pp+'build/';ip=path(report['input_root']) if report.get('input_root') else pp+'input/';raw=z.read(bp+'BUILD.json');build=json.loads(raw);build_files(z,bp,build);period(report,case,opt,'limit',build,digest(raw));data=rows(z,pp+'trajectory/');audit(z,pp+'trajectory/',data,build['project']['start_date']);dz=geometry(z.read(ip+'swap.swp'),build['project']['nodes'])
                require(len(data)==2 and abs(math.fsum(r['external_flux_cm'][3]+r['external_flux_cm'][5] for r in data)-2.4)<=1e-10,'actual1440 source delivery differs');cold=rows(z,pp+'own-1/');audit(z,pp+'own-1/',cold,build['project']['start_date']);require(physical(cold)==physical(data[1:]),'actual1440 AGE cold differs')
                warm,_=checkpoint(z,pp+'trajectory/accepted-column-1-day-2.zip',build,data[1],build['identity']['original_output'],dz);actual,_=checkpoint(z,pp+'own-1/accepted-column-1-day-2.zip',build,cold[-1],build['identity']['original_output'],dz);require(warm==actual,'actual1440 complete AGE native differs');limits+=1;limit_cold+=1
            for left,right in [('ordinary-periodic-crossing-binary','ordinary-periodic-crossing-none'),('history-periodic-crossing-binary','history-periodic-crossing-none')]:
                a=path(run['cases'][left]['short_root'])+'trajectory/';b=path(run['cases'][right]['short_root'])+'trajectory/';require(physical(rows(z,a))==physical(rows(z,b)),'actual AGE format changes physical trajectory')
                for day in (2,4,9,35):
                    with zipfile.ZipFile(io.BytesIO(z.read(a+f'accepted-column-1-day-{day}.zip'))) as az,zipfile.ZipFile(io.BytesIO(z.read(b+f'accepted-column-1-day-{day}.zip'))) as bz:require(all(az.read(n)==bz.read(n) for n in ('result.end','macro.bin')),'actual AGE format changes full native')
    for location in q['contexts']:
        z=archives[location['archive']];prefix=location['prefix'];report=read(z,prefix+'RESULT.json');kind=location['kind'];platform=location['platform'];opt=location.get('optimization','O0');producer=location.get('producer_root')
        def path(value):return locate(value,platform,producer)
        if kind=='epoch':
            require(report['status']=='SIX_NONJANUARY_AGE_GROUNDWATER_EPOCHS_BOTH_RESET_PRIVATE_NATIVE_COLD_PASS' and len(report['cases'])==6,'actual nonJanuary AGE cohort censored')
            for key,item in report['cases'].items():
                r=item['report'];pp=path(item['root'])+'actual/';bp=path(r['build_root']);buildraw=z.read(bp+'BUILD.json');build=json.loads(buildraw);build_files(z,bp,build);dz=geometry(z.read(path(r['input_root'])+'swap.swp'),build['project']['nodes'])
                case=(item['hysteresis'],True,'explicit',3,item['reset'],item['nprintday'],'interval' if item['hysteresis'] else 'point',0,'crossing',1,False,False);period(r,case,opt,'short',build,digest(buildraw));require(build['project']['start_date']==item['epoch'],'actual AGE epoch rebound');data=rows(z,pp+'trajectory/');audit(z,pp+'trajectory/',data,item['epoch'])
                with tempfile.TemporaryDirectory(prefix='s5-age-epoch-') as directory:user_outputs(z,pp,r,data,build,Path(directory))
                require([v['day'] for v in item['actual_native_counters']]==[2,4,7,9,15,19,30,34,35],'actual AGE private epoch denominator differs')
                for inv in item['actual_native_counters']:
                    day=inv['day'];_,actual=checkpoint(z,pp+f'trajectory/accepted-column-1-day-{day}.zip',build,data[day-1],build['identity']['original_output'],dz);h=actual['calendar_header']
                    require((inv['global_day'],inv['period_counter'],inv['expected_counter'],inv['print_counter'],inv['private_day'],inv['private_period'],inv['private_flags'])==(h[6],h[7],h[7],h[8],actual['actual_private_day'],actual['actual_private_period'],actual['actual_private_flags']),'actual private AGE epoch inventory rebound')
                for w in r['cold']:
                    low,high=w['start'],w['end'];cold=rows(z,pp+f'own-{low}/');audit(z,pp+f'own-{low}/',cold,item['epoch']);require(physical(cold)==physical(data[low:high]),'actual AGE epoch cold physical differs')
                    warm,_=checkpoint(z,pp+f'trajectory/accepted-column-1-day-{high}.zip',build,data[high-1],build['identity']['original_output'],dz);actual,_=checkpoint(z,pp+f'own-{low}/accepted-column-1-day-{high}.zip',build,cold[-1],build['identity']['original_output'],dz);require(warm==actual,'actual AGE epoch complete cold differs');epoch_cold+=1
                epochs+=1
        elif kind=='year-controls':
            require(report['status']=='TWENTY_FOUR_ACTUAL_AGE_GROUNDWATER_POST_YEAR_COUNTER_FORGERIES_REFUSED' and len(report['cases'])==6,'actual postyear AGE attacks censored')
            epoch=next(v for v in q['contexts'] if v['kind']=='epoch' and v['platform']==platform and v['optimization']==opt);ez=archives[epoch['archive']];er=read(ez,epoch['prefix']+'RESULT.json')
            for key,item in report['cases'].items():
                e=er['cases'][key];pp=path(e['root'])+'actual/';build=read(ez,path(e['report']['build_root'])+'BUILD.json');data=rows(ez,pp+'trajectory/');source=ez.read(pp+'trajectory/accepted-column-1-day-30.zip');require(digest(source)==item['source_sha256'] and len(item['checks'])==4,'actual postyear AGE source rebound');dz=geometry(ez.read(path(e['report']['input_root'])+'swap.swp'),build['project']['nodes'])
                with zipfile.ZipFile(io.BytesIO(source)) as cp:original=cp.read('macro.bin')
                pos,header,_=calendar(original,build['project']['nodes'])
                for attack in item['checks']:
                    ap=prefix+key+'/'+attack['attack']+'/';diagnostic='\n'.join(z.read(name).decode('utf8') for name in z.namelist() if name.startswith(ap) and name.endswith('donor.stderr'));require(attack['status']=='REFUSED' and attack['day']==30 and attack['actual_counter']==header[7] and attack['forged_counter']!=header[7] and 'ERROR STOP' in diagnostic and diagnostic.replace('\r\n','\n')==attack['diagnostic'].replace('\r\n','\n'),'actual postyear AGE worker differs')
                    expected=bytearray(original)
                    for offset in (28,108):struct.pack_into('<i',expected,pos+offset,attack['forged_counter'])
                    bad=z.read(ap+'origin/macro.bin');require(bad==expected and not any(name.startswith(ap) and Path(name).name.startswith('accepted-') and name.endswith('.zip') for name in z.namelist()),'actual paired postyear AGE mutation/publish differs')
                    try:native(bad,data[29],build['project']['nodes'],build['identity']['original_output'],e['epoch'],dz)
                    except ValueError:pass
                    else:raise ValueError('Actual paired postyear AGE counter independently accepted')
                    years+=1
        elif kind=='public':
            require(report['status']=='SIX_PUBLIC_AGE_GROUNDWATER_SELF_CONTAINED_RESTART_CONTEXTS_PASS' and len(report['profiles'])==6,'actual public AGE cohort censored')
            from original_output_files import records
            for key,item in report['profiles'].items():
                require(item['physical_exact'] is item['complete_native_exact'] is item['origin_unchanged'] is True and item['warm']['returncode']==item['cold']['returncode']==0,'actual public AGE command failed')
                mz,mi,build,dz,ml=main_cases[platform,opt,key];warm=rows(z,prefix+key+'/warm/');cold=rows(z,prefix+key+'/cold/');audit(z,prefix+key+'/warm/',warm,build['project']['start_date']);audit(z,prefix+key+'/cold/',cold,build['project']['start_date']);require(len(warm)==35 and len(cold)==4 and physical(cold)==physical(warm[30:34]) and physical(warm)==physical(rows(mz,locate(mi['short_root'],platform,ml.get('producer_root'))+'trajectory/')),'actual public AGE physical restart differs')
                prior_payload,_=checkpoint(mz,locate(mi['short_root'],platform,ml.get('producer_root'))+'trajectory/accepted-column-1-day-34.zip',build,warm[33],build['identity']['original_output'],dz);actual,_=checkpoint(z,prefix+key+'/cold/accepted-column-1-day-34.zip',build,cold[-1],build['identity']['original_output'],dz);require(prior_payload==actual,'actual public AGE complete native differs')
                with tempfile.TemporaryDirectory(prefix='s5-age-public-') as directory:
                    for name,proof in item['user_output_exact'].items():
                        p=Path(directory)/('user'+Path(name).suffix);p.write_bytes(z.read(prefix+key+'/warm/original/'+name));values=records(p);p.write_bytes(z.read(prefix+key+'/cold/original/'+name));actual=records(p)
                        if name.startswith('result.age'):wanted=[v for v in values if 30<int(next(csv.reader([v]))[2])<=34]
                        else:
                            stamp=lambda v:v[:19].decode('ascii').strip() if isinstance(v,bytes) else v.split(',')[0].strip();s=build['identity']['original_output'];short=s['flprintdt'] or s['nprintday']>1;suffix=' 00:00:00' if short else '';low=(date.fromisoformat(build['project']['start_date'])+timedelta(days=30)).isoformat()+suffix;high=(date.fromisoformat(build['project']['start_date'])+timedelta(days=34)).isoformat()+suffix;wanted=[v for v in values[1:] if (low<stamp(v)<=high if short else low<=stamp(v)<high)];actual=actual[1:]
                        require(proof['exact'] is True and proof['continuation_records']==len(wanted) and actual==wanted,'actual public AGE user records differ')
                publics+=1
        elif kind=='reader':
            require(report['status']=='SEVEN_AGE_GROUNDWATER_READER_TWELVE_LITERAL_PARTITIONS_PASS' and len(report['reader_refusals'])==7 and len(report['literal_delegations'])==12 and len(report['explicit_source_refusals'])==2,'actual AGE reader/partition cohort censored')
            for item in report['reader_refusals']:
                require(item['status']=='REFUSED_BEFORE_HYBRID_READY','actual AGE numeric reader accepted');pp=prefix+'reader-'+item['attack']+'/';logs='\n'.join(z.read(name).decode('utf8') for name in z.namelist() if name.startswith(pp) and name.endswith('donor.stdout'));require('HYBRID_READY' not in logs and not any(name.startswith(pp) and Path(name).name.startswith('accepted-') and name.endswith('.zip') for name in z.namelist()),'actual invalid AGE reader published')
        else:raise ValueError('Foreign AGE context kind')
    for platform,location in q['preservation'].items():
        z=archives[location['archive']]
        for prefix,count in location['profiles'].items():
            report=read(z,prefix+'/RESULT.json');require(report['status']=='ACTUAL_AGE_GROUNDWATER_AFFECTED_'+report['family'].upper()+'_SEAMS_PRESERVED' and len(report['profiles'])==count,'actual AGE preservation cohort censored')
            authority=json.loads((ROOT/PROOF/report['qualification']).read_text(encoding='utf8'));oldrecord=authority['archives'][report['immutable_prior_archive']]
            with zipfile.ZipFile(io.BytesIO(raw_archive(oldrecord))) as old:
                for key,item in report['profiles'].items():
                    pp=prefix+'/'+key+'/';op=item['prior_profile_prefix']+'/';build=read(z,pp+'build/BUILD.json');require(build==item['actual_build'] and item['all_physical_exact'] is item['actual_immutable_prior_member_hashes'] is True,'actual preserved build/physical claim differs');build_files(z,pp+'build/',build)
                    require(digest(old.read(op+'build/BUILD.json'))==item['prior_build_sha256']==oldrecord['members'][op+'build/BUILD.json'] and digest(old.read(op+'RESULT.json'))==item['prior_report_sha256']==oldrecord['members'][op+'RESULT.json'] and digest(old.read(op+'trajectory/daily.jsonl'))==item['prior_daily_sha256']==oldrecord['members'][op+'trajectory/daily.jsonl'],'original actual prior source members rebound')
                    previous=rows(old,op+'trajectory/');data=rows(z,pp+'trajectory/');days=item['trajectory']['days'];preserved_period(key,item,data);require(days==len(previous) and physical(data)==physical(previous),'actual fresh preserved trajectory censored/different')
                    for row in data:
                        flow=row['external_flux_cm'];residual=math.fsum([*flow[:7],*(-x for x in flow[7:]),*row['stock_start_cm'],*(-x for x in row['stock_end_cm'])]);require(all(bounded(v) for v in (residual,row['independent_residual_cm'],row['kernel_residual_cm'])),'actual preserved water guard exceeded')
                    endpoints=sorted(int(Path(name).stem.rsplit('-',1)[1]) for name in oldrecord['members'] if name.startswith(op+'trajectory/accepted-column-1-day-') and name.endswith('.zip'));require([v['day'] for v in item['native']]==endpoints,'actual preserved native endpoints censored')
                    for inv in item['native']:
                        day=inv['day'];oname=op+f'trajectory/accepted-column-1-day-{day}.zip';require(digest(old.read(oname))==oldrecord['members'][oname],'original actual native member changed')
                        with zipfile.ZipFile(io.BytesIO(old.read(oname))) as a,zipfile.ZipFile(io.BytesIO(z.read(pp+f'trajectory/accepted-column-1-day-{day}.zip'))) as b:
                            left,right=a.read('macro.bin'),b.read('macro.bin');require(a.read('result.end')==b.read('result.end'),'actual original preserved sequential state differs')
                            require(left[8:]==right[8:] and left[:8]!=right[:8] and inv['actual_codec_only_projection_exact'] is True if item['overlap_new_codec'] else left==right and inv['complete_native_exact'] is True,'actual preserved complete native/codecdomain differs')
                            require(inv['old_codec']==left[:8].decode() and inv['current_codec']==right[:8].decode(),'actual preserved codec inventory differs')
                    from original_output_files import records
                    with tempfile.TemporaryDirectory(prefix='s5-age-preserve-') as directory:
                        for name,proof in item['original_user_output'].items():
                            oname=op+'trajectory/original/'+name;require(digest(old.read(oname))==oldrecord['members'][oname],'actual prior original output member changed');p=Path(directory)/('user'+Path(name).suffix);p.write_bytes(old.read(oname));before=records(p);p.write_bytes(z.read(pp+'trajectory/original/'+name));after=records(p);require(before==after and proof==dict(exact=True,records=len(before)),'actual preserved user output differs')
                    w=item['cold'];low,high=w['start'],w['end'];cold=rows(z,pp+f'own-{low}/');require(physical(cold)==physical(data[low:high]) and w['exact_physical'] is w['exact_complete_native'] is w['origin_unchanged'] is True,'actual preserved cold differs')
                    with zipfile.ZipFile(io.BytesIO(z.read(pp+f'trajectory/accepted-column-1-day-{high}.zip'))) as a,zipfile.ZipFile(io.BytesIO(z.read(pp+f'own-{low}/accepted-column-1-day-{high}.zip'))) as b:require(all(a.read(name)==b.read(name) for name in ('result.end','macro.bin')),'actual preserved complete cold native differs')
                    preserved+=1
    observations=archives[q['observations_archive']];comparison=q['private_level_comparison'];require(comparison['status']=='IDENTICAL_ACTUAL_PRIVATE_GROUNDWATER_LEVEL_BYTES_REFUSED_BEFORE_WORKER' and comparison['actual_current_fresh_build'] is True and comparison['before_worker'] is True and comparison['published'] is False,'actual groundwater AGE private level observation promoted')
    oldprefix='age-groundwater-private-level-gap-v1/';newprefix='age-groundwater-private-level-refused-current-v1/';old=observations.read(oldprefix+'origin/macro.bin');new=observations.read(newprefix+'origin/macro.bin');require(old==new and digest(new)==comparison['exact_bad_bytes_sha256']==comparison['prior_bad_bytes_sha256'],'actual same bad groundwater AGE bytes rebound')
    logs='\n'.join(observations.read(name).decode('utf8') for name in observations.namelist() if name.startswith(oldprefix) and name.endswith('donor.stdout'));require('HYBRID_READY' in logs and not any(name.startswith(newprefix) and name.endswith('donor.stdout') for name in observations.namelist()),'actual groundwater AGE old accepted/current preworker refusal differs')
    require(q['component_inheritance']['fresh_pass_claim'] is False and all(sha(ROOT/path)==value for path,value in q['component_inheritance']['providers'].items()),'old physical AGE/groundwater component proof relabelled fresh/changed')
    require((fulls,colds,natives,policies,providers,limits,limit_cold,epochs,epoch_cold,years,publics,preserved)==(24,264,948,564,24,8,8,24,96,96,18,42),'actual original AGE scientific/native denominator differs')
    return dict(status='ORIGINAL_AGE_GROUNDWATER_REACTION_PRIVATE_CALENDAR_NATIVE_ADMISSION_PASS',runtime=RUNTIME,predecessor=prior,actual_full_periods=fulls,actual_main_cold_windows=colds,actual_native_private_refusals=natives,actual_policy_refusals=policies,actual_provider_refusals=providers,actual_1440_two_day_periods=limits,actual_1440_cold_windows=limit_cold,actual_non_january_periods=epochs,actual_epoch_cold_windows=epoch_cold,actual_postyear_counter_refusals=years,actual_public_contexts=publics,actual_preserved_contexts=preserved,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')


if __name__=='__main__':print(json.dumps(verify(),indent=2))
