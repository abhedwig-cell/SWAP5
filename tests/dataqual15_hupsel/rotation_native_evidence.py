"""Independent raw-byte rotation native replay and evidence corruption controls."""
import argparse,io,json,struct,subprocess,tarfile,zipfile,zlib
from pathlib import Path
import rotation_native_runtime as policy
ROOT=policy.ROOT;BASE=ROOT/'integration/dataqual15_hupsel';sha=policy.sha
hashes=lambda raw:(sha(raw),sha(raw.replace(b'\r\n',b'\n')),sha(raw.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')))

def source(get,name):
    name=name.replace('\\','/')
    if '/prepared/'in name:return get('prepared/'+name.split('/prepared/',1)[1])
    relative=next((area+'/'+name.split('/'+area+'/',1)[1]for area in ('src','app','tests')if '/'+area+'/'in name),None)
    assert relative,name
    return(ROOT/relative).read_bytes()

def audit_weather(get,windows,parent):
    read=lambda n:get('weather/'+n);suffix='.exe'if windows else''
    b=json.loads(read('BUILD.json'));assert b['coherent_shared_objects']is True
    assert b['objects_sha256']==parent['objects_sha256']and b['sources_sha256']==parent['sources_sha256']
    assert [f for f in b['flags']if not f.startswith(('-I','-J'))]==[f for f in parent['flags']if not f.startswith(('-I','-J'))]
    assert len(b['events'])==4 and all(e['returncode']==0 for e in b['events'])
    for name,h in b['drivers_sha256'].items():assert h in hashes(source(get,name))
    for name,h in b['executables_sha256'].items():assert sha(read(name+suffix))==h
    data=json.loads(read('WEATHER_EXECUTED.json'));assert len(data['events'])==46 and all(e['returncode']==0 for e in data['events'])
    assert set(data['controls'])=={'neutral','hydraulic'}
    for event in data['events']:
        raw=read(event['stdout']);label=event['label']
        if label=='weather-independent-continuous':assert b'TCS6_REAL_WEATHER_WEEK_ROOT_MASS_OPAQUE_RETRY=PASS'in raw
        elif 'native-write'in label:assert b'TCS6_NATIVE_PREFIX_PROCESS_EXIT=PASS'in raw
        elif 'native-resume'in label:assert b'TCS6_NATIVE_FRESH_PROCESS_NO_DAY_REPLAY=PASS'in raw
        elif label.startswith('decoder-'):assert b'TCS6_NATIVE_INVALID_NO_PARTIAL_PUBLICATION=PASS'in raw
    for phase,rows in data['controls'].items():
        assert len(rows)==18 and all(e['returncode']==0 for e in rows)
        tag='morning'if phase=='neutral'else'dayend'
        for row in rows:
            name='w'+suffix+'.'+tag+'.checkpoint'if row['case']=='different_config'else'weather-'+tag+'-'+row['case']+'.bad'
            raw=read(name);assert sha(raw)==row['input_sha256']
            if row['case']not in ('bad_crc','truncated'):
                assert zlib.crc32(raw[:-4])==struct.unpack_from('<I',raw,len(raw)-4)[0]
    result=json.loads(read('RESULT.json'));assert result['status']=='CURRENT_SHARED_WEATHER_PHYSICS_OWN_NATIVE_36_REFUSALS_AND_INDEPENDENT_CRC_PASS'and result['whole_scientific_admission']is False
    assert set(result['native_sha256'])=={'w'+suffix+'.'+phase+'.'+kind for phase in ('morning','dayend')for kind in ('full','opaque','resumed','active.resumed')}
    for phase in ('morning','dayend'):
        raw=read('w'+suffix+'.'+phase+'.full');assert raw[:4]==b'S5WI'
        assert all(read('w'+suffix+'.'+phase+'.'+kind)==raw for kind in ('opaque','resumed','active.resumed'))
    for name,h in result['native_sha256'].items():
        raw=read(name);assert sha(raw)==h and zlib.crc32(raw[:-4])==struct.unpack_from('<I',raw,len(raw)-4)[0]
    return 'ACTUAL_SHARED_WEATHER_36_DECODER_CONTROLS_RESEALED_SEMANTICS_AND_CRC_PASS'

def audit(get,windows):
    suffix='.exe'if windows else''
    r=json.loads(get('RESULT.json'));assert r['status']=='ACTUAL_CURRENT_ROTATION_CRC_SUCCESSOR_LIFECYCLE_AND_24_REFUSALS_PASS'
    assert r['optimization']in ('O0','O2')and r['production_transform']is False and r['whole_scientific_admission']is False and r['migration_complete']is False
    assert r['production_trees']=={area:subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=ROOT,text=True).strip()for area in ('src','app','reference')}
    original=(ROOT/policy.ORIGINAL).read_bytes().replace(b'\r\n',b'\n');donor=(ROOT/policy.DONOR).read_bytes().replace(b'\r\n',b'\n')
    assert sha(original)==r['original_driver_sha256']and sha(donor)==r['donor_sha256']
    assert get('rotation.f90')==policy.projection(original.decode(),donor.decode()).encode()
    assert sha(get('rotation.f90'))==r['successor_driver_sha256']
    assert sha(get('rotation.o'))==r['driver_object_sha256']and sha(get('rotation'+suffix))==r['executable_sha256']
    b=json.loads(get('build/BUILD.json'));assert b['status']=='COMPLETE_SHARED_ADAPTER_CLOSURE_BUILT'and b['candidate']is False
    assert b['providers']==331 and len(b['objects_sha256'])==349
    assert '-'+r['optimization']in b['flags']and all(x in b['flags']for x in policy.common.FLAGS)
    assert all(e['returncode']==0 for e in b['events'])and len(b['events'])==351
    for name,h in b['sources_sha256'].items():
        raw=source(get,name);assert h in hashes(raw),name
    assert len(b['sources_sha256'])==349
    for name,h in b['objects_sha256'].items():assert sha(get('build/'+Path(name.replace('\\','/')).name))==h
    for name,h in b['drivers_sha256'].items():assert h in hashes(source(get,name))
    assert sha(get('build/r'+suffix))==b['executables_sha256']['r']
    for name,h in r['inputs_sha256'].items():
        raw=(ROOT/name).read_bytes();assert h in(sha(raw),sha(raw.replace(b'\r\n',b'\n')),sha(raw.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'))),name
    events=json.loads(get('EXECUTED.json'));assert len(events)==32
    assert events[0]['label']=='original-obsolete-premise'and events[0]['returncode']==events[0]['expected_returncode']==1
    assert b'FAIL reaction rejects after actual crop preparation'in get(events[0]['stdout'])
    assert all(e['returncode']==e['expected_returncode']==0 for e in events[1:])
    assert [e['label']for e in events[1:8]]==['successor-driver-compile','successor-link','successor-original-all-assertions','resume','resume-retired','resume-fallow','roundtrip-successor']
    assert b'ROTATION_ACTUAL_RICHARDS_RETIRE_FALLOW_SUCCESSOR=PASS'in get(events[3]['stdout'])
    for e in events[8:]:assert b'INVALID_DISK=PASS'in get(e['stdout'])
    assert set(r['native_sha256'])=={'first.bin','end.bin','end.bin.opaque','end.bin.retired','end.bin.fallow','resume.bin','resume-retired.bin','resume-fallow.bin','roundtrip-successor.bin'}
    assert {n:sha(get(n))for n in r['native_sha256']}==r['native_sha256']
    for name in r['native_sha256']:
        raw=get(name);assert len(raw)>160 and zlib.crc32(raw[:-4])==struct.unpack_from('<I',raw,len(raw)-4)[0]
    endpoint=get('end.bin')
    assert all(get(n)==endpoint for n in ('end.bin.opaque','resume.bin','resume-retired.bin','resume-fallow.bin','roundtrip-successor.bin'))
    assert get('first.bin')[:8]==b'S5NC0006'and endpoint[:8]==b'S5NC0001'
    assert all(get(n)[:8]==b'S5NC0005'for n in ('end.bin.retired','end.bin.fallow'))
    names=[]
    for phase in ('retired','fallow'):
        data=bytearray(get('end.bin.'+phase));nn=struct.unpack_from('<i',data,152)[0];hh=struct.unpack_from('<i',data,156)[0]
        chemical=160+16*nn+16+(8*nn if hh else 0);pc=struct.unpack_from('<i',data,chemical+24)[0];crop=chemical+28+8*pc+104
        cc=struct.unpack_from('<i',data,crop+8)[0];owner=crop+12+8*cc+4;assert struct.unpack_from('<d',data,owner)[0]==-81002.
        tests={'marker':(0,-81001.),'clock':(1,99.),'identity':(2,99.),'N':(3,99999.),'OM':(4,99999.),'ledger':(7,0.)}
        for label,(index,value)in tests.items():
            bad=data.copy();struct.pack_into('<d',bad,owner+8*index,value);struct.pack_into('<I',bad,len(bad)-4,zlib.crc32(bad[:-4]))
            name=phase+'-'+label+'.bin';assert get(name)==bad;names.append(name)
    for phase in ('first.bin','end.bin','end.bin.retired','end.bin.fallow'):
        raw=get(phase)
        for label,bad in (('crc',raw[:-1]+bytes([raw[-1]^1])),('truncated',raw[:-5]),('zero-crc',raw[:-4]+b'\0'*4)):
            name=phase+'.'+label;assert get(name)==bad;names.append(name)
    assert names==r['controls']and len(names)==24
    for e,name in zip(events[8:],names):assert e['command'][1:]==['reject',name,'unused']
    weather=audit_weather(get,windows,b)
    return dict(status='ACTUAL_CURRENT_ROTATION_NATIVE_AND_24_ATOMIC_REFUSALS_PASS',optimization=r['optimization'],original_obsolete_premise='EXPECTED_FAIL_RETAINED',weather=weather,whole_scientific_admission=False)

def refusals(get,windows):
    result=[]
    for label,name in (('binary','rotation'+('.exe'if windows else'')),('projection','rotation.f90'),('native','resume-fallow.bin'),('compact_corruption','retired-N.bin'),('events','EXECUTED.json'),('promotion','RESULT.json'),('weather_binary','weather/w'+('.exe'if windows else'')),('weather_native','weather/w'+('.exe'if windows else'')+'.morning.full'),('weather_mutant','weather/weather-morning-wrong_clock.bad')):
        raw=get(name)
        if label=='events':r=json.loads(raw);r.pop();bad=json.dumps(r).encode()
        elif label=='promotion':r=json.loads(raw);r['whole_scientific_admission']=True;bad=json.dumps(r).encode()
        else:bad=raw+b'changed'
        try:audit(lambda n:bad if n==name else get(n),windows)
        except(AssertionError,ValueError,KeyError):result.append(label)
        else:raise AssertionError('accepted evidence defect '+label)
    return result

def verify_windows():
    reports={}
    for opt in ('O0','O2'):
        stem='ROTATION_NATIVE_WINDOWS_20261105_'+opt;r=json.loads((BASE/(stem+'.json')).read_text());raw=(BASE/(stem+'.tar.xz')).read_bytes();assert sha(raw)==r['archive_sha256']
        with tarfile.open(fileobj=io.BytesIO(raw))as t:
            assert len(t.getnames())==len(set(t.getnames()));files={m.name:t.extractfile(m).read()for m in t.getmembers()if m.isfile()}
        assert {n:sha(b)for n,b in files.items()}==r['files_sha256']
        get=lambda n:files[n];report=dict(audit=audit(get,True),data_refusals=refusals(get,True));assert report==r['report'];reports[opt]=report
    reports['unchanged_hupsel']=verify_hupsel_dependency()
    return reports

def verify_hupsel_dependency():
    """Actual admitted 236-provider Hupsel evidence excludes the changed module."""
    changed='src/adapter/mod_crop_soil_n_joint_restart_file.f90'
    for opt in ('O0','O2'):
        stem='PRODUCTION_CROP_LOGICAL_WINDOWS_20261105_'+opt
        name='integration/dataqual15_hupsel/'+stem+'.json'
        assert subprocess.check_output(['git','rev-parse',policy.BASE+':'+name],cwd=ROOT)==subprocess.check_output(['git','rev-parse','HEAD:'+name],cwd=ROOT)
        r=json.loads((BASE/(stem+'.json')).read_text());raw=(BASE/(stem+'.tar.xz')).read_bytes();assert sha(raw)==r['archive_sha256']
        with tarfile.open(fileobj=io.BytesIO(raw))as t:data=t.extractfile('hupsel/build/BUILD.json').read()
        assert sha(data)==r['files_sha256']['hupsel/build/BUILD.json']
        b=json.loads(data);assert b['provider_count']==236
        for name,h in b['source_sha256'].items():
            name=name.replace('\\','/');relative=next((area+'/'+name.split('/'+area+'/',1)[1]for area in ('src','app','tests')if '/'+area+'/'in name),None)
            assert relative and relative!=changed
            assert h in hashes((ROOT/relative).read_bytes())
    return 'ADMITTED_ACTUAL_HUPSEL_236_SOURCE_DEPENDENCY_UNCHANGED_CHANGED_CRC_MODULE_NOT_LINKED_PREDECESSOR_RAW_GATE_REQUIRED'

def verify_posix():
    r=json.loads((BASE/'ROTATION_NATIVE_POSIX_20261105.json').read_text());parts=r['archive_parts']
    assert list(parts)==['ROTATION_NATIVE_POSIX_20261105.zip.part%02d'%i for i in range(len(parts))]
    raw=[]
    for name,h in parts.items():b=(BASE/name).read_bytes();assert sha(b)==h;raw.append(b)
    data=b''.join(raw);assert sha(data)==r['artifact_zip_sha256'];reports={}
    with zipfile.ZipFile(io.BytesIO(data))as z:
        assert len(z.namelist())==len(set(z.namelist()))
        for opt in ('O0','O2'):
            get=lambda n:z.read('rotation-native-'+opt+'/'+n)
            reports[opt]=dict(audit=audit(get,False),data_refusals=refusals(get,False))
    assert reports==r['report'];return reports

def main():
    p=argparse.ArgumentParser();p.add_argument('--seal',type=Path);p.add_argument('--posix',action='store_true');a=p.parse_args();policy.guard()
    if a.seal:
        for opt in ('O0','O2'):
            root=a.seal/opt;files={p.relative_to(root).as_posix():p.read_bytes()for p in root.rglob('*')if p.is_file()};get=lambda n:files[n]
            report=dict(audit=audit(get,True),data_refusals=refusals(get,True));stem='ROTATION_NATIVE_WINDOWS_20261105_'+opt;path=BASE/(stem+'.tar.xz')
            with tarfile.open(path,'w:xz')as t:
                for name,b in sorted(files.items()):info=tarfile.TarInfo(name);info.size=len(b);t.addfile(info,io.BytesIO(b))
            (BASE/(stem+'.json')).write_text(json.dumps(dict(archive_sha256=sha(path.read_bytes()),files_sha256={n:sha(b)for n,b in files.items()},report=report),indent=2)+'\n')
    print(verify_windows());
    if a.posix:print(verify_posix())

if __name__=='__main__':main()
