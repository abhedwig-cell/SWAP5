"""Persist original native FSI35, current source owners and actual typed timings."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

ROOT=Path(__file__).resolve().parents[2]
STEM=ROOT/'benchmarks/performance/PERF01_LINE_SEARCH_RETRY_SOURCE_20261022'
sha=lambda b:hashlib.sha256(b).hexdigest()
files={p:Path('/tmp/perf01-lsr-fsi35',p).read_bytes()for p in ['RESULT.json','stdout','stderr']}
native=json.loads(files['RESULT.json']);assert native['status']=='PASS'and native['returncode']==0
assert b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in files['stdout']
assert all(sha(files[p])==h for p,h in native['raw_sha256'].items())
for p,h in native['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h
for label,p in [('controls.json','/tmp/perf01-lsr-controls.json'),('owners.json','/tmp/perf01-lsr-current-owners.json'),
                ('source-owner.json','/tmp/perf01-lsr-owner.json'),('frozen-owner.json','/tmp/perf01-lsr-frozen-owner.json'),
                ('frozen-controls.json','/tmp/perf01-lsr-frozen-controls.json')]:files[label]=Path(p).read_bytes()
assert len(json.loads(files['controls.json']))==15
assert all(r['qualified']and r['returncode']==0 for r in json.loads(files['owners.json']))
for label,directory in [('paired','/tmp/perf01-lsr-paired'),('minimum','/tmp/perf01-lsr-minimum'),
    ('paired-build-off','/tmp/perf01-lsr-paired-off'),('paired-build-on','/tmp/perf01-lsr-paired-on'),
    ('retained-launch','/tmp/perf01-lsr-crop-joint-final-retained-incomplete')]:
    for p in sorted(Path(directory).rglob('*')):
        if p.is_file()and p.suffix not in ['.o','.mod','.a','.so']:
            raw=p.read_bytes()
            if not raw.startswith(b'\x7fELF'):files[label+'/'+str(p.relative_to(directory))]=raw
for p in Path('/tmp').glob('perf01-lsr-controller-*.json'):files['controllers/'+p.name]=p.read_bytes()
for p in Path('/tmp').glob('perf01-lsr-controller-crop-joint-final.*.retained-incomplete'):files['retained-launch/'+p.name]=p.read_bytes()
paired=json.loads(files['paired/RESULT.json'])
assert paired['status']=='SERIAL_PAIRED_NEWTON_WORK_PHYSICAL_SCREEN_PASS'and len(paired['events'])==12
assert paired['builds']['baseline']['weather_line_search_retry']is False
assert paired['builds']['candidate']['weather_line_search_retry']is True
assert json.loads(files['minimum/RESULT.json'])['status']=='EXISTING_TYPED_MINIMUM_DEFERRAL_OFF_ON_O0_O2_PASS'
r=json.loads((ROOT/'benchmarks/performance/PERF01_LINE_SEARCH_RETRY_20261022_STATUS.json').read_text())['source_successor']
summary=dict(status='CURRENT_TYPED_OPTION_SCIENCE_SOURCE_FSI35_AND_PAIRED_NATIVE_PASS',
    candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),
    postimages=r['postimages'],physical_evidence=r['evidence'],native_fsi35_seconds=native['seconds'],
    source_controls=15,frozen_controls=34,actual_typed_paired_cases=paired['cases'],
    warm_start_default=False,line_search_retry_default=False,canonically_admitted=False)
files['SUMMARY.json']=(json.dumps(summary,indent=2)+'\n').encode()
files['MANIFEST.json']=(json.dumps({p:sha(v)for p,v in sorted(files.items())},indent=2)+'\n').encode()
target=STEM.with_suffix('.tar.xz')
with tarfile.open(target,'w:xz',preset=3)as t:
    for p,raw in sorted(files.items()):
        m=tarfile.TarInfo(p);m.size=len(raw);t.addfile(m,io.BytesIO(raw))
with tarfile.open(target)as t:assert {m.name:t.extractfile(m).read()for m in t.getmembers()}==files
summary['evidence']=dict(path=str(target.relative_to(ROOT)),sha256=sha(target.read_bytes()),bytes=target.stat().st_size,members=len(files))
STEM.with_suffix('.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items()if k not in ['postimages','actual_typed_paired_cases']}))
