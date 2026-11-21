"""Preserve targeted unselected postimages, original failed observers and actual CI logs."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile
from groundwater_snow_archive_storage import store_original

ROOT=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True)
    a=p.parse_args();ev=a.work/'evidence';proof=ROOT/'integration/f-ci/nomacro-complete01';files={};projection={}
    prefixes=('model7-unselected-postimages-',)
    for directory in sorted(ev.iterdir()):
        if directory.is_dir() and directory.name.startswith(prefixes):
            for path in sorted(directory.rglob('*')):
                if path.is_file():files['profiles/'+path.relative_to(ev).as_posix()]=path
        elif directory.is_file() and directory.suffix in ('.json','.txt') and directory.name.startswith(('MODEL7_UBUNTU_','CANONICAL085_','MODEL7_OLD_TRIAL_')):
            files['observations/'+directory.name]=directory
    for directory in sorted(a.work.iterdir()):
        if not directory.is_dir() or not directory.name.startswith(prefixes):continue
        for path in sorted(directory.rglob('*')):
            if path.is_file() and (path.name=='BUILD.json' or path.suffix.lower() in ('.f90','.exe','.dll','.so')):
                files['builds/'+path.relative_to(a.work).as_posix()]=path
            if path.is_file() and path.name=='BUILD.json':
                projection[str(path.parent)]=dict(archive_prefix='builds/'+path.parent.relative_to(a.work).as_posix(),actual_BUILD_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    inputs={}
    for opt in ('O0','O2'):
        cohort=json.loads((ev/f'model7-unselected-postimages-{opt}-v4/RESULT.json').read_text())
        assert cohort['status']=='ACTUAL_FOUR_TARGETED_UNSELECTED_MODEL7_DEPENDENCY_POSTIMAGES_PASS'
        for item in cohort['profiles'].values():
            path=Path(item['input_root']);inventory={p.relative_to(path).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(path.rglob('*')) if p.is_file()}
            digest=hashlib.sha256(json.dumps(inventory,sort_keys=True).encode()).hexdigest();prefix='inputs/'+digest
            inputs[str(path)]=dict(archive_prefix=prefix,files=inventory)
            for p in sorted(path.rglob('*')):
                if p.is_file():files[prefix+'/'+p.relative_to(path).as_posix()]=p
    name='HYDRAULIC_MODEL7_UNSELECTED_WINDOWS_RAW_V1.zip';archive=ev/name;record=proof/Path(name).with_suffix('.json')
    assert not archive.exists() and not record.exists();members={}
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for member,path in sorted(files.items()):
            raw=path.read_bytes();z.writestr(member,raw);members[member]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
        member='COMPILED_PROJECTION_V1.json';raw=(json.dumps(projection,indent=2)+'\n').encode();z.writestr(member,raw)
        members[member]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
        member='INPUT_PROJECTION_V1.json';raw=(json.dumps(inputs,indent=2)+'\n').encode();z.writestr(member,raw)
        members[member]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
    with zipfile.ZipFile(archive) as z:
        assert len(z.namelist())==len(set(z.namelist()))==len(members)
        for member,item in members.items():
            raw=z.read(member);assert len(raw)==item['bytes'] and hashlib.sha256(raw).hexdigest()==item['sha256']
    stored=store_original(archive,proof,name)
    q=dict(status='ACTUAL_MODEL7_UNSELECTED_POSTIMAGES_AND_ORIGINAL_OBSERVERS_PRESERVED_NO_ADMISSION',**stored,members=members,
        producer=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        contains_actual_original_CI_logs=True,contains_actual_unselected_postimages=True,
        unselected_contexts=8,unselected_cold_windows=8,unaffected_full_periods_replayed=0,
        original_failed_observers_retained=True,whole_model_qualified=False,public_admission=False)
    record.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(q['status'],stored['bytes'],stored['sha256'],len(members),flush=True)


if __name__=='__main__':main()
