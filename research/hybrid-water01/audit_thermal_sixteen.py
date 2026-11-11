"""Read-only check of cold heat16 discriminator raw source/build/result proof."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--archive',type=Path,required=True)
a=p.parse_args();root=Path(__file__).resolve().parents[2]
s=json.loads((root/'integration/f-ci/THERMAL_SIXTEEN_DISCRIMINATOR_20261111.json').read_text())
sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(a.archive.read_bytes())==s['archive_sha256']
with tarfile.open(a.archive) as archive:
 raw={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
pins=json.loads(raw['MEMBER_SHA256.json'])
for name,h in pins.items():assert sha(raw[name])==h,name
r=json.loads(raw['precision/RESULT.json']);old=json.loads(raw['initial/RESULT.json'])
assert r['status']==s['status']
assert r['results']==s['results']
assert set(r['source_sha256'].values())<=set(pins.values())
assert r['results']['O0']['cases']==r['results']['O2']['cases']
assert r['results']['O0']['unchanged_budget_dt']==r['results']['O2']['unchanged_budget_dt']
assert all(e['returncode']==0 for e in r['events']+old['events'])
for opt in ['O0','O2']:
 assert 'THERMAL_SUBCYCLE_ORIGINAL_SOLVES_FACES_AND_REFUSAL=PASS' in raw[f'precision/{opt}/native.stdout'].decode()
 result=r['results'][opt]
 assert sha(raw[f'precision/{opt}/probe.exe'])==result['executable_sha256']
 assert len(result['cases'])==6 and all(0<c['ratio']<1 for c in result['cases'])
 dt=result['unchanged_budget_dt']
 assert dt['sixteen']>dt['four']>0 and dt['error4']<=1e-5 and dt['error16']<=1e-5
 assert all(c['cpu_seconds']>=.5 for c in result['cost_samples'])
print(json.dumps(dict(status='RAW_COLD_SOURCES_OBJECTS_EXECUTABLES_MARKERS_AND_O0_O2_RESULTS_PASS',
                     files=len(pins),application_speedup='NOT_MEASURED',production_admission=False)))
