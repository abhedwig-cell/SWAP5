"""Preserve original GitHub artifact bytes, without rewriting BUILD or source receipts."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
from groundwater_snow_archive_storage import store_original
ROOT=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--original',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--expected-digest',required=True);p.add_argument('--artifact',type=int,required=True);a=p.parse_args()
    proof=ROOT/'integration/f-ci/nomacro-complete01';name='HYDRAULIC_ANALYTICAL_UBUNTU_'+a.optimization+'_RAW_V1.zip';record=proof/Path(name).with_suffix('.json');assert not record.exists()
    assert hashlib.sha256(a.original.read_bytes()).hexdigest()==a.expected_digest
    members={}
    with zipfile.ZipFile(a.original) as z:
        assert len(z.namelist())==len(set(z.namelist()))
        source=json.loads(z.read('source/RESULT.json'));top=json.loads(z.read('analytical-hydraulic-family/RESULT.json'))
        assert source['producer_head']==top['producer']=='a7d7fba5fa1e07aeeedbc8a1042665c9a900fecc'
        assert top['optimization']==a.optimization and top['status']=='ACTUAL_ANALYTICAL_PORTABLE_20FULL_20SHORT_200COLD_MIXED_COMPONENTS_INDEPENDENT_PASS_NOT_ADMITTED'
        assert all(s['status']=='PASS' for s in top['steps'])
        for name_in_zip in z.namelist():
            value=z.read(name_in_zip);members[name_in_zip]=dict(bytes=len(value),sha256=hashlib.sha256(value).hexdigest())
    stored=store_original(a.original,proof,name)
    q=dict(status='ORIGINAL_GITHUB_ANALYTICAL_FAMILY_ARTIFACT_PRESERVED_NO_ADMISSION',**stored,members=members,actual_workflow_run=44851861883,actual_artifact=a.artifact,
        github_artifact_digest=a.expected_digest,actual_producer=top['producer'],optimization=a.optimization,source_and_BUILD_receipts_rewritten=False,public_admission=False,whole_model_qualified=False)
    record.write_text(json.dumps(q,indent=2)+'\n');print(q['status'],q['bytes'],q['sha256'],len(members),flush=True)


if __name__=='__main__':main()
