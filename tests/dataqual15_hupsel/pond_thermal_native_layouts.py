"""Actual standalone S5PT0002/0003 typed-owner native qualification."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tarfile
import zlib

import pond_thermal_native as native
import pond_thermal_native_evidence as evidence

ROOT = native.ROOT
FIXTURE = 'tests/nut-sol/test_composed_heat_restart.f90'


def driver(layout):
    source = subprocess.check_output(['git', 'show', '89a9e1cffc40b65339f9eba4b9451e7a574ccda6:'+FIXTURE], cwd=ROOT).decode()
    # The qualified full-composition provider image already has exactly this
    # immutable four-node grid. Avoid a second, conflicting legacy context owner.
    assert source.count(' use solute_column_context,only:initialize_column_context') == 1
    source = source.replace(' use solute_column_context,only:initialize_column_context\n', '')
    assert source.count(' call initialize_column_context([.5d0,.5d0,1d0,1d0])') == 1
    source = source.replace(' call initialize_column_context([.5d0,.5d0,1d0,1d0])\n', '')
    if layout == 3:
        source = source.replace('boesten_evaporation', 'black_evaporation').replace('BOESTEN_EVAPORATION', 'BLACK_EVAPORATION')
        assert 'pair%spev=2d0;pair%saev=.5d0' in source
        source = source.replace('pair%spev=2d0;pair%saev=.5d0', 'pair%ldwet=2d0')
        source = source.replace('q%black_evaporation%spev==2d0.and.q%black_evaporation%saev==.5d0', 'q%black_evaporation%ldwet==2d0')
        source = source.replace('p%black_evaporation_active=.true.', 'p%black_evaporation_active=.true.;p%black_heat_composition_enabled=.true.')
    return source


def unpack(out):
    stem = 'POND_THERMAL_NATIVE_'+('WINDOWS' if os.name == 'nt' else 'POSIX')+'_20261106'
    evidence.verify(stem)
    manifest = json.loads((evidence.STORE/(stem+'.json')).read_text())
    raw = b''.join((evidence.STORE/p['path']).read_bytes() for p in manifest['parts'])
    source = out/'qualified-inputs'; source.mkdir()
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as tar:
        for member in tar.getmembers():
            parts = Path(member.name).parts
            if len(parts) < 2 or parts[0] not in ('baseline', 'candidate'):
                continue
            if parts[1] not in ('source', 'base', 'RESULT.json'):
                continue
            assert member.isfile() and not Path(member.name).is_absolute() and '..' not in parts
            blob = tar.extractfile(member).read()
            assert hashlib.sha256(blob).hexdigest() == manifest['members'][member.name]
            p = source/member.name; p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(blob)
    return source, stem


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(); native.guard(); out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    source, stem = unpack(out)
    result = dict(status='RUNNING', provider_capsule=stem, production_admission=False,
                  whole_scientific_admission=False, native_evolution_claim=False, events=[], positives=[], controls=[])
    for role in ('baseline', 'candidate'):
        report = json.loads((source/role/'base/result.json').read_text())
        runner = json.loads((source/role/'RESULT.json').read_text())['events'][0]['command'][2].replace('\\', '/')
        prefix = runner.split('/source/')[0]+'/'

        def remap(value):
            normalized = value.replace('\\', '/')
            return str(source/role/normalized[len(prefix):]) if normalized.startswith(prefix) else value

        for opt in ('O0', 'O2'):
            link = next(e['command'] for e in report['events'] if e['category']=='link' and '/'+opt+'/' in e['command'][-1].replace('\\','/'))
            main_compile = next(e['command'] for e in report['events'] if e['category']=='compile' and Path(e['command'][-3]).name=='test_pond_thermal.f90' and '/'+opt+'/' in e['command'][-1].replace('\\','/'))
            fc = os.environ.get('FC', 'gfortran')
            actual_compiler = subprocess.check_output([fc, '--version'], text=True).splitlines()[0]
            assert actual_compiler == report['compiler'], 'provider compiler drift'
            for layout in (2, 3):
                work = out/role/opt/str(layout); work.mkdir(parents=True)
                f = work/'driver.f90'; f.write_text(driver(layout)); obj=work/'driver.o'
                flags = [remap(p) for p in main_compile[1:main_compile.index('-c')]]
                # -J/-I are concatenated flags, rather than separate paths.
                flags = [p[:2]+remap(p[2:]) if p.startswith(('-J','-I')) else p for p in flags]
                commands = [[fc, *flags, '-c', str(f), '-o', str(obj)]]
                cmd=[fc]+[remap(p) for p in link[1:]]
                old=remap(main_compile[-1]); assert cmd.count(old)==1; cmd[cmd.index(old)]=str(obj)
                exe=work/('layout.exe' if os.name=='nt' else 'layout');cmd[-1]=str(exe)
                if os.name=='nt':
                    response=work/'link.args';response.write_text('\n'.join('"'+v.replace('\\','/')+'"' for v in cmd[1:])+'\n')
                    commands.append([fc,'@'+str(response)])
                else: commands.append(cmd)
                for i, command in enumerate(commands):
                    event=native.execute(command,work,work,'build-'+str(i));result['events'].append(event)
                    assert event['returncode']==0,(work/event['stderr']).read_text(errors='replace')[-3000:]
                path=work/'proper.bin';again=work/'again.bin'
                for mode, target in [('create',path),('read',again)]:
                    event=native.execute([exe,mode,path,target],work,work,mode);result['events'].append(event)
                    assert event['returncode']==0,(work/event['stderr']).read_text(errors='replace')[-3000:]
                    assert b'COMPOSED_RESTART_PAIR_AND_HEAT_PASS' in (work/event['stdout']).read_bytes()
                raw=path.read_bytes();assert raw==again.read_bytes() and raw[:8]==b'S5PT000'+str(layout).encode()
                assert zlib.crc32(raw[:-4])==struct.unpack_from('=I',raw,len(raw)-4)[0]
                result['positives'].append(dict(role=role,optimization=opt,layout=layout,sha256=native.sha(path)))
                for field,offset in [('time_bound',144),('history',152)]:
                    assert struct.unpack_from('=i',raw,offset)[0] in (0,1)
                    for word in (2,-1,0x01000000,0x7fffffff):
                        blob=bytearray(raw);struct.pack_into('=i',blob,offset,word);struct.pack_into('=I',blob,len(blob)-4,zlib.crc32(blob[:-4]))
                        label=field+'-'+str(word);bad=work/(label+'.bin');bad.write_bytes(blob)
                        event=native.execute([exe,'reject',bad,work/'unused'],work,work,label)
                        if role=='candidate':
                            assert event['returncode']==0 and b'COMPOSED_RESTART_REJECTION_PASS' in (work/event['stdout']).read_bytes()
                        result['controls'].append(dict(role=role,optimization=opt,layout=layout,field=field,word=word,event=event))
                for label,blob in [('crc',raw[:20]+bytes([raw[20]^1])+raw[21:]),('truncated',raw[:-12])]:
                    bad=work/(label+'.bin');bad.write_bytes(blob);event=native.execute([exe,'reject',bad,work/'unused'],work,work,label)
                    assert event['returncode']==0 and b'COMPOSED_RESTART_REJECTION_PASS' in (work/event['stdout']).read_bytes()
                    result['controls'].append(dict(role=role,optimization=opt,layout=layout,field=label,event=event))
                event=native.execute([exe,'reject-parameter',path,work/'unused'],work,work,'parameter')
                assert event['returncode']==0 and b'COMPOSED_RESTART_REJECTION_PASS' in (work/event['stdout']).read_bytes()
                result['controls'].append(dict(role=role,optimization=opt,layout=layout,field='parameter',event=event))
                (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
                print(role,opt,'S5PT000'+str(layout),'native layout measured',flush=True)
    for opt in ('O0','O2'):
        for layout in (2,3):
            selected=[e['sha256'] for e in result['positives'] if e['optimization']==opt and e['layout']==layout]
            assert len(selected)==2 and selected[0]==selected[1]
    result['status']='PRIVATE_STANDALONE_S5PT0002_0003_NATIVE_PASS'
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');native.guard()


if __name__=='__main__': main()
