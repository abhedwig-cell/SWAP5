#!/usr/bin/env python3
"""Additional independent native configuration and semantic-CRC controls."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import time
import zlib

ROOT = Path(__file__).resolve().parents[2]
CASES = ['1', '0.5', '0.8', '1.0005', '1.5', '2']

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--physical-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    report = {'status': 'RUNNING', 'cases': {}, 'events': [], 'inputs': {
        str(Path(__file__).relative_to(ROOT)): sha(Path(__file__))}}
    for exponent in CASES:
        physical = args.physical_root.resolve() / ('pond-1-final' if exponent == '1' else 'pond-' + exponent)
        p = json.loads((physical / 'result.json').read_text())
        assert p['status'] == 'NONLINEAR_POND_PHYSICAL_PASS_NOT_ADMITTED'
        case = report['cases'][exponent] = {'physical_sha256': sha(physical / 'result.json'), 'executables': {}}
        for opt in ['O0', 'O2']:
            directory = out / exponent / opt
            directory.mkdir(parents=True)
            exe = physical / opt / 'joint'
            case['executables'][opt] = sha(exe)
            raw = (physical / opt / 'restart.bin').read_bytes()
            n = struct.unpack_from('i', raw, 152)[0]
            history = struct.unpack_from('i', raw, 156)[0]
            chemical = 160 + 8*(2*n+2+(n if history else 0))
            count = struct.unpack_from('i', raw, chemical+24)[0]
            values = chemical+28
            tests = {}
            for label, index, value in [('exponent_changed', count-7, 1.25),
                                        ('exponent_low', count-7, .49999),
                                        ('exponent_high', count-7, 2.00001),
                                        ('cref_changed', count-8, 2.25)]:
                data = bytearray(raw[:-4])
                struct.pack_into('d', data, values+8*index, value)
                tests[label] = bytes(data)+struct.pack('I', zlib.crc32(data)&0xffffffff)
            tests['supplied_configuration_changed'] = raw
            for label, data in tests.items():
                path = directory/(label+'.bin')
                path.write_bytes(data)
                requested = '1.25' if label == 'supplied_configuration_changed' else exponent
                command = [str(exe), 'reject', str(path), str(directory/'unused'), 'wet', requested]
                start = time.perf_counter()
                r = subprocess.run(command, capture_output=True)
                i = len(report['events'])
                (out/f'{i:04d}.stdout').write_bytes(r.stdout)
                (out/f'{i:04d}.stderr').write_bytes(r.stderr)
                report['events'].append({'command': command, 'returncode': r.returncode,
                                          'seconds': time.perf_counter()-start, 'case': exponent,
                                          'opt': opt, 'label': label})
                assert r.returncode == 0 and b'POND_JOINT_INVALID_FILE=PASS' in r.stdout
                assert sha(exe) == case['executables'][opt]
    # A real executable with the original guard must reject the new nonlinear
    # composition; its linear endpoint must be identical. No copied science.
    build = args.physical_root.resolve()/'pond-1-final'
    old_source = subprocess.check_output(['git','show','e61d8e107121bc31fa1d9b0eac73439af29eb76f:src/runtime/mod_fmr_b111_pond_solute_route.f90'], cwd=ROOT)
    old_path = out/'original_pond_route.f90'
    old_path.write_bytes(old_source)
    events = json.loads((build/'events.json').read_text())
    report['preimage'] = {}
    for opt in ['O0','O2']:
        directory = out/'preimage'/opt
        directory.mkdir(parents=True)
        event = next(e for e in events if e['category']=='physical_compile' and '-'+opt in e['command'] and e['command'][e['command'].index('-c')+1].endswith('/src/runtime/mod_fmr_b111_pond_solute_route.f90'))
        compile_command = [str(old_path) if a.endswith('/src/runtime/mod_fmr_b111_pond_solute_route.f90') else str(directory/'old.o') if a==event['command'][-1] else '-J'+str(directory) if a.startswith('-J') else a for a in event['command']]
        link_event = next(e for e in events if e['category']=='physical_link' and '-'+opt in e['command'])
        executable = directory/'old-joint'
        link_command = [str(directory/'old.o') if a==event['command'][-1] else str(executable) if a==link_event['command'][-1] else a for a in link_event['command']]
        observations=[]
        for label,command,expected in [('compile',compile_command,0),('link',link_command,0),
            ('linear',[str(executable),'write',str(directory/'restart.bin'),str(directory/'expected.bin'),'wet','1'],0),
            ('nonlinear',[str(executable),'write',str(directory/'nonlinear-restart.bin'),str(directory/'nonlinear-endpoint.bin'),'wet','.5'],None)]:
            start=time.perf_counter();r=subprocess.run(command,capture_output=True)
            (directory/(label+'.stdout')).write_bytes(r.stdout);(directory/(label+'.stderr')).write_bytes(r.stderr)
            observations.append({'label':label,'command':command,'returncode':r.returncode,'expected_returncode':expected,'seconds':time.perf_counter()-start})
            assert r.returncode==0 if expected==0 else r.returncode!=0
        assert (directory/'expected.bin').read_bytes()==(build/opt/'expected.bin').read_bytes()
        assert b'FAIL smaller retry' in (directory/'nonlinear.stdout').read_bytes()
        report['preimage'][opt]=observations
    report['status'] = 'NONLINEAR_POND_SEMANTIC_NATIVE_CONTROLS_PASS_NOT_ADMITTED' 
    report['native_controls'] = len(report['events'])
    report['native_seconds'] = sum(e['seconds'] for e in report['events'])
    (out/'result.json').write_text(json.dumps(report, indent=2)+'\n')
    print(report['status'], report['native_controls'])

if __name__ == '__main__':
    main()
