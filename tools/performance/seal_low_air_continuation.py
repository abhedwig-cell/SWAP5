#!/usr/bin/env python3
"""Preserve LOW-AIR-10X raw continuation evidence and executed Git recovery."""
import argparse, base64, hashlib, io, json, pathlib, subprocess, tarfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = 'c591205c5e03f1c96c6488eb53c562265f749556'
PRESERVED = '32417c6186aa565f269f8f65c01587c13e2a5769'
# These opt-in feedback/performance files are not inputs of the moving F-CI.
FCI_EXCLUDED = {
    'tests/modularity/test_low_air_development.f90',
    'tools/performance/run_low_air_ab.py',
    'tools/performance/run_low_air_final_candidate.py',
}

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', type=pathlib.Path, required=True)
    args = parser.parse_args()
    workspace = args.workspace.resolve()
    files = {}
    scopes = [
        'moving-qualified', 'moving-final', 'moving-canonical',
        'fine-workspace-ab', 'fine-workspace-direct-ab',
        'workspace-full-o0', 'workspace-full-o2',
        'workspace-controls-o0', 'workspace-controls-o2',
        'direct-workspace-full-o0', 'direct-workspace-full-o2',
        'direct-workspace-controls-o0', 'direct-workspace-controls-o2',
        'physical-workspace-feedback', 'final-workspace-qualification',
    ]
    extensions = {'.json', '.stdout', '.stderr', '.log', '.txt', '.f90', '.py', '.sh'}
    for scope in scopes:
        folder = workspace / scope
        if not folder.is_dir():
            raise ValueError('missing evidence ' + scope)
        for path in sorted(folder.rglob('*')):
            if not path.is_file() or 'git' in path.relative_to(folder).parts:
                continue
            if path.suffix in extensions or path.name in {'stdout', 'stderr', 'sources'}:
                files[str(path.relative_to(workspace))] = path.read_bytes()
        for suffix in ['.stdout', '.stderr']:
            path = workspace / (scope + suffix)
            if path.exists():
                files[path.name] = path.read_bytes()
    files['run_moving_low_air.py'] = (workspace / 'run_moving_low_air.py').read_bytes()
    bundle = workspace / 'LOW_AIR_10X_CONTINUATION_EXECUTED.bundle'
    subprocess.run(['git', 'bundle', 'create', str(bundle), 'HEAD', '^' + BASE], cwd=ROOT, check=True)
    files[bundle.name] = bundle.read_bytes()
    preserved_inputs = {
        line.split('\t')[1]: line.split()[2]
        for line in git('ls-tree', '-r', PRESERVED, '--', 'src', 'tests', 'tools', 'ref').splitlines()
        if line.split('\t')[1] not in FCI_EXCLUDED
    }
    owner = {
        'baseline': BASE, 'executed_local_head': git('rev-parse', 'HEAD'),
        'source_tree': git('rev-parse', 'HEAD:src'),
        'preserved_commit': PRESERVED, 'preserved_input_blobs': preserved_inputs,
        'preservation_excluded_paths': sorted(FCI_EXCLUDED),
        'exclusion_reason': 'Opt-in development fixture and performance controllers were not invoked by moving F-CI. Their fresh executions are separately sealed.',
        'recipe_sha256': hashlib.sha256((ROOT / 'tools/performance/low_air_fine_worker_recipe.py').read_bytes()).hexdigest(),
        'recovery_bundle_sha256': hashlib.sha256(files[bundle.name]).hexdigest(),
        'scope': 'Full moving preservation and complete original highest workspace science; not 48-program cold end-to-end A/B or canonical admission.',
    }
    files['OWNER.json'] = (json.dumps(owner, indent=2) + '\n').encode()
    files['INDEX.json'] = (json.dumps({name: hashlib.sha256(data).hexdigest() for name, data in sorted(files.items())}, indent=2) + '\n').encode()
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w:xz') as archive:
        for name, data in sorted(files.items()):
            member = tarfile.TarInfo(name)
            member.size = len(data)
            member.mode = 0o644
            archive.addfile(member, io.BytesIO(data))
    raw = stream.getvalue()
    destination = ROOT / 'integration/audits/evidence/LOW_AIR_10X_CONTINUATION_20261014.tar.xz.b64'
    if destination.exists():
        raise ValueError('immutable seal already exists')
    destination.write_bytes(base64.encodebytes(raw))
    receipt = {
        'path': str(destination.relative_to(ROOT)),
        'decoded_sha256': hashlib.sha256(raw).hexdigest(),
        'indexed_files': len(files) - 1, 'compressed_bytes': len(raw),
        'recovery_bundle_sha256': owner['recovery_bundle_sha256'],
        'scope': owner['scope'],
    }
    (destination.parent / 'LOW_AIR_10X_CONTINUATION_20261014_RECEIPT.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))

if __name__ == '__main__':
    main()
