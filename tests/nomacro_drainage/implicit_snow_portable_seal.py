"""Retain six original portable artifacts losslessly, including both failed runs."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

from groundwater_snow_archive_storage import store_original


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True);a=p.parse_args()
    proof=Path(__file__).resolve().parents[2]/'integration/f-ci/nomacro-complete01';e=a.work/'evidence'
    roles=(('INITIAL','INITIAL_ORIGINAL',44732748938,'FAILURE',
        {'O0':'cd221b4045c4cbd309d7c756723de10a1e05eb7644ddda40fa59dbe110267b33',
         'O2':'fdf9a00361be63494fd1a0252e9c9eed41905c7762997c067eeb95b1732c70e4'}),
        ('FIRST_RECOVERY','RECOVERY_ORIGINAL_V1',44735754865,'FAILURE',
        {'O0':'410e33e2a57e7f5bd7a404beeb4aa7caffb2937099d47f0e94050a2afb593739',
         'O2':'2ad2b3b9fb004a186429a5e72c8cdfc6d8fc151bb27be3d99371ce35dc3ae791'}),
        ('FINAL_RECOVERY','FINAL_RECOVERY_ORIGINAL_V1',44737214910,'SUCCESS',
        {'O0':'b8e8efb2519206f312f9f087d53663f46f1939b44ee7e95176f39e895576c945',
         'O2':'5a565095918b6ffc4bf69340688367663b07b951cc0598accbb94dd4d93cfacd'}))
    for role,suffix,run,conclusion,hashes in roles:
        for opt in ('O0','O2'):
            source=e/f'IMPLICIT_SNOW_UBUNTU_{opt}_{suffix}.zip'
            assert hashlib.sha256(source.read_bytes()).hexdigest()==hashes[opt]
            members={}
            with zipfile.ZipFile(source) as z:
                assert len(z.namelist())==len(set(z.namelist()))
                for n in z.namelist():
                    assert not Path(n).is_absolute() and '..' not in Path(n).parts
                    raw=z.read(n);members[n]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
            name=f'IMPLICIT_SNOW_COMPOSITION_UBUNTU_{opt}_{role}_RAW_ARCHIVE.zip'
            q=dict(**store_original(source,proof,name),members=members,original_run=run,
                original_whole_job_conclusion=conclusion,role=role,
                original_bytes_unchanged=True,original_failed_producers_preserved=True,
                functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
            with (proof/Path(name).with_suffix('.json')).open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')
            print(opt,role,q['bytes'],len(members),flush=True)
    name='IMPLICIT_SNOW_COMPOSITION_PORTABLE_OBSERVATIONS_RAW_ARCHIVE.zip';source=e/name;members={}
    with zipfile.ZipFile(source,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for path in sorted(e.glob('IMPLICIT_SNOW_UBUNTU_*')):
            if path.is_file() and path.suffix.lower()!='.zip':
                raw=path.read_bytes();z.writestr(path.name,raw);members[path.name]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
    q=dict(**store_original(source,proof,name),members=members,role='Original API metadata, complete job logs and independent observations')
    with (proof/Path(name).with_suffix('.json')).open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')


if __name__=='__main__':main()
