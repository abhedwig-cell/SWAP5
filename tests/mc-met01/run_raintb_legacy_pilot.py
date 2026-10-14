#!/usr/bin/env python3
"""Bounded legacy-table feedback and real weather/Richards integration.

No frozen owner driver, numerical flags, tolerance or admission guard is changed.
Full owner preservation remains a separate pending admission condition.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]
DRIVER = ROOT / 'tests/modularity/test_raintb_legacy_table.f90'
BASE = 'c591205c5e03f1c96c6488eb53c562265f749556'


def source_guard(driver):
    archive = ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes()))) as donor:
        functions = donor.extractfile('SWAP/functions.f90').read()
        meteo = donor.extractfile('SWAP/MOD_meteo.f90').read()
    assert hashlib.sha256(functions).hexdigest() == 'b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527'
    assert hashlib.sha256(meteo).hexdigest() == '99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f'
    text = functions.decode().replace('\r\n', '\n')
    start = text.index('   real(8) function afgen (')
    end = text.index('   end function afgen', start) + len('   end function afgen')
    literal = driver.split('  ! BEGIN LITERAL B1.11 AFGEN\n', 1)[1].split('\n  ! END LITERAL B1.11 AFGEN', 1)[0]
    assert literal == text[start:end], 'independent AFGEN excerpt altered'
    for statement in ('rflx = afgen(raintb, size(raintb), doy)',
                      'rtim = dmin1(1.d0, all_rain(i) * 0.1d0 / rflx)',
                      'rainflx(rain_rec) = all_rain(i) * 0.1d0 / rtim'):
        line = [line for line in meteo.decode().splitlines() if line.strip() == statement]
        assert len(line) == 1 and line[0] in driver, statement
    return {'functions_sha256': hashlib.sha256(functions).hexdigest(),
            'meteo_sha256': hashlib.sha256(meteo).hexdigest(),
            'driver_sha256': hashlib.sha256(driver.encode()).hexdigest()}


def integration(output):
    # The incumbent production fixture supplies real Richards, authentic weather,
    # fixed source-oracle extraction, unchanged geometry and O0/O2 configuration.
    pins = {'tests/fmig431/run_crop_file_weather_production.sh': 'b4cfeedb9a09339ef095005243168978d1376956',
            'tests/fmig431/test_crop_file_weather_production.f90': '5350f175cccda6f01c9812afb7c231a1cb118cc8'}
    for path, expected in pins.items():
        raw = (ROOT / path).read_bytes()
        assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == expected
    body = (ROOT / 'tests/mc-met01/test_raintb_production.inc').read_text()
    body = body.replace('swap_raintb_t,construct_swap_raintb,resolve_swap_raintb_pulse',
                        'swap_raintb_t,construct_swap_raintb,construct_swap_raintb_legacy_table,resolve_swap_raintb_pulse', 1)
    body = body.replace('    type(swap_raintb_t)::table,wrong_table',
                        '    character(16)::table_mode\n    type(swap_raintb_t)::table,wrong_table', 1)
    old = '      call construct_swap_raintb([1.d0,366.d0],[0.5d0*profile,0.5d0*profile],table,st)'
    assert body.count(old) == 1
    body = body.replace(old, '''      call get_command_argument(7,table_mode)
      if(trim(table_mode)=='legacy') then
        ! Historical alternating array: one populated pair and zero sentinel.
        ! Active day-one endpoint intensity drives authentic precipitation.
        call construct_swap_raintb_legacy_table([1.d0,0.5d0*profile,0.d0,0.d0,0.d0,0.d0],table,st)
      else
        call construct_swap_raintb([1.d0],[0.5d0*profile],table,st)
      end if''')
    source = (ROOT / 'tests/fmig431/test_crop_file_weather_production.f90').read_text()
    first = source.index('  call test_rooted_weather_production()')
    boundary = source.index('\ncontains\n')
    source = source[:first] + '  call test_raintb_production()\n' + source[boundary:]
    source = source.replace('\ncontains\n', '\ncontains\n' + body, 1)
    driver = output / 'driver.f90'; driver.write_text(source)
    runner = (ROOT / 'tests/fmig431/run_crop_file_weather_production.sh').read_text()
    runner = runner.split('    for moisture in neutral dry hydraulic; do', 1)[0]
    runner += '''    for table_mode in typed legacy; do
      for mode in continuous restart; do
        python "$PILOT_TIMER" native ./test "$BUILD/weather.999" "$BUILD/altered.999" "$BUILD/bad.999" "$BUILD/backup.999" "$mode" neutral "$table_mode" > "$table_mode-$mode.txt" 2> "$table_mode-$mode.diagnostics"
      done
      cmp "$table_mode-continuous.txt" "$table_mode-restart.txt"
    done
    cmp typed-continuous.txt legacy-continuous.txt
    cp legacy-continuous.txt output.txt
  )
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo 'MC_MET01_LEGACY_TABLE_ACTUAL_RICHARDS_O0_O2=PASS'
'''
    runner = runner.replace('ROOT="$(cd "$(dirname "$0")/../.." && pwd)"', 'ROOT="$PILOT_ROOT"')
    runner = runner.replace('BUILD="$(mktemp -d)"', 'BUILD="$PILOT_BUILD"')
    runner = runner.replace('trap \'rm -rf "$BUILD"\' EXIT', '# Retain raw build and native evidence.')
    runner = runner.replace('"$ROOT/tests/fmig431/test_crop_file_weather_production.f90"', '"$PILOT_DRIVER"')
    shell = output / 'run.sh'; shell.write_text(runner)
    build = output / 'build'; build.mkdir()
    timer = output / 'timer.py'
    timer.write_text('''import json,os,subprocess,sys,time
kind=sys.argv[1];args=sys.argv[2:]
if kind=='compiler':
 kind='compile' if '-c' in args else 'link'
 args=[os.environ['PILOT_COMPILER'],*args]
start=time.perf_counter();cp=subprocess.run(args)
event={'kind':kind,'command':args,'cwd':os.getcwd(),'wall_seconds':time.perf_counter()-start,'returncode':cp.returncode}
with open(os.environ['PILOT_EVENTS'],'a') as stream:stream.write(json.dumps(event)+'\\n')
sys.exit(cp.returncode)
''')
    compiler = shutil.which('gfortran'); assert compiler
    binaries = output / 'bin'; binaries.mkdir()
    wrapper = binaries / 'gfortran'
    wrapper.write_text('#!/bin/sh\nexec python "$PILOT_TIMER" compiler "$@"\n'); wrapper.chmod(0o755)
    environment = dict(os.environ, PILOT_ROOT=str(ROOT), PILOT_BUILD=str(build),
                       PILOT_DRIVER=str(driver), PILOT_TIMER=str(timer), PILOT_COMPILER=compiler,
                       PILOT_EVENTS=str(output / 'events.jsonl'), PATH=str(binaries) + os.pathsep + os.environ['PATH'])
    start = time.perf_counter()
    with (output / 'stdout.log').open('wb') as stdout, (output / 'stderr.log').open('wb') as stderr:
        cp = subprocess.run(['bash', str(shell)], cwd=ROOT, env=environment, stdout=stdout, stderr=stderr)
    events = [json.loads(line) for line in (output / 'events.jsonl').read_text().splitlines()]
    summary = {'terminal_exit': cp.returncode, 'wall_seconds': time.perf_counter()-start,
               'events': events, 'categories': {kind: {'count': sum(e['kind']==kind for e in events),
                 'seconds': sum(e['wall_seconds'] for e in events if e['kind']==kind)}
                 for kind in ('compile', 'link', 'native')}, 'baseline': BASE,
               'head': subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
               'physics_only_seconds': 'UNKNOWN'}
    (output / 'RESULTS.json').write_text(json.dumps(summary,indent=2)+'\n')
    assert cp.returncode == 0, 'actual integration failed; raw evidence retained'
    assert b'MC_MET01_LEGACY_TABLE_ACTUAL_RICHARDS_O0_O2=PASS' in (output / 'stdout.log').read_bytes()
    for opt in (0,2):
        hashes = {hashlib.sha256((build/f'o{opt}'/f'{table}-{mode}.txt').read_bytes()).hexdigest()
                  for table in ('typed','legacy') for mode in ('continuous','restart')}
        assert len(hashes)==1
    print(json.dumps({'integration': 'PASS', 'wall_seconds': summary['wall_seconds'], 'categories': summary['categories']}))


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',required=True)
    ap.add_argument('--integration',action='store_true');args=ap.parse_args()
    output=Path(args.output).resolve();output.mkdir(parents=True,exist_ok=False)
    identity=source_guard(DRIVER.read_text())
    # Deliberate corrupted independent excerpt must be rejected by the guard.
    try: source_guard(DRIVER.read_text().replace('20   afgen = table(i-1)', '20   afgen = 0.d0'))
    except AssertionError: identity['altered_oracle_negative']='PASS'
    else: raise AssertionError('altered oracle admitted')
    (output/'SOURCE_IDENTITY.json').write_text(json.dumps(identity,indent=2)+'\n')
    if args.integration:
        integration(output)
    else:
        subprocess.run([sys.executable,str(ROOT/'tests/modularity/run_modular_tests.py'),
                        '--case','raintb_legacy','--output',str(output/'modular')],check=True,cwd=ROOT)

if __name__=='__main__':main()
