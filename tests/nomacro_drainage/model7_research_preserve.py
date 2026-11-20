"""Preserve original and pre-candidate model7 research once before build cleanup."""
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
    prefixes=('hydraulic-constitutive-','hydraulic-model7-grid-','model7-capacity-','model7-terminal-')
    for directory in sorted(ev.iterdir()):
        if directory.is_dir() and directory.name.startswith(prefixes):
            for path in sorted(directory.rglob('*')):
                if path.is_file():files['profiles/'+path.relative_to(ev).as_posix()]=path
        elif directory.is_file() and directory.suffix in ('.json','.txt') and directory.name.startswith(('HYDRAULIC_CONSTITUTIVE_','HYDRAULIC_MODEL7_','MODEL7_CAPACITY_','MODEL7_TERMINAL_','MODEL7_INDEPENDENT_')):
            files['observations/'+directory.name]=directory
    for directory in sorted(a.work.iterdir()):
        if not directory.is_dir() or not directory.name.startswith(prefixes):continue
        for path in sorted(directory.rglob('*')):
            if path.is_file() and (path.name=='BUILD.json' or path.suffix.lower() in ('.f90','.exe','.dll','.so')):
                files['builds/'+path.relative_to(a.work).as_posix()]=path
            if path.is_file() and path.name=='BUILD.json':
                projection[str(path.parent)]=dict(archive_prefix='builds/'+path.parent.relative_to(a.work).as_posix(),actual_BUILD_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    name='HYDRAULIC_MODEL7_PRETERMINAL_RESEARCH_RAW_V1.zip';archive=ev/name;record=proof/Path(name).with_suffix('.json')
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
    q=dict(status='ORIGINAL_AND_RETAINED_MODEL7_RESEARCH_RAW_PRESERVED_NO_ADMISSION',**stored,members=members,
        producer=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        contains_original_capacity_mismatches=True,contains_corrected_component_proof=True,
        contains_original_salinity_input_refusals=True,contains_capacity_only_and_end_only_day364_refusals=True,
        current_every_trial_candidate_roles_not_included=True,whole_model_qualified=False,public_admission=False)
    record.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(q['status'],stored['bytes'],stored['sha256'],len(members),flush=True)


if __name__=='__main__':main()
