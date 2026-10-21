"""Isolated thermal SOL successor; exact incumbent sources and predecessor gate."""
import base64
import hashlib
import io
import json
import os
import runpy
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASE = '3cb20b8a48440a9445277dfba0982b697197638a'
STATUS = 'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
SCIENCE = ['src', 'tests', 'tools', 'reference', '.github', 'app', 'examples', 'integration/performance/authority.py',
           'integration/audits/qualify_matrix_thermal.py', 'integration/audits/verify_matrix_thermal.py']
HOOK = """    thermal=ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
    if thermal.exists() and 'evidence' in json.loads(thermal.read_text()):
        return runpy.run_path(str(ROOT/'integration/audits/verify_matrix_thermal.py'),run_name='registered_sol_thermal')['verify_qualification']()
"""


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(b):
    return hashlib.sha256(b).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def record():
    return json.loads((ROOT / STATUS).read_text())


def source():
    if 'evidence' in record().get('nonlinear_pond_successor', {}):
        return runpy.run_path(str(ROOT / 'integration/audits/verify_nonlinear_pond.py'))['source']()
    if 'evidence' in record().get('nonlinear_successor', {}):
        return runpy.run_path(str(ROOT / 'integration/audits/verify_matrix_thermal_nonlinear.py'))['source']()
    s = record()
    require(s['baseline'] == BASE, 'thermal predecessor')
    git('merge-base', '--is-ancestor', BASE, 'HEAD')
    require(not git('status', '--porcelain', '--', *SCIENCE), 'dirty thermal science')
    changed = {v.split('\t')[1]: v.split('\t')[0] for v in git('diff', '--name-status', BASE, 'HEAD', '--', *SCIENCE).splitlines()}
    require(changed == {p: v['status'] for p, v in s['postimages'].items()}, 'foreign thermal delta')
    require({p for p in changed if p.startswith('src/')} == {
        'src/runtime/mod_fmr_b111_matrix_thermal_application.f90', 'src/adapter/mod_matrix_thermal_restart_file.f90'}, 'thermal production boundary')
    require(all(changed[p] == 'A' for p in changed if p.startswith('src/')), 'incumbent production mutation')
    for p, v in s['postimages'].items():
        require(sha((ROOT / p).read_bytes()) == v['sha256'], 'thermal postimage ' + p)
    path = 'integration/performance/authority.py'
    old = subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT, text=True)
    expected = old.replace('def verify_qualification():\n', 'def verify_qualification():\n' + HOOK, 1)
    original_fsi = "    if 'evidence' in current:\n        runpy.run_path(str(ROOT/'integration/audits/verify_nut_gash_successor.py'),run_name='registered_gash_fsi35')['source']()"
    thermal_fsi = "    thermal=ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'\n    if thermal.exists() and 'evidence' in json.loads(thermal.read_text()):\n        runpy.run_path(str(ROOT/'integration/audits/verify_matrix_thermal.py'),run_name='registered_sol_thermal_fsi35')['source']()\n    elif 'evidence' in current:\n        runpy.run_path(str(ROOT/'integration/audits/verify_nut_gash_successor.py'),run_name='registered_gash_fsi35')['source']()"
    require(old.count(original_fsi) == 1, 'unrecognized predecessor FSI35 handoff')
    expected = expected.replace(original_fsi, thermal_fsi, 1)
    require((ROOT / path).read_text() == expected, 'thermal exact predecessor handoff')
    return s


def capsule():
    e = record()['evidence']
    raw = base64.b64decode((ROOT / e['path']).read_bytes(), validate=True)
    require(sha(raw) == e['decoded_sha256'], 'thermal capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        members = archive.getmembers()
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members), 'unsafe thermal capsule')
        require(len(members) == len({m.name for m in members}), 'duplicate thermal member')
        files = {m.name: archive.extractfile(m).read() for m in members}
    manifest = json.loads(files.pop('MANIFEST.json'))
    require(set(manifest) == set(files), 'thermal member inventory')
    for p, h in manifest.items():
        require(sha(files[p]) == h, 'thermal raw member ' + p)
    return files


def validate(files, reader=lambda p: (ROOT / p).read_bytes(), build=None):
    p = json.loads(files['physical/result.json'])
    q = json.loads(files['qualification/result.json'])
    require(p['status'] == 'FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED', 'missing native physical proof')
    require(q['status'] == 'DYNAMIC_ACCEPTED_ENDPOINT_DECAY_O0_O2_RESTART_REFINEMENT_CRASH_PASS_NOT_ADMITTED', 'missing refinement/crash proof')
    require(q['physical_sha256'] == sha(files['physical/result.json']), 'unbound second phase')
    require(p['authority_sha256'] == '2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2', 'historical solute authority')
    for path, h in {**p['inputs'], **q['inputs']}.items():
        require(sha(reader(path)) == h, 'stale executed thermal input ' + path)
    require(p['results']['O0'] == p['results']['O2'], 'thermal native optimization drift')
    for prefix, report in [('physical', p), ('qualification', q)]:
        for i, e in enumerate(report['events']):
            require(e['returncode'] == e.get('expected_returncode', 0), 'failed thermal event')
            for stream in ['stdout', 'stderr']:
                require(f'{prefix}/{i:04d}.{stream}' in files, 'missing thermal raw stream')
            if '-c' in e['command']:
                require('-fcheck=all' in e['command'] and '-ffpe-trap=invalid,zero,overflow' in e['command'], 'unchecked thermal compilation')
    if build is None:
        require(len(p['events']) == 594 and p['provider_count'] == 277, 'unmeasured thermal closure')
    else:
        compiled = json.loads(build)
        require(len(p['events']) == 36 and p['provider_count'] == 277, 'unmeasured reused thermal executions')
        require(len(compiled['events']) == 594 and compiled['provider_count'] == 277, 'unmeasured original build')
        require(p['reused_physical_sha256'] == sha(build), 'unbound reused compilation')
        require(p['inputs'] == compiled['inputs'] and p['executables'] == compiled['executables'], 'reused build source/binary drift')
    require(len(q['events']) == (39 if build is None else 45), 'missing thermal refinement/semantic/crash executions')
    previous = None
    for opt in ['O0', 'O2']:
        result = {k: v for k, v in q['results'][opt].items() if k != 'executable_sha256'}
        if previous is not None:
            require(result == previous, 'thermal qualified O0/O2 drift')
        previous = result
        windows = [2, 4, 8, 16, 32, 64, 128] + ([] if build is None else [256])
        require(result['windows'] == windows, 'missing complete fixed-horizon refinement')
        for key in ['mass_delta', 'decay_delta']:
            d = result[key]
            require(len(d) == len(windows)-1 and all(a > b > 0 for a, b in zip(d, d[1:])), 'nondecreasing ' + key)
        require(0 < result['final_relative_decay_difference'] < 1e-3, 'unresolved thermal split error')
        for n in [2, 4, 8, 16]:
            a = files[f'physical/{opt}/{n}/full.bin']
            require(a == files[f'physical/{opt}/{n}/resumed.bin'], 'thermal original fresh endpoint')
            require(sha(a) == p['results'][opt][str(n)]['endpoint_sha256'], 'thermal native endpoint digest')
        for n in windows[4:]:
            require(files[f'qualification/{opt}/{n}/full.bin'] == files[f'qualification/{opt}/{n}/fresh.bin'], 'thermal refined fresh endpoint')
        finest = files[f'qualification/{opt}/{windows[-1]}/full.bin']
        require(sha(finest) == result['finest_endpoint_sha256'], 'thermal finest digest')
        require(finest == files[f'qualification/O0/{windows[-1]}/full.bin'], 'thermal finest optimization')
        for a, b in [('before', 'after'), ('initial', 'hydraulic')]:
            require(files[f'physical/{opt}/controls/control.{a}'] == files[f'physical/{opt}/controls/control.{b}'], 'thermal rejected owner mutation')
        require(set(result['semantic_negatives']) == {'overlong', 'water_clock', 'water_revision', 'physical_id', 'geometry', 'negative_water', 'nonfinite_temperature'}, 'thermal semantic negatives')
        require(files[f'qualification/{opt}/kill-before/generation.bin'] == files[f'physical/{opt}/2/restart.bin'], 'thermal pre-rename generation')
        require(files[f'qualification/{opt}/kill-after/generation.bin'] == files[f'physical/{opt}/2/full.bin'], 'thermal post-rename generation')
        require(files[f'qualification/{opt}/kill-before/fresh.bin'] == files[f'physical/{opt}/2/full.bin'], 'thermal crash fresh continuation')
    return {'dynamic_accepted_endpoint_decay': True, 'thermal_independent_process_restart': True,
            'thermal_rollback': True, 'thermal_crash_generation': True, 'thermal_refinement': True}


def predecessor():
    with tempfile.TemporaryDirectory(prefix='swap5-sol-thermal-predecessor-') as temp:
        base = Path(temp) / 'base'
        subprocess.run(['git', 'worktree', 'add', '--detach', str(base), BASE], cwd=ROOT, check=True, capture_output=True)
        try:
            p = subprocess.run([sys.executable, '-B', 'tests/nut-sol/verify_surface_age_successor.py'], cwd=base,
                               capture_output=True, text=True, env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'})
            require(p.returncode == 0, 'unchanged predecessor gate: ' + p.stderr[-2000:])
            old = json.loads(p.stdout)
            require(old['qualified'], 'unqualified incumbent authority')
            return old
        finally:
            subprocess.run(['git', 'worktree', 'remove', '--force', str(base)], cwd=ROOT, check=True, capture_output=True)


def verify_qualification():
    if 'evidence' in record().get('nonlinear_pond_successor', {}):
        return runpy.run_path(str(ROOT / 'integration/audits/verify_nonlinear_pond.py'))['verify_qualification']()
    if 'evidence' in record().get('nonlinear_successor', {}):
        return runpy.run_path(str(ROOT / 'integration/audits/verify_matrix_thermal_nonlinear.py'))['verify_qualification']()
    source()
    current = validate(capsule())
    old = predecessor()
    return {**old, **current, 'qualified': True, 'full_capability': False,
            'source_tree': git('rev-parse', 'HEAD:src'),
            'current_source_tree': git('rev-parse', 'HEAD:src'), 'full_fci': 'NOT_SELECTED_IMPACT',
            'incumbent_production_unchanged': True, 'thermal_admission': 'BOUNDED_ENDPOINT_SPLIT_ONLY'}


def self_test():
    if 'evidence' in record().get('nonlinear_pond_successor', {}):
        return runpy.run_path(str(ROOT / 'integration/audits/verify_nonlinear_pond.py'))['self_test']()
    if 'evidence' in record().get('nonlinear_successor', {}):
        return runpy.run_path(str(ROOT / 'integration/audits/verify_matrix_thermal_nonlinear.py'))['self_test']()
    f = capsule()
    validate(f)
    passed = []
    for name in ['physical/result.json', 'qualification/result.json', 'physical/O2/2/resumed.bin',
                 'physical/O0/controls/control.after', 'qualification/O0/128/fresh.bin',
                 'qualification/O2/kill-after/generation.bin']:
        broken = dict(f)
        broken.pop(name)
        try:
            validate(broken)
        except (ValueError, KeyError):
            passed.append(name)
        else:
            raise ValueError('accepted missing evidence ' + name)
    for path in ['src/runtime/mod_fmr_b111_matrix_thermal_application.f90', 'src/process/mod_b111_solute_decay.f90']:
        try:
            validate(f, lambda p: (ROOT / p).read_bytes() + (b'!' if p == path else b''))
        except ValueError:
            passed.append(path)
        else:
            raise ValueError('accepted stale input ' + path)
    return {'count': len(passed), 'negative_controls': passed}


if __name__ == '__main__':
    print(json.dumps(self_test() if '--self-test' in sys.argv else verify_qualification(), indent=2))
