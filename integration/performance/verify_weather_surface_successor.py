"""Exact PERF01 weather successor over the complete admitted f7c60410 owner.

Source registration and current physical proof are distinct from canonical
admission and from the independently executed original FSI35 native body.
"""
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
BASE = 'f7c6041096a0cc1a7a71fbe9e37b390d976744ac'
STATUS = 'benchmarks/performance/PERF01_WARM_START_20261022_STATUS.json'
KEY = 'source_successor_20261022'
SELF = 'integration/performance/verify_weather_surface_successor.py'
PARENT = 'integration/audits/verify_crop_root_joint.py'
REGISTRY = 'integration/performance/authority.py'
RUNNER = 'tests/fci/run_fci93_non_m1_fixed_k_qualification.sh'
MANIFEST = 'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json'
PROOF = 'benchmarks/performance/verify_perf01_canonical_composition.py'
PROOF_SHA = '978896827b5fc1701a04ce871da6747bf6af874fe5b470f5de0c7af89ea558e5'
SCIENCE = ['src', 'app', 'tests', 'tools', 'reference', 'examples', '.github',
           'integration/audits', 'integration/performance', 'integration/diagnostics']
PRODUCTION = {
    'src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90',
    'src/adapter/mod_reference_richards_legacy_binding.f90',
    'src/legacy/b1_10_port/headcalc.f90',
    'src/runtime/mod_fmr_production_application_bootstrap.f90',
    'src/runtime/mod_fmr_serialized_multiswap_runtime.f90',
    'src/runtime/mod_fmr_serialized_reference_backend.f90',
    'src/solver/mod_b110_default_mvg_directional_provider.f90',
    'src/solver/mod_b110_default_mvg_provider.f90',
    'src/solver/mod_soil_water_solver_contract.f90',
}


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def record(reader=lambda p: (ROOT / p).read_bytes()):
    return json.loads(reader(STATUS))[KEY]


def hook(name, arguments='', indent=' '):
    return (indent + "if 'evidence' in json.loads((ROOT/'" + STATUS + "').read_text()).get('" + KEY + "',{}):\n" +
            indent * 2 + "return runpy.run_path(str(ROOT/'" + SELF + "'))['" + name + "'](" + arguments + ")\n")


def projection(path):
    text = subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT, text=True)
    if path == PARENT:
        for entry, args in [('source', 'reader,changed'), ('verify', ''), ('self_test', '')]:
            offset = text.index('\n', text.index('def ' + entry + '(')) + 1
            text = text[:offset] + hook(entry, args) + text[offset:]
    elif path == REGISTRY:
        marker = 'def fsi35_successors():\n'
        require(text.count(marker) == 1, 'registry hook point')
        text = text.replace(marker, marker + hook('fsi35_successors', indent='    '), 1)
    elif path == RUNNER:
        p = 'src/solver/mod_soil_water_solver_contract.f90'
        old = '7b16c3fcf58179f1491104a1dce3279010b4178a'
        line = 'test "$(git rev-parse HEAD:' + p + ')" = ' + old + ' || fail "postimage drift ' + p + '"'
        require(text.count(line) == 1, 'original contract source lock')
        replacement = '\n'.join([
            'if [[ "$(git rev-parse HEAD:' + p + ')" == ' + old + ' ]]; then', '  ' + line, 'else',
            "  python3 - <<'PY_CONTRACT_SUCCESSOR'", 'import runpy,subprocess', 'path=' + repr(p),
            "row=runpy.run_path('integration/performance/authority.py')['fsi35_successors']().get(path,{})",
            "actual=subprocess.check_output(['git','rev-parse','HEAD:'+path],text=True).strip()",
            "assert row.get('historical_blob')==" + repr(old) + " and row.get('canonical_blob')==actual,'unregistered solver contract successor'",
            "print('FCI93_SELECTED_CONTRACT_SOURCE_BOUNDARY=PASS')", 'PY_CONTRACT_SUCCESSOR', 'fi'])
        text = text.replace(line, replacement, 1)
    return text.encode()


def evidence():
    e = record()['evidence']
    raw = (ROOT / e['path']).read_bytes()
    require(sha(raw) == e['sha256'] == PROOF_SHA and len(raw) == e['bytes'], 'weather native capsule identity')
    import io
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as t:
        members = t.getmembers()
        require(len(members) == e['members'] == len({m.name for m in members}), 'weather native census')
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members), 'unsafe weather native member')
        return {m.name: t.extractfile(m).read() for m in members}


def source(reader=lambda p: (ROOT / p).read_bytes(), changed=None):
    r = record(reader)
    require(r['baseline'] == BASE, 'weather source baseline')
    git('merge-base', '--is-ancestor', BASE, 'HEAD')
    delta = {line.split('\t')[1]: line.split('\t')[0] for line in
             git('diff', '--name-status', BASE, 'HEAD', '--', *SCIENCE).splitlines()}
    require(delta == r['source_delta'] and set(delta) == set(r['postimages']), 'foreign weather scientific delta')
    require({p for p in delta if p.startswith('src/')} == PRODUCTION, 'weather production boundary')
    require(not any(p.startswith('reference/') for p in delta), 'changed original reference')
    for p, h in r['postimages'].items():
        require(sha(reader(p)) == h, 'weather successor postimage ' + p)
    for p in [PARENT, REGISTRY, RUNNER]:
        require(reader(p) == projection(p), 'original owner assertions changed ' + p)
    for p, h in r['executed_input_sha256'].items():
        require(sha(reader(p)) == h, 'weather current compiled input ' + p)
    require(not git('status', '--porcelain', '--', *SCIENCE), 'dirty weather scientific source')
    if changed is not None:
        for p in changed:
            if p not in delta:
                require(subprocess.run(['git', 'cat-file', '-e', BASE + ':' + p], cwd=ROOT,
                                       capture_output=True).returncode == 0, 'unknown caller scientific path ' + p)
    return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']


def fsi35_successors():
    source()
    rows = {p: dict(v) for p, v in record()['frozen_fsi35_successors'].items()}
    require((ROOT / MANIFEST).read_bytes() == subprocess.check_output(['git', 'show', BASE + ':' + MANIFEST], cwd=ROOT), 'original FSI35 compile manifest')
    for dep in json.loads((ROOT / MANIFEST).read_text())['dependencies']:
        p, old = dep['path'], dep['blob']
        actual = git('rev-parse', 'HEAD:' + p)
        if actual == old:
            continue
        if p in PRODUCTION:
            rows[p] = {'historical_blob': old, 'canonical_blob': actual}
        else:
            require(rows.get(p) == {'historical_blob': old, 'canonical_blob': actual}, 'unregistered inherited FSI35 dependency ' + p)
            require(actual == git('rev-parse', BASE + ':' + p), 'changed inherited FSI35 dependency ' + p)
    # HeadCalc/top/transaction also have direct locks outside the manifest.
    for p, row in rows.items():
        if p in PRODUCTION:
            row['canonical_blob'] = git('rev-parse', 'HEAD:' + p)
        require(row['canonical_blob'] == git('rev-parse', 'HEAD:' + p), 'stale FSI35 registration ' + p)
    return rows


def verify():
    source()
    files = evidence()
    checker = runpy.run_path(str(ROOT / PROOF))
    current = checker['verify'](files)
    prior = json.loads(files['frozen-canonical-owner.json'])
    require(prior['qualified'] and prior['controls'] == 40 and
            prior['current_source_tree'] == git('rev-parse', BASE + ':src'), 'complete frozen original canonical owner')
    # All earlier owner fields remain available to their existing callers.
    return {**prior, 'weather_successor': current, 'current_source_tree': git('rev-parse', 'HEAD:src'),
            'source_tree': git('rev-parse', 'HEAD:src'), 'qualified': True,
            'qualification_scope': 'CURRENT_BOUNDED_SOL_NUT_AND_WEATHER_COMPOSITION',
            'canonically_admitted': False, 'fsi35_native': record().get('fsi35_native', 'PENDING')}


def self_test():
    controls = []
    for p in record()['postimages']:
        def reader(q):
            return (ROOT / q).read_bytes() + (b'!' if q == p else b'')
        try:
            source(reader)
        except ValueError:
            controls.append('source:' + p)
        else:
            raise AssertionError('accepted stale weather successor ' + p)
    try:
        source(changed={'src/foreign_weather_successor.f90': 'A'})
    except ValueError:
        controls.append('foreign scientific path')
    else:
        raise AssertionError('accepted unknown scientific path')
    checker = runpy.run_path(str(ROOT / PROOF))
    files = evidence()
    for p in ['season-O2-4x/native/stdout', 'trace/O0/native.stdout',
              'nut-owner/thermal/O2/output.restart.environment-after', 'frozen-canonical-owner.json']:
        bad = dict(files)
        bad.pop(p)
        try:
            checker['verify'](bad)
        except (ValueError, KeyError):
            controls.append('missing:' + p)
        else:
            raise AssertionError('accepted incomplete weather proof ' + p)
    return controls


if __name__ == '__main__':
    import sys
    print(json.dumps(self_test() if '--self-test' in sys.argv else verify(), indent=2))
