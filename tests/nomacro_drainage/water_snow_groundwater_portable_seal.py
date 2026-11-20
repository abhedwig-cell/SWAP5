"""Retain original failed and successful portable ZIPs byte for byte."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

from groundwater_snow_archive_storage import store_original


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True);a=p.parse_args()
    proof=Path(__file__).resolve().parents[2]/'integration/f-ci/nomacro-complete01';e=a.work/'evidence'
    roles=(('INITIAL','INITIAL_ORIGINAL',44749932813,'FAILURE',
        {'O0':'f0e67a9d27b09ddac1aad30d41f82d30c549c97afb56473e36c03c60fe9922a3',
         'O2':'a028da328a783f3da40fdbab5444b47e3f48e09727ebcffb10e8059a8c212d18'}),
        ('RECOVERY','RECOVERY_ORIGINAL_V1',44754314080,'SUCCESS',
        {'O0':'55ded6c27c70a2e2b0533d134b379db066e2183884d9abed9d034c9c344680ca',
         'O2':'82c8d99e453d8b464656588621616e1df3fb3cf7c72173188eebe6bb36dd4b6e'}))
    for role,suffix,run,conclusion,hashes in roles:
        for opt in ('O0','O2'):
            original=e/f'WATER_SNOW_GROUNDWATER_UBUNTU_{opt}_{suffix}.zip'
            assert hashlib.sha256(original.read_bytes()).hexdigest()==hashes[opt]
            members={}
            with zipfile.ZipFile(original) as z:
                assert len(z.namelist())==len(set(z.namelist()))
                for name in z.namelist():
                    assert not Path(name).is_absolute() and '..' not in Path(name).parts
                    raw=z.read(name);members[name]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
            name=f'WATER_SNOW_GROUNDWATER_UBUNTU_{opt}_{role}_RAW_ARCHIVE.zip'
            q=dict(**store_original(original,proof,name),members=members,original_run=run,
                original_whole_job_conclusion=conclusion,role=role,original_bytes_unchanged=True,
                original_failed_producers_preserved=True,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
            with (proof/Path(name).with_suffix('.json')).open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')
            print(opt,role,q['bytes'],len(members),flush=True)
    name='WATER_SNOW_GROUNDWATER_PORTABLE_OBSERVATIONS_RAW_ARCHIVE.zip';original=e/name;members={}
    with zipfile.ZipFile(original,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for path in sorted(e.glob('WATER_SNOW_GROUNDWATER_UBUNTU_*')):
            if path.is_file() and path.suffix.lower()!='.zip':
                raw=path.read_bytes();z.writestr(path.name,raw);members[path.name]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
    q=dict(**store_original(original,proof,name),members=members,role='Original API metadata, complete logs and independent observations')
    with (proof/Path(name).with_suffix('.json')).open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')


if __name__=='__main__':main()
