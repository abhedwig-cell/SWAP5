"""Independent complete S5PT writer source/object/authority/crash remeasurement."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import tarfile
import zlib

import pond_thermal_writer as writer
import pond_thermal_native_evidence as previous

STORE=previous.STORE
CACHE={}


def sha(raw):return hashlib.sha256(raw).hexdigest()


def dependency(stem):
    if stem not in CACHE:
        previous.verify(stem)
        m=json.loads((STORE/(stem+'.json')).read_text())
        raw=b''.join((STORE/p['path']).read_bytes() for p in m['parts'])
        with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as tar:
            blob=tar.extractfile('candidate/base/result.json').read()
        assert sha(blob)==m['members']['candidate/base/result.json']
        CACHE[stem]=(m,json.loads(blob))
    return CACHE[stem]


def status(raw):
    found=re.findall(br'^WRITE_STATUS=([0-9]+)\r?$',raw,re.M)
    assert len(found)==1
    return int(found[0])


def audit(files):
    result=json.loads(files['RESULT.json']);platform=result['platform']
    assert platform in ('nt','posix') and result['status']=='PRIVATE_COMPLETE_S5PT_WRITER_FAULTS_AND_ACTUAL_CRASHES_PASS'
    assert result['production_admission'] is False and result['whole_scientific_admission'] is False
    stem=result['provider_capsule'];assert stem=='POND_THERMAL_NATIVE_'+('WINDOWS' if platform=='nt' else 'POSIX')+'_20261106'
    provider,report=dependency(stem)
    summary=dict(new_compiler_objects=12,normal_publications=0,raw_logical_refusals=0,
                 precommit_io_refusals=0,stage6_windows_successes=0,stage6_posix_postcommit_failures=0,
                 retained_pending_retry_refusals=0,actual_terminations=0,fresh_crash_reconstructions=0,
                 production_admission=False,whole_scientific_admission=False)
    for opt in ('O0','O2'):
        prefix=opt+'/'
        expected_sources={'writer-test.f90':writer.injected_source().encode(),
                          'publication.c':(writer.ROOT/'app/support/restart_publish.c').read_bytes(),
                          'shim.c':writer.shim_source(platform).encode(),
                          **{f'driver-{layout}.f90':writer.probe_driver(layout).encode() for layout in (1,2,3)}}
        for name,expected in expected_sources.items():
            assert files[prefix+name].replace(b'\r\n',b'\n')==expected.replace(b'\r\n',b'\n'),name
        build=json.loads(files[prefix+'BUILD.json']);assert len(build)==9 and all(e['returncode']==0 for e in build)
        objects=['writer-test.o','real.o','shim.o','driver-1.o','driver-2.o','driver-3.o']
        for name in objects:assert files[prefix+name]
        old_driver=next(e['command'] for e in report['events'] if e['category']=='compile' and e['command'][-3].replace('\\','/').endswith('/test_pond_thermal.f90') and '-'+opt in e['command'])
        old_module=next(e['command'] for e in report['events'] if e['category']=='compile' and e['command'][-3].replace('\\','/').endswith('/'+writer.native.SOURCE) and '-'+opt in e['command'])
        def basekey(path):
            path=path.replace('\\','/');return 'candidate/base/'+opt+'/'+path.rsplit('/',1)[1]
        expected={p for p in provider['members'] if p.startswith('candidate/base/'+opt+'/') and len(p.split('/'))==4 and p.endswith('.o')}
        expected-={basekey(old_driver[-1]),basekey(old_module[-1]),'candidate/base/'+opt+'/restart_publish.o'}
        for layout in (1,2,3):
            if platform=='nt':
                args=re.findall(r'^"(.*)"$',files[prefix+f'link-{layout}.args'].decode().replace('\r\n','\n'),re.M)
            else:args=build[4+(layout-1)*2]['command'][1:]
            members=[p.replace('\\','/') for p in args if p.endswith('.o')]
            inherited={p.split('/qualified-inputs/',1)[1] for p in members if '/qualified-inputs/' in p}
            assert inherited==expected and len(members)==len(expected)+4
            new={p.rsplit('/',1)[1] for p in members if '/qualified-inputs/' not in p}
            assert new=={'writer-test.o','real.o','shim.o',f'driver-{layout}.o'}
            exe=prefix+f'writer-{layout}'+('.exe' if platform=='nt' else '');assert files[exe]
        for layout in (1,2,3,4):
            d=prefix+str(layout)+'/'
            old=files[d+'expected-old.bin'];good=files[d+'expected-good.bin'];assert old!=good
            for blob in (old,good):
                assert blob[:8]==b'S5PT000'+str(layout).encode()
                assert zlib.crc32(blob[:-4])==struct.unpack_from('=I',blob,len(blob)-4)[0]
                assert struct.unpack_from('=i',blob,152)[0]==0
            if layout in (1,4):
                p='candidate/'+('base' if layout==1 else 'rutter')+'/'+opt+'/2/'
                assert sha(old)==provider['members'][p+'restart.bin'] and sha(good)==provider['members'][p+'full.bin']
    assert len(result['events'])==60 and len(result['crashes'])==16
    seen=set()
    for entry in result['events']:
        opt=entry['optimization'];layout=entry['layout'];kind=entry['kind'];value=entry['value']
        key=(opt,layout,kind,value);assert key not in seen;seen.add(key)
        assert opt in ('O0','O2') and layout in (1,2,3,4)
        assert (kind=='normal' and value==0) or (kind=='logical' and value in ((1,2,3) if layout==4 else (1,))) or (kind=='io' and value in (2,3,4,5,6))
        d=opt+'/'+str(layout)+'/';p=d+kind+'-'+str(value)+'/'
        event=entry['event'];assert event['returncode']==0
        success=kind=='normal' or (kind=='io' and value==6 and platform=='nt')
        published=kind=='normal' or (kind=='io' and value==6)
        assert entry['published'] is published
        assert status(files[p+event['stdout']])==(0 if success else 1)
        if kind=='normal':summary['normal_publications']+=1
        elif kind=='logical':
            assert b'RAW_WORD=2' in files[p+event['stdout']] and ('RAW_SITE='+str(value)).encode() in files[p+event['stdout']]
            summary['raw_logical_refusals']+=1
        elif value==6:summary['stage6_windows_successes' if platform=='nt' else 'stage6_posix_postcommit_failures']+=1
        else:summary['precommit_io_refusals']+=1
        old=files[d+'expected-old.bin'];good=files[d+'expected-good.bin']
        assert files[p+'authority']==(good if published else old) and files[p+'recovered']==good
        retained=kind=='io' and value in (2,3,4,5);assert entry['retained_pending'] is retained
        assert (p+'authority.pending' in files)==retained
        if retained:
            assert files[p+'authority.pending']==good
            retry=event['retained_pending_retry'];assert retry['returncode']==0
            assert status(files[p+retry['stdout']])==1 and files[p+'retry-recovered']==good
            summary['retained_pending_retry_refusals']+=1
    seen=set()
    for entry in result['crashes']:
        opt=entry['optimization'];layout=entry['layout'];phase=entry['phase'];key=(opt,layout,phase)
        assert key not in seen;seen.add(key);assert opt in ('O0','O2') and layout in (1,2,3,4) and phase in ('before','after')
        d=opt+'/'+str(layout)+'/';p=d+'terminate-'+phase+'/'
        event=entry['event'];assert event['phase']==phase and event['actual_process_terminated'] is True
        assert event['termination_returncode']==(1 if platform=='nt' else -9)
        assert event['stop_observed']==('Windows named event' if platform=='nt' else 'SIGSTOP')
        assert event['termination_method']==('TerminateProcess' if platform=='nt' else 'SIGKILL')
        assert p+'crash.stdout' in files and p+'crash.stderr' in files
        old=files[d+'expected-old.bin'];good=files[d+'expected-good.bin'];expected=old if phase=='before' else good
        assert files[p+'authority']==files[p+'fresh']==files[p+'fresh-again']==expected
        fresh=entry['fresh'];assert fresh['returncode']==0 and status(files[p+fresh['stdout']])==0
        assert (p+'authority.pending' in files)==(phase=='before')
        if phase=='before':
            assert files[p+'authority.pending']==good
            retry=entry['pending_retry'];assert retry['returncode']==0 and status(files[p+retry['stdout']])==1
            assert files[p+'pending-retry-recovered']==good;summary['retained_pending_retry_refusals']+=1
        summary['actual_terminations']+=1;summary['fresh_crash_reconstructions']+=1
    assert summary['normal_publications']==8 and summary['raw_logical_refusals']==12 and summary['precommit_io_refusals']==32
    assert summary['stage6_windows_successes']+summary['stage6_posix_postcommit_failures']==8
    assert summary['retained_pending_retry_refusals']==40 and summary['actual_terminations']==16
    return summary


def pack(folder,stem):
    files={p.relative_to(folder).as_posix():p.read_bytes() for p in sorted(folder.rglob('*'))
           if p.is_file() and p.relative_to(folder).parts[0]!='qualified-inputs'}
    measurement=audit(files);source=json.loads(files['RESULT.json'])['provider_capsule']
    manifest=dict(status='PRIVATE_COMPLETE_NATIVE_WRITER_REMEASURED',remeasurement=measurement,provider_capsule=source,
                  provider_manifest_lf_sha256=sha((STORE/(source+'.json')).read_bytes().replace(b'\r\n',b'\n')),
                  members={p:sha(b) for p,b in files.items()},parts=[])
    buf=io.BytesIO()
    with tarfile.open(fileobj=buf,mode='w:xz') as tar:
        for name,blob in files.items():
            info=tarfile.TarInfo(name);info.size=len(blob);tar.addfile(info,io.BytesIO(blob))
    raw=buf.getvalue()
    for offset in range(0,len(raw),40*1024*1024):
        blob=raw[offset:offset+40*1024*1024];name=stem+f'.tar.xz.part{len(manifest["parts"]):02d}'
        (STORE/name).write_bytes(blob);manifest['parts'].append(dict(path=name,sha256=sha(blob),size=len(blob)))
    (STORE/(stem+'.json')).write_text(json.dumps(manifest,indent=2)+'\n')


def verify(stem,self_test=False):
    m=json.loads((STORE/(stem+'.json')).read_text());chunks=[]
    for part in m['parts']:
        raw=(STORE/part['path']).read_bytes();assert sha(raw)==part['sha256'] and len(raw)==part['size'];chunks.append(raw)
    assert sha((STORE/(m['provider_capsule']+'.json')).read_bytes().replace(b'\r\n',b'\n'))==m['provider_manifest_lf_sha256']
    with tarfile.open(fileobj=io.BytesIO(b''.join(chunks)),mode='r:xz') as tar:
        files={member.name:tar.extractfile(member).read() for member in tar.getmembers()}
    assert {p:sha(b) for p,b in files.items()}==m['members'];assert audit(files)==m['remeasurement']
    if self_test:
        for path in ['O0/writer-test.f90','O0/real.o','O0/4/logical-3/writer.stdout','O2/2/io-2/authority.pending','O0/3/terminate-before/authority','O2/4/terminate-after/fresh']:
            before=files[path];files[path]=b''
            try:audit(files)
            except (AssertionError,KeyError,struct.error):pass
            else:raise AssertionError('writer evidence corruption accepted: '+path)
            finally:files[path]=before
    return m['remeasurement']


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--pack',type=Path)
    p.add_argument('--stem',default='POND_THERMAL_WRITER_WINDOWS_20261106');p.add_argument('--self-test',action='store_true');a=p.parse_args()
    if a.pack:pack(a.pack.resolve(),a.stem)
    print(json.dumps(verify(a.stem,a.self_test),sort_keys=True))
