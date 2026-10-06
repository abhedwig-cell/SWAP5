#!/usr/bin/env python3
"""Qualify the preregistered source only after every whole physical gate finishes."""
from pathlib import Path
import argparse
import gzip
import hashlib
import json
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = '636e782080abdd2c0366f96317c4f59e8170dc53'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--archive', required=True)
    parser.add_argument('--record', required=True)
    args = parser.parse_args()
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD:src'], cwd=ROOT, text=True).strip() == SOURCE
    names = ('compile', 'source', 'component-preservation', 'additional',
             'positive-preservation', 'normal-runtime', 'low-runtime',
             'incumbent-normal', 'incumbent-low_air', 'external-preservation',
             'scientific', 'exact', 'jarvis', 'jarvis-dispersion', 'walsum',
             'walsum-dispersion', 'remaining')
    records = {}
    for name in names:
        path = Path(f'/tmp/frost-b19-{name}.json')
        assert path.is_file(), f'Incomplete required gate: {name}'
        records[name] = json.loads(path.read_text())
    assert records['compile']['sources'] == 177
    source = records['source']
    assert (source['cases_per_optimization'], source['accepted'], source['unavailable']) == (660, 412, 248)
    assert source['O0_O2_byte_identity'] is True
    component = records['component-preservation']
    assert (component['accepted_component_cases'], component['unavailable_original_tiny_scalar_cases'],
            component['invalid_domain_cases'], component['actual_reference_boundary_cases']) == (3240, 1296, 32, 2)
    for key in ('typed_O0_O2_byte_identity', 'reference_O0_O2_byte_identity',
                'actual_B17_corrected_reference_output_identity'):
        assert component[key] is True
    additional = records['additional']
    assert (additional['committed_native_calls_per_optimization'], additional['held_calls_per_optimization'],
            additional['invalid_application_cases_per_optimization']) == (756, 84, 28)
    assert additional['O0_O2_byte_identity'] is True
    assert records['positive-preservation']['O0_O2_byte_identity'] is True
    assert len(records['positive-preservation']['outputs']) == 4
    maxima = {'head_cm': 0.0, 'temperature_c': 0.0, 'mass': 0.0}
    runtime_receipts = 0
    for name, route, trajectories, steps in (
            ('normal-runtime', 'normal', 12, 8192), ('low-runtime', 'low', 36, 65536)):
        record = records[name]
        assert record['production_source'] == SOURCE and record['route'] == route
        assert record['whole_module_sources'] == 177 and record['whole_cases'] == 12
        assert record['primary_trajectories_per_optimization'] == trajectories
        assert record['reference_steps'] == steps and record['O0_O2_stdout_byte_identity'] is True
        assert set(record['case_receipts']) == {f'o{opt}/family-{family}' for opt in (0, 2) for family in range(1, 7)}
        for key, receipt in record['case_receipts'].items():
            assert receipt['complete_case'] is True and receipt['exit_code'] == 0
            output = Path(record['build']) / (key + '.txt')
            content = output.read_bytes()
            assert hashlib.sha256(content).hexdigest() == receipt['stdout_sha256']
            text = content.decode()
            assert text.count('B19_RUNTIME_PASS ') == 1
            assert text.count('B19_PRIMARY ') == trajectories // 6
            assert text.count('B19_FINE ') == trajectories // 6
            errors = re.findall(r'B19_FINE steps=\d+ head_cm=\s*(\S+) temperature_c=\s*(\S+)', text)
            masses = re.findall(r'B19_PRIMARY[^\n]+ mass=\s*(\S+)', text)
            assert len(errors) == len(masses) == trajectories // 6
            for head, temperature in errors:
                head, temperature = float(head), float(temperature)
                assert 0 <= head <= 1e-6 and 0 <= temperature <= 1e-4
                maxima['head_cm'] = max(maxima['head_cm'], head)
                maxima['temperature_c'] = max(maxima['temperature_c'], temperature)
            for mass in masses:
                mass = float(mass)
                assert 0 <= mass <= 1e-12
                maxima['mass'] = max(maxima['mass'], mass)
            runtime_receipts += 1
        for family in range(1, 7):
            assert (Path(record['build']) / f'o0/family-{family}.txt').read_bytes() == (Path(record['build']) / f'o2/family-{family}.txt').read_bytes()
    incumbent_receipts = 0
    for name, expected in (('incumbent-normal', 32), ('incumbent-low_air', 48)):
        record = records[name]
        assert record['production_source'] == SOURCE and record['whole_module_sources'] == 177
        assert len(record['receipts']) == expected
        for receipt in record['receipts'].values():
            assert receipt['complete_case'] is True and receipt['process_exit_code'] == 0
            assert receipt['production_source_tree'] == SOURCE
            family = f"-family-{receipt['family']}" if receipt['family'] else ''
            output = Path(f"/tmp/frost-b19-preserve-{record['route']}-{receipt['program']}-o{receipt['optimization']}{family}.log")
            assert hashlib.sha256(output.read_bytes()).hexdigest() == receipt['stdout_sha256']
        programs = {receipt['program'] for receipt in record['receipts'].values()}
        for program in programs:
            outputs = [Path(f"/tmp/frost-b19-preserve-{record['route']}-{program}-o{opt}.log").read_bytes() for opt in (0, 2)]
            assert outputs[0] == outputs[1]
            match = re.match(r'ppa_wu05b(12|13|14|15)_', program)
            if match:
                for opt in (0, 2):
                    original = Path(f"/tmp/ppa-wu05b{match[1]}-{record['route'].replace('_', '-')}-runtime/o{opt}/output.txt")
                    assert outputs[opt // 2] == original.read_bytes()
        incumbent_receipts += expected
    assert records['scientific']['cases_per_opt'] == 1507
    assert records['scientific']['O0_O2_identical'] is True
    assert set(records['external-preservation']['programs']) == {'FAPP09', 'VQ128', 'VQ73', 'VQ74'}
    assert all(p['O0_O2_stdout_identical'] is True for p in records['external-preservation']['programs'].values())
    remaining = records['remaining']['results']
    assert set(remaining) == {'scientific', 'exact', 'external-preservation', 'jarvis',
                            'jarvis-dispersion', 'walsum', 'walsum-dispersion',
                            'canonical-preservation', 'docs', 'mkdocs'}
    assert all(r['complete'] is True and r['exit_code'] == 0 and r['production_source'] == SOURCE for r in remaining.values())
    # The snapshot rechecks current source hashes and complete receipt/output hashes.
    # It never includes output from a still-running physical case.
    with tempfile.TemporaryDirectory(prefix='ppa-wu05b19-final-pack-') as directory:
        snapshot_path = Path(directory) / 'complete.json.gz'
        subprocess.run([sys.executable, str(ROOT / 'tests/frost/snapshot_ppa_wu05b19_completed.py'),
                        '--output', str(snapshot_path)], check=True)
        snapshot = json.loads(gzip.decompress(snapshot_path.read_bytes()))
    assert len(snapshot['completed_records']) == len(names)
    snapshot.update(status='LOCAL_COMPLETE_BOUNDED_RUNTIME_QUALIFICATION_NOT_CANONICAL_ADMISSION',
                    qualification=True, admitted=False, aggregate_frost_migration_complete=False,
                    pending='Exact live canonical reconciliation, proposed/actual merge verification, admission and closeout.',
                    runtime_receipts=runtime_receipts, incumbent_receipts=incumbent_receipts,
                    maximum_runtime_reference_errors=maxima)
    archive = Path(args.archive)
    archive.write_bytes(gzip.compress(json.dumps(snapshot, sort_keys=True).encode(), mtime=0))
    summary = {key: snapshot[key] for key in ('work_unit', 'status', 'production_source', 'qualification',
               'admitted', 'aggregate_frost_migration_complete', 'runtime_receipts', 'incumbent_receipts',
               'maximum_runtime_reference_errors', 'pending')}
    summary['evidence'] = {'path': str(archive), 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
                           'bytes': archive.stat().st_size, 'manifest_files': len(snapshot['manifest'])}
    Path(args.record).write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
