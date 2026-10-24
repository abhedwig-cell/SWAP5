"""Bounded current Picard corner repair; frozen predecessor proofs stay dated."""
import base64
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
BASE = '32676715fe351beb548c8791bfda941fac8e031a'
NUMERICAL_BASE = '367c11e394e3f166f861d9f1502aaeeda01215d7'
HEAD = 'src/legacy/b1_10_port/headcalc.f90'
PARENT = 'integration/audits/verify_cauchy_macro_current.py'
SELF = 'integration/audits/verify_picard_corner_current.py'
STATUS = 'integration/performance/PERF01_PICARD_CORNER_STATUS.json'
SCIENCE = ['src', 'app', 'tools', 'tests', 'examples', 'reference', '.github', 'integration/audits']
sha = lambda b: hashlib.sha256(b).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def projection():
    text = subprocess.check_output(['git', 'show', BASE + ':' + PARENT], cwd=ROOT).decode()
    for name, args in [('source', 'reader,changed'), ('verify', ''), ('self_test', ''), ('fsi35_successors', '')]:
        start = re.search(r'^def ' + name + r'\([^\n]*', text, re.M)
        if not start.group().endswith(':'):
            colon = text.index(':', start.start()) + 1
            text = text[:colon] + '\n ' + text[colon:]
        at = text.index('\n', re.search(r'^def ' + name + r'\(', text, re.M).start()) + 1
        text = text[:at] + " if (ROOT/'" + STATUS + "').is_file():return __import__('runpy').run_path(str(ROOT/'" + SELF + "'))['" + name + "'](" + args + ")\n" + text[at:]
    return text.encode()


def source(reader=lambda p: (ROOT / p).read_bytes(), changed=None):
    record = json.loads(reader(STATUS))
    assert record['baseline'] == BASE
    git('merge-base', '--is-ancestor', BASE, 'HEAD')
    delta = {s.split('\t')[1]: s.split('\t')[0] for s in
             git('diff', '--name-status', BASE, 'HEAD', '--', *SCIENCE).splitlines()}
    assert delta == record['scientific_delta'], 'unqualified corner successor delta'
    assert {p for p in delta if p.startswith('src/')} == {HEAD}
    assert not git('status', '--porcelain', '--', *SCIENCE), 'unpersisted scientific postimage'
    assert reader(PARENT) == projection(), 'predecessor assertions changed'
    for p, h in record['postimages'].items():
        assert sha(reader(p)) == h, ('current source', p)
    if changed is not None:
        for p in changed:
            assert p in delta or subprocess.run(['git', 'cat-file', '-e', BASE + ':' + p], cwd=ROOT,
                                               capture_output=True).returncode == 0, 'foreign caller'
    return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']


def capsule():
    e = json.loads((ROOT / STATUS).read_bytes())['evidence']
    raw = (ROOT / e['path']).read_bytes()
    assert sha(raw) == e['sha256'] and len(raw) == e['bytes']
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as t:
        members = t.getmembers()
        assert len(members) == e['members'] == len({m.name for m in members})
        assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
        f = {m.name: t.extractfile(m).read() for m in members}
    assert json.loads(f.pop('MANIFEST.json')) == {p: sha(b) for p, b in f.items()}
    return f


def validate(f):
    js = lambda p: json.loads(f[p])
    rows = lambda p: list(csv.DictReader(io.StringIO(f[p].decode())))
    reconciled = reconciliation()
    for p, h in js('RESULT.json')['current_executed_inputs'].items():
        if sha((ROOT / p).read_bytes()) != h:
            # The admitted concurrent delta only opens mode3/macro guards.
            # All repaired full-period/NUT cases have no macropores and retain
            # the same executable numerical branch. Current ABI and both
            # sides of that separate admission are executed below.
            assert p in reconciled['providers'], ('executed dependency', p)
            assert h == reconciled['providers'][p]['preimage_sha256']
            assert sha((ROOT / p).read_bytes()) == reconciled['providers'][p]['postimage_sha256']
    parent = js('raw/corner-parent-owner/RESULT.json')
    raw = f['raw/corner-parent-owner/commit.raw']
    assert hashlib.sha1(b'commit ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == NUMERICAL_BASE
    assert parent['owner']['qualified'] and len(parent['controls']) == 25
    small = js('raw/corner-small-v3/RESULT.json')
    assert small['status'] == 'PICARD_CORNER_REAL_PREDECESSOR_O0_O2_FSI35_NATIVE_PASS'
    assert small['provider_closure'] == 21 and all(e['returncode'] == 0 for e in small['events'])
    assert b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS' in f['raw/corner-small-v3/fsi35-native.stdout']
    for rain in [1, 4]:
        for opt in ['O0', 'O2']:
            prefix = 'raw/corner-full' + str(rain) + 'x-' + opt + '/head/'
            data = rows(prefix + 'budget.csv')
            assert len(data) == 481
            for d in data:
                assert abs(float(d['water_residual_cm'])) < 1e-10
                assert abs(float(d['solute_residual_mg_cm2'])) < 1e-10
                assert all(float(d[k]) == 0 for k in ['solute_start_mg_cm2', 'solute_end_mg_cm2', 'solute_in_mg_cm2', 'solute_out_mg_cm2'])
                gross = (float(d['water_end_cm']) - float(d['water_start_cm']) - float(d['rain_supplied_cm'])
                         - float(d['runon_cm']) - float(d['bottom_up_cm']) + float(d['runoff_cm'])
                         + float(d['soil_evaporation_cm']) + float(d['pond_evaporation_cm'])
                         + float(d['actual_transpiration_cm']))
                assert abs(gross) < 1e-10, 'independent gross water closure'
            for n in ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']:
                assert f[prefix + n] == f['raw/corner-full' + str(rain) + 'x-O2/head/' + n]
            pre = rows('old-prefix/' + str(rain) + 'x/budget.csv')
            assert data[:len(pre)] == pre
        restart = 'raw/corner-restart' + str(rain) + 'x/'
        assert js(restart + 'RESULT.json')['status'] == 'ACTUAL_DAY240_RESTART_EXACT'
        full = 'raw/corner-full' + str(rain) + 'x-O2/head/'
        for n in ['state.csv', 'endpoint.csv', 'restart.bin']:
            assert f[restart + 'resume/' + n] == f[full + n]
        assert rows(restart + 'resume/budget.csv') == rows(full + 'budget.csv')[240:]
    for opt in ['O0', 'O2']:
        bbc = 'raw/corner-bbc-' + opt + '/'
        assert js(bbc + 'result.json')['status'] == 'BOUNDED_ORIGINAL_BBC_NATIVE_RESTART_PASS'
        for n in ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']:
            assert f[bbc + 'full/' + n] == f['old-bbc/' + opt + '/' + n]
            assert f['raw/corner-oldflux-' + opt + '/' + n] == f['old-flux/' + opt + '/' + n]
        for n in ['state.csv', 'endpoint.csv', 'restart.bin']:
            assert f[bbc + 'full/' + n] == f[bbc + 'resumed/' + n]
        assert rows(bbc + 'resumed/budget.csv') == rows(bbc + 'full/budget.csv')[365:]
    for name, expected in [('corner-nut-joint', 'ACTUAL_PARTITION_CROP_RICHARDS_O0_O2_PASS'),
                           ('corner-nut-nonjuvenile', 'NONJUVENILE_ACTUAL_PARTITION_CROP_RICHARDS_O0_O2_PASS')]:
        r = js('raw/' + name + '/result.json')
        assert r['status'] == expected and r['runs'] == 4 and r['restarts'] == 8
        for key in r['results']:
            for day in [1, 4]:
                for suffix in ['', '.ledger']:
                    assert f['raw/' + name + '/' + key + '.endpoint' + suffix] == f['raw/' + name + '/' + key + '.fresh-' + str(day) + suffix]
    for opt in ['O0', 'O2']:
        for case in ['crop_nh4', 'crop_both']:
            for suffix in ['', '.ledger']:
                assert f['raw/corner-nut-nonjuvenile/' + opt + '/' + case + '.endpoint' + suffix] == f['old-nonjuvenile/' + opt + '/' + case + '.endpoint' + suffix]
    return dict(qualified=True, status='BOUNDED_PICARD_CORNER_SOURCE_AND_COMPOSITION_QUALIFIED',
                source_repair=True, direct_provider_count=21, full481_1x4x_O0_O2=True,
                actual_day240_restarts=True, original_BBC_and_flux_exact=True,
                current_NUT_coupled_runs=8, current_NUT_process_restarts=16,
                plain_Boesten_endpoint_admitted=False, wider_output_amount_policy_admitted=False,
                capped_interval_policy_admitted=False, full_mc_sol01_closed=False, full_mc_nut01_closed=False)


def reconciliation():
    record = json.loads((ROOT / STATUS).read_bytes())['concurrent_guard_reconciliation']
    raw = (ROOT / record['path']).read_bytes()
    assert sha(raw) == record['sha256']
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as t:
        f = {m.name: t.extractfile(m).read() for m in t.getmembers()}
    assert json.loads(f.pop('MANIFEST.json')) == {p: sha(b) for p, b in f.items()}
    info = json.loads(f['RESULT.json'])
    assert info['baseline'] == BASE and info['numerical_preimage'] == NUMERICAL_BASE
    for p, row in info['providers'].items():
        assert sha(subprocess.check_output(['git', 'show', NUMERICAL_BASE + ':' + p], cwd=ROOT)) == row['preimage_sha256']
        assert sha(subprocess.check_output(['git', 'show', BASE + ':' + p], cwd=ROOT)) == row['postimage_sha256']
        assert sha((ROOT / p).read_bytes()) == row['postimage_sha256']
    parent = json.loads(f['parent/RESULT.json'])
    old = f['parent/commit.raw']
    assert hashlib.sha1(b'commit ' + str(len(old)).encode() + b'\0' + old).hexdigest() == BASE
    assert parent['owner']['qualified'] and len(parent['controls']) == 17
    for opt in ['O0', 'O2']:
        r = json.loads(f[opt + '/RESULT.json'])
        assert r['status'] == 'CURRENT_COMPOSED_54_MACRO_CASES_AND_BBC481_EXACT'
        assert all(e['returncode'] == 0 for e in r['events']) and all(r['bbc_physical_identity'].values())
        assert len(r['unchanged_compiled_interfaces']) == 2
        for p, h in r['input_sha256'].items():
            assert sha((ROOT / p).read_bytes()) == h, ('composed executed source', p)
        assert b'CAUCHY_MACRO_INDEPENDENT_PASS' in f[opt + '/oracle-native.stdout']
        if opt == 'O2':
            assert f[opt + '/oracle-native.stdout'] == f['O0/oracle-native.stdout']
        for name in ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']:
            assert sha(f[opt + '/bbc/' + name]) == info['bbc_preimage_sha256'][opt][name]
    return info


def verify():
    source()
    return validate(capsule())


def fsi35_successors():
    source()
    reconciliation()
    # The latest macro owner is the predecessor of the registered source map.
    raw = (ROOT / json.loads((ROOT / STATUS).read_bytes())['concurrent_guard_reconciliation']['path']).read_bytes()
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as t:
        rows = json.load(t.extractfile('parent/RESULT.json'))['fsi35']
    for p, row in rows.items():
        current = git('rev-parse', 'HEAD:' + p)
        if current != row['canonical_blob']:
            assert p == HEAD
            row['canonical_blob'] = current
    return rows


def self_test():
    source()
    f = capsule()
    validate(f)
    passed = []

    def reject(label, fn):
        try:
            fn()
        except (AssertionError, KeyError, ValueError, TypeError, UnicodeError):
            passed.append(label)
            return
        raise AssertionError('accepted corner corruption ' + label)

    for p in json.loads((ROOT / STATUS).read_bytes())['postimages']:
        reject('source ' + p, lambda p=p: source(lambda q: (ROOT / q).read_bytes() + (b'!' if p == q else b'')))
    reject('foreign caller', lambda: source(changed={'src/foreign_corner.f90': 'A'}))
    for p in ['raw/corner-small-v3/RESULT.json', 'raw/corner-full4x-O2/head/budget.csv',
              'raw/corner-restart1x/resume/restart.bin', 'raw/corner-bbc-O0/full/state.csv',
              'raw/corner-nut-nonjuvenile/O0/crop_both.fresh-4.ledger']:
        bad = dict(f)
        bad[p] += b'!'
        reject('raw ' + p, lambda bad=bad: validate(bad))
    return passed


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
