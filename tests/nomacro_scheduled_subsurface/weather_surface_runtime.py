"""Revisit the two sealed H day364 failures using their exact physical inputs.

This is a targeted numerical investigation, not historical family admission.
No old checkpoint is rebound to a current build. All cold origins are current.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import time

import implicit_conductivity_runtime as prior

m = prior.m
ROOT = prior.ROOT
PROOF = ROOT / 'integration/nomacro-coverage01'
CASES = {'pulsed': 'PULSED_RAIN', 'hourly': 'HOURLY'}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def inputs(case, out):
    label = CASES[case]
    # The refusal archive preserves worker-normalized output decks. Reuse the
    # sealed original input directory, whose hashes the failure receipt names.
    archive = PROOF / 'BLOCK_H_LAST_TEMPORAL_RAW.tar.xz'
    sealed = json.loads((PROOF / 'BLOCK_H_LAST_TEMPORAL_ARCHIVE.json').read_text())
    assert sha(archive.read_bytes()) == sealed['sha256']
    failed = json.loads((PROOF / ('BLOCK_H_' + label + '364_FAILURE.json')).read_text())
    out.mkdir()
    hashes = {}
    with tarfile.open(archive) as raw:
        directory = '/input-' + ('rain-detailed' if case == 'pulsed' else 'weather-hourly') + '/'
        for name, expected in failed['input_sha256'].items():
            assert Path(name).name == name
            members = [v for v in raw.getmembers() if v.name.endswith(directory + name)]
            assert len(members) <= 1
            data = raw.extractfile(members[0]).read() if members else (ROOT / 'reference/swap-4.3.1/projects/1.hupselbrook' / name).read_bytes()
            assert sha(data) == expected, name
            (out / name).write_bytes(data)
            hashes[name] = expected
    return dict(archive=archive.name, archive_sha256=sealed['sha256'],
                exact_original_input_sha256=hashes,
                prior_accepted_days=failed['committed_days'],
                prior_first_refusal=failed['first_refusal'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=CASES, required=True)
    parser.add_argument('--reference-work', type=Path, required=True)
    parser.add_argument('--build-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    parser.add_argument('--days', type=int, choices=(5, 367, 532, 1096), default=367)
    parser.add_argument('--reuse-build', action='store_true')
    a = parser.parse_args()
    out = a.output.resolve()
    out.mkdir()
    q = dict(status='RUNNING', source_commit=subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        optimization=a.optimization, case=a.case, requested_days=a.days,
        functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED',
        unchanged_water_and_chemical_guard=1e-10)

    def save():
        (out / 'RESULT.json').write_text(json.dumps(q, indent=2) + '\n', encoding='utf8')

    save()
    try:
        q['input_provenance'] = inputs(a.case, out / 'input')
        project = m.e.load(out / 'input')
        build = a.build_root / a.case
        q.update(build_root=str(build), input_root=str(out / 'input'))
        if not a.reuse_build:
            command = [sys.executable, '-B', str(ROOT / 'tools/solute/run_water.py'),
                       '--model', project.model, '--experimental-project', str(out / 'input'),
                       '--reference-work', str(a.reference_work), '--build-only',
                       '--donor-opt', a.optimization, '--kernel-opt', a.optimization,
                       '--output', str(build)]
            started = time.monotonic()
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=180)
            q['build'] = dict(command=command, returncode=result.returncode, seconds=time.monotonic()-started)
            (out / 'build.stdout').write_text(result.stdout, encoding='utf8')
            (out / 'build.stderr').write_text(result.stderr, encoding='utf8')
            save()
            result.check_returncode()
        windows = [(2, 4)]
        if a.days >= 367:
            windows += [(363, 364), (364, 367)]
        if a.days >= 532:
            windows += [(530, 532)]
        if a.days == 1096:
            windows += [(1094, 1096)]
        trajectory = out / 'trajectory'
        q['trajectory'], data = m.trajectory(build, a.reference_work, project, trajectory,
            a.days, {a.days, *({531} if a.days >= 532 else set()), *(v for pair in windows for v in pair)}, 180)
        save()
        q['cold'] = []
        for start, end in windows:
            q['cold'].append(m.own(build, a.reference_work, project, trajectory,
                                 data, start, end, out / ('cold-' + str(start))))
            save()
        q['status'] = 'ACTUAL_EXACT_H_INPUT_CURRENT_WARM_COLD_PASS'
    except Exception as error:
        q.update(status='FAILED', error=repr(error))
        raise
    finally:
        save()
    print(q['status'], a.case, a.optimization, a.days, flush=True)


if __name__ == '__main__':
    main()
