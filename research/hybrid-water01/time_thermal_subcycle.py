"""Bounded serial ABBA four-day timing and own day2-to4 process restart."""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--baseline', type=Path, required=True)
p.add_argument('--candidate', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
builds = {name: (folder.resolve(), json.loads((folder/'BUILD.json').read_text()))
          for name, folder in [('baseline', a.baseline), ('candidate', a.candidate)]}
for folder, build in builds.values():
    assert build['status'] == 'ORIGINAL_INTERVAL_COMPLETED'
    assert build['profile'] == 'production'
    assert build['grass_numerical_profile'] in ['thermal-control-1e-5C','thermal-subcycle4-1e-5C','thermal-subcycle16-1e-5C']
    assert sha(folder/build['executable']) == build['executable_sha256']
assert builds['baseline'][1]['compiler'] == builds['candidate'][1]['compiler']
assert builds['baseline'][1]['original_inputs_sha256'] == builds['candidate'][1]['original_inputs_sha256']
for source, h in builds['candidate'][1]['source_sha256'].items():
    assert sha(source) == h, source
events = []
physical = ['budget.csv', 'conductive_budget.csv', 'crop.csv', 'state.csv', 'endpoint.csv']


def run(arm, name, end=4, origin=None):
    folder, build = builds[arm]
    case = out/name
    case.mkdir()
    for n, h in build['original_inputs_sha256'].items():
        assert sha(folder/'original-interval'/n) == h
        shutil.copyfile(folder/'original-interval'/n, case/n)
    shutil.copyfile(folder/'original-interval/application.binding', case/'application.binding')
    cmd = [str(folder/build['executable']), str(end), 'retain-step', '100000',
           str(origin) if origin else '',
           {'thermal-subcycle4-1e-5C':'thermal-control-4','thermal-subcycle16-1e-5C':'thermal-control-16'}.get(build['grass_numerical_profile'],'thermal-control')]
    start = time.perf_counter()
    try:
        r = subprocess.run(cmd, cwd=case, capture_output=True, timeout=60,
                           env=dict(os.environ, OMP_NUM_THREADS='1'))
        rc = r.returncode
    except subprocess.TimeoutExpired as e:
        r, rc = e, None
    seconds = time.perf_counter()-start
    (case/'stdout').write_bytes(r.stdout or b'')
    (case/'stderr').write_bytes(r.stderr or b'')
    events.append(dict(arm=arm, name=name, command=cmd, seconds=seconds, returncode=rc))
    (out/'events.json').write_text(json.dumps(events, indent=2)+'\n')
    assert rc == 0, (name, rc)
    return case


runs = {name: run(arm, name) for arm, name in
        [('baseline', 'A1'), ('candidate', 'B1'), ('candidate', 'B2'), ('baseline', 'A2')]}
for one, two in [('A1', 'A2'), ('B1', 'B2')]:
    for name in physical+['checkpoint.bin']:
        assert (runs[one]/name).read_bytes() == (runs[two]/name).read_bytes(), (one, two, name)
cut = run('candidate', 'cut', 2)
resumed = run('candidate', 'resumed', 4, cut/'checkpoint.bin')
for name in ['state.csv', 'endpoint.csv', 'checkpoint.bin']:
    assert (runs['B1']/name).read_bytes() == (resumed/name).read_bytes(), name
for name in ['budget.csv', 'conductive_budget.csv', 'crop.csv']:
    rows = lambda folder: list(csv.DictReader((folder/name).open()))
    assert rows(runs['B1']) == rows(cut)+rows(resumed), name
medians = {arm: statistics.median(e['seconds'] for e in events
            if e['arm'] == arm and e['name'] in runs) for arm in builds}
counts = {arm: sum(int(r['accepted_steps']) for r in csv.DictReader(
          (runs[name]/'budget.csv').open())) for arm, name in [('baseline','A1'),('candidate','B1')]}
result = dict(status='SHORT_ABBA_AND_OWN_RESTART_PASS', events=events,
              numerical_profiles={arm:b['grass_numerical_profile'] for arm,(_,b) in builds.items()},
              median_native_seconds=medians, accepted_steps=counts,
              median_reduction_percent=100*(1-medians['candidate']/medians['baseline']),
              build_manifest_sha256={arm: sha(folder/'BUILD.json') for arm,(folder,_) in builds.items()},
              executable_sha256={arm: b['executable_sha256'] for arm,(_,b) in builds.items()},
              physical_sha256={arm:{n:sha(runs[label]/n) for n in physical} for arm,label in [('baseline','A1'),('candidate','B1')]},
              scope='Windows GNU16.2 O2 production four-day original-input window; each arm deterministic and own candidate restart exact. Different time grids, not byte-identical cross-arm or full science/runtime parity.')
(out/'RESULT.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['status','median_native_seconds','accepted_steps','median_reduction_percent']}))
