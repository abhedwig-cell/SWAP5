"""Seal actual Windows interval/drainage evidence once, retaining all failed probe roles."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True);a=p.parse_args()
    evidence=a.work/'evidence';proof=ROOT/'integration/f-ci/nomacro-complete01';files={};builds=set()
    def visit(v):
        if isinstance(v,dict):
            for key in ('build_root','current_build'):
                if isinstance(v.get(key),str):
                    path=Path(v[key])
                    if (path/'BUILD.json').is_file():builds.add(path)
            for item in v.values():visit(item)
        elif isinstance(v,list):
            for item in v:visit(item)
    for folder in sorted(evidence.iterdir()):
        if folder.is_dir() and folder.name.startswith('groundwater-interval'):
            for file in folder.rglob('*'):
                if file.is_file():
                    assert not file.is_symlink();files['profiles/'+file.relative_to(evidence).as_posix()]=file
                    if file.name=='RESULT.json':
                        try:visit(json.loads(file.read_text(encoding='utf-8')))
                        except (ValueError,UnicodeError):pass
        elif folder.is_file() and folder.name.startswith('GROUNDWATER_INTERVAL_'):
            files['observations/'+folder.name]=folder
    files['provider-PREPARED.json']=Path('C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider/PREPARED.json')
    projection={}
    for index,bundle in enumerate(sorted(builds)):
        prefix='compiled/'+str(index);projection[str(bundle)]=dict(prefix=prefix,actual_BUILD_sha256=hashlib.sha256((bundle/'BUILD.json').read_bytes()).hexdigest())
        for file in bundle.iterdir():
            if file.is_file() and (file.name=='BUILD.json' or file.suffix.lower() in ('.f90','.exe','.dll','.so')):files[prefix+'/'+file.name]=file
    for group in ('O0_SCIENCE','O0_CONTROLS','O2_SCIENCE','O2_CONTROLS','SUPPORT'):
        selected={}
        for name,file in files.items():
            label='O0' if 'O0' in name or name.startswith('compiled/') and 'O0' in str(file) else 'O2' if 'O2' in name or name.startswith('compiled/') and 'O2' in str(file) else 'SUPPORT'
            control=any(token in name for token in ('/groundwater-interval-controls-','/groundwater-interval-source-controls-','/groundwater-interval-control-cohort-'))
            if label!='SUPPORT':label+='_'+('CONTROLS' if control else 'SCIENCE')
            if label==group:selected[name]=file
        path=proof/f'GROUNDWATER_CDE_INTERVAL_WINDOWS_{group}_RAW_ARCHIVE.zip';record=path.with_suffix('.json');assert not path.exists() and not record.exists();members={}
        with zipfile.ZipFile(path,'x',compression=zipfile.ZIP_DEFLATED) as z:
            for name,file in sorted(selected.items()):
                raw=file.read_bytes();members[name]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest());z.writestr(name,raw)
            if group=='SUPPORT':
                raw=(json.dumps(projection,indent=2)+'\n').encode();name='COMPILED_PROJECTION_V1.json'
                members[name]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest());z.writestr(name,raw)
        q=dict(status='ACTUAL_ORIGINAL_GROUNDWATER_INTERVAL_WINDOWS_RAW_SEALED_PENDING_ADMISSION',archive=path.name,
               bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),members=members,
               sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
               role='Original producer/BUILD/input/native/source identities and failed observers preserved without rebinding',
               functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
        record.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(group,q['bytes'],q['sha256'],len(members),flush=True)


if __name__=='__main__':main()
