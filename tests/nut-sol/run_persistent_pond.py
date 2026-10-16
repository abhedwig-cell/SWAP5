#!/usr/bin/env python3
"""Bounded real production pond state/exchange and literal source qualification."""
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import shlex
import subprocess
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(os.environ['POND_RESULT_DIR']).resolve()
OUT.mkdir(parents=True, exist_ok=False)
FC = shlex.split(os.environ.get('FC', 'gfortran'))
events = []
archive = ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())), mode='r:gz') as t:
    raw = t.extractfile('SWAP/solute.f90').read()
assert hashlib.sha256(raw).hexdigest() == '2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
lines = raw.decode('latin1').splitlines()
assert 'csurf = (nird*cirr' in lines[345]
oracle = '''module historical_surface_oracle
use iso_fortran_env,only:real64
implicit none
contains
subroutine literal_surface(initial,rain,rc,irr,ic,qtop,pond,dtsolu,cpond,transfer,remaining)
real(real64),intent(in)::initial,rain,rc,irr,ic,qtop,pond,dtsolu
real(real64),intent(out)::cpond,transfer,remaining
real(real64)::csurf,nird,cirr,nraidt,cpre,cfluxt,ArMpSs,isqtop
csurf=initial;nird=irr;cirr=ic;nraidt=rain;cpre=rc;ArMpSs=0
''' + '\n'.join(lines[345:355]) + '''
transfer=-cfluxt;remaining=csurf
end subroutine
end module
'''
(OUT / 'oracle.f90').write_text(oracle)
sources = [ROOT / p for p in (
    'src/process/mod_b111_pond_solute_exchange.f90',
    'src/process/mod_b111_persistent_pond.f90',
    'tests/nut-sol/test_persistent_pond.f90')]
inputs = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources + [archive, Path(__file__).resolve()]}
outputs = []
for opt in ('O0', 'O2'):
    build = OUT / opt
    build.mkdir()
    flags = ['-' + opt, '-g', '-fcheck=all', '-ffpe-trap=invalid,zero,overflow',
             '-fbacktrace', '-Wall', '-Wextra', '-Werror', '-Wno-compare-reals', '-ffree-line-length-none']
    objects = []
    commands = []
    for i, source in enumerate([sources[0], sources[1], OUT / 'oracle.f90', sources[2]]):
        obj = build / f'{i}.o'
        objects.append(obj)
        commands.append(('compile', FC + flags + ['-c', str(source), '-o', str(obj)]))
    commands.extend([('link', FC + flags + list(map(str, objects)) + ['-o', str(build / 'pond')]),
                     ('native', [str(build / 'pond')])])
    for category, cmd in commands:
        start = time.perf_counter()
        p = subprocess.run(cmd, cwd=build, capture_output=True)
        stem = f'{opt}-{len(events):03d}'
        (OUT / (stem + '.stdout')).write_bytes(p.stdout)
        (OUT / (stem + '.stderr')).write_bytes(p.stderr)
        events.append(dict(category=category, command=cmd, seconds=time.perf_counter()-start,
                           exit=p.returncode, stdout=stem+'.stdout', stderr=stem+'.stderr'))
        (OUT / 'events.json').write_text(json.dumps(events, indent=2)+'\n')
        if p.returncode:
            print(p.stdout.decode(errors='replace'), p.stderr.decode(errors='replace'))
            p.check_returncode()
        if category == 'native':
            assert b'PERSISTENT_POND_LITERAL_240_DRY_REWET_BALANCE_REPLAY_RESTORE_NEGATIVES=PASS' in p.stdout
            outputs.append(p.stdout)
assert outputs[0] == outputs[1]
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest() == h for p, h in inputs.items())
result = dict(status='LEAF_PASS_NOT_RUNTIME_ADMISSION', input_sha256=inputs, providers=2,
              source_authority_sha256=hashlib.sha256(raw).hexdigest(),
              compiler=subprocess.check_output(FC+['--version']).decode(),
              stdout=outputs[0].decode(),
              cost_seconds={k:sum(e['seconds'] for e in events if e['category']==k) for k in ('compile','link','native')})
(OUT / 'result.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result['cost_seconds']), result['status'])
