#!/usr/bin/env python3
"""Immutable complete-matrix evidence; active runs are never qualification."""
import argparse, base64, hashlib, io, json, pathlib, subprocess, tarfile
ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = 'c591205c5e03f1c96c6488eb53c562265f749556'

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--workspace', required=True, type=pathlib.Path)
    p.add_argument('--name', required=True, choices=['CANDIDATE', 'COLD', 'PAIRED'])
    args = p.parse_args()
    workspace = args.workspace.resolve()
    scopes = ['full-low-air-candidate-r0', 'full-low-air-candidate-diagnosis', 'full-low-air-lazy-diagnosis']
    if args.name in ['COLD', 'PAIRED']:
        scopes += ['full-low-air-baseline-r0', 'full-low-air-candidate-cold-r1']
    if args.name == 'PAIRED':
        scopes += ['full-low-air-baseline-cold-r1', 'full-low-air-candidate-cold-fast-r2']
    files = {}
    for scope in scopes:
        folder = workspace / scope
        report = json.loads((folder / 'RESULTS.json').read_text())
        if report.get('complete') is False:
            raise ValueError('refuse active/partial qualification ' + scope)
        for path in sorted(folder.rglob('*')):
            if path.is_file() and path.suffix in {'.json', '.stdout', '.stderr', '.f90', '.py', '.sh', '.log', '.txt'}:
                files[str(path.relative_to(workspace))] = path.read_bytes()
        for suffix in ['.stdout', '.stderr']:
            path = workspace / (scope + suffix)
            if path.exists():
                files[path.name] = path.read_bytes()
    files['full-low-air-controls.stdout'] = (workspace / 'full-low-air-controls.stdout').read_bytes()
    if args.name in ['COLD', 'PAIRED']:
        for name in ['full-low-air-baseline-recovery.stdout', 'full-low-air-baseline-recovery.stderr', 'full-low-air-PAIRED.json', 'full48-source-proof.stdout', 'full48-docs-check.stdout', 'full48-docs-check.stderr', 'full48-mkdocs.stdout', 'full48-mkdocs.stderr', 'full48-provider-identity.json']:
            files[name] = (workspace / name).read_bytes()
    bundle = workspace / ('LOW_AIR_10X_FULL48_' + args.name + '_EXECUTED.bundle')
    bundle_base = BASE
    if args.name == 'PAIRED':
        bundle_base = json.loads((ROOT / 'integration/audits/evidence/LOW_AIR_10X_FULL48_COLD_20261014_RECEIPT.json').read_text())['executed_local_head']
    subprocess.run(['git', 'bundle', 'create', str(bundle), 'HEAD', '^' + bundle_base], cwd=ROOT, check=True)
    files[bundle.name] = bundle.read_bytes()
    def git(*command):
        return subprocess.check_output(['git', *command], cwd=ROOT, text=True).strip()
    owner = {'baseline': BASE, 'bundle_prerequisite': bundle_base, 'executed_local_head': git('rev-parse', 'HEAD'),
             'source_tree': git('rev-parse', 'HEAD:src'), 'scopes': scopes,
             'recipe_sha256': hashlib.sha256((ROOT / 'tools/performance/low_air_fine_worker_recipe.py').read_bytes()).hexdigest(),
             'recovery_bundle_sha256': hashlib.sha256(files[bundle.name]).hexdigest(),
             'tenfold_proved': False, 'canonical_admission': False,
             'scope': 'Complete original candidate matrix' if args.name == 'CANDIDATE' else 'Complete matched warm native baseline/candidate and complete cold candidate. Parallel build pipeline not yet qualified; full-wall A/B pending.' if args.name == 'COLD' else 'Complete original full cold baseline/candidates plus earlier recovered native A/B; no automatic 10x/admission.'}
    files['OWNER.json'] = (json.dumps(owner, indent=2) + '\n').encode()
    files['INDEX.json'] = (json.dumps({name: hashlib.sha256(data).hexdigest() for name, data in sorted(files.items())}, indent=2) + '\n').encode()
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w:xz') as archive:
        for name, data in sorted(files.items()):
            member = tarfile.TarInfo(name); member.size = len(data); member.mode = 0o644
            archive.addfile(member, io.BytesIO(data))
    raw = stream.getvalue()
    stem = 'LOW_AIR_10X_FULL48_' + args.name + '_20261014'
    destination = ROOT / 'integration/audits/evidence' / (stem + '.tar.xz.b64')
    if destination.exists():
        raise ValueError('immutable seal already exists')
    destination.write_bytes(base64.encodebytes(raw))
    receipt = {'path': str(destination.relative_to(ROOT)), 'decoded_sha256': hashlib.sha256(raw).hexdigest(),
               'indexed_files': len(files)-1, 'compressed_bytes': len(raw), **owner}
    (destination.parent / (stem + '_RECEIPT.json')).write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))
if __name__ == '__main__':
    main()
