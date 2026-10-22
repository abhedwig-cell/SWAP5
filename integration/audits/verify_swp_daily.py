"""Exact additive daily MET successor, retaining the complete water authority."""
import base64
import csv
import hashlib
import io
import json
import runpy
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
BASE = '46ad96ee2cc65fdee48a1f3b47e3290f86f7ffd6'
STATUS = 'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
PARENT = 'integration/audits/verify_swp_water.py'
SELF = 'integration/audits/verify_swp_daily.py'
KEY = 'daily_meteo_successor'
WORKFLOW = '.github/workflows/mc-sol01-swp-reader.yml'
ENTRIES = [('source', 'source', 'reader,changed'), ('verify_qualification', 'verify', ''), ('self_test', 'self_test', '')]


def projection(path):
    text = historical(path).decode()
    if path == PARENT:
        for entry, target, arguments in ENTRIES:
            start = text.index('def ' + entry + '(')
            offset = text.index('\n', start) + 1
            hook = (" if 'daily_meteo_successor' in record():\n"
                    "  return __import__('runpy').run_path(str(ROOT/'" + SELF + "'))['" + target + "'](" + arguments + ")\n")
            text = text[:offset] + hook + text[offset:]
    elif path == WORKFLOW:
        marker = '      - name: Source bound admission and negative controls\n'
        step = """      - name: Native daily MET and actual fallow column
        run: |
          set -euo pipefail
          root="$RUNNER_TEMP/swp-reader"
          python -B tools/solute/build_daily.py --optimization O0 --output "$root/daily-O0"
          python -B tools/solute/build_daily.py --optimization O2 --output "$root/daily-O2"
          python -B tests/nut-sol/qualify_swp_daily.py --reader-O0 "$root/daily-O0/swap5_read_daily" --reader-O2 "$root/daily-O2/swap5_read_daily" --column-O0 "$root/O0/swap5_solute_column" --column-O2 "$root/O2/swap5_solute_column" --output "$root/daily"
"""
        require(text.count(marker) == 1, 'workflow insertion point')
        text = text.replace(marker, step + marker, 1)
    return text.encode()



def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(ok, why):
    if not ok:
        raise ValueError(why)


def historical(path):
    return subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT)


def record(reader=lambda p: (ROOT / p).read_bytes()):
    return json.loads(reader(STATUS))['swp_water_successor'][KEY]


def parent_namespace():
    namespace = {'__file__': str(ROOT / PARENT), '__name__': 'frozen_swp_water'}
    exec(compile(historical(PARENT), str(ROOT / PARENT), 'exec'), namespace)
    return namespace


def source(reader=lambda p: (ROOT / p).read_bytes(), changed=None):
    r = record(reader)
    require(r['baseline'] == BASE, 'daily baseline drift')
    baseline = json.loads(historical(STATUS))
    actual_status = json.loads(reader(STATUS))
    actual_status['swp_water_successor'].pop(KEY)
    require(actual_status == baseline, 'unrelated status mutation')
    for path in [PARENT, WORKFLOW]:
        require(reader(path) == projection(path), 'predecessor assertions changed ' + path)
    for path, expected in r['postimages'].items():
        require(sha(reader(path)) == expected, 'daily source identity ' + path)
    parent = parent_namespace()
    # Check the full scientific delta before projecting the exact additive seam.
    actual = {} if changed is None else changed
    if changed is None:
        lines = subprocess.check_output(['git', 'diff', '--name-status', parent['BASE'], 'HEAD',
                                         '--', *parent['SCIENCE']], cwd=ROOT, text=True).splitlines()
        actual = {line.split('\t')[1]: line.split('\t')[0] for line in lines}
    expected = dict(baseline['swp_water_successor']['admission']['source_delta'])
    expected.update(r['additive_science_delta'])
    require(actual == expected, 'foreign daily scientific delta')

    def inherited(path):
        # The modified owner is an exact early hook. All its old assertions and
        # original postimage hash are still evaluated against its original bytes.
        return historical(path) if path in [PARENT, WORKFLOW] else reader(path)

    return parent['source'](inherited, baseline['swp_water_successor']['admission']['source_delta'])


def capsule():
    e = record()['evidence']
    raw = base64.b64decode(b''.join((ROOT / e['path']).read_bytes().split()), validate=True)
    require(sha(raw) == e['decoded_sha256'], 'daily capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as archive:
        members = archive.getmembers()
        require(len(members) == e['members'] and len({m.name for m in members}) == len(members), 'daily census')
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts
                    for m in members), 'unsafe daily member')
        files = {m.name: archive.extractfile(m).read() for m in members}
    manifest = json.loads(files.pop('MANIFEST.json'))
    require(set(manifest) == set(files), 'daily inventory')
    require(all(sha(files[p]) == h for p, h in manifest.items()), 'daily member corruption')
    return files


def validate(files, reader=lambda p: (ROOT / p).read_bytes()):
    def js(path):
        return json.loads(files[path])

    def rows(path):
        return [{k: float(v) for k, v in row.items()} for row in csv.DictReader(io.StringIO(files[path].decode()))]

    r = js('qualification/result.json')
    require(r['status'] == 'PASS' and len(r['cases']) == 8, 'daily proof incomplete')
    require(len(r['events']) == 72, 'daily process census')
    for p, h in r['inputs'].items():
        require(sha(reader(p)) == h, 'stale executed daily input ' + p)
    for event in r['events']:
        require((event['returncode'] == 0) == event['expected_success'], 'failed process counted as pass')
    for opt in ['O0', 'O2']:
        b = js('build-' + opt + '/build-complete.json')
        require(b == r['builds'][opt]['reader'] and b['status'] == 'BUILT', 'reader build receipt')
        require('-' + opt in b['flags'] and '-fcheck=all' in b['flags'], 'reader build policy')
        require(sha(files['build-' + opt + '/swap5_read_daily']) == b['executable_sha256'], 'reader executable')
        require(all(e['returncode'] == 0 for e in b['events']), 'reader build failed')
        for p, h in b['input_sha256'].items():
            require(sha(reader(p)) == h, 'stale reader input ' + p)
        for p, h in b['generated_input_sha256'].items():
            require(sha(files['build-' + opt + '/' + p]) == h, 'original TTUTIL identity')
        # Reused physical executable is bound to every current source input and
        # unchanged full build receipt; native composition executes it anew.
        cb = r['builds'][opt]['column']
        for p, h in cb['input_sha256'].items():
            require(sha(reader(p)) == h, 'changed inherited column provider ' + p)
        for name in ['leap', 'year', 'century_leap', 'century_common']:
            prefix = 'qualification/' + opt + '/' + name + '/'
            require(rows(prefix + 'daily.csv') == rows(prefix + 'oracle.csv') == r['cases'][opt + '-' + name],
                    'original native meteorology mismatch')
        prefix = 'qualification/' + opt + '/'
        require(files[prefix + 'original.f90'].decode() == runpy.run_path(str(ROOT / 'tests/nut-sol/qualify_swp_daily.py'))['oracle_source'](), 'original procedure extraction drift')
        for name in ['state.csv', 'endpoint.csv', 'restart.bin']:
            require(files[prefix + 'full/' + name] == files[prefix + 'resumed/' + name], 'daily fresh restart')
        for name in ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']:
            require(files[prefix + 'full/' + name] == files[prefix + 'explicit/' + name], 'explicit calculation drift')
        for generation in ['full', 'split', 'resumed', 'explicit']:
            m = js(prefix + generation + '/manifest.json')
            require(m['status'] == 'COMPLETE' and m['executable_sha256'] == cb['executable_sha256'], 'native generation')
            for p, h in m['files'].items():
                require(sha(files[prefix + generation + '/' + p]) == h, 'daily generation bytes')
        budget = rows(prefix + 'full/budget.csv')
        require(rows(prefix + 'resumed/budget.csv') == budget[1:], 'daily continuation rows')
        for i, row in enumerate(budget):
            require(abs(row['water_in_cm'] - [.2, 0., .1][i]) < 1e-10, 'native rainfall amount')
            for substance, unit in [('water', 'cm'), ('solute', 'mg_cm2')]:
                residual = row[f'{substance}_end_{unit}'] - row[f'{substance}_start_{unit}'] - row[f'{substance}_in_{unit}'] + row[f'{substance}_out_{unit}']
                require(abs(residual) < 1e-10 and abs(row[f'{substance}_residual_{unit}']) < 1e-10, 'daily mass balance')
    return {'status': 'NATIVE_DAILY_MET_O0_O2_PASS', 'original_comparisons': 8,
            'fresh_restarts': 2, 'full_historical_migration': False}


def self_test(include_predecessor=True):
    files = capsule()
    controls = []
    for path in record()['postimages']:
        def corrupt(p):
            return (ROOT / p).read_bytes() + (b'corrupt' if p == path else b'')
        try:
            source(corrupt)
        except (ValueError, json.JSONDecodeError):
            controls.append(path)
        else:
            raise AssertionError('stale daily source accepted: ' + path)
    for path in ['qualification/result.json', 'qualification/O0/leap/daily.csv',
                 'qualification/O2/full/restart.bin', 'qualification/O0/full/budget.csv',
                 'build-O2/swap5_read_daily']:
        bad = dict(files)
        bad[path] += b'corrupt'
        try:
            validate(bad)
        except (ValueError, KeyError, json.JSONDecodeError):
            controls.append(path)
        else:
            raise AssertionError('corrupt daily proof accepted: ' + path)
    baseline = json.loads(historical(STATUS))
    foreign = dict(baseline['swp_water_successor']['admission']['source_delta'])
    foreign.update(record()['additive_science_delta'])
    foreign['src/foreign_meteo.f90'] = 'A'
    try:
        source(changed=foreign)
    except ValueError:
        controls.append('unregistered scientific delta')
    else:
        raise AssertionError('foreign daily source accepted')
    if include_predecessor:
        parent = parent_namespace()
        parent['source'] = source
        controls += ['predecessor:' + p for p in parent['self_test']()]
    return controls


def verify():
    source()
    result = validate(capsule())
    # Run all original scientific/evidence assertions, not a substitute receipt.
    parent = parent_namespace()
    parent['source'] = source
    result['predecessor'] = parent['verify_qualification']()
    result['predecessor_controls'] = len(parent['self_test']())
    result['controls'] = len(self_test(False))
    return result


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
