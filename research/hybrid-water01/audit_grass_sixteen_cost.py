"""Verify retained unchanged-release16 samples and both exact wet continuations."""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import tarfile

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--profile-archive',type=Path,required=True)
p.add_argument('--full-archive',type=Path,required=True)
a=p.parse_args()
root=Path(__file__).resolve().parents[2]
record=json.loads((root/'integration/f-ci/GRASS_SIXTEEN_NATIVE_COST_20261111.json').read_text())
sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(a.profile_archive.read_bytes())==record['archive_sha256']
assert sha(a.full_archive.read_bytes())==record['full_archive_sha256']
with tarfile.open(a.profile_archive) as archive:
    raw={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
for name,h in json.loads(raw['MEMBER_SHA256.json']).items():assert sha(raw[name])==h,name
receipt=json.loads(raw['receipt.json'])
names=['budget.csv','crop.csv','conductive_budget.csv','checkpoint-187.bin','checkpoint-190.bin']
with tarfile.open(a.full_archive) as full:
    expected={n:full.extractfile('full/'+n).read() for n in names}
    build=json.load(full.extractfile('bundle/BUILD.json'))
    exe=full.extractfile('bundle/'+build['executable']).read()
assert sha(exe)==build['executable_sha256']==record['release_executable_sha256']
rows=lambda b:list(csv.DictReader(io.StringIO(b.decode())))
for case,proof in receipt['proofs'].items():
    r=proof['profile']
    assert json.loads(raw[case+'/PROFILE.json'])==r
    assert r['status']=='SAMPLED' and r['returncode']==0 and not r['censored']
    assert r['wall_seconds']<r['hard_cap_seconds']==25
    assert r['numerical_profile']=='thermal-subcycle16-1e-5C'
    assert r['executable_sha256']==build['executable_sha256']
    assert r['origin_sha256']==sha(expected['checkpoint-187.bin'])
    assert r['sampler_sha256']==sha(raw['source/sampler.py'])
    counts=dict(r['exclusive_counts']);callers=dict(r['external_first_native_caller_counts'])
    assert sum(counts.values())==r['samples']
    assert sum(callers.values())==sum(v for k,v in counts.items() if k.startswith('EXTERNAL:'))
    wf='__mod_bartholomeus_waterfilm_MOD_bartholomeus_waterfilm_mvg_integrand'
    waterfilm=counts.get(wf,0)+callers.get(wf,0)
    heat=sum(v for k,v in counts.items() if 'mod_restricted_soil_temperature' in k)
    heat+=sum(v for k,v in callers.items() if 'mod_restricted_soil_temperature' in k)
    assert proof['summary']['waterfilm_samples']==waterfilm
    assert proof['summary']['restricted_heat_samples']==heat
    for name in names[:3]:
        assert rows(raw[case+'/'+name])==[r for r in rows(expected[name]) if 188<=int(r['day'])<=190]
    assert raw[case+'/checkpoint.bin']==expected['checkpoint-190.bin']
assert len(receipt['proofs'])==2
assert receipt['total_probe_seconds']==sum(p['profile']['wall_seconds'] for p in receipt['proofs'].values())<60
print(json.dumps({'status':'RAW_SIXTEEN_SAMPLER_IDENTITY_COUNTERS_AND_BOTH_EXACT_SUFFIXES_PASS',
                  'cases':2,'total_native_probe_seconds':receipt['total_probe_seconds'],
                  'retained_files':len(json.loads(raw['MEMBER_SHA256.json']))}))
