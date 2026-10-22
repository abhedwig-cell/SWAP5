"""Seal the bounded surface-work observation and current application preservation.

No source-owner override or admission is performed by this assessor.
"""
import argparse
import base64
import csv
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--runs-root', type=Path, default=Path('/tmp'))
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    runs = args.runs_root.resolve()
    files = {}
    paths = {
        'probe-1x': 'perf01-surface-followup-1x-bound',
        'probe-4x': 'perf01-surface-followup-4x-heads',
        'column': 'perf01-surface-column-controls',
        'water': 'perf01-surface-water-controls',
        'daily': 'perf01-surface-daily-controls',
        'build-O0': 'perf01-surface-incumbent-O0',
        'build-O2': 'perf01-surface-incumbent-O2',
        'reader-O0': 'perf01-surface-daily-O0',
        'reader-O2': 'perf01-surface-daily-O2',
        'reference-1x': 'wet4-comparison-1x-1e3',
        'reference-4x': 'wet4-review-20261022-fallback-1e3',
    }
    for label, folder in paths.items():
        for path in sorted((runs / folder).rglob('*')):
            if path.is_file() and (path.suffix in {'.json', '.csv', '.nml', '.stdout', '.stderr',
                                                   '.bin', '.swp', '.met', '.f90', '.999', '.log'}
                                   or path.name in {'stdout', 'stderr'}):
                files[label + '/' + str(path.relative_to(runs / folder))] = path.read_bytes()
    files['owner-guard.log'] = (runs / 'perf01-surface-owner-guard.log').read_bytes()
    assert b'foreign daily scientific delta' in files['owner-guard.log']
    inputs = {}
    builds = {}
    for opt in ['O0', 'O2']:
        report = json.loads(files[f'build-{opt}/build-complete.json'])
        assert report['status'] == 'BUILT' and report['provider_count'] == 190
        assert all(e['returncode'] == 0 for e in report['events'])
        for path, expected in report['input_sha256'].items():
            assert digest((ROOT / path).read_bytes()) == expected, path
            inputs[path] = expected
        assert digest((runs / paths['build-' + opt] / 'swap5_solute_column').read_bytes()) == report['executable_sha256']
        builds[opt] = {'providers': report['provider_count'], 'original_input_providers': report['original_input_provider_count'],
                       'seconds': sum(e['seconds'] for e in report['events']),
                       'executable_sha256': report['executable_sha256']}
    controls = {}
    for label in ['column', 'water', 'daily']:
        report = json.loads(files[label + '/result.json'])
        assert report['status'] == 'PASS'
        if label != 'column':
            assert all((e['returncode'] == 0) == e['expected_success'] for e in report['events']), label
        else:
            # This unchanged owning runner asserts every exit before publishing
            # PASS; unlike the two newer runners its log omits expected_success.
            from collections import Counter
            assert Counter(e['returncode'] for e in report['events']) == {0: 36, 1: 46, 77: 2, 78: 2}
        controls[label] = {'events': len(report['events']), 'status': report['status']}
    assert controls['column']['events'] == 86
    assert controls['daily']['events'] == 72
    water = json.loads(files['water/result.json'])
    assert (water['native_mapping_cases'], water['independent_process_restarts'], water['invalid_cases']) == (12, 12, 60)

    # Independent immutable incumbent outputs, never replacement source hashes.
    status = json.loads((ROOT / 'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text())
    prior = status['swp_water_successor']['evidence']
    prior_raw = base64.b64decode((ROOT / prior['path']).read_bytes())
    assert digest(prior_raw) == prior['decoded_sha256']
    with tarfile.open(fileobj=io.BytesIO(prior_raw)) as archive:
        old = {m.name: archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}
    physical = []
    for path, raw in old.items():
        if not path.startswith('qualified-incumbent/') or Path(path).name not in {'state.csv', 'budget.csv', 'endpoint.csv', 'restart.bin'}:
            continue
        target = 'column/' + path.removeprefix('qualified-incumbent/')
        # Temporary rejected-generation names differ between independent runs.
        if '.pending-' in target:
            continue
        assert target in files and files[target] == raw, target
        physical.append(target)
    assert len(physical) >= 152, len(physical)

    observations = {}
    for label in ['1x', '4x']:
        report = json.loads(files[f'probe-{label}/RESULT.json'])
        assert report['status'] == 'OBSERVED_WORK_PHYSICAL_AND_WORK_EXACT'
        assert report['physical_and_receipt_identity'] and report['tolerance_cm'] == .001
        original_rows = list(csv.DictReader(io.StringIO(files[f'reference-{label}/daily.csv'].decode())))
        new_rows = list(csv.DictReader(io.StringIO(files[f'probe-{label}/native/daily.csv'].decode())))
        def no_clock(rows):
            return [{k: v for k, v in row.items() if k != 'core_cpu_s'} for row in rows]
        assert no_clock(original_rows) == no_clock(new_rows)
        clean = b''.join(row for row in files[f'probe-{label}/native/stdout'].splitlines(keepends=True)
                         if not row.startswith(b'SURFACE_WORK'))
        assert clean == files[f'reference-{label}/stdout']
        groups = report['groups']
        assert sum(int(r['headcalc_calls']) for r in original_rows) == groups['all']['calls']
        assert groups['all']['calls'] == groups['switching']['calls'] + groups['no_switch']['calls']
        observations[label] = {'groups': groups, 'days': report['days'],
                               'transaction_work': {k: sum(int(r[k]) for r in original_rows)
                                                    for k in ['accepted', 'headcalc_calls', 'temporal_rejections']},
                               'original_user_cpu_seconds': json.loads(files[f'reference-{label}/RESULT.json'])['user_seconds']}
        # Retain the exact executed observer source even when an earlier observation
        # used the same counters without the later extra head columns.
        ref = report['baseline']
        script = subprocess.check_output(['git', 'show', ref + ':benchmarks/performance/probe_perf01_surface_work.py'], cwd=ROOT)
        assert digest(script) == report['probe_script_sha256']
        files[f'executed-scripts/probe-{label}.py'] = script

    # Additional localization from the extended 4x trace, excluding any diagnostic
    # state change: these entry heads are observations, not a new acceptance rule.
    failed = []
    for line in files['probe-4x/native/stdout'].decode().splitlines():
        if line.startswith('SURFACE_WORK'):
            values = line.split()[1:]
            if int(values[12]):
                failed.append([float(x) for x in values[:7]])
    assert len(failed) == observations['4x']['groups']['failed']['calls']
    localization = {str(width): {'top_entry_within_cm': sum(abs(r[1]) <= width for r in failed),
                                'bottom_entry_within_cm': sum(abs(r[4]) <= width for r in failed)}
                    for width in [.01, .1, 1., 10.]}
    for path in ['benchmarks/performance/probe_perf01_surface_work.py',
                 'benchmarks/performance/assess_perf01_surface_followup.py',
                 'src/legacy/b1_10_port/headcalc.f90',
                 'src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90',
                 'tests/nut-sol/test_column_input.py', 'tests/nut-sol/qualify_swp_water.py',
                 'tests/nut-sol/qualify_swp_daily.py']:
        files['current-source/' + path] = (ROOT / path).read_bytes()
    result = {'status': 'BOUNDED_OBSERVATION_AND_INCUMBENT_PRESERVATION_PASS_ADMISSION_BLOCKED',
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'production_changed_in_followup': False, 'canonically_admitted': False,
              'builds': builds, 'current_inputs': inputs, 'controls': controls,
              'predecessor_capsule_sha256': digest(prior_raw),
              'exact_incumbent_physical_files': physical, 'observations': observations,
              'failed_entry_head_localization_cm': localization,
              'interpretation': 'Within-solve regime switching is rare; rejected Newton work dominates this observation. Association alone does not identify the underlying cause or a portable speedup.',
              'admission_blocker': 'Existing SWP daily source authority rejects the unregistered eight-file production successor. Original owner assertions were not changed or bypassed.'}
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.with_suffix('.json').write_text(json.dumps(result, indent=2) + '\n')
    files['ASSESSMENT.json'] = output.with_suffix('.json').read_bytes()
    files['MANIFEST.json'] = (json.dumps({p: digest(raw) for p, raw in sorted(files.items())}, indent=2) + '\n').encode()
    archive = output.with_suffix('.tar.xz')
    with tarfile.open(archive, 'w:xz') as tar:
        for path, raw in sorted(files.items()):
            member = tarfile.TarInfo(path)
            member.size = len(raw)
            member.mode = 0o644
            tar.addfile(member, io.BytesIO(raw))
    with tarfile.open(archive, 'r:xz') as tar:
        assert len(tar.getmembers()) == len(files)
        for member in tar.getmembers():
            assert tar.extractfile(member).read() == files[member.name]
    index = {'path': str(archive.relative_to(ROOT)), 'bytes': archive.stat().st_size,
             'sha256': digest(archive.read_bytes()), 'members': len(files)}
    output.with_suffix('.index.json').write_text(json.dumps(index, indent=2) + '\n')
    print(json.dumps({'status': result['status'], 'exact_incumbent_files': len(physical),
                      'controls': controls, 'evidence': index, 'localization': localization}))


if __name__ == '__main__':
    main()
