#!/usr/bin/env python3
"""Seal terminal moving evidence without exporting the private receipt key."""
from pathlib import Path
import argparse
import base64
import hashlib
import io
import json
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execution', type=Path, required=True)
    parser.add_argument('--checkout', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    execution = args.execution.resolve()
    result = json.loads((execution / 'RESULTS.json').read_text())
    if result['exit'] != 0 or result['status'] != 'PASS' or not result['preserved']:
        raise ValueError('moving execution not terminal PASS')
    if result['first_parent'] != result['source']['baseline']:
        raise ValueError('moving execution not canonical-first')
    files = {}
    for name in ['stdout', 'stderr', 'PROGRESS.json', 'RESULTS.json']:
        files[name] = (execution / name).read_bytes()
    for name in ['stdout', 'stderr']:
        if digest(files[name]) != result[name + '_sha256']:
            raise ValueError('moving raw log drift: ' + name)
    if b'FCI_CANONICAL_LINEAGE_AWARE_GATE PASS' not in files['stdout']:
        raise ValueError('moving terminal marker absent')
    # SHADOW always executes. Unqualified receipt profiles fall back to RUN;
    # their absence is never represented as a signed receipt or inherited PASS.
    receipts = execution / 'receipts'
    if receipts.exists():
        for path in sorted(receipts.rglob('*')):
            if path.is_file() and path.suffix in {'.json', '.stdout', '.stderr', '.log'}:
                files['receipts/' + str(path.relative_to(receipts))] = path.read_bytes()
    head = result['head']
    def git(*arguments):
        return subprocess.check_output(['git', *arguments], cwd=ROOT).decode().strip()
    if git('rev-parse', head + ':src') != result['source']['source_tree']:
        raise ValueError('executed source tree mismatch')
    inputs = {}
    for line in git('ls-tree', '-r', head, '--', 'src', 'tests', 'tools', 'reference', 'ref').splitlines():
        metadata, path = line.split('\t', 1)
        mode, kind, blob = metadata.split()
        if kind == 'blob':
            inputs[path] = {'mode': mode, 'git_blob': blob}
    bundle = execution / 'EXECUTED.bundle'
    actual_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=args.checkout, text=True).strip()
    if actual_head != head:
        raise ValueError('executed checkout HEAD changed')
    subprocess.run(['git', 'bundle', 'create', str(bundle), 'HEAD', '^' + result['first_parent']], cwd=args.checkout, check=True)
    subprocess.run(['git', 'bundle', 'verify', str(bundle)], cwd=ROOT, check=True, capture_output=True)
    files['EXECUTED.bundle'] = bundle.read_bytes()
    files['OWNER.json'] = (json.dumps({'executed_head': head, 'first_parent': result['first_parent'],
        'source_tree': result['source']['source_tree'], 'inputs': inputs,
        'claim': 'COMPLETE_MOVING_PRESERVATION_NOT_CANONICAL_ADMISSION',
        'private_receipt_key_exported': False, 'receipt_mode': result['mode'],
        'bundle_sha256': digest(files['EXECUTED.bundle'])}, indent=2) + '\n').encode()
    index = {name: digest(raw) for name, raw in sorted(files.items())}
    files['INDEX.json'] = (json.dumps(index, indent=2) + '\n').encode()
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w:xz') as archive:
        for name, raw in sorted(files.items()):
            member = tarfile.TarInfo(name); member.size = len(raw); member.mode = 0o644
            archive.addfile(member, io.BytesIO(raw))
    raw = stream.getvalue()
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as archive:
        for name, expected in index.items():
            if digest(archive.extractfile(name).read()) != expected:
                raise ValueError('moving seal roundtrip mismatch')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('xb') as target:
        target.write(base64.encodebytes(raw))
    receipt = {'path': str(args.output), 'decoded_sha256': digest(raw), 'members': len(files),
               'compressed_bytes': len(raw), 'wall_seconds': result['wall_seconds'],
               'executed_head': head, 'source_tree': result['source']['source_tree'],
               'preserved': True, 'admitted': False, 'private_key_exported': False}
    args.output.with_suffix('.receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
