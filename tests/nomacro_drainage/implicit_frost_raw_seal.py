"""Seal actual implicit Frost Windows successes, initial refusals and source bytes once."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile
from groundwater_snow_archive_storage import store_original

ROOT=Path(__file__).resolve().parents[2]
SHA=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True)
    a=p.parse_args();ev=a.work/'evidence';proof=ROOT/'integration/f-ci/nomacro-complete01'
    files={};projection={}
    for directory in sorted(ev.glob('frost-implicit-*')):
        if directory.is_dir():
            for path in sorted(directory.rglob('*')):
                if path.is_file():
                    assert not path.is_symlink();files['profiles/'+path.relative_to(ev).as_posix()]=path
        elif directory.suffix in ('.tar','.json'):files['observations/'+directory.name]=directory
    for path in sorted(ev.glob('FROST_IMPLICIT_*.json')):files['observations/'+path.name]=path
    for directory in sorted(a.work.glob('frost-implicit-*')):
        if not directory.is_dir():continue
        for path in sorted(directory.rglob('*')):
            if not path.is_file():continue
            relative=path.relative_to(a.work)
            # Preserve real generated sources/binaries from failed and completed
            # roles, changed original reader inputs and their actual bindings.
            parts=path.relative_to(directory).parts
            input_mutant=any(part.startswith('input-') for part in parts)
            source_mutants=[part for part in parts if part.startswith('source-')]
            source_mutant=bool(source_mutants) and path.name in (source_mutants[-1][7:],'BUILD.json')
            if input_mutant or source_mutant or (not source_mutants and (path.name=='BUILD.json' or path.suffix.lower() in ('.f90','.exe','.dll','.so'))):
                files['builds/'+relative.as_posix()]=path
            if path.name=='BUILD.json' and not source_mutants:
                projection[str(path.parent)]=dict(prefix='builds/'+path.parent.relative_to(a.work).as_posix(),actual_BUILD_sha256=SHA(path))
    provider=Path('C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider')
    files['provider-PREPARED.json']=provider/'PREPARED.json'
    for path in sorted((provider/'build').rglob('*')):
        if path.is_file():files['original-provider-build/'+path.relative_to(provider/'build').as_posix()]=path
    assigned={}
    for member,path in files.items():
        group='SUPPORT'
        if 'O0' in member:group='O0'
        elif 'O2' in member:group='O2'
        if group!='SUPPORT':group+='_CONTROLS' if 'controls' in member else '_SCIENCE'
        assigned[member]=group
    for group in ('O0_SCIENCE','O0_CONTROLS','O2_SCIENCE','O2_CONTROLS','SUPPORT'):
        name='FROST_IMPLICIT_WINDOWS_'+group+'_RAW_ARCHIVE.zip'
        archive=ev/name;record=proof/Path(name).with_suffix('.json');assert not archive.exists() and not record.exists()
        members={}
        with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
            for member,path in sorted(files.items()):
                if assigned[member]!=group:continue
                raw=path.read_bytes();z.writestr(member,raw);members[member]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
            if group=='SUPPORT':
                member='COMPILED_PROJECTION_V1.json';raw=(json.dumps(projection,indent=2)+'\n').encode()
                z.writestr(member,raw);members[member]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
        with zipfile.ZipFile(archive) as z:
            assert len(z.namelist())==len(set(z.namelist()))==len(members)
            for member,item in members.items():
                raw=z.read(member);assert len(raw)==item['bytes'] and hashlib.sha256(raw).hexdigest()==item['sha256']
        stored=store_original(archive,proof,name)
        q=dict(status='NEUTRAL_ORIGINAL_IMPLICIT_FROST_WINDOWS_RAW_SEALED_PENDING_ADMISSION',**stored,members=members,
            sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            original_FI001_roles_preserved_not_counted_as_final_native2=True,canonical_admission=False)
        record.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
        print(group,stored['bytes'],stored['sha256'],len(members),flush=True)


if __name__=='__main__':main()
