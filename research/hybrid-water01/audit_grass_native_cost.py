"""Read-only verification of the sampled unchanged-binary wet restart proof."""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import tarfile


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--profile-archive',type=Path,required=True)
    p.add_argument('--full-archive',type=Path,required=True)
    a=p.parse_args()
    root=Path(__file__).resolve().parents[2]
    record=json.loads((root/'integration/f-ci/GRASS_NATIVE_COST_ATTRIBUTION_20261111.json').read_text())
    sha=lambda b:hashlib.sha256(b).hexdigest()
    assert sha(a.profile_archive.read_bytes())==record['archive_sha256']
    assert sha(a.full_archive.read_bytes())=='b98e534a8eb1510187c3ce81c95931f8e8130f54c989f1523bf7b58908a42bec'
    with tarfile.open(a.profile_archive) as archive:
        raw={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
    for name,h in json.loads(raw['MEMBER_SHA256.json']).items():assert sha(raw[name])==h,name
    r=json.loads(raw['receipt.json'])
    with tarfile.open(a.full_archive) as full:
        expected={name:full.extractfile('full/'+name).read() for name in
                  ['budget.csv','crop.csv','conductive_budget.csv','checkpoint-187.bin','checkpoint-190.bin']}
    rows=lambda b:list(csv.DictReader(io.StringIO(b.decode())))
    for case,v in r['proofs'].items():
        observed=v['profile'];assert observed['status']=='SAMPLED' and observed['returncode']==0
        assert not observed['censored'] and observed['wall_seconds']<120
        assert observed['samples']==sum(n for _,n in observed['exclusive_counts'])
        assert observed['origin_sha256']==sha(expected['checkpoint-187.bin'])
        for name in ['budget.csv','crop.csv','conductive_budget.csv']:
            assert rows(raw[case+'/'+name])==[x for x in rows(expected[name]) if 188<=int(x['day'])<=190]
        assert raw[case+'/checkpoint.bin']==expected['checkpoint-190.bin']
    u=r['proofs']['s5-grass-native-stack-cost-20261111']['profile']
    assert sha(raw['source/unwind.py'])==u['sampler_sha256']
    assert sum(n for _,n in u['external_first_native_caller_counts'])==sum(n for s,n in u['exclusive_counts'] if s.startswith('EXTERNAL:'))
    print(json.dumps(dict(status='RAW_SAMPLING_IDENTITIES_COUNTERS_AND_BOTH_EXACT_SUFFIX_CHECKPOINTS_PASS',
                         cases=len(r['proofs']),total_probe_seconds=sum(v['profile']['wall_seconds'] for v in r['proofs'].values()))))


if __name__=='__main__':main()
