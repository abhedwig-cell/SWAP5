"""Preserve six actual default-model postimages, failures and source custody once."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
RUNTIME='a5038b98597e9ff83364aa454b7250387c3716be'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True);a=p.parse_args()
    ev=a.work/'evidence';proof=ROOT/'integration/f-ci/nomacro-complete01';files={};compiled={};roles=[]
    def add_tree(root,prefix):
        assert root.is_dir() and not root.is_symlink()
        for path in sorted(root.rglob('*')):
            assert not path.is_symlink()
            if path.is_file():
                name=prefix+'/'+path.relative_to(root).as_posix();assert name not in files;files[name]=path
    for directory in sorted(ev.iterdir()):
        if directory.is_dir() and (directory.name.startswith(('default-model-grammar-','signed-default-dispatch-assessment-')) or directory.name=='original-signed-default-reader-v1'):
            add_tree(directory,'profiles/'+directory.name)
    for opt in ('O0','O2'):
        q=json.loads((ev/f'default-model-grammar-{opt}-v3/RESULT.json').read_text())
        assert q['status']=='THREE_ACTUAL_DEFAULT_MODEL_STATE_OWNER_POSTIMAGES_PASS_NOT_ADMITTED' and len(q['profiles'])==3
        for name,item in q['profiles'].items():
            assert len(item['cold'])==2 and not item['whole_Fortran_delta']
            build=Path(item['build_root']);prefix=f'compiled/{opt}/{name}';add_tree(build,prefix)
            compiled[item['build_root']]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()))
            assert compiled[item['build_root']]['actual_BUILD_sha256']==item['actual_BUILD_sha256']
        roles.append(dict(optimization=opt,profile=f'profiles/default-model-grammar-{opt}-v3'))
    for path in sorted(ev.glob('DEFAULT_MODEL_GRAMMAR_*')):
        assert path.is_file();files['observations/'+path.name]=path
    for name in ('original_signed_default_reader_v1.py','signed_default_dispatch_assessment_v1.py','signed_default_dispatch_assessment_initial_v1.py'):files['observations/'+name]=ev/name
    extra={'COMPILED_PROJECTION_V1.json':(json.dumps(compiled,indent=2)+'\n').encode()}
    scopes=('app','src','tools/solute','tools/vq','reference/swap-4.3.1')
    assert not subprocess.check_output(['git','diff',RUNTIME,'--',*scopes],cwd=ROOT)
    capsule=subprocess.check_output(['git','archive','--format=tar',RUNTIME,*scopes],cwd=ROOT)
    extra['actual-runtime-source.tar']=capsule;source={}
    with tarfile.open(fileobj=io.BytesIO(capsule)) as tar:
        for member in tar:
            if member.isdir():continue
            assert member.isfile() and not member.name.startswith('/') and '..' not in member.name.split('/')
            original=tar.extractfile(member).read();actual_path=ROOT/member.name
            actual=actual_path.read_bytes() if actual_path.is_file() else None
            if actual is not None:assert actual.replace(b'\r\n',b'\n')==original.replace(b'\r\n',b'\n')
            source[member.name]=dict(git_bytes=len(original),git_sha256=SHA(original),actual_working_sha256=SHA(actual) if actual is not None else None)
            if actual is not None and actual!=original:extra['actual-working-source/'+member.name]=actual
    extra['SOURCE_CUSTODY_V1.json']=(json.dumps(dict(runtime=RUNTIME,git_tar_sha256=SHA(capsule),members=source,actual_working_bytes_preserved_where_distinct=True,scientific_fixture_bytes_never_rewritten=True),indent=2)+'\n').encode()
    archive=proof/'HYDRAULIC_DEFAULT_MODEL_GRAMMAR_WINDOWS_RAW_V1.zip';assert not archive.exists() and not archive.with_suffix('.json').exists()
    members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()}
    assert not set(files)&set(extra);members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()})
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for name,path in sorted(files.items()):z.write(path,name)
        for name,raw in sorted(extra.items()):z.writestr(name,raw)
    with zipfile.ZipFile(archive) as z:
        assert len(z.namelist())==len(set(z.namelist()))==len(members)
        for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
    q=dict(status='ACTUAL_DEFAULT_MODEL_GRAMMAR_WINDOWS_SOURCE_RAW_POSTIMAGES_SEALED_NOT_ADMITTED',archive=archive.name,bytes=archive.stat().st_size,sha256=SHA(archive.read_bytes()),members=members,roles=roles,runtime=RUNTIME,sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),actual_short35_contexts=6,actual_exact_cold_windows=12,actual_frontend_controls=90,fresh_full_periods=0,completed_warm_or_cold_periods_not_repeated_after_observer_fixes=True,original_failed_observers_preserved=True,canonical_admission=False,original_provider_dependency='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1: immutable complete original Windows provider')
    q['parts']=[dict(file=archive.name,bytes=q['bytes'],sha256=q['sha256'])]
    archive.with_suffix('.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],q['bytes'],q['sha256'],len(members))


if __name__=='__main__':main()
