"""Persist the original current FSI35 body and the exact successor controls."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
STEM = ROOT / 'benchmarks/performance/PERF01_WEATHER_SOURCE_ADMISSION_20261022'
paths = {
    'fsi35/RESULT.json': '/tmp/perf01-fsi35-native/RESULT.json',
    'fsi35/stdout': '/tmp/perf01-fsi35-native/stdout',
    'fsi35/stderr': '/tmp/perf01-fsi35-native/stderr',
    'owners/root.json': '/tmp/perf01-root-owner-final.json',
    'owners/root.stderr': '/tmp/perf01-root-owner-final.stderr',
    'owners/nut.json': '/tmp/perf01-nut-owner-final.json',
    'owners/nut.stderr': '/tmp/perf01-nut-owner-final.stderr',
    'controls.json': '/tmp/perf01-registered-controls-final.json',
    'controls.stderr': '/tmp/perf01-registered-controls-final.stderr',
    'predecessor/fsi35-source.stdout': '/tmp/perf01-canonical-fsi35-source.stdout',
    'predecessor/fsi35-source.stderr': '/tmp/perf01-canonical-fsi35-source.stderr',
    'source/stdout': '/tmp/perf01-current-fsi35-source.stdout',
    'source/stderr': '/tmp/perf01-current-fsi35-source.stderr',
    'diagnostics/incomplete-registry.stderr': '/tmp/perf01-current-fsi35-source-incomplete.stderr',
}
files = {p: Path(v).read_bytes() for p, v in paths.items() if Path(v).exists()}
sha = lambda b: hashlib.sha256(b).hexdigest()
r = json.loads(files['fsi35/RESULT.json'])
assert r['status'] == 'PASS' and r['returncode'] == 0
for name, expected in r['raw_sha256'].items():
    assert sha(files['fsi35/' + name]) == expected
assert b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS' in files['fsi35/stdout']
controls = json.loads(files['controls.json'])
assert len(controls) == 28 and len(controls) == len(set(controls))
for name in ['root', 'nut']:
    q = json.loads(files['owners/' + name + '.json'])
    assert q['qualified'] and q['weather_successor']['status'] == 'CURRENT_COMPOSITION_NATIVE_PASS_OWNER_ADMISSION_PENDING' if name == 'root' else q['qualified']
    assert not files['owners/' + name + '.stderr']
record = json.loads((ROOT / 'benchmarks/performance/PERF01_WARM_START_20261022_STATUS.json').read_text())['source_successor_20261022']
for p, h in record['postimages'].items():
    raw = (ROOT / p).read_bytes()
    assert sha(raw) == h
    files['current-source/' + p] = raw
files['current-source/' + str(Path(__file__).relative_to(ROOT))] = Path(__file__).read_bytes()
summary = dict(status='EXACT_WEATHER_SOURCE_AND_ORIGINAL_FSI35_O0_O2_PASS',
               source_checkpoint=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               canonical_input=record['baseline'], current_source_tree=subprocess.check_output(['git', 'rev-parse', 'HEAD:src'], cwd=ROOT, text=True).strip(),
               native_fsi35_seconds=r['seconds'], source_evidence_controls=len(controls),
               original_frozen_owner_controls=40, canonically_admitted=False,
               postimages=record['postimages'], physical_evidence=record['evidence'],
               next_action='Reconcile later canonical80dbce8d root/backend and calendar-output changes before merge. This proof remains qualified at its exact f7c60410 composition.')
files['SUMMARY.json'] = (json.dumps(summary, indent=2) + '\n').encode()
files['MANIFEST.json'] = (json.dumps({p: sha(raw) for p, raw in sorted(files.items())}, indent=2) + '\n').encode()
with tarfile.open(STEM.with_suffix('.tar.xz'), 'w:xz', preset=3) as t:
    for p, raw in sorted(files.items()):
        member = tarfile.TarInfo(p)
        member.size = len(raw)
        t.addfile(member, io.BytesIO(raw))
with tarfile.open(STEM.with_suffix('.tar.xz')) as t:
    assert {m.name: t.extractfile(m).read() for m in t.getmembers()} == files
index = dict(path=str(STEM.with_suffix('.tar.xz').relative_to(ROOT)), sha256=sha(STEM.with_suffix('.tar.xz').read_bytes()),
             bytes=STEM.with_suffix('.tar.xz').stat().st_size, members=len(files))
STEM.with_suffix('.json').write_text(json.dumps({**summary, 'evidence': index}, indent=2) + '\n')
print(json.dumps({k: v for k, v in {**summary, 'evidence': index}.items() if k not in ['postimages']}))
