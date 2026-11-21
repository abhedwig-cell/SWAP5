"""Preserve actual model7 short postimages and all original observer refusals."""
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
    for directory in sorted(ev.iterdir()):
        if directory.is_dir() and directory.name.startswith('analytical-model7-postimages-'):
            for path in sorted(directory.rglob('*')):
                if path.is_file():files['profiles/'+path.relative_to(ev).as_posix()]=path
        elif directory.is_file() and directory.name=='ANALYTICAL_UNSELECTED_DISPATCH_INDEPENDENT_V1.json':
            files['observations/'+directory.name]=directory
    for opt in ('O0','O2'):
        q=json.loads((ev/f'analytical-model7-postimages-{opt}-v3/RESULT.json').read_text())
        assert q['status']=='ACTUAL_MODEL7_COMPLETE_COMPILED_NATIVE_SHORT_POSTIMAGES_EXACT_OLD_FULL_CONTROLS_REUSABLE' and len(q['contexts'])==2
    for directory in sorted(a.work.iterdir()):
        if not directory.is_dir() or not directory.name.startswith('analytical-model7-postimages-'):continue
        for path in sorted(directory.rglob('*')):
            if path.is_file() and (path.name=='BUILD.json' or path.suffix.lower() in ('.f90','.exe','.dll','.so')):
                files['builds/'+path.relative_to(a.work).as_posix()]=path
            if path.is_file() and path.name=='BUILD.json':
                projection[str(path.parent)]=dict(archive_prefix='builds/'+path.parent.relative_to(a.work).as_posix(),actual_BUILD_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    assert len(projection)==4
    name='HYDRAULIC_ANALYTICAL_POSTIMAGES_RAW_V1.zip';archive=ev/name;record=proof/Path(name).with_suffix('.json')
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
    q=dict(status='ACTUAL_ANALYTICAL_MODEL7_SHORT_POSTIMAGES_AND_ORIGINAL_OBSERVERS_PRESERVED_NO_ADMISSION',**stored,members=members,
        producer=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        fresh_unaffected_full_periods=0,actual_short_contexts=4,original_observer_refusals_retained=4,
        whole_model_qualified=False,public_admission=False)
    record.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(q['status'],stored['bytes'],stored['sha256'],len(members),flush=True)


if __name__=='__main__':main()
