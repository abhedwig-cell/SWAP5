"""Retain completed current owner/source gates separately from native archives."""
import hashlib
import argparse
import io
import json
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
STEM = ROOT / 'benchmarks/performance/PERF01_COMPOSED_SOURCE_20261022'
parser = argparse.ArgumentParser()
parser.add_argument('--saved', action='store_true')
args = parser.parse_args()
if args.saved:
    STEM = ROOT / 'benchmarks/performance/PERF01_SAVED_SOURCE_20261022'
paths = {
    'owner.json': '/tmp/perf01-current80-owner.json',
    'owner.stderr': '/tmp/perf01-current80-owner.stderr',
    'controls.json': '/tmp/perf01-current80-controls.json',
    'controls.stderr': '/tmp/perf01-current80-controls.stderr',
    'fsi35-source.stdout': '/tmp/perf01-current80-fsi35.stdout',
    'fsi35-source.stderr': '/tmp/perf01-current80-fsi35.stderr',
    'owning-entrypoints.json': '/tmp/perf01-final-current-owners.json',
}
files = {p: Path(v).read_bytes() for p, v in paths.items()}
owner = json.loads(files['owner.json'])
assert owner['qualified'] and owner['current_harvest_output']['qualified']
controls = json.loads(files['controls.json'])
assert len(controls) == len(set(controls)) == (34 if args.saved else 33)
assert all(r['qualified'] and r['returncode'] == 0 for r in json.loads(files['owning-entrypoints.json']))
assert all(not v for p, v in files.items() if p.endswith('.stderr'))
assert b'FCI93_FIXED_K_EXACT_BOUNDED_POSTIMAGE=PASS' in files['fsi35-source.stdout']
status = json.loads((ROOT / 'benchmarks/performance/PERF01_WARM_START_20261022_STATUS.json').read_text())['source_composition_80db']
sha = lambda raw: hashlib.sha256(raw).hexdigest()
for p, h in status['postimages'].items():
    raw = (ROOT / p).read_bytes()
    assert sha(raw) == h
    files['current-source/' + p] = raw
summary = dict(status='CURRENT_COMPOSED_SOURCE_AND_NATIVE_QUALIFIED', qualified=True,
    canonical_input=status['baseline'], physical_baseline=status['physical_baseline'],
    source_checkpoint=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
    current_source_tree=subprocess.check_output(['git', 'rev-parse', 'HEAD:src'], cwd=ROOT, text=True).strip(),
    current_controls=len(controls), frozen_root_controls=36, frozen_harvest_controls=18,
    physical_evidence=status['evidence'], harvest_evidence=status['harvest_evidence'],
    fsi35_native_inheritance=status['fsi35_native_inheritance'], canonically_admitted=False)
if args.saved:
    summary.update(saved_evidence=status['saved_evidence'], frozen_saved_controls=19)
    assert owner['current_saved_output']['qualified']
files['SUMMARY.json'] = (json.dumps(summary, indent=2) + '\n').encode()
files['MANIFEST.json'] = (json.dumps({p: sha(v) for p, v in sorted(files.items())}, indent=2) + '\n').encode()
target = STEM.with_suffix('.tar.xz')
with tarfile.open(target, 'w:xz', preset=3) as archive:
    for p, raw in sorted(files.items()):
        member = tarfile.TarInfo(p)
        member.size = len(raw)
        archive.addfile(member, io.BytesIO(raw))
with tarfile.open(target) as archive:
    assert {m.name: archive.extractfile(m).read() for m in archive.getmembers()} == files
summary['evidence'] = dict(path=str(target.relative_to(ROOT)), sha256=sha(target.read_bytes()),
                          bytes=target.stat().st_size, members=len(files))
STEM.with_suffix('.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps({k: v for k, v in summary.items() if k != 'fsi35_native_inheritance'}))
