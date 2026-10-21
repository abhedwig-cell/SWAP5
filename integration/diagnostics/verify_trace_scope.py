"""Source-bound scratch reclamation; reuse original scientific validators verbatim."""
import base64
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASE = 'c4ec414fe5ae55e992e557e394cb4003beaf3e39'
MEASURED_BASE = '969aa918f0104546ec4ca2372feccf37b0145627'
STATUS = 'integration/diagnostics/PERF01_TRACE_SCOPE_STATUS.json'
OWNER = 'integration/audits/verify_pond_thermal.py'
NUT_OWNER = 'integration/audits/verify_nut_negative.py'
PRODUCTION = {'src/transaction/mod_transaction_reference.f90',
              'src/runtime/mod_fmr_serialized_reference_backend.f90'}
ADDED = {'tests/performance/test_perf01_scratch_lifecycle.f90',
         'tests/performance/test_perf01_trace_scope.f90',
         'tests/performance/test_perf01_trace_scope_payload.f90',
         'integration/diagnostics/build_trace_scope.py',
         'integration/diagnostics/qualify_trace_scope.py',
         'integration/diagnostics/verify_trace_scope.py'}
CASES = ['1', '0.5', '0.8', '1.0005', '1.5', '2']


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def record():
    return json.loads((ROOT / STATUS).read_text())


def hook(fn):
    return (" if 'evidence' in json.loads((ROOT/'" + STATUS + "').read_text()):\n"
            "  import runpy\n"
            "  return runpy.run_path(str(ROOT/'integration/diagnostics/verify_trace_scope.py'))['" + fn + "'](" +
            ('reader,changed' if fn == 'source' else '') + ")\n")


def science(path):
    return path.split('/')[0] in {'src', 'tests', 'tools', 'reference', '.github', 'app', 'examples'} or (
        path.startswith('integration/') and Path(path).suffix in {'.py', '.f90', '.c', '.inc', '.sh'})


def source(reader=lambda p: (ROOT / p).read_bytes(), changed=None):
    s = record()
    require(s['baseline'] == BASE, 'wrong predecessor')
    git('merge-base', '--is-ancestor', BASE, 'HEAD')
    dirty = git('status', '--porcelain')
    require(not any(science(line[3:]) for line in dirty.splitlines()), 'dirty scientific source')
    actual = changed if changed is not None else {line.split('\t')[1]: line.split('\t')[0]
        for line in git('diff', '--name-status', BASE, 'HEAD').splitlines() if science(line.split('\t')[1])}
    expected = {**{p: 'M' for p in PRODUCTION | {OWNER, NUT_OWNER}}, **{p: 'A' for p in ADDED}}
    require(actual == expected, 'unregistered scientific delta')
    require(set(s['postimages']) == set(expected), 'postimage inventory')
    for path in expected:
        require(sha(reader(path)) == s['postimages'][path]['sha256'], 'source identity ' + path)
    for owner in [OWNER, NUT_OWNER]:
        original = subprocess.check_output(['git', 'show', BASE + ':' + owner], cwd=ROOT, text=True)
        for fn in ['source', 'verify_qualification', 'self_test']:
            start = re.search(r'^def ' + fn + r'\(', original, re.M).start()
            end = original.index('\n', start) + 1
            original = original[:end] + hook(fn) + original[end:]
        require(reader(owner).decode() == original, 'predecessor assertions changed')
    path = 'src/transaction/mod_transaction_reference.f90'
    old = subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT, text=True)
    def body(text, name):
        match = re.search(r'^  subroutine ' + name + r'\(.*?^  end subroutine ' + name,
                          text, re.M | re.S)
        require(match is not None, 'transaction body absent')
        return match[0].replace(name, 'execute_reference_interval')
    require(body(old, 'execute_reference_interval') == body(reader(path).decode(), 'execute_reference_interval_body'),
            'original transaction numerics changed')
    return s


def capsule():
    e = record()['evidence']
    raw = base64.b64decode(b''.join((ROOT / e['directory'] / p).read_bytes() for p in e['parts']), validate=True)
    require(sha(raw) == e['decoded_sha256'], 'capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        members = archive.getmembers()
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members), 'unsafe capsule')
        require(len(members) == len({m.name for m in members}), 'duplicate member')
        files = {m.name: archive.extractfile(m).read() for m in members}
    manifest = json.loads(files.pop('MEMBERS.json'))
    require(set(files) == set(manifest), 'member inventory')
    require(all(sha(files[p]) == h for p, h in manifest.items()), 'member corruption')
    return files


def validate(files, reader=lambda p: (ROOT / p).read_bytes()):
    def js(path):
        return json.loads(files[path])
    def current(inputs):
        for path, digest in inputs.items():
            require(sha(reader(path)) == digest, 'stale executed source ' + path)
    def project(prefix, target, mapping):
        mapping.update({target + p[len(prefix):]: raw for p, raw in files.items() if p.startswith(prefix)})
    b = js('build/BUILD.json')
    require(b['status'] == 'FRESH_BUILDS_AND_LIFECYCLE_IMMUTABLE_SCOPE_CONTRACTS_PASS' and b['baseline'] == MEASURED_BASE, 'unfinished build contracts')
    current(b['inputs'])
    require(len(b['direct']) == 6 and len(b['private']) == 12, 'missing direct cases')
    require(sum(e['returncode'] != 0 for e in b['private']) == 8, 'missing expected rejection controls')
    for event in b['events']:
        stdout, stderr = (files['build/' + event[x]] for x in ['stdout', 'stderr'])
        if event['category'] == 'private_native' and event['returncode'] != 0:
            require(b'stale or invalid attempt context' in stderr or b'invalid scratch scope' in stderr, 'wrong negative failure')
        else:
            require(event['returncode'] == 0, 'native build/test failed')
        if event['category'] in {'direct_native', 'private_native'} and event['returncode'] == 0:
            require(b'=PASS' in stdout, 'missing native contract marker')
    for opt in ['O0', 'O2']:
        build = js('build/current-' + opt + '/build-complete.json')
        current(build['input_sha256'])
        require(build['provider_count'] == 187 and build['status'] == 'BUILT', 'column closure changed')
        projected = files['build/private-' + opt + '/backend.f90']
        expected = reader('src/runtime/mod_fmr_serialized_reference_backend.f90').replace(b'  implicit none\n  private\n', b'  implicit none\n  public\n', 1)
        require(projected == expected, 'private test changed executable logic')
    deep = js('payload/DEEP.json')
    require(deep['source_sha256'] == sha(reader('tests/performance/test_perf01_trace_scope_payload.f90')), 'stale deep-payload test')
    require({r['opt'] for r in deep['runs']} == {'O0', 'O2'}, 'missing payload optimization')
    require(all(r['returncode'] == 0 and r['stdout'] == 'TRACE_SCOPE_DEEP_SALT_RANK2_EMPTY_PAYLOAD_EXACT=PASS\n' for r in deep['runs']), 'deep payload drift')
    c = js('columns-v2/RESULT.json')
    require(c['status'] == 'ORIGINAL86_AND_EXACT_DRY_FAILURE_UNDER512MIB_PASS', 'dry probes unfinished')
    current(c['inputs'])
    old = runpy.run_path(str(ROOT / 'integration/diagnostics/verify_perf01_dry.py'))['capsule']()
    def rows(raw):
        return [{k: v for k, v in r.items() if k != 'cpu'} for r in csv.DictReader(io.StringIO(raw.decode()))]
    for tag in ['baseline-O2-1536', 'current-O2-512', 'current-O0-512']:
        prefix = 'columns-v2/' + tag + '/'
        for name in ['budget.csv', 'trajectory.csv', 'stdout']:
            require(files[prefix + name] == old['oracle/' + name], 'original physical/failure bytes changed')
        require(rows(files[prefix + 'work.csv']) == rows(old['oracle/work.csv']), 'deterministic work changed')
        r = js(prefix + 'RESOURCE.json')
        require(r['exit'] == 1 and not r['timed_out'], 'numerical failure censored')
    control = js('columns-v2/baseline-O2-512/RESOURCE.json')
    require(control['exit'] == -11 and not control['timed_out'] and control['max_rss_kib'] >= 480 * 1024, 'failed resource control relabelled')
    require(len(rows(files['columns-v2/baseline-O2-512/work.csv'])) < 6, 'resource control unexpectedly complete')
    require(files['columns-v2/baseline-O2-512/stdout'] != old['oracle/stdout'], 'resource control misclassified')
    old_rss = js('columns-v2/baseline-O2-1536/RESOURCE.json')['max_rss_kib']
    new_rss = js('columns-v2/current-O2-512/RESOURCE.json')['max_rss_kib']
    require(new_rss < 128 * 1024 and old_rss / new_rss > 10, 'memory correction absent')
    require(js('columns-v2/current-O0-512/RESOURCE.json')['max_rss_kib'] < 128 * 1024, 'checked memory correction absent')
    p = js('preservation/RESULT.json')
    require(p['status'] == 'CURRENT_RUNTIME_MATRIX_POND_THERMAL_AND_MONTH_YEAR_PRESERVED', 'unfinished preservation')
    current(p['inputs'])
    for event in p['events']:
        require(event['returncode'] == 0, 'preservation command failed')
        for stream in ['stdout', 'stderr']:
            require('preservation/' + event[stream] in files, 'missing preservation stream')
    runtime = js('preservation/runtime/PRESERVATION.json')
    current(runtime['inputs'])
    incumbent = json.loads(runpy.run_path(str(ROOT / 'integration/performance/authority.py'))['capsule']()['arena-preservation/CONTROL.json'])
    require(runtime['status'] == 'INCUMBENT_EIGHT_RUNTIME_OBSERVATIONS_EXACT_PASS' and runtime['runs'] == incumbent['runs'], 'incumbent runtime changed')
    for i, event in enumerate(runtime['events']):
        require(event['returncode'] == 0, 'runtime command failed')
        for stream in ['stdout', 'stderr']:
            require(f'preservation/runtime/{i:04d}.{stream}' in files, 'missing runtime stream')
    matrix = runpy.run_path(str(ROOT / 'integration/audits/verify_matrix_thermal.py'))
    compiled = files['preservation/runtime/thermal-physical/result.json']
    for exponent in CASES:
        mapped = {}
        prefix = 'preservation/runtime/thermal-' if exponent == '1' else 'preservation/matrix/' + exponent + '/'
        project(prefix + 'physical/', 'physical/', mapped)
        project(prefix + 'qualified/', 'qualification/', mapped)
        matrix['validate'](mapped, reader, None if exponent == '1' else compiled)
    pond = runpy.run_path(str(ROOT / OWNER))
    mapped = {}
    for exponent in CASES:
        for part in ['physical', 'qualified']:
            project(f'preservation/pond/{exponent}/{part}/', f'{part}/{exponent}/', mapped)
    project('columns-v2/qualification/', 'column/qualification/', mapped)
    for opt in ['O0', 'O2']:
        mapped['column/' + opt + '/build-complete.json'] = files['build/current-' + opt + '/build-complete.json']
    for duration in ['month', 'season']:
        project('preservation/' + duration + '/', duration + '/', mapped)
    # Reuse immutable expected hashes; original validator checks all 160 fresh raw artifacts against them.
    mapped['incumbent-comparison.json'] = pond['capsule']()['incumbent-comparison.json']
    result = pond['validate'](mapped, reader)
    nut = runpy.run_path(str(ROOT / NUT_OWNER))
    prior = nut['capsule']()
    native = runpy.run_path(str(ROOT / 'tests/nut-crop/verify_historical_gross.py'))
    require(js('nut/RESULT.json')['status'] == 'CONCURRENT_FINITE_DONOR_AND_RETAINED_FRESH_PASS', 'unfinished concurrent NUT preservation')
    mapped_nut = {}
    project('nut/', '', mapped_nut)
    for prefix in ['production', 'production/physical', 'retained']:
        report = json.loads(mapped_nut[prefix + '/result.json'])
        current(report['input_sha256'])
        events = json.loads(mapped_nut[prefix + '/events.json'])
        require(all(e['returncode'] == 0 for e in events), 'concurrent NUT native failure')
        if prefix != 'production':
            native['executions'](mapped_nut, prefix, events)
        else:
            require(sum(e['category'] == 'joint_native' for e in events) == 4 and
                    sum(e['category'] == 'restart_native' for e in events) == 8 and
                    sum(e['category'] == 'invalid_native' for e in events) == 2, 'missing finite-donor current cases')
            for event in events:
                for stream in ['stdout', 'stderr']:
                    require(sha(mapped_nut[prefix + '/' + event[stream]]) == event[stream + '_sha256'], 'concurrent NUT raw stream drift')
        old_report = json.loads(prior[prefix + '/result.json'])
        keys = ['direct', 'joint'] if prefix == 'production' else (['results'] if prefix.endswith('physical') else ['b112_retained'])
        for key in keys:
            require(report[key] == old_report[key], 'concurrent NUT physical result drift ' + key)
    # Fresh original native assertions include all disk/rollback controls. Bind
    # their physical endpoints to the admitted finite-donor raw artifacts too.
    endpoints = [p for p in prior if p.startswith(('production/', 'retained/')) and
                 (p.endswith('.endpoint') or p.endswith('.endpoint.ledger'))]
    require(len(endpoints) >= 20, 'incumbent endpoint inventory')
    for path in endpoints:
        require(mapped_nut[path] == prior[path], 'concurrent NUT endpoint drift ' + path)
    result.update(trace_scope=True, matrix_six_exponents=True, concurrent_finite_donor_preserved=True,
                  fresh_nut_endpoint_artifacts=len(endpoints), memory_baseline_kib=old_rss,
                  memory_current_kib=new_rss, memory_reduction_fraction=1 - new_rss / old_rss,
                  dry_numerical_failure_unchanged=True, speedup_claim=False)
    return result


def predecessor():
    with tempfile.TemporaryDirectory(prefix='swap5-trace-scope-predecessor-') as tmp:
        path = Path(tmp) / 'base'
        subprocess.run(['git', 'worktree', 'add', '--detach', path, BASE], cwd=ROOT, check=True, capture_output=True)
        try:
            p = subprocess.run([sys.executable, '-B', NUT_OWNER], cwd=path, capture_output=True, text=True,
                               env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'})
            require(p.returncode == 0 and json.loads(p.stdout)['qualified'], 'exact predecessor ' + p.stderr[-1000:])
        finally:
            subprocess.run(['git', 'worktree', 'remove', '--force', path], cwd=ROOT, check=True, capture_output=True)
    return True


def verify_qualification():
    source()
    result = validate(capsule())
    result.update(predecessor_qualified=predecessor(), source_tree=git('rev-parse', 'HEAD:src'),
                  current_source_tree=git('rev-parse', 'HEAD:src'))
    return result


def self_test():
    files = capsule()
    validate(files)
    controls = []
    for path in ['payload/DEEP.json', 'columns-v2/baseline-O2-512/RESOURCE.json',
                 'columns-v2/current-O2-512/work.csv', 'preservation/pond/0.8/qualified/result.json',
                 'preservation/matrix/2/physical/O2/16/resumed.bin', 'preservation/season/O0-0.5-4/full/budget.csv']:
        bad = dict(files)
        del bad[path]
        try:
            validate(bad)
        except (ValueError, KeyError):
            controls.append('missing ' + path)
        else:
            raise ValueError('missing native evidence accepted')
    for path in PRODUCTION:
        try:
            validate(files, lambda p: (ROOT / p).read_bytes() + (b'!' if p == path else b''))
        except ValueError:
            controls.append('stale ' + path)
        else:
            raise ValueError('stale source accepted')
    path = 'columns-v2/baseline-O2-512/RESOURCE.json'
    bad = dict(files)
    bad[path] = json.dumps({**json.loads(bad[path]), 'exit': 0}).encode()
    try:
        validate(bad)
    except ValueError:
        controls.append('failed resource control relabelled PASS')
    else:
        raise ValueError('false resource PASS accepted')
    changes = {p: v['status'] for p, v in record()['postimages'].items()}
    for fn in [lambda: source(changed={**changes, 'src/foreign.f90': 'A'}),
               lambda: source(lambda p: (ROOT / p).read_bytes() + (b'!' if p == OWNER else b''))]:
        try:
            fn()
        except ValueError:
            controls.append('source boundary ' + str(len(controls)))
        else:
            raise ValueError('source boundary escaped')
    return {'count': len(controls), 'negative_controls': controls}


if __name__ == '__main__':
    print(json.dumps(self_test() if '--self-test' in sys.argv else verify_qualification(), indent=2))
