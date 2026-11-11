"""Real original donor/kernel proof of external daily prepare/discard/accept.

Reuse exact qualified O0/O2 binaries. Never build or rerun a full application.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import threading
import traceback
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--platform', choices=['windows', 'linux'], required=True)
p.add_argument('--workspace', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir()
events, results = [], []
report = {'status': 'RUNNING', 'source_commit': subprocess.check_output(
    ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
    'source_sha256': {name: h.sha(ROOT / name) for name in
                     ['app/hybrid_water/daily_coupling.py', 'research/hybrid-water01/qualify_daily_coupling.py']}}

def physical(row):
    return {k: v for k, v in row.items() if k not in ('column', 'revision', 'coupling')}

def rows(path):
    return [json.loads(line) for line in path.read_text().splitlines()]

def payload(path):
    with zipfile.ZipFile(path) as z:
        return {n: z.read(n) for n in h.CHECKPOINT_FILES}

def fails(fn, exceptions=(ValueError,)):
    try:
        fn()
    except exceptions:
        return
    raise AssertionError('Invalid external transaction accepted')

def root_for(project, opt):
    if a.platform == 'linux':
        return a.workspace / f'generic-{project}-{opt}'
    if project == 'hupsel' and opt == 'O2':
        return a.workspace / 's5-hybrid-hupsel-O2-season-20261111'
    return a.workspace / f's5-hybrid-hupsel-release-{project}-{opt}-20261111'

started, expired, compiler_events = [], [], []
real_start, real_run = h.start_process, subprocess.run
def track_start(*args):
    process, log = real_start(*args)
    started.append(process)
    return process, log
def track_run(command, *args, **kwargs):
    begin = time.monotonic()
    result = real_run(command, *args, **kwargs)
    if isinstance(command, list) and command and command[0] == 'gcc':
        compiler_events.append({'command': list(map(str, command)), 'seconds': time.monotonic()-begin,
                                'returncode': result.returncode})
    return result
def stop():
    expired.append(True)
    for process in started:
        if process.poll() is None:
            process.kill()
h.start_process, subprocess.run = track_start, track_run
timer = threading.Timer(180, stop)
timer.daemon = True
timer.start()
reference = a.workspace / ('generic-reference' if a.platform == 'linux' else 's5-water-integrated-reference')
try:
    for key, project in [('grass', h.GRASSGROWTH), ('hupsel', h.HUPSEL), ('andelst', h.ANDELST)]:
        for opt in ['O0', 'O2']:
            begin = time.monotonic()
            bundle = root_for(key, opt)
            output = a.output / f'{key}-{opt}'
            output.mkdir()
            native = bundle / 'continuous/accepted-column-1-day-2.zip'
            original_hash = h.sha(native)
            model = CoupledDailyColumn(bundle, reference, output / 'external', project, 'column-A',
                                       origin=native, day=2, adopt_native=True)
            base = (model.day, model.revision, model.checkpoint, h.sha(model.checkpoint))
            proposal = model.prepare()
            assert model.day == 2 and model.revision == 0 and h.sha(native) == original_hash
            assert proposal.budget['committed'] is False and proposal.budget['candidate_only'] is True
            assert proposal.t0_day1900 == project.start_clock+2 and proposal.t1_day1900 == project.start_clock+3
            assert not list((output / 'external').glob('accepted-*.zip'))
            fails(model.prepare)
            modified = proposal.budget
            modified['pressure_head_cm'][0] += 1
            assert proposal.budget != modified
            for area in [0, -1, float('nan'), float('inf')]:
                fails(lambda: proposal.bottom_outward_m3(area))
            assert proposal.bottom_outward_m3(100) == proposal.bottom_outward_cm * .01 * 100
            assert proposal.mean_bottom_outward_m_per_s == proposal.bottom_outward_cm * .01 / 86400
            first_payload = payload(model._candidate[3])
            model.discard(proposal)
            assert base == (model.day, model.revision, model.checkpoint, h.sha(model.checkpoint))
            fails(lambda: model.accept(proposal))
            retry = model.prepare()
            assert retry.token != proposal.token
            assert retry.budget == proposal.budget
            assert payload(model._candidate[3]) == first_payload
            # A second independent column owns the same physical origin but a
            # different namespace. Its proposal cannot commit this owner.
            peer = CoupledDailyColumn(bundle, reference, output / 'peer', project, 'column-B',
                                      origin=native, day=2, adopt_native=True)
            other = peer.prepare()
            assert other.budget == retry.budget
            fails(lambda: model.accept(other))
            accepted = model.accept(retry)
            assert model.day == 3 and model.revision == 1 and accepted.exists()
            assert peer.day == 2 and peer.revision == 0
            peer.discard(other)
            fails(lambda: model.accept(retry))
            fails(lambda: model.discard(retry))
            assert h.sha(native) == original_hash
            # Actual fresh-process external recovery and continuing owner agree.
            restored = CoupledDailyColumn(bundle, reference, output / 'restored', project,
                                          'column-A', origin=accepted, day=3)
            uninterrupted = model.prepare()
            resumed = restored.prepare()
            assert uninterrupted.budget == resumed.budget
            assert payload(model._candidate[3]) == payload(restored._candidate[3])
            final = restored.accept(resumed)
            model.discard(uninterrupted)
            assert restored.day == 4 and restored.revision == 2
            expected = rows(bundle / 'continuous/daily.jsonl')[3]
            # Macro cold/restored auxiliary96-byte behavior is separately scoped;
            # physical outcomes and same-origin repeated proposals remain exact.
            with zipfile.ZipFile(final) as z:
                manifest = json.loads(z.read('checkpoint.json'))
            assert physical(manifest['receipt']) == physical(expected)
            assert manifest['receipt']['coupling']['origin_sha256'] == h.sha(accepted)
            assert manifest['receipt']['coupling']['revision'] == 2
            bad_output = output / 'foreign'
            fails(lambda: CoupledDailyColumn(bundle, reference, bad_output, project,
                                             'wrong-column', origin=accepted, day=3))
            assert not bad_output.exists()
            # Fail closed if a durable publication reports failure AFTER replace.
            failed = CoupledDailyColumn(bundle, reference, output / 'sync-failure', project,
                                        'column-A', origin=accepted, day=3)
            f = failed.prepare()
            publish = failed._publisher
            def after_replace(src, dst):
                assert publish(src, dst) == 0
                return 6
            failed._publisher = after_replace
            fails(lambda: failed.accept(f), (OSError,))
            assert failed.day == 3 and failed.revision == 1
            assert (failed.output / 'accepted-column-1-day-4.zip').exists()
            fails(failed.prepare)
            # Explicit disk recovery is required; replacement is never undone.
            recovered = CoupledDailyColumn(bundle, reference, output / 'sync-recovered', project,
                                           'column-A', origin=failed.output/'accepted-column-1-day-4.zip', day=4)
            assert recovered.day == 4 and recovered.revision == 2
            elapsed = time.monotonic()-begin
            events.append({'case': f'{key}-{opt}', 'seconds': elapsed, 'status': 'PASS'})
            results.append({'project': key, 'optimization': opt, 'bundle_build_sha256': h.sha(bundle/'BUILD.json'),
                            'native_origin_sha256': original_hash, 'external_day4_sha256': h.sha(final),
                            'exact_discard_retry_payload': True, 'exact_external_disk_recovery': True,
                            'independent_peer_and_stale_refusal': True, 'post_replace_failure_recovery': True})
            print(key, opt, 'PASS', round(elapsed, 3), flush=True)
    assert not expired, 'Selected180-second wall cap exceeded'
    report.update(status='EXTERNAL_DAILY_THREE_PROJECTS_O0_O2_ACCEPT_DISCARD_RECOVERY_PASS',
                  platform=a.platform, cases=results, events=events,
                  scope='Serial externally accepted original-forcing daily transactions. No new groundwater feedback, forcing physics, peer-backend or whole-science qualification.')
except BaseException:
    report.update(status='FAILED', traceback=traceback.format_exc(), censored=bool(expired))
    raise
finally:
    timer.cancel()
    report['compiler_events'] = compiler_events
    report['events'] = events
    (a.output/'RESULT.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
