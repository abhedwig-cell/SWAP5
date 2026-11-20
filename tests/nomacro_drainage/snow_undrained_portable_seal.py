"""Retain the original portable Snow ZIP bytes and terminal observations once."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

from groundwater_snow_archive_storage import store_original


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True);a=p.parse_args()
    proof=Path(__file__).resolve().parents[2]/'integration/f-ci/nomacro-complete01';e=a.work/'evidence'
    metadata=json.loads((e/'SNOW_UNDRAINED_UBUNTU_ORIGINAL_ARTIFACTS_V1.json').read_text(encoding='utf-8'))
    run=json.loads((e/'SNOW_UNDRAINED_UBUNTU_ORIGINAL_RUN_API_V1.json').read_text(encoding='utf-8'))
    assert run['id']==44779472684 and run['status']=='completed' and run['conclusion']=='success'
    for opt in ('O0','O2'):
        item=next(v for v in metadata['artifacts'] if v['name'].startswith('snow-undrained-'+opt+'-'))
        original=e/f'SNOW_UNDRAINED_UBUNTU_{opt}_ORIGINAL_V1.zip'
        assert original.stat().st_size==item['size_in_bytes'] and 'sha256:'+hashlib.sha256(original.read_bytes()).hexdigest()==item['digest']
        assert item['workflow_run']['id']==44779472684 and item['workflow_run']['head_sha']=='2934c78b9e5ae5893cf8cdd42e040a5496cb538e'
        members={}
        with zipfile.ZipFile(original) as z:
            assert len(z.namelist())==len(set(z.namelist()))
            for name in z.namelist():
                assert not Path(name).is_absolute() and '..' not in Path(name).parts
                raw=z.read(name);members[name]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
        name=f'SNOW_UNDRAINED_UBUNTU_{opt}_RAW_ARCHIVE.zip'
        q=dict(**store_original(original,proof,name),members=members,original_run=44779472684,
            original_whole_job_conclusion='SUCCESS',original_artifact=item,original_bytes_unchanged=True,
            functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
        with (proof/Path(name).with_suffix('.json')).open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')
        print(opt,q['bytes'],len(members),flush=True)
    name='SNOW_UNDRAINED_PORTABLE_OBSERVATIONS_RAW_ARCHIVE.zip';original=e/name;members={}
    with zipfile.ZipFile(original,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for path in sorted(e.glob('SNOW_UNDRAINED_UBUNTU_*')):
            if path.is_file() and path.suffix.lower()!='.zip':
                raw=path.read_bytes();z.writestr(path.name,raw);members[path.name]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
    q=dict(**store_original(original,proof,name),members=members,role='Original API metadata, complete terminal logs and independent original-artifact observations')
    with (proof/Path(name).with_suffix('.json')).open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')


if __name__=='__main__':main()
