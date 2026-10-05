"""Package completed local research, including negatives and postimage scopes.

Usage: python persist_fpe_a28_joint_surface_evidence.py /tmp
Creates repository evidence artifacts, never launches builds/runs or changes gates.
"""
import gzip
import hashlib
import json
import subprocess
import sys
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
scratch = Path(sys.argv[1]).resolve()
out = repo / 'docs/audits/evidence'
stem = 'PPA_WU05A28_JOINT_SURFACE'
files = {}
hashes = {}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def retain(path, key):
    assert path.is_file(), path
    files[key] = path.read_text()
    hashes[key] = {'sha256': digest(path), 'bytes': path.stat().st_size}

for profile in ('joint', 'joint-observed', 'joint-final', 'joint-temporal', 'head-policy'):
    for suffix in ('live.json', 'live.log', 'water.json'):
        p = scratch / f'a28-{profile}-{suffix}'
        retain(p, p.name)
for name in ('joint-build', 'joint-final-build', 'joint-final-generate',
             'joint-temporal-generate', 'head-policy-generate', 'joint-init',
             'joint-unit', 'joint-unit-final', 'joint-docs-check', 'joint-docs-final',
             'joint-docs-check-initial', 'joint-docs-final-initial'):
    p = scratch / f'a28-{name}.log'
    retain(p, p.name)
retain(scratch / 'a28-joint-analysis.json', 'a28-joint-analysis.json')

build_hashes = {}
for name in ('joint-build', 'joint-observed-build', 'joint-final-build',
             'joint-temporal-build', 'head-policy-build'):
    directory = scratch / f'a28-{name}'
    assert directory.is_dir(), directory
    build_hashes[name] = {}
    for p in sorted(directory.iterdir()):
        if p.suffix in ('.o', '.so', '.f90', '.f'):
            build_hashes[name][p.name] = digest(p)
            if p.suffix in ('.f90', '.f'):
                retain(p, f'{name}/{p.name}')

baseline = '76f23dfa75e74f8836aaeb3cce79b24225aa56fd'
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
chronology = subprocess.check_output(['git', 'log', '--reverse', '--format=fuller',
                                     '--stat', baseline + '..' + head], cwd=repo, text=True)
files['local-preregistration-chronology.txt'] = chronology
for commit, path in (
    ('752f0ef0', 'docs/audits/PPA_WU05A28_JOINT_SURFACE_PREREGISTRATION.md'),
    ('1ea66256', 'docs/audits/PPA_WU05A28_JOINT_SURFACE_PREREGISTRATION.md'),
    ('177b796b', 'docs/audits/PPA_WU05A28_JOINT_SURFACE_PREREGISTRATION.md'),
    ('0ef62c00', 'docs/audits/PPA_WU05A28_TEMPORAL_HEAD_POLICY_PREREGISTRATION.md')):
    files[f'prereg/{commit}/{Path(path).name}'] = subprocess.check_output(
        ['git', 'show', f'{commit}:{path}'], cwd=repo, text=True)
for commit in ('39c478c3', '1ea66256', '177b796b', '0ef62c00'):
    for path in ('tests/fpe/build_fpe_a28_coupled_local.py',
                 'tests/fpe/support/mod_fpe_a28_joint_surface_receipt.f90',
                 'tests/fpe/support/mod_fpe_a28_fgc45_rfm_bridge.f90'):
        files[f'postimage/{commit}/{Path(path).name}'] = subprocess.check_output(
            ['git', 'show', f'{commit}:{path}'], cwd=repo, text=True)

mf = scratch / 'a28-mf6-680/mf6.8.0_linux/bin/libmf6.so'
assert digest(mf) == '8589fceef108757f62bb82cb2b0282562172312a75187b70ae7a06f4bd15fbf9'
archive = scratch / 'a28-mf6-680.zip'
assert digest(archive) == '33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e'
payload = {
    'date': '2026-10-05', 'baseline': baseline, 'local_packaging_head': head,
    'decision': 'COUPLED_RFM_BLOCKED', 'new_actions_runs': 0,
    'physical_profile': 'EXTERNAL_SUPPLY_PARTITION_V1_RESEARCH',
    'physical_profile_admitted': False, 'production_execution_changed': False,
    'scope_binding': {
        'joint': '39c478c3 initial four-value guarded service; full build',
        'joint-observed': 'initial build plus88cd8f43 read-only pond bridge;17-window cut',
        'joint-final': '1ea66256 full six-value guarded build, positive pond observer; NO temporal observer',
        'joint-temporal': '177b796b correct generated bounded temporal observer; incremental backend only',
        'head-policy': '0ef62c00 generated head-only1e-3 temporal pilot; incremental backend only',
    },
    'protocol_deviation': '01def1a0 indentation error aborted generation. Shell without set-e compiled previous1ea66256 source. joint-final is valid previous postimage evidence, NOT bounded temporal observation. Fixed177b796b, correct generation and separate joint-temporal run retained.',
    'policies': {'internal_balance_cm': 1e-5, 'nonlinear_head_abs_cm': 1e-6,
                 'nonlinear_head_rel': 1e-6, 'rfm_physical_cm': 1e-12,
                 'transaction_posttrial_mass_cm': 1e-12, 'strict_temporal_head_cm': 1e-5,
                 'temporal_water_channels_cm': 1e-5, 'pilot_temporal_head_cm': .001,
                 'coupling_flux_m_s': 1e-15, 'fd_relative_spread_limit': .001,
                 'substep_cap': 16384, 'anchored_terminal_prototype_admitted': False},
    'common_build_flags': ['A28_FIELD_DEPTH', 'A28_SEPARATE_RFM_TOLERANCE',
                          'A28_PARTITION_AWARE_PREFLIGHT', 'A28_TYPED_STABLE_STORAGE_INCREMENT',
                          'A28_POSTFILL_TERMINAL_PRESSURE_PROTOTYPE', 'A28_ANCHORED_POSTFILL_PROTOTYPE',
                          'A28_BOUNDED_TRANSACTION_PROPOSAL', 'A28_CORRECTOR_DIAGNOSTICS',
                          'A28_RFM_PREPARER_DIAGNOSTICS', 'A28_JOINT_SURFACE'],
    'mf6': {'version': '6.8.0', 'library_sha256': digest(mf), 'archive_sha256': digest(archive)},
    'compiler': subprocess.check_output(['gfortran', '--version'], text=True),
    'build_hashes': build_hashes, 'raw_file_hashes': hashes, 'files': files,
}
packed = gzip.compress(json.dumps(payload, sort_keys=True).encode(), mtime=0)
bundle = out / f'{stem}_EVIDENCE.json.gz'
bundle.write_bytes(packed)
manifest = {'bundle': bundle.name, 'sha256': digest(bundle), 'bytes': len(packed),
            'local_packaging_head': head, 'decision': payload['decision'],
            'raw_logs_trimmed': False, 'production_admitted': False,
            'raw_file_hashes': hashes, 'build_hashes': build_hashes}
(out / f'{stem}_MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
assert json.loads(gzip.decompress(bundle.read_bytes())) == payload
print(json.dumps({k: v for k, v in manifest.items() if k not in ('raw_file_hashes', 'build_hashes')}))
