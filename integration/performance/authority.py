"""Bounded PERF01 successor: unchanged original authority plus current native proof.

This admits an exact implementation change, not new physics, temporal policy,
RossFast scope, a whole-master promotion or regional production capability.
"""
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
BASE = '5ce0f1115a5ea89be54aacaae02ed61ab2ca2696'
STATUS = 'integration/performance/SWAP5-PERF01_STATUS.json'
SURFACE = ['src', 'tests', 'tools', 'reference', '.github', 'integration/performance/authority.py']
PRODUCTION = {'src/legacy/b1_10_port/headcalc.f90',
              'src/runtime/mod_fmr_serialized_reference_backend.f90'}
HOOK = """ perf=ROOT/'integration/performance/authority.py'
 if perf.exists():
  return runpy.run_path(str(perf),run_name='registered_perf01')['verify_qualification']()
"""
AGE_HOOK = """    perf=ROOT/'integration/performance/authority.py'
    if perf.exists():
        import runpy
        return runpy.run_path(str(perf),run_name='registered_perf01_age')['verify_qualification']()
"""

def require(ok, why):
    if not ok:
        raise ValueError(why)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()

def record():
    return json.loads((ROOT / STATUS).read_text())['exact_successor']

def capsule():
    index_path = ROOT / record()['evidence_index']
    index = json.loads(index_path.read_text())
    raw = base64.b64decode(b''.join((index_path.parent / p).read_bytes() for p in index['parts']), validate=True)
    require(sha(raw) == index['decoded_sha256'] == record()['evidence_sha256'], 'PERF01 archive identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        files = {p.name: archive.extractfile(p).read() for p in archive.getmembers() if p.isfile()}
    manifest = json.loads(files.pop('MEMBERS.json'))
    require(set(files) == set(manifest), 'PERF01 member inventory')
    for p, h in manifest.items():
        require(sha(files[p]) == h, 'PERF01 member digest ' + p)
    return files

def source():
    r = record()
    require(r['base_canonical'] == BASE, 'PERF01 predecessor')
    git('merge-base', '--is-ancestor', BASE, 'HEAD')
    require(not git('status', '--porcelain', '--', *SURFACE), 'dirty PERF01 source')
    changed = {v.split('\t')[1]: v.split('\t')[0] for v in git('diff', '--name-status', BASE, 'HEAD', '--', *SURFACE).splitlines()}
    require(changed == {p: v['status'] for p, v in r['postimages'].items()}, 'foreign PERF01 delta')
    require({p for p in changed if p.startswith('src/')} == PRODUCTION, 'PERF01 production boundary')
    require(not any(p.startswith('reference/') for p in changed), 'changed historical reference')
    for p, v in r['postimages'].items():
        require(sha((ROOT / p).read_bytes()) == v['sha256'], 'PERF01 postimage ' + p)
    path = 'tests/nut-crop/verify_accepted_atmosphere.py'
    original = subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT, text=True)
    require((ROOT / path).read_text() == original.replace('def verify_qualification():\n', 'def verify_qualification():\n' + HOOK, 1), 'original atmosphere assertions changed')
    path = 'tests/nut-sol/verify_surface_age_successor.py'
    original = subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT, text=True)
    require((ROOT / path).read_text() == original.replace('def verify_qualification():\n', 'def verify_qualification():\n' + AGE_HOOK, 1), 'original surface-age assertions changed')

def validate(files, reader=lambda p: (ROOT / p).read_bytes()):
    def load(p):
        return json.loads(files[p])
    def inputs(values):
        for p, h in values.items():
            require(sha(reader(p)) == h, 'stale executed input ' + p)
    for name in ['arena-O0', 'arena-O2', 'arena-O2-checked']:
        b = load(name + '/build-complete.json')
        require(b['status'] == 'BUILT' and b['provider_count'] == 178, 'missing real production closure')
        require('-ffpe-trap=invalid,zero,overflow' in b['flags'], 'lost FPE protection')
        inputs(b['input_sha256'])
    q = load('arena-qualification/result.json')
    require(q['status'] == 'PASS' and len(q['events']) == 86, 'incomplete original application qualification')
    require(sha(reader('tests/nut-sol/test_column_input.py')) == q['test_sha256'], 'changed original column assertions')
    for opt in ['O0', 'O2']:
        require(q['results'][opt]['restart_sha256'] == '42d92009baeb4e7a90ef2e2ebbd22c79df69cb05bc7cf0e01e7cea39bf192e4f', 'original endpoint drift')
    p = load('arena-preservation/CONTROL.json')
    require(p['pass'] and len(p['runs']) == 8, 'transaction/macropore/restart preservation')
    inputs(p['source_sha256'])
    require(all('PASS' in r['stdout'] for r in p['runs']), 'missing native preservation assertion')
    b = load('trace-branch/CONTROL.json')
    require(b['production_source_sha256'] == sha(reader('src/runtime/mod_fmr_serialized_reference_backend.f90')), 'stale arena branch proof')
    require(len(b['records']) == 3 and all(r['passed'] for r in b['records']), 'branch/stale/cursor rejection')
    for name, status in [('arena-age', 'PHYSICAL_PASS_NOT_ADMITTED'), ('arena-reactive-unlimited', 'SCOPED_REACTIVE_QUALIFICATION_PASS_NOT_ADMITTED')]:
        r = load(name + '/result.json')
        require(r['status'] == status and set(r['runs']) == {'O0', 'O2'}, 'missing original nutrient/age runner')
        inputs(r['input_sha256'])
    # The original source-bound age receipt cannot be relabelled as current.
    # Execute its authority unchanged in predecessor(), then require fresh
    # current-provider endpoint/fresh-process bytes to equal its native files.
    age_owner = runpy.run_path(str(ROOT / 'tests/nut-sol/verify_surface_age_successor.py'), run_name='perf01_original_age_functions')
    original_age = age_owner['evidence']()
    age = load('arena-age/result.json')
    events = load('arena-age/events.json')
    require(all(e['returncode'] == 0 for e in events), 'failed current age event')
    for opt in ['O0', 'O2']:
        row = age['runs'][opt]
        for target in ['expected.bin', 'surface_expected.bin']:
            current = files['arena-age/' + opt + '/' + target]
            fresh = files['arena-age/' + opt + '/' + target.replace('expected', 'fresh')]
            require(current == fresh == original_age['physical/' + opt + '/' + target], 'changed original age endpoint ' + target)
        require(set(row['surface']['snapshot_negatives']) == {'truncated', 'overlong', 'outer_crc', 'inner_crc'}, 'current age decoder controls')
        native = [e for e in events if e['category'] == 'surface_native' and '/' + opt + '/' in e['command'][0]]
        require(len(native) == 6, 'current surface-age native count')
        for e in native[2:]:
            require(b'SURFACE_AGE_INVALID_SNAPSHOT=PASS' in files['arena-age/' + e['stdout']], 'current age negative not executed')
    r = load('arena-reactive-unlimited/result.json')
    require(r['o0_o2_endpoint_identity'] and all(v['incumbent_admitted_byte_identity'] for v in r['runs'].values()), 'mineral incumbent endpoint drift')
    dry = load('arena-dry/result.json')
    require(dry['status'] == 'SAME_HORIZON_DRY_REFERENCE_PROFILE_QUALIFIED', 'dry full-horizon/restart')
    for opt in ['O0', 'O2']:
        inputs(dry['results'][opt]['provider_sha256'])
        for f in ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']:
            require(files['arena-dry/O0/full/' + f] == files['arena-dry/' + opt + '/full/' + f], 'dry O0/O2 drift')
    for name in ['arena-benchmark', 'canonical-benchmark']:
        a = load(name + '/CONTROL.json')
        require(len(a['runs']) == 42 and len(a['summary']) == 3, 'incomplete paired application matrix')
        inputs(a['builds']['after']['input_sha256'])
        require(all(r['exit'] == 0 for r in a['runs']), 'failed native timing counted')
        for n in [4, 32, 256]:
            rows = [r for r in a['runs'] if r['nodes'] == n]
            require(all(r['files'] == rows[0]['files'] and r['accepted_substeps'] == rows[0]['accepted_substeps'] for r in rows), 'changed application trajectory')
            for arm in ['before', 'after']:
                for f, h in rows[0]['files'].items():
                    require(sha(files[f'{name}/{n}-0-{arm}/' + f]) == h, 'raw model file drift')
    a = load('observations-final/CONTROL.json')
    for n in [4, 32, 256]:
        b, c = [next(r for r in a['runs'] if r['nodes'] == n and r['arm'] == arm) for arm in ['before', 'after']]
        require(b['counters'] == c['counters'] and b['dt'] == c['dt'] and b['files'] == c['files'], 'changed numerical work')
    for name, count in [('three-way', 264), ('historical-O0-final', 72), ('historical-O3', 72)]:
        a = load(name + '/CONTROL.json')
        require(len(a['summary']) == 8 and len(a['runs']) == count, 'historical matrix incomplete')
        require(all(r['exit'] == 0 for r in a['runs']) and all(r['scientific_before_after_byte_exact'] for r in a['summary']), 'direct hydraulic regression')
    return dict(performance_exact_implementation=True, application_process_observations=86,
                unchanged_application_work=True, dry_same_horizon=True, full_capability=False,
                mastercoverage_promotion=False, full_migration_qualified=False,
                full_fci='NOT_SELECTED_IMPACT', highest_low_air='NOT_SELECTED_POLICY')

def predecessor():
    with tempfile.TemporaryDirectory(prefix='swap5-perf01-predecessor-') as temp:
        base = Path(temp) / 'baseline'
        subprocess.run(['git', 'worktree', 'add', '--detach', str(base), BASE], cwd=ROOT, check=True, capture_output=True)
        try:
            require(subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=base, text=True).strip() == BASE, 'foreign predecessor checkout')
            p = subprocess.run([sys.executable, '-B', 'tests/nut-crop/verify_accepted_atmosphere.py'], cwd=base, capture_output=True, text=True, env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'})
            require(p.returncode == 0, 'unchanged original predecessor authority: ' + p.stderr[-3000:])
            old = json.loads(p.stdout)
            require(old['qualified'] and old['predecessor_qualified'], 'unqualified predecessor')
            # This canonical predecessor registers PR1337's source successor.
            # Its unchanged authority already executes the original nine
            # atmosphere controls in its own exact predecessor. Check the
            # eleven native-character controls on this current predecessor.
            p = subprocess.run([sys.executable, '-B', 'integration/audits/verify_nut_native_character.py', '--self-test'], cwd=base, capture_output=True, text=True)
            require(p.returncode == 0 and json.loads(p.stdout)['count'] == 11, 'original current NUT corruption controls: ' + p.stderr[-1000:])
            p = subprocess.run([sys.executable, '-B', 'tests/nut-sol/verify_surface_age_successor.py'], cwd=base, capture_output=True, text=True, env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'})
            require(p.returncode == 0 and json.loads(p.stdout)['qualified'], 'original surface-age authority: ' + p.stderr[-2000:])
            return old
        finally:
            subprocess.run(['git', 'worktree', 'remove', '--force', str(base)], cwd=ROOT, check=True, capture_output=True)

def verify_qualification():
    source()
    result = validate(capsule())
    old = predecessor()
    return {**old, **result, 'qualified': True, 'current_grid_providers_unchanged': False,
            'physical_triplet': True, 'fresh_process': True, 'incumbent_age_preserved': True,
            'predecessor_qualified': True, 'preservation': 'ORIGINAL_AUTHORITY_PLUS_CURRENT_EXACT_NATIVE_PERF01',
            'source_tree': git('rev-parse', 'HEAD:src'), 'current_source_tree': git('rev-parse', 'HEAD:src')}

def fsi35_successors():
    """Exact HeadCalc registration only; original FSI35 native checks still run."""
    source()
    path = 'src/legacy/b1_10_port/headcalc.f90'
    return {path: {'historical_blob': '7ff36cbadf8acfaa09e129ff54aa54a933c3f1ac',
                   'canonical_blob': git('rev-parse', 'HEAD:' + path)}}

def self_test():
    f = capsule()
    validate(f)
    passed = []
    def reject(name, mutate, reader=lambda p: (ROOT / p).read_bytes()):
        ff = dict(f)
        mutate(ff)
        try:
            validate(ff, reader)
        except (ValueError, KeyError):
            passed.append(name)
            return
        raise AssertionError('accepted corruption ' + name)
    for p in ['arena-qualification/result.json', 'trace-branch/CONTROL.json', 'arena-preservation/CONTROL.json',
              'arena-age/result.json', 'arena-reactive-unlimited/result.json', 'canonical-benchmark/CONTROL.json',
              'historical-O0-final/CONTROL.json', 'arena-dry/O2/full/restart.bin', 'arena-benchmark/4-0-after/state.csv',
              'arena-age/O0/surface_expected.bin', 'arena-age/O2/fresh.bin']:
        reject('missing ' + p, lambda ff, p=p: ff.pop(p))
    for p in PRODUCTION:
        reject('current source ' + p, lambda ff: None, lambda q, p=p: (ROOT / q).read_bytes() + (b'!' if q == p else b''))
    return {'count': len(passed), 'negative_controls': passed}

if __name__ == '__main__':
    print(json.dumps(self_test() if '--self-test' in sys.argv else verify_qualification(), indent=2))
