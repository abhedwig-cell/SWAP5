"""Fresh original scientific/native reads through explicit immutable archive views."""
import argparse,io,json,math,struct,zipfile
from contextlib import ExitStack
from frost_history_state_archives import P,LogicalArchive,OriginalProviderArchive,BuildReference,Locations,ReadView,Archive,SHA
from frost_history_state_model_forensics import audit as model
from ordinary_pond_evidence import physical
from frost_history_state_publisher import publisher_equivalence


def read(view):return json.loads(view.read_text())
def rows(view):return [json.loads(line) for line in (view/'daily.jsonl').read_text().splitlines()]


def compiled(left,right):
    suffixes={'.o','.mod','.smod','.exe','.dll','.so','.a'}
    files=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and (p.suffix.lower() in suffixes or p.name in ('day_donor','day_kernel'))}
    a,b=files(left),files(right);assert a and a.keys()==b.keys();observed=[]
    for name,path in sorted(a.items()):
        old,new=path.read_bytes(),b[name].read_bytes();item=dict(file=name,left_sha256=SHA(old),right_sha256=SHA(new),left_bytes=len(old),right_bytes=len(new))
        if old==new:item['status']='ACTUAL_COMPLETE_COMPILED_BYTES_EXACT'
        else:
            assert path.suffix.lower() in ('.dll','.exe') and old[:2]==new[:2]==b'MZ'
            item['PE_loader_relative_whole_code_data']=publisher_equivalence(path,b[name]);item['status']='ACTUAL_COMPLETE_PE_CODE_DATA_RELOCATIONS_EXACT_LINK_METADATA_DIFFERENCES_RETAINED'
        observed.append(item)
    assert {'day_donor.exe','day_kernel.exe','restart_publish.dll'}<=set(a) or {'day_donor','day_kernel','restart_publish.so'}<=set(a)
    return dict(status='ALL_ACTUAL_GENERATED_OBJECT_MODULE_EXECUTABLE_PUBLISHER_CODE_DATA_POSTIMAGES_VERIFIED',files=observed,raw_bytes_rewritten=False,model_executions=0,compiler_executions_in_reader=0)


def generated(left,right):
    files=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in ('.f90','.f','.for','.inc')}
    a,b=files(left),files(right);assert a and a.keys()==b.keys();observed=[]
    for name,path in sorted(a.items()):
        old,new=path.read_bytes(),b[name].read_bytes();assert old.replace(b'\r\n',b'\n')==new.replace(b'\r\n',b'\n');observed.append(dict(file=name,left_sha256=SHA(old),right_sha256=SHA(new)))
    return observed


def original_history(raw,kind,mode):
    records=[];at=0
    while at<len(raw):
        n=struct.unpack_from('<i',raw,at)[0];assert 0<=n<=len(raw)-at-8 and struct.unpack_from('<i',raw,at+4+n)[0]==n
        records.append(raw[at+4:at+4+n]);at+=n+8
    values=iter(records)
    def take(fmt):return struct.unpack('<'+fmt,next(values))
    integer=lambda:take('i')[0]
    assert integer()==1 and integer()==0;nodes=integer();assert nodes==34
    heads=take(str(nodes)+'d');pond=take('d')[0];assert integer()==1;snow=(take('d')[0],take('d')[0]);evaporation=integer();assert evaporation in (0,1,2)
    for _ in range(evaporation):take('d')
    assert integer()==mode;history=[];indices=()
    if mode:
        indices=take(str(nodes)+'i');assert all(x in (-1,1) for x in indices);history=[take(str(nodes)+'d') for _ in range(3)]
    assert integer()==1;temperature=take(str(nodes)+'d');assert integer()==int(kind=='cde')
    assert all(map(math.isfinite,(*heads,pond,*snow,*temperature,*[x for row in history for x in row])))
    return dict(original_hysteresis_mode=mode,history_arrays=len(history),actual_direction_reversal=any(x!=1 for x in indices),original_head_nodes=nodes)


def native(raw,meta,kind,mode,implicit):
    expected_magic=(b'S5FIC002' if kind=='cde' else b'S5FIW002') if implicit else (b'S5FDC001' if kind=='cde' else b'S5FDW001')
    assert raw[:8]==expected_magic
    header=struct.pack('<10i',1,meta['project']['nodes'],0,int(kind=='cde'),mode,1,1,1,1,2);assert raw.count(header+header)==1
    if implicit:
        expected=(4,meta['project']['nodes'],int(kind=='cde'),1,mode,6,1,0);assert struct.unpack('<16i',raw[-96:-32])==expected+expected
        values=struct.unpack('<4d',raw[-32:]);assert values[:2]==values[2:] and all(map(math.isfinite,values))


def checkpoints(warm,data,meta,kind,mode,implicit):
    byday={row['day']:row for row in data};samples=[]
    for path in warm.glob('accepted-column-1-day-*.zip'):
        day=int(path.stem.rsplit('-',1)[1]);assert day in byday
        with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
            q=json.loads(z.read('checkpoint.json'));assert q['binding']==meta['binding'] and q['receipt']==byday[day]
            assert all(SHA(z.read(name))==digest for name,digest in q['files'].items())
            native(z.read('macro.bin'),meta,kind,mode,implicit);history=original_history(z.read('result.end'),kind,mode)
        samples.append(dict(day=day,**history))
    assert {x['day'] for x in samples}=={2,4,19,23,30,34,35}
    return sorted(samples,key=lambda x:x['day'])


def transaction(folder,data,meta,kind,mode,implicit,start):
    stages=[('trial-1',start+1),('trial-2',start+1),('',start+1)]
    observed=[]
    for stem,day in stages:
        view=folder/stem if stem else folder
        with zipfile.ZipFile(io.BytesIO((view/f'accepted-column-1-day-{day}.zip').read_bytes())) as z:
            q=json.loads(z.read('checkpoint.json'));assert {k:v for k,v in q['binding'].items() if k!='external_daily'}==meta['binding']
            assert physical([{k:v for k,v in q['receipt'].items() if k!='coupling'}])==physical([data[day-1]])
            assert all(SHA(z.read(name))==digest for name,digest in q['files'].items());raw=z.read('macro.bin');native(raw,meta,kind,mode,implicit);observed.append((raw,z.read('result.end')))
    assert observed[0]==observed[1]==observed[2]
    return dict(start_day=start,discard_replay_commit_native_exact=True)


def controls(folder,profile,meta,kind,mode,implicit):
    q=read(folder/'RESULT.json');assert q['status']=='ACTUAL_FROST_STATE_COMPILED_NATIVE_ROOT_SNOW_AND_ACTIVE_FROST_TRANSACTIONS_PASS_NOT_ADMITTED'
    counts=[]
    with zipfile.ZipFile(io.BytesIO((profile/'trajectory/accepted-column-1-day-4.zip').read_bytes())) as z:good=z.read('macro.bin')
    groups=[('native',q['native_refusals'])]
    if implicit:groups.append(('root',q['root_refusals']['refusals']));assert q['root_refusals']['accepted_model_days']==0
    for stem,items in groups:
        assert len(items)==(25 if stem=='root' else 44 if kind=='cde' else 39)
        for item in items:
            target=folder/stem/item['attack'];stderr=list(target.rglob('donor.stderr'));stdout=list(target.rglob('donor.stdout'));assert len(stderr)==len(stdout)==1
            assert b'ERROR STOP' in stderr[0].read_bytes() and b'HYBRID_READY' not in stdout[0].read_bytes() and b'HYBRID_DAY_RETURN' not in stdout[0].read_bytes()
            assert (target/'origin/macro.bin').read_bytes()!=good and not list(target.rglob('accepted-*.zip'))
        counts.append(len(items))
    data=rows(profile/'trajectory')
    snow=transaction(folder/'snow-transactions/external',data,meta,kind,mode,implicit,4)
    frost=transaction(folder/'frost-external',data,meta,kind,mode,implicit,19)
    for recovered,start in [(folder/'snow-transactions/recovered',5),(folder/'frost-recovered',20)]:
        with zipfile.ZipFile(io.BytesIO((recovered/f'trial-1/accepted-column-1-day-{start+1}.zip').read_bytes())) as z:
            value=json.loads(z.read('checkpoint.json'));assert physical([{k:v for k,v in value['receipt'].items() if k!='coupling'}])==physical([data[start]]);native(z.read('macro.bin'),meta,kind,mode,implicit)
    return dict(compiled_native_refusals=sum(counts),accepted_mutant_days=0,snow=snow,frost=frost)


def audit(platform,opt):
    with ExitStack() as stack:
        if platform=='Windows':
            store=LogicalArchive('FROST_HYSTERESIS_STATE01_WINDOWS_RAW_V1',stack);loc=Locations(store,json.loads(store.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')));reference=BuildReference(OriginalProviderArchive(stack),'original-provider/build');cohort=[]
            for stem,implicit in [('frost-history-state01-windows-batch-v1',0),('frost-history-state01-implicit-windows-batch-v1',1)]:
                batch=read(store.view('profiles/'+stem+'/RESULT.json'))
                for item in batch['contexts']:
                    if item['optimization']==opt:cohort.append((item,loc.resolve(item['profile']),implicit))
        else:
            store=Archive(P,'FROST_HYSTERESIS_STATE01_UBUNTU_'+opt+'_ORIGINAL_V1',stack);batch=json.loads(store.get('current/BATCH.json'));reference=BuildReference(store,'original-provider-build');cohort=[];projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
            for item in batch['contexts']:
                label=('implicit' if item['implicit'] else 'explicit')+'-'+item['kind']+'-hys'+str(item['hysteresis'])+'-initial'+str(item['initial']);cohort.append((item,ReadView(store,'current/'+label),item['implicit']))
        results=[]
        for item,profile,implicit in cohort:
            report=read(profile/'RESULT.json');kind=report['kind'];mode=item['hysteresis']
            if platform=='Windows':bundle,inputs=loc.resolve(report['build_root']),loc.resolve(report['input_root'])
            else:
                label=profile.name;entry=projection[report['build_root']];assert entry['actual_BUILD_sha256']==report['trajectory']['build_sha256'];bundle=ReadView(store,entry['archive_prefix']);inputs=ReadView(store,'current/inputs/'+label)
            locations=dict(bundle=bundle,inputs=inputs,warm=profile/'trajectory',cold=lambda day,profile=profile:profile/('own-'+str(day)))
            scientific=model(profile,reference,locations=locations);assert scientific==item['independent'];meta=read(bundle/'BUILD.json');data=rows(profile/'trajectory');sample=checkpoints(profile/'trajectory',data,meta,kind,mode,implicit)
            record=dict(kind=kind,hysteresis=mode,implicit=implicit,initial=item['initial'],optimization=opt,actual_producer=report['source'],scientific=scientific,native_samples=sample)
            if platform=='Ubuntu':record['controls']=controls(ReadView(store,profile.path+'-controls'),profile,meta,kind,mode,implicit)
            results.append(record)
        assert len(results)==(16 if platform=='Windows' else 8)
        return dict(status='FRESH_ORIGINAL_FROST_STATE_SOURCE_WATER_CDE_NATIVE_HISTORY_COLD_AND_CONTROLS_PASS',platform=platform,optimization=opt,archive_sha256=store.record['sha256'],contexts=results,full35_contexts=len(results),exact_cold_windows=3*len(results),native_samples=7*len(results),compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--output',required=True);a=p.parse_args();value=audit(a.platform,a.optimization)
    with open(a.output,'x') as out:json.dump(value,out,indent=2);out.write('\n')
    print(value['status'],value['platform'],value['optimization'])
