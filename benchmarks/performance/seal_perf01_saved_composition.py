"""Seal current saved-output tests without including reproducible build objects."""
import hashlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
STEM = ROOT / 'benchmarks/performance/PERF01_SAVED_COMPOSITION_20261022'
owner = runpy.run_path(str(ROOT / 'integration/audits/verify_nut_saved_output.py'))
files = owner['capsule']()
for prefix in ['component', 'physical']:
    files = {p: v for p, v in files.items() if not p.startswith(prefix + '/')}
    directory = Path('/tmp/perf01-compose3-saved-' + prefix)
    for path in sorted(directory.rglob('*')):
        if not path.is_file() or path.suffix in ['.o', '.mod', '.a', '.so']:
            continue
        raw = path.read_bytes()
        if not raw.startswith(b'\x7fELF'):
            files[prefix + '/' + str(path.relative_to(directory))] = raw
for name, path in [('FROZEN_LATEST.json', '/tmp/perf01-canonical7eb-owner-result.json'),
                   ('FROZEN_LATEST_CONTROLS.json', '/tmp/perf01-canonical7eb-owner-controls.json')]:
    files[name] = Path(path).read_bytes()
result = owner['validate'](files)
assert json.loads(files['FROZEN_LATEST.json'])['qualified']
assert len(json.loads(files['FROZEN_LATEST_CONTROLS.json'])) == 19
sha = lambda raw: hashlib.sha256(raw).hexdigest()
for prefix in ['component', 'physical']:
    for p, h in json.loads(files[prefix + '/result.json'])['input_sha256'].items():
        assert sha((ROOT / p).read_bytes()) == h
files['MANIFEST.json'] = (json.dumps({p: sha(v) for p, v in sorted(files.items())}, indent=2) + '\n').encode()
target = STEM.with_suffix('.tar.xz')
with tarfile.open(target, 'w:xz', preset=3) as archive:
    for p, raw in sorted(files.items()):
        member = tarfile.TarInfo(p)
        member.size = len(raw)
        archive.addfile(member, io.BytesIO(raw))
with tarfile.open(target) as archive:
    assert {m.name: archive.extractfile(m).read() for m in archive.getmembers()} == files
index = dict(path=str(target.relative_to(ROOT)), sha256=sha(target.read_bytes()),
             bytes=target.stat().st_size, members=len(files))
summary = dict(status='CURRENT_SAVED_COMPOSITION_O0_O2_PASS', evidence=index,
               canonical_input='7eb6f10baabae2f26af168c59bf63459fa0a3516',
               source_checkpoint=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               current_saved=result, frozen_latest_controls=19)
STEM.with_suffix('.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary))
