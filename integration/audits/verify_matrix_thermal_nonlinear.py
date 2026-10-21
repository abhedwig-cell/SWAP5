"""Bounded nonlinear thermal composition; execute exact admitted predecessor."""
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASE = '9c16572a57ada1c4b7e619bae8c1bdfb3c6f5e9c'
STATUS = 'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
SCIENCE = ['src', 'tests', 'tools', 'reference', '.github', 'app', 'examples',
           'integration/performance/authority.py', 'integration/audits/qualify_matrix_thermal.py',
           'integration/audits/verify_matrix_thermal.py', 'integration/audits/verify_matrix_thermal_nonlinear.py']
CASES = ['1', '0.5', '0.8', '1.0005', '1.5', '2']


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def record():
    return json.loads((ROOT / STATUS).read_text())['nonlinear_successor']


def source():
    s = record()
    require(s['baseline'] == BASE, 'nonlinear predecessor')
    git('merge-base', '--is-ancestor', BASE, 'HEAD')
    require(not git('status', '--porcelain', '--', *SCIENCE), 'dirty nonlinear science')
    changed = dict((v.split('\t')[1], v.split('\t')[0]) for v in git('diff', '--name-status', BASE, 'HEAD', '--', *SCIENCE).splitlines())
    require(changed == {p: v['status'] for p, v in s['postimages'].items()}, 'foreign nonlinear scientific delta')
    require({p for p in changed if p.startswith('src/')} == {'src/runtime/mod_fmr_b111_matrix_thermal_application.f90'}, 'nonlinear production boundary')
    for p, v in s['postimages'].items():
        require(sha((ROOT / p).read_bytes()) == v['sha256'], 'nonlinear postimage ' + p)
    p = 'src/runtime/mod_fmr_b111_matrix_thermal_application.f90'
    old = subprocess.check_output(['git', 'show', BASE + ':' + p], cwd=ROOT, text=True)
    require(old.count('if(p%frexp/=1d0)return') == 1, 'unrecognized linear guard')
    require((ROOT / p).read_text() == old.replace('if(p%frexp/=1d0)return', 'if(p%frexp<.5d0.or.p%frexp>2d0)return'), 'nonlinear process mutation')
    require((ROOT / 'integration/performance/authority.py').read_bytes() == subprocess.check_output(
        ['git', 'show', BASE + ':integration/performance/authority.py'], cwd=ROOT), 'incumbent dispatcher changed')
    require(not git('diff', BASE, 'HEAD', '--', 'integration/performance'), 'concurrent PERF diagnostics changed')
    return s


def unpack(e):
    raw = base64.b64decode((ROOT / e['path']).read_bytes(), validate=True)
    require(sha(raw) == e['decoded_sha256'], 'nonlinear capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        members = archive.getmembers()
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members), 'unsafe nonlinear capsule')
        require(len(members) == len({m.name for m in members}), 'duplicate nonlinear member')
        files = {m.name: archive.extractfile(m).read() for m in members}
    manifest = json.loads(files.pop('MANIFEST.json'))
    require(set(manifest) == set(files), 'nonlinear capsule inventory')
    require(all(sha(files[p]) == h for p, h in manifest.items()), 'nonlinear raw integrity')
    return files


def capsule():
    return unpack(record()['evidence'])


def validate(files, reader=lambda p: (ROOT / p).read_bytes()):
    incumbent = runpy.run_path(str(ROOT / 'integration/audits/verify_matrix_thermal.py'))
    build = files['1/physical/result.json']
    # The existing scientific assertions execute for every actual exponent.
    for case in CASES:
        prefix = case + '/'
        subset = {p[len(prefix):]: raw for p, raw in files.items() if p.startswith(prefix)}
        p = json.loads(subset['physical/result.json'])
        require(p['exponent'] == float(case), 'missing exponent qualification')
        incumbent['validate'](subset, reader, None if case == '1' else build)
        q = json.loads(subset['qualification/result.json'])
        for phase, report in [('physical', p), ('qualification', q)]:
            for i, event in enumerate(report['events']):
                category = event['category']
                if category in ['compile', 'link', 'observer_compile_link']:
                    continue
                require(float(event['command'][-1]) == float(case), 'executed exponent drift')
                raw = subset[f'{phase}/{i:04d}.stdout'].decode()
                if category == 'native' and event['command'][1] in ['full', 'split', 'resume']:
                    opt = Path(event['command'][0]).parent.name
                    n = event['command'][-2]
                    mode = ['full', 'split', 'resume'].index(event['command'][1])
                    require(raw == p['results'][opt][n]['stdout'][mode], 'unbound native physical stdout')
                if category == 'refinement_native' and event['command'][1] == 'full':
                    opt = Path(event['command'][0]).parent.name
                    n = event['command'][-2]
                    require(raw == q['results'][opt]['stdout'][n], 'unbound refined physical stdout')
        for opt in ['O0', 'O2']:
            require(q['results'][opt]['executable_sha256'] == p['executables'][opt], 'qualified executable drift')
            for n in [2, 4, 8, 16]:
                require(sha(subset[f'physical/{opt}/{n}/restart.bin']) == p['results'][opt][str(n)]['restart_sha256'], 'restart digest')
    # Fresh current-runtime linear results must preserve every admitted byte.
    parent = json.loads((ROOT / STATUS).read_text())
    original = unpack(parent['evidence'])
    for opt in ['O0', 'O2']:
        for n in [2, 4, 8, 16, 32, 64, 128]:
            phase = 'physical' if n <= 16 else 'qualification'
            for name in ['full.bin', 'restart.bin']:
                p = f'{phase}/{opt}/{n}/{name}'
                require(files['1/' + p] == original[p], 'incumbent linear byte drift ' + p)
    return {'nonlinear_dynamic_endpoint_decay': True, 'exponents': [float(c) for c in CASES],
            'linear_seven_mesh_restart_bytes_preserved': True, 'nonlinear_fresh_restart': True,
            'nonlinear_rollback_retry': True, 'nonlinear_crash_generation': True,
            'nonlinear_fixed_horizon_refinement': True}


def predecessor():
    with tempfile.TemporaryDirectory(prefix='swap5-nonlinear-predecessor-') as temp:
        base = Path(temp) / 'base'
        subprocess.run(['git', 'worktree', 'add', '--detach', str(base), BASE], cwd=ROOT, check=True, capture_output=True)
        try:
            r = subprocess.run([sys.executable, '-B', 'integration/audits/verify_matrix_thermal.py'], cwd=base,
                               capture_output=True, text=True, env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'})
            require(r.returncode == 0, 'unchanged admitted predecessor: ' + r.stderr[-3000:])
            old = json.loads(r.stdout)
            require(old['qualified'], 'unqualified predecessor')
            for arguments in [[], ['--self-test']]:
                r = subprocess.run([sys.executable, '-B', 'integration/performance/verify_solver_study.py', *arguments],
                                   cwd=base, capture_output=True, text=True,
                                   env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'})
                require(r.returncode == 0, 'exact concurrent diagnostic predecessor: ' + r.stderr[-2000:])
                result = json.loads(r.stdout)
                require(result.get('native_executions') == 159 if not arguments else result.get('count') == 5,
                        'missing concurrent diagnostic evidence')
            return old
        finally:
            subprocess.run(['git', 'worktree', 'remove', '--force', str(base)], cwd=ROOT, check=True, capture_output=True)


def concurrent_diagnostic():
    # The unchanged complete verifier executes at its exact admitted predecessor.
    # Revalidate every raw observation and all178 executed providers HERE as well;
    # its whole-tree no-change preflight is not rebound to the thermal successor.
    ns = runpy.run_path(str(ROOT / 'integration/performance/verify_solver_study.py'))
    status = json.loads((ROOT / 'integration/performance/SWAP5-PERF01_SOLVER_STUDY_STATUS.json').read_text())
    for kind, names in [('screen', ['temporal-'+p for p in ['cap', 'ceiling', 'recover', 'fallback']]),
                        ('candidate', ['temporal-O0', 'temporal-O2'])]:
        e = status['evidence'][kind]
        files = ns['capsule'](ROOT / e['index'], e['sha256'])
        ns['validate'](files, names)
    require(ns['self_test']()['count'] == 5, 'current concurrent diagnostic controls')
    return {'concurrent_solver_diagnostic_178_current_providers': True,
            'concurrent_solver_diagnostic_exact_predecessor': BASE,
            'concurrent_solver_diagnostic_controls': 5}


def verify_qualification():
    source()
    current = validate(capsule())
    old = predecessor()
    return {**old, **current, **concurrent_diagnostic(), 'qualified': True, 'full_capability': False,
            'source_tree': git('rev-parse', 'HEAD:src'), 'current_source_tree': git('rev-parse', 'HEAD:src'),
            'incumbent_production_unchanged': False,
            'production_delta': 'Only optional thermal Freundlich guard1 -> bounded0.5..2',
            'thermal_admission': 'BOUNDED_NUMERIC_HEAT_NONLINEAR_ENDPOINT_SPLIT_ONLY'}


def self_test():
    files = capsule()
    validate(files)
    controls = []
    for path in ['0.5/physical/result.json', '2/qualification/result.json', '1.0005/physical/O2/2/resumed.bin',
                 '0.8/physical/O0/controls/control.after', '1.5/qualification/O0/128/fresh.bin',
                 '2/qualification/O2/kill-after/generation.bin', '1/qualification/O0/128/full.bin']:
        bad = dict(files)
        bad.pop(path)
        try:
            validate(bad)
        except (ValueError, KeyError):
            controls.append(path)
        else:
            raise ValueError('accepted missing evidence ' + path)
    for path in ['src/runtime/mod_fmr_b111_matrix_thermal_application.f90', 'src/process/mod_b111_solute_decay.f90']:
        try:
            validate(files, lambda p: (ROOT / p).read_bytes() + (b'!' if p == path else b''))
        except ValueError:
            controls.append(path)
        else:
            raise ValueError('accepted stale nonlinear source ' + path)
    return {'count': len(controls), 'negative_controls': controls}


if __name__ == '__main__':
    print(json.dumps(self_test() if '--self-test' in sys.argv else verify_qualification(), indent=2))
