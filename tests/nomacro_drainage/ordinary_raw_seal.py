"""Retain actual ordinary Windows evidence once; never relabel producer bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--work',type=Path,required=True)
    a=p.parse_args();e=a.work/'evidence';proof=ROOT/'integration/f-ci/nomacro-complete01'
    files={};builds=set()
    def include(prefix,folder):
        for f in folder.rglob('*'):
            if f.is_file():
                assert not f.is_symlink()
                files[prefix+'/'+f.relative_to(folder).as_posix()]=f
                if f.name=='RESULT.json':
                    try:q=json.loads(f.read_text(encoding='utf-8'))
                    except (ValueError,UnicodeError):continue
                    def visit(v):
                        if isinstance(v,dict):
                            if isinstance(v.get('build_root'),str):
                                candidate=Path(v['build_root'])
                                if (candidate/'BUILD.json').is_file():builds.add(candidate)
                            for item in v.values():visit(item)
                        elif isinstance(v,list):
                            for item in v:visit(item)
                    visit(q)
    for folder in sorted(e.iterdir()):
        if folder.is_dir() and folder.name.startswith(('ordinary','weighted-history')):
            include('profiles/'+folder.name,folder)
        elif folder.is_file() and folder.name.startswith('ORDINARY'):
            files['observations/'+folder.name]=folder
    debug=a.work/'ordinary-weighted-history-diagnostic-v1'
    for folder in sorted(debug.iterdir()):
        if folder.is_dir() and folder.name!='source':
            for f in folder.rglob('*'):
                if f.is_file() and f.suffix.lower() in ('.f90','.exe','.json','.log','.txt'):
                    files['private-diagnostics/'+f.relative_to(debug).as_posix()]=f
    provider=Path('C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider/PREPARED.json')
    files['provider-PREPARED.json']=provider
    projection={}
    for i,build in enumerate(sorted(builds)):
        prefix='compiled/'+str(i)
        projection[str(build)]=dict(prefix=prefix,BUILD_sha256=hashlib.sha256((build/'BUILD.json').read_bytes()).hexdigest())
        for f in sorted(build.iterdir()):
            if f.is_file() and (f.name=='BUILD.json' or f.suffix.lower() in ('.f90','.exe','.dll','.so')):
                files[prefix+'/'+f.name]=f
    records={}
    for group in ('O0','O2','SUPPORT'):
        selected={}
        for name,path in files.items():
            label='O0' if 'O0' in name or ('/compiled/' in '/'+name and 'O0' in str(path)) else 'O2' if 'O2' in name or ('/compiled/' in '/'+name and 'O2' in str(path)) else 'SUPPORT'
            if group==label:selected[name]=path
        archive=proof/('ORDINARY_IMPLICIT_POND_WINDOWS_'+group+'_RAW_ARCHIVE.zip')
        record=archive.with_suffix('.json');assert not archive.exists() and not record.exists()
        members={}
        with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for name,path in sorted(selected.items()):
                raw=path.read_bytes();members[name]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest());z.writestr(name,raw)
            if group=='SUPPORT':
                raw=(json.dumps(projection,indent=2)+'\n').encode();name='COMPILED_PROJECTION_V1.json'
                members[name]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest());z.writestr(name,raw)
        q=dict(status='ACTUAL_ORIGINAL_ORDINARY_RAW_BYTES_SEALED_PENDING_ADMISSION',archive=archive.name,
               bytes=archive.stat().st_size,sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),members=members,
               sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
               producer_roles='Original receipts retain source paths, compiler identities, failed/censored and diagnostic roles; no rebinding',
               functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
        record.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');records[group]=dict(archive=archive.name,sha256=q['sha256'],bytes=q['bytes'],members=len(members))
        print(json.dumps(records[group]),flush=True)
    print('ACTUAL_ORDINARY_WINDOWS_RAW_SEALED',flush=True)


if __name__=='__main__':main()
