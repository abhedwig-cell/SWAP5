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
parser.add_argument('--profile', choices=['identity', 'certificate', 'certificate_refined', 'application'], default='identity')
parser.add_argument('--preserve-owners', action='store_true', help='Run unchanged WU01/WU03/Black/Boesten/Rutter drivers against the same provider build')
args = parser.parse_args()
assert not args.preserve_owners or args.profile == 'application'
evidence = args.evidence_dir.resolve()
evidence.mkdir(parents=True, exist_ok=False)
driver_path = ROOT/'tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90'
adapter = 'src/runtime/mod_fmr_interception_source_window_binding.f90'
assert blob(driver_path.read_bytes()) == 'af34185b6fd1001cacdb5156eaecdd79302add74'
assert blob((ROOT/adapter).read_bytes()) == '36f340ad425191a6149a50a21daccaf81d2bf839'
driver = driver_path.read_text()
assert driver.count('\ncontains\n') == 1
probe = (ROOT/'tests/fpm/test_int12c_real_endpoint.inc').read_text()
profile_argument = '.true., .true.' if args.profile == 'certificate_refined' else ('.true.' if args.profile == 'certificate' else '.false.')
if args.profile == 'application':
    probe=(ROOT/'tests/fpm/test_int12c_application.inc').read_text()
    driver=driver.replace('\ncontains\n','\n  call verify_int12c_application()\n\ncontains\n'+probe+'\n')
else:
    driver = driver.replace('\ncontains\n', '\n  call verify_int12c_real_endpoint('+profile_argument+')\n\ncontains\n'+probe+'\n')
generated = evidence/'driver.f90'
generated.write_text(driver)
original_runner = (ROOT/'tests/fmr/run_fmr44r_serialized_prescribed_qbot_gate.sh').read_text()
sources = re.search(r'MODULE_SRC=\(\n(.*?)\n\)', original_runner, re.S).group(1).split()
if args.profile == 'application':
    sources += ['src/runtime/mod_fmr_production_application_bootstrap.f90']
sources += ['src/process/mod_pmdirect_swetr0_process.f90',
            'src/runtime/mod_interception_source_window_runtime.f90', adapter]
owner_drivers=[]
if args.preserve_owners:
    owner_drivers=['tests/fapp/test_ppa_wu01_production_application_bootstrap.f90',
        'tests/fapp/test_ppa_wu03_common_forcing_adapter.f90',
        'tests/fapp/test_ppa_wu04a_black_runtime.f90',
        'tests/fapp/test_ppa_wu04b_boesten_runtime.f90',
        'tests/fapp/test_ppa_wu04a_black_process.f90',
        'tests/fapp/test_ppa_wu04b_boesten_process.f90',
        'tests/f-app08/test_rutter_output_binding.f90']
    incumbent=(ROOT/'tests/fapp/run_ppa_wu04b_boesten_evaporation.sh').read_text()
    sources += re.search(r'MODULE_SRC=\(\n(.*?)\n\)',incumbent,re.S).group(1).split()
    for path in owner_drivers:
        assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',
            'a86da5b6931b15ef8a5432fd03adc30a72491b65:'+path],cwd=ROOT), 'owner oracle changed: '+path
    sources += owner_drivers
sources = subprocess.check_output(['python3', 'tests/support/augment_bartholomeus_backend_sources.py',
                                   '--all', *sources], cwd=ROOT, text=True).splitlines()
sources=[s for s in sources if s not in owner_drivers]
(evidence/'compile_sources.json').write_text(json.dumps([
    {'path': s, 'git_blob': blob((ROOT/s).read_bytes()),
     'sha256': hashlib.sha256((ROOT/s).read_bytes()).hexdigest()} for s in [*sources,*owner_drivers]], indent=2)+'\n')
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
if args.profile == 'application':
    markers=markers[:4]+['INT12C_REAL_APPLICATION_PHYSICAL_AND_COMPANION_COMMIT=PASS',
        'INT12C_REAL_APPLICATION_PREFLIGHT_AND_STALE_CURSOR_NONMUTATION=PASS',
        'INT12C_REAL_APPLICATION_COMPANION_CONTINUATION=PASS',
        'INT12C_REAL_APPLICATION_EXACT_ONCE_SOURCE_MASS=PASS',
        'INT12C_REAL_APPLICATION_TWO_COLUMN_ROLLBACK_AND_RETRY=PASS',
        'INT12C_DIRECT_PMDIRECT_DYNAMIC_TOP_ACTIVE_ROOT_COMMITS=PASS',
        'INT12C_DIRECT_WET_DRY_DEMAND_AND_PHYSICAL_MASS=PASS',
        'INT12C_DIRECT_UPSTREAM_REJECTION_AND_OPTIN_BOUNDARY=PASS']
results = []
with tempfile.TemporaryDirectory(prefix='swap5-int12c-real-') as temp:
    for opt in [0, 2]:
        out = Path(temp)/('o'+str(opt))
        out.mkdir()
        common = ['gfortran', *flags, '-O'+str(opt), '-J', str(out), '-I', str(out)]
        objects = []
        for index, source in enumerate(sources):
            obj = out/(str(index)+'.o')
            subprocess.run([*common, '-c', source, '-o', str(obj)], cwd=ROOT, check=True)
            objects.append(str(obj))
        for name, source, expected in [('endpoint',str(generated),markers),
                *[(Path(path).stem,path,[]) for path in owner_drivers]]:
            obj=out/(name+'.o')
            subprocess.run([*common,'-c',source,'-o',str(obj)],cwd=ROOT,check=True)
            exe=out/name
            subprocess.run(['gfortran','-fopenmp','-O'+str(opt),*objects,str(obj),'-o',str(exe)],check=True)
            output_path=evidence/(('o'+str(opt)) if name=='endpoint' else (name+'-o'+str(opt)))
            output_path=output_path.with_suffix('.txt')
            with output_path.open('wb') as stdout:
                run=subprocess.run([str(exe)],stdout=stdout,stderr=subprocess.STDOUT,cwd=ROOT)
            output=output_path.read_text()
            print(output,end='',flush=True)
            results.append({'driver':name,'optimization':opt,'returncode':run.returncode,
                'missing_markers':[marker for marker in expected if marker not in output]})
            print('INT12C_REAL_O'+str(opt)+'_'+name+'_RETURN_CODE='+str(run.returncode),flush=True)
(evidence/'results.json').write_text(json.dumps(results, indent=2)+'\n')
assert all(r['returncode'] == 0 and not r['missing_markers'] for r in results), 'real endpoint positive gate failed; both optimization results preserved'
assert (evidence/'o0.txt').read_bytes() == (evidence/'o2.txt').read_bytes(), 'O0/O2 semantic drift'
for path in owner_drivers:
    name=Path(path).stem
    assert (evidence/(name+'-o0.txt')).read_bytes()==(evidence/(name+'-o2.txt')).read_bytes(), 'owner O0/O2 drift: '+name
if owner_drivers: print('INT12C_UNCHANGED_APPLICATION_OWNERS_O0_O2=PASS')
print('INT12C_REAL_O0_O2_SEMANTIC_IDENTITY=PASS')
