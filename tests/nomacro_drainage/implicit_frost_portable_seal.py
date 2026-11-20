"""Preserve both original successful portable ZIPs verbatim with member identities."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile
from groundwater_snow_archive_storage import store_original

ROOT=Path(__file__).resolve().parents[2]
ARTIFACTS=(('O0',14675376247,34740277,'a230622fed8d666aa815fac59253a8fea27a970e94a6b63741912a2a7cc294ff'),('O2',14675705599,34677426,'1fa9675311b7c2a74363692ac33917717894321c645ab533a85de0b16b5398b9'))


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--evidence',type=Path,required=True)
    a=p.parse_args();proof=ROOT/'integration/f-ci/nomacro-complete01'
    for opt,artifact,size,digest in ARTIFACTS:
        original=a.evidence/('FROST_IMPLICIT_ROOT_UBUNTU_'+opt+'_ORIGINAL_V1.zip')
        assert original.stat().st_size==size and hashlib.sha256(original.read_bytes()).hexdigest()==digest
        name='FROST_IMPLICIT_UBUNTU_'+opt+'_RAW_ARCHIVE.zip';record=proof/Path(name).with_suffix('.json');assert not record.exists()
        members={}
        with zipfile.ZipFile(original) as z:
            assert len(z.namelist())==len(set(z.namelist()))
            for name_in_archive in z.namelist():
                raw=z.read(name_in_archive);members[name_in_archive]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
        stored=store_original(original,proof,name)
        q=dict(status='NEUTRAL_ORIGINAL_IMPLICIT_FROST_UBUNTU_RAW_SEALED_PENDING_ADMISSION',**stored,members=members,
            workflow_run=44827783246,artifact_id=artifact,actual_producer_source='a6e37763a689716ec505d5f5f71dda0e94667014',optimization=opt,
            sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),canonical_admission=False)
        record.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(opt,size,digest,len(members),flush=True)


if __name__=='__main__':main()
