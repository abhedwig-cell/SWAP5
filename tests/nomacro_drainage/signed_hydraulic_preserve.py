"""Preserve actual signed-selector inputs, compiled closures and observations once."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--evidence',type=Path,required=True);a=p.parse_args()
    ev=a.evidence;proof=ROOT/'integration/f-ci/nomacro-complete01';files={};compiled={};roles=[]
    def add_tree(path,prefix):
        assert path.is_dir() and not path.is_symlink()
        for file in sorted(path.rglob('*')):
            assert not file.is_symlink()
            if file.is_file():
                name=prefix+'/'+file.relative_to(path).as_posix();assert name not in files;files[name]=file
    for kind in ('water','cde'):
        for opt in ('O0','O2'):
            name=f'signed-hydraulic-mixed-7-8-{kind}-{opt}-v1';profile=ev/name;q=json.loads((profile/'RESULT.json').read_text())
            assert q['status']==f'CANDIDATE_ACTUAL_VAPOR_FAMILY_8_{kind.upper()}_SHORT_PASS_NOT_ADMITTED'
            assert q['source'].startswith('8672c751d') and len(q['own'])==3
            add_tree(profile,'profiles/'+name);build=Path(q['build_root']);prefix=f'compiled/{kind}/{opt}'
            add_tree(build,prefix);compiled[q['build_root']]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()))
            for suffix in ('.stdout.txt','.stderr.txt'):files['profiles/'+name+suffix]=ev/(name+suffix)
            roles.append(dict(kind=kind,optimization=opt,profile='profiles/'+name))
    for name in ('signed-hydraulic-inputs-v1','signed-hydraulic-parser-controls-v1','original-signed-hydraulic-reader-v1'):add_tree(ev/name,'profiles/'+name)
    for name in ('SIGNED_HYDRAULIC_COMPILED_POSTIMAGES_V1.json','SIGNED_HYDRAULIC_DISPATCH_CANDIDATE_V1.json','SIGNED_HYDRAULIC_POSTIMAGE_OBSERVER_INITIAL_FAILURE_V1.stdout.txt','SIGNED_HYDRAULIC_POSTIMAGE_OBSERVER_INITIAL_FAILURE_V1.stderr.txt','original_signed_hydraulic_reader_v1.py','signed_hydraulic_dispatch_candidate_v1.py'):
        files['observations/'+name]=ev/name
    runtime='8672c751d';source_paths=subprocess.check_output(['git','ls-tree','-r','--name-only',runtime,'--','app','src','tools/solute','tools/vq','reference/swap-4.3.1'],cwd=ROOT,text=True).splitlines()
    sources={path:subprocess.check_output(['git','show',runtime+':'+path],cwd=ROOT) for path in source_paths}
    archive=proof/'HYDRAULIC_SIGNED_SELECTORS_WINDOWS_RAW_V1.zip';assert not archive.exists() and not archive.with_suffix('.json').exists()
    members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()}
    extra={'COMPILED_PROJECTION_V1.json':(json.dumps(compiled,indent=2)+'\n').encode()}
    extra.update({'actual-runtime-source/'+path:raw for path,raw in sources.items()})
    assert not set(files)&set(extra)
    members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()})
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for name,path in sorted(files.items()):z.write(path,name)
        for name,raw in sorted(extra.items()):z.writestr(name,raw)
    with zipfile.ZipFile(archive) as z:
        assert len(z.namelist())==len(set(z.namelist()))==len(members)
        for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
    q=dict(status='ACTUAL_ORIGINAL_SIGNED_HYDRAULIC_WINDOWS_RAW_SEALED_NOT_ADMITTED',archive=archive.name,bytes=archive.stat().st_size,sha256=SHA(archive.read_bytes()),members=members,roles=roles,runtime=subprocess.check_output(['git','rev-parse',runtime],cwd=ROOT,text=True).strip(),sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),actual_short35_contexts=4,actual_exact_cold_windows=12,new_full_periods=0,original_reader_startups=3,parser_controls=38,original_provider_dependency='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1: immutable complete original provider',original_unsigned_full_dependencies=['HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1','HYDRAULIC_VAPOR_WINDOWS_CDE_RAW_V1'],canonical_admission=False)
    q['parts']=[dict(file=archive.name,bytes=q['bytes'],sha256=q['sha256'])]
    archive.with_suffix('.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],q['bytes'],q['sha256'],len(members))


if __name__=='__main__':main()
