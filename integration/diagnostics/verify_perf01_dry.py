"""Verify historical failure evidence, never qualify a production solver change."""
import base64
import csv
import hashlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
BASE = 'c62ca4ce2e33c65be3630f947b8ff322cd2f9863'
INDEX = ROOT/'integration/diagnostics/evidence/perf01-dry-20261021/INDEX.json'


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def capsule():
    index = json.loads(INDEX.read_text())
    raw = base64.b64decode(b''.join((INDEX.parent/p).read_bytes() for p in index['parts']), validate=True)
    require(sha(raw) == index['decoded_sha256'], 'capsule hash')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        members = archive.getmembers()
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members), 'unsafe member')
        require(len(members) == len({m.name for m in members}), 'duplicate members')
        files = {m.name: archive.extractfile(m).read() for m in members}
    manifest = files.pop('MEMBERS.json')
    require(sha(manifest) == index['members_sha256'], 'manifest hash')
    inventory = json.loads(manifest)
    require(files.keys() == inventory.keys() and len(files) == index['members'], 'inventory')
    require(all(sha(files[p]) == v for p, v in inventory.items()), 'member hash')
    return files


def validate(files):
    old = runpy.run_path(str(ROOT/'integration/performance/verify_proposal.py'))['capsule']()
    rows = lambda raw: list(csv.DictReader(io.StringIO(raw.decode())))
    load = lambda p: json.loads(files[p])
    oracle = 'temporal-day64-inflow-O2/dry_infiltration32/1e-06-off-0/'
    for name in ['budget.csv', 'stdout', 'work.csv', 'trajectory.csv', 'stderr']:
        require(files['oracle/'+name] == old[oracle+name], 'relabelled original failure '+name)
    counters = lambda raw: [{k: v for k, v in r.items() if k != 'cpu'} for r in rows(raw)]
    reference_work = counters(files['oracle/work.csv'])
    rings = []
    for opt, directory, original in [('O0', 'O0', 'temporal-short-O0'), ('O2', 'O2-v6', 'temporal-day64-inflow-O2')]:
        require(files['oracle/'+opt+'-CONTROL.json'] == old[original+'/CONTROL.json'], 'original build provenance')
        prior = json.loads(old[original+'/CONTROL.json'])
        build = load(directory+'/BUILD.json')
        require(build['observer']['object_sha256'] == prior['generated']['object_sha256'], 'reused object identity')
        require(len(build['observer']['object_sha256']) == 177, 'column closure size')
        require('-'+opt in build['build']['flags'] and '-ffpe-trap=invalid,zero,overflow' in build['build']['flags'], 'compile policy')
        for p, digest in build['build']['input_sha256'].items():
            raw = subprocess.check_output(['git', 'show', BASE+':'+p], cwd=ROOT)
            require(sha(raw) == digest, 'unbound historical source '+p)
        for p, digest in build['generated_sha256'].items():
            require(sha(files[directory+'/observer/'+p]) == digest, 'generated source identity')
        result = load(directory+'/RESULT.json')
        require(result['status'] == 'DIAGNOSTIC_FAILURE_REPRODUCED_NOT_PRODUCTION_QUALIFIED', 'relabelled diagnosis')
        require([r['policy'] for r in result['observations']] == ['off', 'on'], 'policy selection')
        for record in result['observations']:
            prefix = directory+'/'+record['policy']+'/'
            require(record['returncode'] == 1, 'native failure missing')
            for p, digest in record['raw_sha256'].items():
                require(sha(files[prefix+p]) == digest, 'raw observation hash')
            for p in ['budget.csv', 'stdout', 'trajectory.csv']:
                require(files[prefix+p] == files['oracle/'+p], 'failure trajectory changed '+p)
            require(counters(files[prefix+'work.csv']) == reference_work, 'work changed')
            transaction = rows(files[prefix+'transaction_failure.csv'])[0]
            require(int(transaction['calls']) == sum(int(r['headcalc_calls']) for r in reference_work), 'incomplete solve sequence')
            require(float(transaction['t0']) == .078125 and float(transaction['t1']) == .09375, 'wrong failed window')
            require(int(transaction['mass_rejections']) == 0, 'unreported mass rejection')
            ring = rows(files[prefix+'solver_failure.csv'])
            require(len(ring) == 64 and ring[-1]['call'] == transaction['calls'], 'missing terminal solver failure')
            for r in ring:
                require(abs(float(r['max_residual'])) <= float(r['compartment_tolerance']), 'compartment criterion failed')
                require(abs(float(r['total_residual'])) > float(r['total_tolerance']), 'total-only failure missing')
                require(float(r['head_increment_ratio']) <= 1 and r['pond_failure'] == 'F', 'head or pond failed')
                require(r['at_min'] == 'F', 'legacy minimum-step acceptance used')
            rings.append(files[prefix+'solver_failure.csv'])
    require(all(r == rings[0] for r in rings), 'O0/O2/policy terminal difference')
    terminal = rows(rings[0])[-1]
    require(float(terminal['head_increment_ratio']) == 0, 'terminal head not stagnant')
    return dict(status='BASELINE_FAILURE_DIAGNOSIS_VERIFIED', baseline=BASE, native_executions=4,
        raw_terminal_rings_identical=True, terminal=terminal,
        terminal_depth_residual_cm=float(terminal['dt'])*float(terminal['total_residual']),
        production_changed=False, production_qualified=False,
        interpretation='Total balance stagnation established; arithmetic-resolution explanation remains an inference')


def self_test(files):
    cases = []
    def reject(name, broken):
        try:
            validate(broken)
        except (KeyError, ValueError):
            cases.append(name)
        else:
            raise ValueError('accepted corruption '+name)
    broken = dict(files)
    del broken['O0/on/solver_failure.csv']
    reject('missing terminal failure', broken)
    for key, edit in [
        ('O2-v6/RESULT.json', lambda raw: raw.replace(b'"returncode": 1', b'"returncode": 0')),
        ('O0/off/solver_failure.csv', lambda raw: raw.replace(b'-4.52061638243112272E-005', b' 0.00000000000000000E+000')),
        ('O2-v6/observer/headcalc.f90', lambda raw: raw+b'!foreign source\n'),
        ('oracle/budget.csv', lambda raw: raw+b'!modified failure\n')]:
        broken = dict(files)
        broken[key] = edit(broken[key])
        reject(key, broken)
    return dict(negative_controls=len(cases), rejected=cases)


if __name__ == '__main__':
    files = capsule()
    report = validate(files)
    if '--self-test' in sys.argv:
        report['self_test'] = self_test(files)
    print(json.dumps(report, indent=2))
