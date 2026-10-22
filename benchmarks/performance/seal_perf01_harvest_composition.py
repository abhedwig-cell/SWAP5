"""Seal fresh harvest streams over byte-identical current cold/thermal builds."""
import hashlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
STEM = ROOT / 'benchmarks/performance/PERF01_HARVEST_COMPOSITION_20261022'
owner = runpy.run_path(str(ROOT / 'integration/audits/verify_nut_harvest_output.py'))
files = owner['capsule']()
for prefix in ['cold', 'thermal', 'harvest']:
    files = {p: v for p, v in files.items() if not p.startswith(prefix + '/')}
    directory = Path('/tmp/perf01-compose2-nut-' + prefix)
    for path in sorted(directory.rglob('*')):
        if not path.is_file() or path.suffix in ['.o', '.mod', '.a', '.so']:
            continue
        raw = path.read_bytes()
        if raw.startswith(b'\x7fELF'):
            continue
        files[prefix + '/' + str(path.relative_to(directory))] = raw
for name, path in [('FROZEN_LATEST.json', '/tmp/perf01-canonical0be-owner-result.json'),
                   ('FROZEN_LATEST_CONTROLS.json', '/tmp/perf01-canonical0be-owner-controls.json')]:
    files[name] = Path(path).read_bytes()
result = owner['validate'](files)
assert json.loads(files['FROZEN_LATEST.json'])['qualified']
assert len(json.loads(files['FROZEN_LATEST_CONTROLS.json'])) == 18
for p, h in json.loads(files['harvest/result.json'])['input_sha256'].items():
    assert hashlib.sha256((ROOT / p).read_bytes()).hexdigest() == h
sha = lambda raw: hashlib.sha256(raw).hexdigest()
files['MANIFEST.json'] = (json.dumps({p: sha(v) for p, v in sorted(files.items())}, indent=2) + '\n').encode()
target = STEM.with_suffix('.tar.xz')
pending = target.with_suffix('.pending')
with tarfile.open(pending, 'w:xz', preset=3) as archive:
    for p, raw in sorted(files.items()):
        member = tarfile.TarInfo(p)
        member.size = len(raw)
        archive.addfile(member, io.BytesIO(raw))
with tarfile.open(pending) as archive:
    assert {m.name: archive.extractfile(m).read() for m in archive.getmembers()} == files
pending.replace(target)
index = dict(path=str(target.relative_to(ROOT)), sha256=sha(target.read_bytes()),
             bytes=target.stat().st_size, members=len(files))
summary = dict(status='CURRENT_HARVEST_COMPOSITION_O0_O2_PASS', evidence=index,
               canonical_input='0be6037b670fdd3cb004ff616b0925291ae56728',
               source_checkpoint=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               current_harvest=result, frozen_latest_controls=18)
STEM.with_suffix('.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary))
