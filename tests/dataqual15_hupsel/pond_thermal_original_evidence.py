"""Independent original-runner complete source/object/PE/native qualification."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import tarfile
import zlib

import pond_thermal_native as native
import pond_thermal_native_evidence as previous

STORE=previous.STORE
BASE='9a55a1780de67db95a6003ab397f332ed2c0e965'
BLOBS={}


def sha(raw):return hashlib.sha256(raw).hexdigest()


def original(path):
    if path not in BLOBS:BLOBS[path]=subprocess.check_output(['git','show',BASE+':'+path],cwd=native.ROOT)
    return BLOBS[path]


def audit(files,platform):
    assert platform in ('nt','posix')
    private='POND_THERMAL_NATIVE_'+('WINDOWS' if platform=='nt' else 'POSIX')+'_20261106'
    expected=json.loads((STORE/(private+'.json')).read_text())
    assert files['source/'+native.RUNNER].replace(b'\r\n',b'\n')==original(native.RUNNER)
    assert files['source/'+native.SOURCE].replace(b'\r\n',b'\n')==native.CANDIDATE.read_bytes()
    summary=dict(compiler_objects=0,coherent_resumed_objects=0,proper_native_files=0,default_windows_stack=2097152 if platform=='nt' else None,
                 actual_original_runner=True,runner_changed=False,production_admission=False,whole_scientific_admission=False)
    for recipe,old_recipe in [('physical','base'),('black-rutter','rutter')]:
        report=json.loads(files[recipe+'/result.json'])
        assert report['compiler']==json.loads(files['physical/result.json'])['compiler']
        assert report['results']['O0']==report['results']['O2']
        assert all(e['returncode']==0 for e in report['events'])
        assert report['provider_count']>270
        marker='FOCUSED_BLACK_RUTTER_HEAT_REACTIVE_PASS_NOT_ADMITTED' if recipe=='black-rutter' else 'FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED'
        assert report['status']==marker
        driver_compile=next(e['command'] for e in report['events'] if e['category']=='compile' and e['command'][-3].replace('\\','/').endswith('/tests/nut-sol/test_pond_thermal.f90'))
        root=driver_compile[-3].replace('\\','/').split('/source/')[0]+'/'
        def mapped(path):
            path=path.replace('\\','/');assert path.startswith(root),path
            return path[len(root):]
        for name,digest in report['inputs'].items():
            name=name.replace('\\','/');blob=files['source/'+name];assert sha(blob)==digest
            expected_blob=native.CANDIDATE.read_bytes() if name==native.SOURCE else original(name)
            assert blob.replace(b'\r\n',b'\n')==expected_blob.replace(b'\r\n',b'\n'),name
        for event in report['events']:
            if event['category'] in ('compile','compile-publication'):
                cmd=event['command'];source=mapped(cmd[cmd.index('-c')+1]);obj=mapped(cmd[cmd.index('-o')+1])
                assert files[source] and files[obj];summary['compiler_objects']+=1
                opt=obj.split('/')[1]
                assert opt in ('O0','O2') and '-'+opt in cmd
                if event['category']=='compile':
                    assert all(flag in cmd for flag in ('-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow'))
                else:assert '-std=c11' in cmd and source=='source/app/support/restart_publish.c'
        for opt in ('O0','O2'):
            link=next(e['command'] for e in report['events'] if e['category']=='link' and '-'+opt in e['command'])
            objects=[p for p in link if p.endswith('.o')]
            assert len(objects)==report['provider_count']+2 and any(p.endswith('restart_publish.o') for p in objects)
            for obj in objects:assert files[mapped(obj)]
            if recipe=='black-rutter':
                for obj in objects:
                    name=Path(obj.replace('\\','/')).name
                    if name=='restart_publish.o':continue
                    compiled=[e for e in report['events'] if e['category']=='compile' and e['command'][-1]==obj]
                    if not compiled:
                        assert files[mapped(obj)]==files['physical/'+opt+'/'+name]
                        summary['coherent_resumed_objects']+=1
            exe=files[mapped(link[-1])]
            assert sha(exe)==report['executables'][opt]
            if platform=='nt':
                pe=struct.unpack_from('<I',exe,0x3c)[0];assert exe[pe:pe+4]==b'PE\0\0'
                assert struct.unpack_from('<Q',exe,pe+24+72)[0]==2097152
                response=files[recipe+'/'+opt+'/link.args'].decode().replace('\r\n','\n')
                args=re.findall(r'^"(.*)"$',response,re.M)
                assert args==[p.replace('\\','/') for p in link[1:]]
                assert not any('--stack' in p for p in link)
            else:assert exe[:4]==b'\x7fELF'
            for path,blob in files.items():
                prefix=recipe+'/'+opt+'/'
                if not path.startswith(prefix) or not path.endswith('.bin'):continue
                relative=path[len(prefix):];parts=relative.split('/')
                if len(parts)!=2 or parts[0] in ('controls','logical-controls'):continue
                key='candidate/'+old_recipe+'/'+opt+'/'+relative
                assert sha(blob)==expected['members'][key],key
                assert zlib.crc32(blob[:-4])==struct.unpack_from('=I',blob,len(blob)-4)[0]
                summary['proper_native_files']+=1
    assert summary['proper_native_files']==54
    assert summary['compiler_objects']==576 and summary['coherent_resumed_objects']==568
    return summary


def load(stem):
    m=json.loads((STORE/(stem+'.json')).read_text());chunks=[]
    for part in m['parts']:
        raw=(STORE/part['path']).read_bytes();assert sha(raw)==part['sha256'] and len(raw)==part['size'];chunks.append(raw)
    with tarfile.open(fileobj=io.BytesIO(b''.join(chunks)),mode='r:xz') as tar:
        files={member.name:tar.extractfile(member).read() for member in tar.getmembers()}
    assert {p:sha(b) for p,b in files.items()}==m['members']
    return m,files


def verify(stem,platform,self_test=False):
    m,files=load(stem);measurement=audit(files,platform)
    if 'remeasurement' in m:assert measurement==m['remeasurement']
    if self_test:
        exe='physical/O0/thermal'+('.exe' if platform=='nt' else '')
        for path in ['source/'+native.RUNNER,'source/'+native.SOURCE,'physical/O0/restart_publish.o',exe,'black-rutter/O2/2/restart.bin']:
            before=files[path];files[path]=b''
            try:audit(files,platform)
            except (AssertionError,KeyError,ValueError,struct.error):pass
            else:raise AssertionError('original-build corruption accepted: '+path)
            finally:files[path]=before
    return measurement


def pack(folder,stem,platform):
    files={p.relative_to(folder).as_posix():p.read_bytes() for p in sorted(folder.rglob('*')) if p.is_file() and p.name!='.git'}
    measurement=audit(files,platform)
    m=dict(status='ACTUAL_ORIGINAL_BUILD_INDEPENDENTLY_QUALIFIED',remeasurement=measurement,members={p:sha(b) for p,b in files.items()},parts=[])
    buf=io.BytesIO();seen={}
    with tarfile.open(fileobj=buf,mode='w:xz') as tar:
        for name,blob in files.items():
            info=tarfile.TarInfo(name);digest=sha(blob)
            if digest in seen:info.type=tarfile.LNKTYPE;info.linkname=seen[digest];tar.addfile(info)
            else:info.size=len(blob);tar.addfile(info,io.BytesIO(blob));seen[digest]=name
    raw=buf.getvalue()
    for offset in range(0,len(raw),40*1024*1024):
        blob=raw[offset:offset+40*1024*1024];name=stem+f'.tar.xz.part{len(m["parts"]):02d}'
        (STORE/name).write_bytes(blob);m['parts'].append(dict(path=name,sha256=sha(blob),size=len(blob)))
    (STORE/(stem+'.json')).write_text(json.dumps(m,indent=2)+'\n')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--stem',default='POND_THERMAL_ORIGINAL_WINDOWS_MEASUREMENT_20261106')
    p.add_argument('--platform',choices=['nt','posix'],default=os.name);p.add_argument('--pack',type=Path);p.add_argument('--self-test',action='store_true');a=p.parse_args()
    if a.pack:pack(a.pack.resolve(),a.stem,a.platform)
    print(json.dumps(verify(a.stem,a.platform,a.self_test),sort_keys=True))
