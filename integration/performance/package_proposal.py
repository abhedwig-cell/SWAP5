"""Archive actual native proof and commands, excluding compiler outputs/binaries."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import tarfile


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--results', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    root, out = args.results.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    files = {}
    extensions = {'.json', '.csv', '.nml', '.f90', '.py', '.log', '.stdout', '.stderr', '.bin', '.inc', '.c'}
    for p in sorted(root.rglob('*')):
        if p.is_file() and (p.suffix in extensions or p.name in {'stdout', 'stderr'} or p.name.startswith('control.')):
            files[str(p.relative_to(root))] = p.read_bytes()
    manifest = json.dumps({p: hashlib.sha256(v).hexdigest() for p, v in files.items()}, indent=2, sort_keys=True).encode()
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode='w:xz', preset=6) as archive:
        for p, raw in {**files, 'MEMBERS.json': manifest}.items():
            info = tarfile.TarInfo(p)
            info.size = len(raw)
            info.mtime = 0
            archive.addfile(info, io.BytesIO(raw))
    raw = data.getvalue()
    encoded = base64.b64encode(raw)
    parts = []
    for i in range(0, len(encoded), 512000):
        name = f'evidence.part-{i//512000:03d}.b64'
        (out/name).write_bytes(encoded[i:i+512000])
        parts.append(name)
    report = dict(parts=parts, encoding='concatenated-base64-xz-tar', decoded_sha256=hashlib.sha256(raw).hexdigest(),
                  decoded_bytes=len(raw), members=len(files), members_sha256=hashlib.sha256(manifest).hexdigest(),
                  includes_failed_and_successful_observations=True)
    (out/'INDEX.json').write_text(json.dumps(report, indent=2)+'\n')
    assert base64.b64decode(b''.join((out/p).read_bytes() for p in parts), validate=True) == raw
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
