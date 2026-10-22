"""Checkpoint actual typed-solver controls, retaining setup failures separately."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

ROOT=Path(__file__).resolve().parents[2]
STEM=ROOT/'benchmarks/performance/PERF01_LINE_SEARCH_RETRY_DIRECT_20261022'
folders={'qualified':'/tmp/perf01-line-search-direct-final',
         'first-wrong-grid':'/tmp/perf01-line-search-direct',
         'second-uninitialized-test-snapshot':'/tmp/perf01-line-search-direct30'}
files={};sha=lambda raw:hashlib.sha256(raw).hexdigest()
for label,directory in folders.items():
    for p in sorted(Path(directory).rglob('*')):
        if p.is_file() and p.suffix not in ['.o','.mod','.a','.so']:
            raw=p.read_bytes()
            if not raw.startswith(b'\x7fELF'):files[label+'/'+str(p.relative_to(directory))]=raw
r=json.loads(files['qualified/RESULT.json'])
assert r['status']=='TYPED_LINE_SEARCH_OFF_ON_UNSUPPORTED_AND_ORIGINAL_O0_O2_PASS'
assert all(e['returncode']==0 for e in r['events'])
for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h
summary=dict(status=r['status'],providers=r['provider_count'],events=len(r['events']),
    baseline='17a6c17a478238e5fafc469aa275313bcdf2e184',
    source_checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    production_source_sha256={p:sha((ROOT/p).read_bytes())for p in subprocess.check_output(['git','diff','--name-only','17a6c17a478238e5fafc469aa275313bcdf2e184','HEAD','--','src'],cwd=ROOT,text=True).splitlines()},
    full_application_qualification=False,canonically_admitted=False,
    retained_failures='First used3cm stub instead of30cm fixture; second snapshotted theta before test initialization. Both remain FAILED; final original solver assertions and initialized immutable-base checks pass.')
files['SUMMARY.json']=(json.dumps(summary,indent=2)+'\n').encode()
files['MANIFEST.json']=(json.dumps({p:sha(v)for p,v in sorted(files.items())},indent=2)+'\n').encode()
target=STEM.with_suffix('.tar.xz')
with tarfile.open(target,'w:xz',preset=3)as t:
    for p,raw in sorted(files.items()):
        m=tarfile.TarInfo(p);m.size=len(raw);t.addfile(m,io.BytesIO(raw))
summary['evidence']=dict(path=str(target.relative_to(ROOT)),sha256=sha(target.read_bytes()),bytes=target.stat().st_size,members=len(files))
STEM.with_suffix('.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary))
