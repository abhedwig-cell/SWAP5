#!/usr/bin/env python3
"""Persist fresh temporal diagnostics, retaining failures and excluding binaries."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import tarfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--results', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root, out = args.results.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    members, dispositions = {}, {}
    for directory in sorted(root.glob('temporal-*')):
        if directory.is_file():
            if directory.suffix == '.log':
                members[directory.name] = directory.read_bytes()
            continue
        control = directory/'CONTROL.json'
        if control.exists():
            record = json.loads(control.read_text())
            dispositions[directory.name] = dict(
                status=record.get('status', 'INCOMPLETE_DIAGNOSTIC_SEE_RETAINED_LOG'),
                native_runs=len(record['runs']), failures=[r for r in record['runs'] if r.get('exit') != 0],
                complete_cases=[s['case'] for s in record['summary']],
                driver_sha256=hashlib.sha256((directory/'driver.py').read_bytes()).hexdigest())
        for path in sorted(directory.rglob('*')):
            if path.is_file() and (path.suffix in {'.json', '.csv', '.nml', '.f90', '.py', '.log'}
                                   or path.name in {'stdout', 'stderr', 'restart.bin'}):
                members[str(path.relative_to(root))] = path.read_bytes()
    for path in root.glob('build-*/build-complete.json'):
        members[str(path.relative_to(root))] = path.read_bytes()
    if (root/'PIPELINE.json').exists():
        members['PIPELINE.json'] = (root/'PIPELINE.json').read_bytes()
    manifest = {name: hashlib.sha256(data).hexdigest() for name, data in members.items()}
    metadata = json.dumps(manifest, indent=2, sort_keys=True).encode()
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode='w:xz', preset=6) as archive:
        for name, payload in {**members, 'MEMBERS.json': metadata}.items():
            entry = tarfile.TarInfo(name)
            entry.size, entry.mtime = len(payload), 0
            archive.addfile(entry, io.BytesIO(payload))
    raw = data.getvalue()
    encoded = base64.b64encode(raw)
    parts = []
    for i in range(0, len(encoded), 512000):
        name = f'evidence.part-{i//512000:03d}.b64'
        (out/name).write_bytes(encoded[i:i+512000])
        parts.append(name)
    index = dict(schema=1, encoding='concatenated-base64-xz-tar', parts=parts,
                 decoded_sha256=hashlib.sha256(raw).hexdigest(), decoded_bytes=len(raw),
                 member_count=len(members), members_sha256=hashlib.sha256(metadata).hexdigest(),
                 disposition=dispositions, fresh_reexecution=True,
                 scope='DIAGNOSTICS_ONLY_NO_PRODUCTION_ADMISSION')
    (out/'INDEX.json').write_text(json.dumps(index, indent=2)+'\n')
    restored = base64.b64decode(b''.join((out/p).read_bytes() for p in parts), validate=True)
    if hashlib.sha256(restored).hexdigest() != index['decoded_sha256']:
        raise ValueError('capsule digest mismatch')
    with tarfile.open(fileobj=io.BytesIO(restored), mode='r:xz') as archive:
        for name, expected in manifest.items():
            if hashlib.sha256(archive.extractfile(name).read()).hexdigest() != expected:
                raise ValueError('member digest mismatch: '+name)
    print(json.dumps(dict(member_count=len(members), decoded_bytes=len(raw), verified=True)))


if __name__ == '__main__':
    main()
