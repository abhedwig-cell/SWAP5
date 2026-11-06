"""Remeasure new standalone layouts against immutable full provider capsules."""
import argparse
import hashlib
import io
import json
import re
from pathlib import Path
import struct
import tarfile
import zlib

import pond_thermal_native_evidence as previous
import pond_thermal_native_layouts as layouts

STORE = previous.STORE


def sha(blob):
    return hashlib.sha256(blob).hexdigest()


def audit(files):
    result=json.loads(files['RESULT.json']);assert result['status']=='PRIVATE_STANDALONE_S5PT0002_0003_NATIVE_PASS'
    assert result['production_admission'] is False and result['native_evolution_claim'] is False
    assert result['provider_capsule'] in ('POND_THERMAL_NATIVE_WINDOWS_20261106','POND_THERMAL_NATIVE_POSIX_20261106')
    assert len(result['events'])==32 and all(e['returncode']==0 for e in result['events'])
    assert len(result['positives'])==8 and len(result['controls'])==88
    summary=dict(proper_generation_files=16,header_controls_per_role=32,candidate_all_refusals=44,
                 original_failed_header_reject_assertions=0,new_compiled_drivers=8,
                 production_admission=False,native_evolution_claim=False)
    positive={}
    provider=json.loads((STORE/(result['provider_capsule']+'.json')).read_text())
    for index,entry in enumerate(result['positives']):
        prefix=f"{entry['role']}/{entry['optimization']}/{entry['layout']}/"
        proper=files[prefix+'proper.bin'];again=files[prefix+'again.bin']
        assert proper==again and sha(proper)==entry['sha256']
        assert proper[:8]==b'S5PT000'+str(entry['layout']).encode()
        assert zlib.crc32(proper[:-4])==struct.unpack_from('=I',proper,len(proper)-4)[0]
        n,history,identity,count=struct.unpack_from('=iiqi',proper,148)
        assert n==4 and history==0 and identity>0 and count>0
        assert files[prefix+'driver.f90'].replace(b'\r\n',b'\n')==layouts.driver(entry['layout']).encode()
        assert files[prefix+'driver.o']
        compile_event,link_event,create_event,read_event=result['events'][index*4:index*4+4]
        compile_command=compile_event['command'];assert '-c' in compile_command
        assert compile_command[-3].replace('\\','/').endswith('/'+prefix+'driver.f90')
        assert compile_command[-1].replace('\\','/').endswith('/'+prefix+'driver.o')
        if 'WINDOWS' in result['provider_capsule']:
            assert len(link_event['command'])==2 and link_event['command'][1].startswith('@')
            arguments=re.findall(r'^"(.*)"$',files[prefix+'link.args'].decode().replace('\r\n','\n'),re.M)
        else:arguments=link_event['command'][1:]
        members=[p.replace('\\','/') for p in arguments if p.endswith('.o')]
        expected={p for p in provider['members'] if p.startswith(entry['role']+'/base/'+entry['optimization']+'/') and len(p.split('/'))==4 and p.endswith('.o')}
        original_main=max((p for p in expected if Path(p).stem.isdigit()),key=lambda p:int(Path(p).stem));expected.remove(original_main)
        inherited={p.split('/qualified-inputs/',1)[1] for p in members if '/qualified-inputs/' in p}
        assert inherited==expected and len(members)==len(expected)+1
        assert sum(p.endswith('/'+prefix+'driver.o') for p in members)==1
        assert arguments[-1].replace('\\','/').endswith('/'+prefix+('layout.exe' if 'WINDOWS' in result['provider_capsule'] else 'layout'))
        exe=prefix+('layout.exe' if 'WINDOWS' in result['provider_capsule'] else 'layout');assert files[exe]
        for stage in ('build-0','build-1','create','read'):
            assert prefix+stage+'.stdout' in files and prefix+stage+'.stderr' in files
        for stage in ('create','read'):
            assert b'COMPOSED_RESTART_PAIR_AND_HEAT_PASS' in files[prefix+stage+'.stdout']
        key=(entry['optimization'],entry['layout']);positive.setdefault(key,[]).append(proper)
    assert all(len(pair)==2 and pair[0]==pair[1] for pair in positive.values())
    for entry in result['controls']:
        prefix=f"{entry['role']}/{entry['optimization']}/{entry['layout']}/";field=entry['field']
        original=files[prefix+'proper.bin']
        if field in ('time_bound','history'):
            blob=files[prefix+field+'-'+str(entry['word'])+'.bin'];offset=144 if field=='time_bound' else 152
            assert len(blob)==len(original) and blob[:offset]==original[:offset] and blob[offset+4:-4]==original[offset+4:-4]
            assert struct.unpack_from('=i',blob,offset)[0]==entry['word']
            assert zlib.crc32(blob[:-4])==struct.unpack_from('=I',blob,len(blob)-4)[0]
        elif field=='crc':
            blob=files[prefix+'crc.bin'];assert blob[:20]+bytes([blob[20]^1])+blob[21:]==original
        elif field=='truncated': assert files[prefix+'truncated.bin']==original[:-12]
        else: assert field=='parameter'
        event=entry['event'];stdout=files[prefix+event['stdout']];stderr=files[prefix+event['stderr']]
        if entry['role']=='candidate' or field not in ('time_bound','history'):
            assert event['returncode']==0 and b'COMPOSED_RESTART_REJECTION_PASS' in stdout
        elif event['returncode']:
            assert b'atomic invalid restart' in stdout+stderr
            summary['original_failed_header_reject_assertions']+=1
        else: assert b'COMPOSED_RESTART_REJECTION_PASS' in stdout
    return summary


def pack(folder,stem):
    files={p.relative_to(folder).as_posix():p.read_bytes() for p in sorted(folder.rglob('*'))
           if p.is_file() and p.relative_to(folder).parts[0]!='qualified-inputs'}
    measurement=audit(files);dependency=json.loads(files['RESULT.json'])['provider_capsule']
    previous.verify(dependency)
    manifest=dict(status='PRIVATE_STANDALONE_NATIVE_REMEASURED',remeasurement=measurement,
                  provider_capsule=dependency,provider_manifest_lf_sha256=sha((STORE/(dependency+'.json')).read_bytes().replace(b'\r\n',b'\n')),
                  members={p:sha(b) for p,b in files.items()})
    buf=io.BytesIO()
    with tarfile.open(fileobj=buf,mode='w:xz') as tar:
        for name,blob in files.items():
            member=tarfile.TarInfo(name);member.size=len(blob);tar.addfile(member,io.BytesIO(blob))
    raw=buf.getvalue();assert len(raw)<45*1024*1024
    manifest['archive_sha256']=sha(raw);(STORE/(stem+'.tar.xz')).write_bytes(raw)
    (STORE/(stem+'.json')).write_text(json.dumps(manifest,indent=2)+'\n')


def verify(stem,self_test=False):
    m=json.loads((STORE/(stem+'.json')).read_text());raw=(STORE/(stem+'.tar.xz')).read_bytes();assert sha(raw)==m['archive_sha256']
    assert sha((STORE/(m['provider_capsule']+'.json')).read_bytes().replace(b'\r\n',b'\n'))==m['provider_manifest_lf_sha256']
    previous.verify(m['provider_capsule'])
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as tar:
        files={e.name:tar.extractfile(e).read() for e in tar.getmembers()}
    assert {p:sha(b) for p,b in files.items()}==m['members'];assert audit(files)==m['remeasurement']
    if self_test:
        for name in ['candidate/O0/2/driver.f90','candidate/O0/3/driver.o','candidate/O2/2/time_bound-2.bin','candidate/O2/3/proper.bin','candidate/O0/2/history-2.stdout']:
            before=files[name];files[name]=b''
            try: audit(files)
            except (AssertionError,KeyError,struct.error): pass
            else: raise AssertionError('evidence corruption accepted: '+name)
            finally: files[name]=before
    return m['remeasurement']


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--pack',type=Path)
    p.add_argument('--stem',default='POND_THERMAL_LAYOUT_WINDOWS_20261106');p.add_argument('--self-test',action='store_true');a=p.parse_args()
    if a.pack:pack(a.pack.resolve(),a.stem)
    print(json.dumps(verify(a.stem,a.self_test),sort_keys=True))
