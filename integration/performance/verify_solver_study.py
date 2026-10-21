"""Verify bounded diagnostic evidence, not production policy admission."""
import base64
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
STATUS = ROOT/'integration/performance/SWAP5-PERF01_SOLVER_STUDY_STATUS.json'
CASES = ['pond4', 'pond32', 'pond256', 'dry32', 'pulse4']
FILES = ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def capsule(path, digest):
    index = json.loads(path.read_text())
    raw = base64.b64decode(b''.join((path.parent/p).read_bytes() for p in index['parts']), validate=True)
    require(sha(raw) == digest == index['decoded_sha256'], 'capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        members = archive.getmembers()
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts
                    for m in members), 'unsafe member')
        require(len(members) == len({m.name for m in members}), 'duplicate member')
        files = {m.name: archive.extractfile(m).read() for m in members}
    manifest_bytes = files.pop('MEMBERS.json')
    require(sha(manifest_bytes) == index['members_sha256'], 'manifest identity')
    manifest = json.loads(manifest_bytes)
    require(len(files) == index['member_count'] and files.keys() == manifest.keys(), 'member inventory')
    require(all(sha(files[p]) == h for p, h in manifest.items()), 'member digest')
    return files


def validate(files, names, reader=lambda p: (ROOT/p).read_bytes()):
    controls = {}
    for name in names:
        record = json.loads(files[name+'/CONTROL.json'])
        controls[name] = record
        build = record['build']
        require(build['provider_count'] == 178, 'production closure')
        for path, digest in build['input_sha256'].items():
            require(sha(reader(path)) == digest, 'changed production provider '+path)
        require(sha(files[name+'/driver.py']) == record['driver_sha256'], 'registered driver')
        for policy, generated in record['generated'].items():
            prefix = name+'/'+policy+'/'
            require(sha(files[prefix+'main.f90']) == generated['main_sha256'], 'generated main')
            require(sha(files[prefix+'mod_canonical_interval_runtime.f90']) == generated['runtime_sha256'],
                    'generated runtime')
        for run in record['runs']:
            prefix = name+'/'+run['directory']+'/'
            if run['exit'] != 0:
                require(record['status'] == 'NATIVE_FAILED_OR_CENSORED_NOT_QUALIFIED', 'failure relabelled')
                require(name == 'temporal-recover' and run['exit'] == 1, 'unexpected native failure')
                out = files[prefix+'stdout'].decode()
                require('COMMITTED_WATER_CLOCK   0.0000000000000000' in out and
                        'COMMITTED_CHEMICAL_CLOCK   0.0000000000000000' in out and
                        'CHEMICAL_STEPS           0' in out, 'failed atomicity')
                continue
            require(all(sha(files[prefix+f]) == run['files'][f] for f in FILES), 'physical file digest')
            if 'work' in run:
                work = list(csv.DictReader(io.StringIO(files[prefix+'work.csv'].decode())))
                require(all(sum(int(r[k]) for r in work) == v for k, v in run['work'].items()), 'work counters')
                require(run['work']['mass_rejections'] == 0, 'mass rejection')
                rows = list(csv.DictReader(io.StringIO(files[prefix+'trajectory.csv'].decode())))
                expected = len(work)*len(list(csv.DictReader(io.StringIO(files[prefix+'state.csv'].decode()))))
                require(len(rows) == expected, 'trajectory inventory')
                require(all(math.isfinite(float(r[k])) for r in rows
                            for k in ['head', 'theta', 'concentration']), 'nonfinite trajectory')
        for summary in record['summary']:
            require(summary['observer_exact'] and summary['both_restarts_exact'], 'original assertions')
            case = summary['case']
            for policy in ['off', 'on']:
                full = name+'/'+case+'/1e-06-'+policy+'-0/'
                resumed = name+'/'+case+'/'+policy+'-restart/'
                require(all(files[full+f] == files[resumed+f] for f in FILES[1:]), 'fresh restart bytes')
                for f in ['budget.csv', 'trajectory.csv']:
                    read = lambda prefix: list(csv.DictReader(io.StringIO(files[prefix+f].decode())))
                    require([r for r in read(full) if int(r['window']) > 4] == read(resumed), 'resumed trajectory')
            if name == 'temporal-O2':
                for ref in ['off', 'on']:
                    error = summary['errors_to_'+ref+'_reference']
                    require(error['1e-06-on']['head'] > error['2.5e-07-on']['head'] >
                            error['6.25e-08-on']['head'], 'head refinement')
    return controls


def verify():
    status = json.loads(STATUS.read_text())
    require(status['production_changed'] is False, 'production scope')
    for path, digest in status['source_sha256'].items():
        require(sha((ROOT/path).read_bytes()) == digest, 'diagnostic source drift')
    diff = subprocess.check_output(['git', 'diff', status['baseline'], 'HEAD', '--', 'src', 'tests', 'tools',
                                    'reference', '.github', 'app', 'examples'], cwd=ROOT)
    require(not diff, 'incumbent science mutation')
    collections = {k: capsule(ROOT/v['index'], v['sha256']) for k, v in status['evidence'].items()}
    screen = validate(collections['screen'], ['temporal-'+p for p in ['cap', 'ceiling', 'recover', 'fallback']])
    candidate = validate(collections['candidate'], ['temporal-O0', 'temporal-O2'])
    require(len(candidate['temporal-O0']['runs']) == 45 and len(candidate['temporal-O2']['runs']) == 85,
            'candidate execution count')
    require(all([s['case'] for s in r['summary']] == CASES and r['status'] ==
                'DIAGNOSTIC_COMPLETE_NO_PRODUCTION_ADMISSION' for r in candidate.values()), 'candidate completion')
    o2 = {r['directory']: r for r in candidate['temporal-O2']['runs']}
    for r in candidate['temporal-O0']['runs']:
        require(r['files'] == o2[r['directory']]['files'], 'optimization physical drift')
        require(r.get('work') == o2[r['directory']].get('work'), 'optimization numeric work drift')
    original = status['incumbent_temporal_evidence']
    old = capsule(ROOT/original['index'], original['sha256'])
    for case in ['pond4', 'pond32', 'pond256', 'pulse4']:
        for tol in ['1e-06', '2.5e-07', '6.25e-08', '1e-09']:
            suffix = case+'/'+tol+'-on-0/'
            for f in FILES+['trajectory.csv']:
                require(collections['candidate']['temporal-O2/'+suffix+f] ==
                        old['temporal-fresh-O2/'+suffix+f], 'wet incumbent optional drift')
    records = [*screen.values(), *candidate.values()]
    count = sum(len(r['runs']) for r in records)
    failures = sum(x['exit'] != 0 for r in records for x in r['runs'])
    require(count == 159 and failures == 1, 'complete native disposition')
    return dict(status='BOUNDED_DIAGNOSTIC_PASS_NO_PRODUCTION_ADMISSION', native_executions=count,
                retained_failures=failures, optimization_exact_observations=45,
                incumbent_wet_exact_observations=16, fresh_restart_policy_cases=20)


def self_test():
    status = json.loads(STATUS.read_text())
    e = status['evidence']['candidate']
    original = capsule(ROOT/e['index'], e['sha256'])
    passed = []
    for path in ['temporal-O2/on/mod_canonical_interval_runtime.f90',
                 'temporal-O2/dry32/1e-06-on-0/state.csv',
                 'temporal-O0/pond4/on-restart/restart.bin',
                 'temporal-O2/pond32/1e-06-on-0/trajectory.csv']:
        files = dict(original)
        files[path] += b'!'
        try:
            validate(files, ['temporal-O0', 'temporal-O2'])
        except (ValueError, KeyError):
            passed.append(path)
        else:
            raise ValueError('accepted corruption '+path)
    try:
        validate(original, ['temporal-O2'], lambda p: (ROOT/p).read_bytes()+b'!')
    except ValueError:
        passed.append('stale production provider')
    else:
        raise ValueError('accepted stale production')
    return dict(negative_controls=passed, count=len(passed))


if __name__ == '__main__':
    print(json.dumps(self_test() if '--self-test' in sys.argv else verify(), indent=2))
