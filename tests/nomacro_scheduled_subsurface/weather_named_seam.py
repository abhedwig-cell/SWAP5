"""Two-day named native seam after the shared weather/canonical composition.

Only functional source, ledger and restart comparisons are selected. No timing
comparison, benchmark or repeat of already qualified named full periods.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import implicit_conductivity_runtime as prior

m = prior.m
ROOT = prior.ROOT


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work', 'output', 'build-root'):
        p.add_argument('--'+name, type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    p.add_argument('--platform', choices=('Windows', 'Ubuntu'), required=True)
    a = p.parse_args();a.output.mkdir()
    proof = ROOT/'integration/f-ci/saltfarm-guard-cost05'
    record = json.loads((proof/'COMPOSITION_QUALIFICATION.json').read_text())['archives'][a.platform]
    archive = proof/record['archive']
    assert m.sha(archive) == record['sha256']
    q = dict(status='RUNNING', source_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
             optimization=a.optimization, platform=a.platform, actual_days=2, full_periods_repeated=0, calls={})

    def save():
        (a.output/'RESULT.json').write_text(json.dumps(q, indent=2)+'\n', encoding='utf8')

    project = m.h.SALTFARM
    command = [sys.executable, '-B', str(ROOT/'tools/solute/run_water.py'), '--model', project.model,
               '--no-macro-release', '--reference-work', str(a.reference_work)]

    def call(label, extra):
        r = subprocess.run([*command, *map(str, extra)], cwd=ROOT, capture_output=True, text=True, timeout=180)
        (a.output/(label+'.stdout')).write_text(r.stdout, encoding='utf8')
        (a.output/(label+'.stderr')).write_text(r.stderr, encoding='utf8')
        q['calls'][label] = dict(command=[*command, *map(str, extra)], returncode=r.returncode)
        save();r.check_returncode()

    save()
    try:
        with zipfile.ZipFile(archive) as gold:
            prefix = 'qualified-'+a.optimization+'/'
            original = json.loads(gold.read(prefix+'BUILD.json'))
            sources = {n[len(prefix):]:gold.read(n) for n in gold.namelist()
                       if n.startswith(prefix) and '/' not in n[len(prefix):] and n.endswith('.f90')}
            rows = [json.loads(v) for v in gold.read('accept-'+a.optimization+'/full/daily.jsonl').splitlines()]
        call('build', ['--build-only', '--donor-opt', a.optimization, '--kernel-opt', a.optimization, '--output', a.build_root])
        meta, _ = m.validate_bundle(a.build_root, a.reference_work, project)
        assert {f.name:f.read_bytes() for f in a.build_root.glob('*.f90')} == sources
        assert meta['inputs'] == original['inputs'] and meta['identity']['kernel_sources'] == original['identity']['kernel_sources']
        assert meta['identity'].get('direct_day_kernel') is not None
        for label, cut in [('warm', 1), ('warm-endpoint', 2)]:
            call(label, ['--build-bundle', a.build_root, '--days', 2, '--checkpoint-at', cut, '--output', a.output/label])
        origin = a.output/'warm/accepted-column-1-day-1.zip';digest = m.sha(origin)
        call('cold', ['--build-bundle', a.build_root, '--days', 2, '--checkpoint-at', 2,
                      '--restart', origin, '--restart-day', 1, '--output', a.output/'cold'])
        warm, cold, endpoint = (m.rows(a.output/n) for n in ('warm', 'cold', 'warm-endpoint'))
        for data in (warm, cold, endpoint):m.check(data)
        assert m.physical(warm) == m.physical(endpoint) == m.physical(rows[:2])
        assert m.physical(cold) == m.physical(warm[1:2]) and m.sha(origin) == digest
        with zipfile.ZipFile(a.output/'cold/accepted-column-1-day-2.zip') as x, zipfile.ZipFile(a.output/'warm-endpoint/accepted-column-1-day-2.zip') as y:
            assert all(x.read(n) == y.read(n) for n in ('result.end', 'macro.bin'))
        q.update(status='ACTUAL_NAMED_SHARED_TRANSPORT_PHYSICAL_COMPLETE_NATIVE_SEAM_PASS',
                 exact_generated_fortran=True, exact_inputs=True, exact_prior_physical=True,
                 exact_complete_native_replay=True, origin_unchanged=True)
    except Exception as error:
        q.update(status='FAILED', error=repr(error));raise
    finally:
        save()
    print(q['status'], a.optimization, flush=True)


if __name__ == '__main__':
    main()
