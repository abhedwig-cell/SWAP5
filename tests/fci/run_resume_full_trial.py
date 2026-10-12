#!/usr/bin/env python3
"""Same-head OFF, controlled prefix, RESUME and byte-exact science comparison."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--output', type=Path, required=True)
p.add_argument('--key', type=Path, required=True)
p.add_argument('--toolchain-dirs', required=True)
a = p.parse_args()
OUT = a.output.resolve()
OUT.mkdir(parents=True, exist_ok=False)
env = dict(os.environ, FCI_RESUME_KEY=str(a.key.resolve()),
           FCI_RESUME_STORE=str(OUT / 'receipts'),
           FCI_RESUME_TOOLCHAIN_DIRS=a.toolchain_dirs)
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
command = ['bash', '-x', 'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh']

def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def run(name, mode, stop=None):
    e = dict(env, FCI_RESUME_MODE=mode)
    e.pop('FCI_RESUME_STOP_AFTER', None)
    if stop:
        e['FCI_RESUME_STOP_AFTER'] = stop
    control = {'command': command, 'mode': mode, 'executed_head': head,
               'started_utc': utc(), 'terminal_status': 'UNKNOWN',
               'environment_sha256': hashlib.sha256(json.dumps(e,sort_keys=True).encode()).hexdigest()}
    path = OUT / (name + '.control.json')
    path.write_text(json.dumps(control, indent=2))
    t0 = time.monotonic()
    with (OUT / (name + '.stdout')).open('wb') as stdout, (OUT / (name + '.stderr')).open('wb') as stderr:
        child = subprocess.run(command, cwd=ROOT, env=e, stdout=stdout, stderr=stderr)
    control.update(terminal_status='PASS' if child.returncode == 0 else 'FAIL',
                   terminal_exit_code=child.returncode, ended_utc=utc(), wall_seconds=time.monotonic()-t0,
                   end_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                   stdout_sha256=hashlib.sha256((OUT/(name+'.stdout')).read_bytes()).hexdigest(),
                   stderr_sha256=hashlib.sha256((OUT/(name+'.stderr')).read_bytes()).hexdigest())
    path.write_text(json.dumps(control,indent=2))
    print(json.dumps(control),flush=True)
    if control['end_head'] != head:
        raise SystemExit('candidate changed during execution')
    return child.returncode

if run('baseline','OFF') != 0:
    raise SystemExit('full baseline failed; no full qualification claim')
if run('interrupted','SHADOW','frost-independent') == 0:
    raise SystemExit('controlled interruption failed')
if run('resumed','RESUME') != 0:
    raise SystemExit('full resumed gate failed')

def science(name):
    lines = (OUT/(name+'.stdout')).read_bytes().splitlines(keepends=True)
    return b''.join(line for line in lines if not line.startswith(b'FCI_RESUME_'))

left, right = science('baseline'), science('resumed')
(OUT/'baseline.science.stdout').write_bytes(left)
(OUT/'resumed.science.stdout').write_bytes(right)
result = {'executed_head':head,'baseline_science_sha256':hashlib.sha256(left).hexdigest(),
          'resumed_science_sha256':hashlib.sha256(right).hexdigest(),
          'all_scientific_stdout_byte_identical':left==right,
          'comparison_excludes_only_controller_event_lines':True,
          'original_tolerances_changed':False}
stdout = (OUT/'resumed.stdout').read_bytes()
result['inherited_groups'] = [g for g in ['frost-invalid','frost-independent'] if ('FCI_RESUME_INHERITED '+g).encode() in stdout]
result['eight_scientific_compiler_invocations_avoided'] = len(result['inherited_groups'])==2
(OUT/'comparison.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result),flush=True)
if not left==right or len(result['inherited_groups'])!=2:
    raise SystemExit('scientific output or inheritance comparison requires adjudication')
