#!/usr/bin/env python3
"""Bounded receiving-seam witness; never patches production or old fixtures."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
def blob(data):
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()

parser = argparse.ArgumentParser()
parser.add_argument('--evidence-dir', type=Path, required=True)
args = parser.parse_args()
evidence = args.evidence_dir.resolve()
evidence.mkdir(parents=True, exist_ok=False)
driver_path = ROOT/'tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90'
adapter = 'tests/fpm/recovered/mod_fmr_interception_source_window_binding.f90'
assert blob(driver_path.read_bytes()) == 'af34185b6fd1001cacdb5156eaecdd79302add74'
assert blob((ROOT/adapter).read_bytes()) == '36f340ad425191a6149a50a21daccaf81d2bf839'
driver = driver_path.read_text()
assert driver.count('\ncontains\n') == 1
probe = (ROOT/'tests/fpm/test_int12c_real_endpoint.inc').read_text()
driver = driver.replace('\ncontains\n', '\n  call verify_int12c_real_endpoint()\n\ncontains\n'+probe+'\n')
generated = evidence/'driver.f90'
generated.write_text(driver)
original_runner = (ROOT/'tests/fmr/run_fmr44r_serialized_prescribed_qbot_gate.sh').read_text()
sources = re.search(r'MODULE_SRC=\(\n(.*?)\n\)', original_runner, re.S).group(1).split()
sources += ['src/process/mod_pmdirect_swetr0_process.f90',
            'src/runtime/mod_interception_source_window_runtime.f90', adapter]
sources = subprocess.check_output(['python3', 'tests/support/augment_bartholomeus_backend_sources.py',
                                   '--all', *sources], cwd=ROOT, text=True).splitlines()
(evidence/'compile_sources.json').write_text(json.dumps([
    {'path': s, 'git_blob': blob((ROOT/s).read_bytes()),
     'sha256': hashlib.sha256((ROOT/s).read_bytes()).hexdigest()} for s in sources], indent=2)+'\n')
(evidence/'compiler.txt').write_bytes(subprocess.check_output(['gfortran', '--version']))
flags = ['-std=f2008', '-ffree-line-length-none', '-Wall', '-Wextra', '-fcheck=all',
         '-fbacktrace', '-ffpe-trap=invalid,zero,overflow', '-fopenmp']
markers = ['FMR44R_MODE2_EQUILIBRIUM_TRANSACTION=PASS',
           'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS',
           'FMR44R_NEARBY_BOTTOM_MODE_FAIL_CLOSED=PASS',
           'FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS',
           'INT12C_REAL_FMR_COMMITTED_ENDPOINTS=PASS',
           'INT12C_REAL_PREFLIGHT_REJECT_RETRY_PROGRESS=PASS',
           'INT12C_REAL_COMPANION_PROGRESS_RESTORE=PASS',
           'INT12C_REAL_NET_RAIN_AND_INTERCEPTION_ACCOUNTING=PASS']
with tempfile.TemporaryDirectory(prefix='swap5-int12c-real-') as temp:
    for opt in [0, 2]:
        out = Path(temp)/('o'+str(opt))
        out.mkdir()
        common = ['gfortran', *flags, '-O'+str(opt), '-J', str(out), '-I', str(out)]
        objects = []
        for index, source in enumerate([*sources, str(generated)]):
            obj = out/(str(index)+'.o')
            subprocess.run([*common, '-c', source, '-o', str(obj)], cwd=ROOT, check=True)
            objects.append(str(obj))
        exe = out/'test'
        subprocess.run(['gfortran', '-fopenmp', '-O'+str(opt), *objects, '-o', str(exe)], check=True)
        with (evidence/('o'+str(opt)+'.txt')).open('wb') as stdout:
            subprocess.run([str(exe)], stdout=stdout, stderr=subprocess.STDOUT, check=True)
        output = (evidence/('o'+str(opt)+'.txt')).read_text()
        print(output, end='', flush=True)
        for marker in markers:
            assert marker in output, marker
        print('INT12C_REAL_O'+str(opt)+'=PASS', flush=True)
assert (evidence/'o0.txt').read_bytes() == (evidence/'o2.txt').read_bytes(), 'O0/O2 semantic drift'
print('INT12C_REAL_O0_O2_SEMANTIC_IDENTITY=PASS')
