"""Preserve actual model7 saturated-search and retained censor roles once."""
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
    prefixes=('hydraulic-saturation-matrix-','model7-native-trial-','model7-search-')
    for directory in sorted(ev.iterdir()):
        if directory.is_dir() and directory.name.startswith(prefixes):
            for path in sorted(directory.rglob('*')):
                if path.is_file():files['profiles/'+path.relative_to(ev).as_posix()]=path
        elif directory.is_file() and directory.suffix in ('.json','.txt','.tar') and directory.name.startswith(('HYDRAULIC_SATURATED_','MODEL7_NATIVE_TRIAL_','MODEL7_SEARCH_','MODEL7_UBUNTU_','model7-search-controller-')):
            files['observations/'+directory.name]=directory
    for directory in sorted(a.work.iterdir()):
        if not directory.is_dir() or not directory.name.startswith(prefixes):continue
        for path in sorted(directory.rglob('*')):
            if path.is_file() and (path.name=='BUILD.json' or path.suffix.lower() in ('.f90','.exe','.dll','.so')):
                files['builds/'+path.relative_to(a.work).as_posix()]=path
            if path.is_file() and path.name=='BUILD.json':
                projection[str(path.parent)]=dict(archive_prefix='builds/'+path.parent.relative_to(a.work).as_posix(),actual_BUILD_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    name='HYDRAULIC_MODEL7_SEARCH_WINDOWS_RAW_V1.zip';archive=ev/name;record=proof/Path(name).with_suffix('.json')
    assert not archive.exists() and not record.exists();members={}
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for member,path in sorted(files.items()):
            raw=path.read_bytes();z.writestr(member,raw);members[member]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
        member='COMPILED_PROJECTION_V1.json';raw=(json.dumps(projection,indent=2)+'\n').encode();z.writestr(member,raw)
        members[member]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
    with zipfile.ZipFile(archive) as z:
        assert len(z.namelist())==len(set(z.namelist()))==len(members)
        for member,item in members.items():
            raw=z.read(member);assert len(raw)==item['bytes'] and hashlib.sha256(raw).hexdigest()==item['sha256']
    stored=store_original(archive,proof,name)
    q=dict(status='ACTUAL_MODEL7_SEARCH_WINDOWS_RAW_AND_RETAINED_CENSORS_PRESERVED_NO_ADMISSION',**stored,members=members,
        producer=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        contains_actual_original_saturation_matrices=True,contains_search_component_proof=True,
        contains_original_every_trial_day365_censors=True,contains_actual_full1096_water_CDE_O0_O2=True,
        all_current_windows_native_and_active_controls_included=True,whole_model_qualified=False,public_admission=False)
    record.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(q['status'],stored['bytes'],stored['sha256'],len(members),flush=True)


if __name__=='__main__':main()
