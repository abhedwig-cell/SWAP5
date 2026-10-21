"""Seal complete native raw artifacts, including NUT endpoints without suffixes."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import tarfile

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--results', type=Path, required=True)
ap.add_argument('--output', type=Path, required=True)
a = ap.parse_args()
root, out = a.results.resolve(), a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
files = {}
for path in sorted(root.rglob('*')):
    if not path.is_file() or path.suffix in {'.o', '.mod', '.smod', '.pyc', '.a'}:
        continue
    raw = path.read_bytes()
    if raw.startswith(b'\x7fELF'):
        continue
    files[str(path.relative_to(root))] = raw
manifest = json.dumps({p: hashlib.sha256(b).hexdigest() for p, b in files.items()}, indent=2, sort_keys=True).encode()
stream = io.BytesIO()
with tarfile.open(fileobj=stream, mode='w:xz', preset=6) as archive:
    for path, raw in {**files, 'MEMBERS.json': manifest}.items():
        item = tarfile.TarInfo(path)
        item.size, item.mtime, item.mode = len(raw), 0, 0o644
        archive.addfile(item, io.BytesIO(raw))
raw = stream.getvalue()
encoded = base64.b64encode(raw)
parts = []
for offset in range(0, len(encoded), 512000):
    name = f'evidence.part-{offset // 512000:03d}.b64'
    (out / name).write_bytes(encoded[offset:offset + 512000])
    parts.append(name)
index = dict(parts=parts, decoded_sha256=hashlib.sha256(raw).hexdigest(), members=len(files),
             decoded_bytes=len(raw), members_sha256=hashlib.sha256(manifest).hexdigest(),
             includes_failed_and_successful_observations=True, compiler_binaries_excluded=True)
(out / 'INDEX.json').write_text(json.dumps(index, indent=2) + '\n')
print(json.dumps(index))
