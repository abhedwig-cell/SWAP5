"""Preserve the exact original Ubuntu receipt-offset failure artifacts once."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
from groundwater_snow_archive_storage import store_original

ROOT=Path(__file__).resolve().parents[2]
EXPECTED={
    'O0':(14690500300,'938d1f6bfc6ac54da717f8e0f418292cf3bc7bdd9b1a56888e0876d3315df6d4'),
    'O2':(14690401081,'f673fb51366cdf8f67fbf867601dbee3001bf9243bfa6dbea86cf22e6a247283'),
}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--original',type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True);a=parser.parse_args()
    artifact,digest=EXPECTED[a.optimization]
    assert hashlib.sha256(a.original.read_bytes()).hexdigest()==digest
    proof=ROOT/'integration/f-ci/nomacro-complete01';name='HYDRAULIC_VAPOR_UBUNTU_INITIAL_'+a.optimization+'_RAW_V1.zip'
    record=proof/Path(name).with_suffix('.json');assert not record.exists();members={}
    with zipfile.ZipFile(a.original) as archive:
        names=archive.namelist();assert len(names)==len(set(names))
        source=json.loads(archive.read('source/RESULT.json'));assert source['producer_head']=='effd77a2f326e9b8b0cee14181bc18b9c669f142'
        top=json.loads(archive.read('vapor-hydraulic-family/RESULT.json'))
        assert top['status']=='FAILED_OR_CENSORED' and top['optimization']==a.optimization and top['producer']==source['producer_head']
        assert top['steps'][-1]['label']=='8-cde-controls' and top['steps'][-1]['status']=='FAILED_OR_CENSORED'
        assert all(step['status']=='PASS' for step in top['steps'][:-1])
        for kind in ('water','cde'):
            q=json.loads(archive.read('vapor-hydraulic-family/8-'+kind+'-full/RESULT.json'))
            assert q['trajectory']['days']==1096 and len(q['own'])==7 and q['status'].endswith('_PASS_NOT_ADMITTED')
        error=json.loads(archive.read('vapor-hydraulic-family/8-cde-controls/RESULT.json'))
        assert error['error']=="ValueError('Private CDE native stock differs from candidate receipt')"
        assert len(error['refusals'])==57 and len(error['inherited_output_native_refusals'])==29
        for member in names:
            raw=archive.read(member);members[member]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
    stored=store_original(a.original,proof,name)
    q=dict(status='ACTUAL_UBUNTU_VAPOR_INITIAL_CDE_PUBLIC_RECEIPT_OFFSET_FAILURE_RAW_RETAINED_NOT_ADMITTED',
        **stored,members=members,actual_workflow_run=44861552730,actual_artifact=artifact,github_artifact_digest=digest,
        actual_producer=source['producer_head'],optimization=a.optimization,completed_full1096_periods=2,exact_cold_windows=14,
        failure_is_retained=True,raw_or_BUILD_receipts_rewritten=False,public_admission=False)
    record.open('x',encoding='utf8').write(json.dumps(q,indent=2)+'\n')
    print(q['status'],q['bytes'],q['sha256'],len(members),flush=True)


if __name__=='__main__':main()
