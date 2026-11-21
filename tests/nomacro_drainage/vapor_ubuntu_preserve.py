"""Preserve exact successful Ubuntu continuation artifact bytes and identities."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
from groundwater_snow_archive_storage import store_original

ROOT=Path(__file__).resolve().parents[2]
EXPECTED={
    'O0':(14690173185,'68c6b6e234d9bc08dc9446cafa07724f1c329a4ec8638d57cad420a56c6c1bbb'),
    'O2':(14690437194,'ad3bfa83b7a9a4c586f1bd7b953091731c85a704585ee2bff551ef399006b349'),
}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--original',type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True);a=parser.parse_args()
    artifact,digest=EXPECTED[a.optimization]
    assert hashlib.sha256(a.original.read_bytes()).hexdigest()==digest
    proof=ROOT/'integration/f-ci/nomacro-complete01';name='HYDRAULIC_VAPOR_UBUNTU_CONTINUATION_'+a.optimization+'_RAW_V1.zip'
    record=proof/Path(name).with_suffix('.json');assert not record.exists();members={}
    with zipfile.ZipFile(a.original) as archive:
        names=archive.namelist();assert len(names)==len(set(names))
        source=json.loads(archive.read('source/RESULT.json'));assert source['producer_head']=='afac661b04e0224f89b6d54060fdc9993f413eec'
        top=json.loads(archive.read('vapor-hydraulic-family/RESULT.json'))
        assert top['status']=='ACTUAL_VAPOR_PORTABLE_16FULL_112COLD_MIXED_COMPONENTS_COMPILED_NATIVE_TRANSACTIONS_INDEPENDENT_PASS_NOT_ADMITTED'
        assert top['optimization']==a.optimization and top['producer']==source['producer_head']
        assert len(top['steps'])==30 and all(step['status']=='PASS' for step in top['steps'])
        assert top['reused_initial']['status']=='INITIAL_TWO_FULL_PERIODS_14_EXACT_COLD_WINDOWS_REUSED_AFTER_PYTHON_ONLY_DECODER_FIX'
        for member in names:
            raw=archive.read(member);members[member]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
    stored=store_original(a.original,proof,name)
    q=dict(status='ACTUAL_UBUNTU_VAPOR_CONTINUATION_ARTIFACT_PRESERVED_NOT_ADMITTED',
        **stored,members=members,actual_workflow_run=44862284800,actual_artifact=artifact,github_artifact_digest=digest,
        actual_producer=source['producer_head'],optimization=a.optimization,new_full1096_periods=14,new_exact_cold_windows=98,
        initial_raw_record='HYDRAULIC_VAPOR_UBUNTU_INITIAL_'+a.optimization+'_RAW_V1.json',
        original_receipts_rewritten=False,public_admission=False)
    record.open('x',encoding='utf8').write(json.dumps(q,indent=2)+'\n')
    print(q['status'],q['bytes'],q['sha256'],len(members),flush=True)


if __name__=='__main__':main()
