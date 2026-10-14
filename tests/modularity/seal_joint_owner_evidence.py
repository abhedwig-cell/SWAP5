#!/usr/bin/env python3
"""Seal complete fresh joint owner evidence; no F-CI/admission claim."""
from pathlib import Path
import argparse
import base64
import hashlib
import io
import json
import subprocess
import tarfile

from joint_admission_authority import ROOT, verify_source, git
from verify_joint_preservation import validate


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--workspace', type=Path, required=True)
    ap.add_argument('--revision', choices=['v2', 'v3'], default='v2')
    args = ap.parse_args()
    source = verify_source(); workspace = args.workspace.resolve(); data = {}
    prefix_base = 'joint-v3-' if args.revision == 'v3' else 'joint-'
    scopes = [('modular', prefix_base + 'modular'), ('weather', prefix_base + 'weather-owner'),
              ('additional', prefix_base + 'additional')]
    for prefix, folder in scopes:
        directory = workspace / folder
        assert (directory / 'RESULTS.json').is_file(), 'missing terminal result: ' + prefix
        for p in sorted(directory.rglob('*')):
            if p.is_file() and p.suffix in ['.json', '.stdout', '.stderr', '.f90', '.txt', '.py', '.sh', '.log']:
                data[prefix + '/' + str(p.relative_to(directory))] = p.read_bytes()
    for prefix, folder in [('normal-off', prefix_base + 'highest-normal-off'), ('low-air-off', prefix_base + 'highest-low-off'),
                           ('low-air-on', prefix_base + 'highest-low-on')]:
        directory = workspace / folder
        assert (directory / 'RESULTS.json').is_file(), 'missing terminal highest: ' + prefix
        for p in directory.iterdir():
            if p.is_file() and p.suffix in ['.json', '.py', '.f90']:
                data['highest/' + prefix + '/' + p.name] = p.read_bytes()
        builds = [p for p in directory.iterdir() if p.is_dir() and p.name.startswith('ppa-wu05b15-joint-')]
        assert len(builds) == 1
        for p in builds[0].rglob('*'):
            if p.is_file() and (p.suffix in ['.txt', '.err', '.f90'] or p.name == 'sources'):
                data['highest/' + prefix + '/' + str(p.relative_to(builds[0]))] = p.read_bytes()
    for folder in ['joint-guard-negative']:
        for p in (workspace / folder).iterdir():
            if p.is_file():
                data[folder + '/' + p.name] = p.read_bytes()
    for name in ['joint-source-proof.json', 'joint-incumbent-guard-tests.log', 'flopy-pinned-install.log', 'xmipy-pinned-install.log']:
        actual = name.replace('joint-', 'joint-v3-', 1) if args.revision == 'v3' and name.startswith('joint-') else name
        data['controls/' + name] = (workspace / actual).read_bytes()
    # Bind the complete conservative production tree and all original tests and
    # references involved in the mandatory owner routes. The newly authored
    # admission guard itself is governance, not a numerical input.
    prefixes = ['src', 'reference', 'tests/frost', 'tests/fmig431', 'tests/fkt', 'tests/fapp',
                'tests/fpm', 'tests/fgc', 'tests/fvq', 'tests/support']
    dependencies = {}
    for line in git('ls-tree', '-r', 'HEAD', '--', *prefixes).splitlines():
        descriptor, path = line.split('\t', 1); dependencies[path] = descriptor.split()[2]
    for p in ['tests/mc-met01/test_daily_demand_production.inc', 'tests/mc-met01/test_raintb_production.inc',
              'tests/mc-met01/run_daily_demand_source.py', 'tests/mc-met01/run_daily_demand_reference_preservation.py',
              'tests/mc-met01/run_raintb_legacy_owner_preservation.py', 'tests/mc-met01/run_raintb_legacy_pilot.py',
              'tests/modularity/test_raintb_legacy_table.f90', 'tests/modularity/test_low_air_step_policy.f90',
              'tests/modularity/test_low_air_development.f90', 'tests/modularity/mod_low_air_policy_oracle.f90',
              'tests/modularity/low_air_consistent_grid_stubs.f90', 'tests/modularity/run_modular_tests.py']:
        dependencies[p] = git('rev-parse', 'HEAD:' + p)
    manifest = {'source_tree': source['source_tree'], 'reference_tree': git('rev-parse', 'HEAD:reference'),
                'baseline': source['baseline'], 'sealing_head': git('rev-parse', 'HEAD'),
                'dependency_blobs': dependencies, 'highest_cases_inherited': 0,
                'highest_configurations': 24, 'fine_comparisons': 144, 'policy_on_configurations': 12,
                'claim': 'COMPLETE_FRESH_JOINT_OWNER_COUPLING_PREREQUISITE_NOT_FCI_ADMISSION'}
    # Independently retained historical owning OFF output, without replacing
    # or relabeling that reference. Changed physics/tolerance would fail here.
    old = json.loads((ROOT / 'integration/audits/MC_MET01_STATUS.json').read_text())['daily_demand_successor']['owner_evidence']
    raw = base64.b64decode((ROOT / old['path']).read_bytes())
    assert hashlib.sha256(raw).hexdigest() == old['decoded_sha256']
    with tarfile.open(fileobj=io.BytesIO(raw)) as prior:
        for route, scope in [('normal', 'normal-off'), ('low-air', 'low-air-off')]:
            for opt in (0, 2):
                actual = data[f'highest/{scope}/o{opt}/output.txt']
                assert actual == prior.extractfile(f'highest/{route}/o{opt}/output.txt').read(), 'default-OFF historical owning drift'
    manifest['default_off_reference_equivalence'] = {'path': old['path'], 'decoded_sha256': old['decoded_sha256'],
                                                    'actual_full_outputs_byte_equal': True}
    validate(data, manifest, source)
    manifest['member_sha256'] = {name: hashlib.sha256(raw).hexdigest() for name, raw in sorted(data.items())}
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode='w:xz') as archive:
        all_data = {'MANIFEST.json': (json.dumps(manifest, indent=2) + '\n').encode(), **data}
        for name, raw in sorted(all_data.items()):
            item = tarfile.TarInfo(name); item.size = len(raw); item.mode = 0o644; item.mtime = 0
            archive.addfile(item, io.BytesIO(raw))
    compressed = buffer.getvalue(); digest = hashlib.sha256(compressed).hexdigest()
    target = 'integration/audits/evidence/MC_MET01_LOW_AIR_JOINT_OWNER_' + ('V3_' if args.revision == 'v3' else '') + '20261014.tar.xz.b64'
    path = ROOT / target
    assert not path.exists(), 'joint capsule is immutable once created'
    path.write_bytes(base64.encodebytes(compressed))
    status_path = ROOT / 'integration/audits/MC_MET01_LOW_AIR_JOINT_ADMISSION_20261014.json'
    status = json.loads(status_path.read_text())
    status['owner_evidence'] = {'path': target, 'decoded_sha256': digest, 'members': len(data),
                                'highest_configurations': 24, 'policy_on_configurations': 12, 'fine_comparisons': 216}
    status['tested'] = True; status['stage'] = 'COMPLETE_JOINT_OWNER_PASS_MOVING_PRESERVATION_PENDING'
    status['qualified'] = False; status['preserved'] = False; status['admitted'] = False
    status['next_action'] = 'Run full current moving F-CI on canonical-first synthetic merge; recheck owner/canonical and admit only after all gates.'
    status_path.write_text(json.dumps(status, indent=2) + '\n')
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(path.read_bytes()))) as archive:
        for name, raw in all_data.items():
            assert archive.extractfile(name).read() == raw
    print(json.dumps({'capsule': target, 'decoded_sha256': digest, 'raw_members_verified': len(data),
                      'compressed_bytes': len(compressed)}))


if __name__ == '__main__':
    main()
