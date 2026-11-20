"""Seal actual Windows ordinary Snow undrained bytes once, preserving all failed roles."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

from groundwater_snow_archive_storage import store_original

ROOT=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True);a=p.parse_args()
    evidence=a.work/'evidence';proof=ROOT/'integration/f-ci/nomacro-complete01';files={};builds=set()
    def visit(value):
        if isinstance(value,dict):
            for key in ('build_root','current_build','actual_original_build'):
                if isinstance(value.get(key),str):
                    path=Path(value[key])
                    if path.is_relative_to(a.work) and path.relative_to(a.work).parts[0].startswith('snow-undrained-') and (path/'BUILD.json').is_file():builds.add(path)
            for child in value.values():visit(child)
        elif isinstance(value,list):
            for child in value:visit(child)
    for item in sorted(evidence.iterdir()):
        if item.is_dir() and item.name.startswith('snow-undrained-'):
            for file in sorted(item.rglob('*')):
                if file.is_file():
                    assert not file.is_symlink();files['profiles/'+file.relative_to(evidence).as_posix()]=file
                    if file.name=='RESULT.json':
                        try:visit(json.loads(file.read_text(encoding='utf-8')))
                        except (ValueError,UnicodeError):pass
        elif item.is_file() and item.name.startswith('SNOW_UNDRAINED_') and item.suffix.lower()!='.zip':
            files['observations/'+item.name]=item
    for name in ('snow-undrained-controller-source-v1.tar','snow-undrained-controller-source-v2.tar','snow-undrained-controller-source-v3.tar'):
        if (evidence/name).is_file():files['observations/'+name]=evidence/name
    files['provider-PREPARED.json']=Path('C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider/PREPARED.json')
    files['provider-MOD_meteo.f90']=Path('C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider/build/swap-selected/MOD_meteo.f90')
    projection={}
    for index,bundle in enumerate(sorted(builds)):
        prefix='compiled/'+str(index);projection[str(bundle)]=dict(prefix=prefix,actual_BUILD_sha256=hashlib.sha256((bundle/'BUILD.json').read_bytes()).hexdigest())
        for file in sorted(bundle.iterdir()):
            if file.is_file() and (file.name=='BUILD.json' or file.suffix.lower() in ('.f90','.exe','.dll','.so')):files[prefix+'/'+file.name]=file
    failed=a.work/'snow-undrained-source-O0-v1/water-explicit-flux-daily/bundle'
    if failed.is_dir() and not (failed/'BUILD.json').exists():
        for file in sorted(failed.iterdir()):
            if file.is_file() and file.suffix.lower() in ('.f90','.exe','.dll','.so'):
                files['compiled-failed/source-O0-v1/'+file.name]=file
    assigned={}
    for name,file in files.items():
        opt='O0' if 'O0' in name or name.startswith('compiled/') and 'O0' in str(file) else 'O2' if 'O2' in name or name.startswith('compiled/') and 'O2' in str(file) else None
        control=any(token in name for token in ('-native-','-source-refusals-','-transactions-','-source-controls-'))
        assigned[name]='SUPPORT' if opt is None else opt+('_CONTROLS' if control else '_SCIENCE')
    for group in ('O0_SCIENCE','O0_CONTROLS','O2_SCIENCE','O2_CONTROLS','SUPPORT'):
        selected={name:file for name,file in files.items() if assigned[name]==group}
        name='SNOW_UNDRAINED_WINDOWS_'+group+'_RAW_ARCHIVE.zip'
        path=evidence/name;record=proof/Path(name).with_suffix('.json');assert not path.exists() and not record.exists()
        members={}
        with zipfile.ZipFile(path,'x',compression=zipfile.ZIP_DEFLATED) as z:
            for member,file in sorted(selected.items()):
                raw=file.read_bytes();z.writestr(member,raw);members[member]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
            if group=='SUPPORT':
                raw=(json.dumps(projection,indent=2)+'\n').encode();member='COMPILED_PROJECTION_V1.json';z.writestr(member,raw)
                members[member]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
        with zipfile.ZipFile(path) as z:
            assert set(z.namelist())==set(members)
            for member,item in members.items():
                raw=z.read(member);assert len(raw)==item['bytes'] and hashlib.sha256(raw).hexdigest()==item['sha256']
        stored=store_original(path,proof,name)
        q=dict(status='ACTUAL_ORIGINAL_SNOW_UNDRAINED_WINDOWS_RAW_SEALED_PENDING_ADMISSION',**stored,members=members,
            sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            role='Actual original inputs/BUILD/native/output/source and all failed/censored prototype roles; no producer rebinding',
            original_ubuntu_artifacts_stored_separately=True,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
        with record.open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')
        print(group,q['bytes'],q['sha256'],len(members),flush=True)


if __name__=='__main__':main()
