"""Preserve only explicit-guard continuation and exact new compiled postimages."""
import argparse,json,subprocess,zipfile
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import SHA,Archive
ROOT=Path(__file__).resolve().parents[2]
CORE='c1e1dd81382926053a42cda6260874483dab37b1'


def main():
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);a=p.parse_args();ev=a.evidence;proof=ROOT/'integration/f-ci/nomacro-complete01';git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT);assert not git('diff',CORE,'--','app','src','tools/solute','tools/vq','reference');files={};projection={};roles=[];postimages=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for p in sorted(path.rglob('*')):
   assert not p.is_symlink()
   if p.is_file():name=prefix+'/'+p.relative_to(path).as_posix();assert name not in files;files[name]=p
 for opt in ('O0','O2'):
  name=f'vapor-boundary-closed-unit8-active-cde7-8-{opt}-v2';path=ev/name;q=json.loads((path/'RESULT.json').read_text());assert q['status']=='ACTUAL_VAPOR_BOUNDARY_NATIVE5_WATER_CDE_ORIGINAL_OUTPUT_EXACT_COLD_PASS_NOT_ADMITTED' and q['days']==35 and len(q['cold'])==3;tree(path,'profiles/'+name);build=Path(q['build_root']);tree(build,'compiled/'+name);projection[q['build_root']]=dict(archive_prefix='compiled/'+name,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()));roles.append(dict(profile='profiles/'+name,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),independent='observations/'+name+'-INDEPENDENT.json',kind='cde'))
  observed=json.loads((ev/(name+'-INDEPENDENT.json')).read_text());assert observed['CDE_initial_stock']>0
  name=f'vapor-boundary-guard-open-postimage-{opt}-v1';path=ev/name;q=json.loads((path/'RESULT.json').read_text());assert q['status']=='ACTUAL_NATIVE5_EXPLICIT_GUARD_COMPILED_POSTIMAGE_OLD_RUN_INHERITANCE_PASS_NO_MODEL_REPEAT' and q['model_executions']==0;tree(path,'profiles/'+name);build=Path(q['build_root']);tree(build,'compiled/'+name);projection[q['build_root']]=dict(archive_prefix='compiled/'+name,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()));postimages.append('profiles/'+name)
 for name in ('vapor-boundary-closed-inputs-v1','vapor-boundary-closed-inputs-v2'):tree(ev/name,'profiles/'+name)
 for opt in ('O0','O2'):
  name=f'vapor-boundary-closed-unit8-active-cde7-8-{opt}-v1';assert 'Unimplemented experimental selector: SWINCO=1' in (ev/(name+'.stderr.txt')).read_text() and not (ev/name/'RESULT.json').exists();assert not any((ev.parent/name).iterdir())
 for path in ev.iterdir():
  if path.is_file() and path.name.lower().startswith(('vapor-boundary-closed-','vapor-boundary-guard-','vapor_boundary_guard_')):files['observations/'+path.name]=path
 changed=git('diff','--name-only','9cde60cff60e1a0b2d4a21019e69eefb1007bd8b',CORE,'--','app','src','tools/solute','tools/vq','reference').decode().splitlines();assert changed==['app/hybrid_water/vapor_boundary_composition.py'];extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode()}
 for path in changed:
  raw=git('show',CORE+':'+path);actual=(ROOT/path).read_bytes();assert actual.replace(b'\r\n',b'\n')==raw;extra['source-delta/git/'+path]=raw
  if actual!=raw:extra['source-delta/actual-working/'+path]=actual
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()};members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()});archive=proof/'HYDRAULIC_VAPOR_BOUNDARY_GUARD_WINDOWS_RAW_V1.zip';assert not archive.exists() and not archive.with_suffix('.json').exists()
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for name,path in sorted(files.items()):z.write(path,name)
  for name,raw in sorted(extra.items()):z.writestr(name,raw)
 size=archive.stat().st_size;digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_WINDOWS_NATIVE5_EXPLICIT_GUARD_CONTINUATION_RAW_SEALED_NOT_ADMITTED',runtime=CORE,parent_runtime='9cde60cff60e1a0b2d4a21019e69eefb1007bd8b',parent_archive='HYDRAULIC_VAPOR_BOUNDARY_WINDOWS_RAW_V1',parent_archive_sha256='99f1cb18503d226db2aa2f1ccafa3183aa023a84f5880ab38689cbed8586aa9c',archive=archive.name,bytes=size,sha256=digest,parts=[dict(file=archive.name,bytes=size,sha256=digest)],members=members,roles=roles,postimages=postimages,sealer_source=git('rev-parse','HEAD').decode().strip(),new_short35_contexts=2,new_exact_cold_windows=6,new_native_checkpoints=14,new_exact_private_CDE_stocks=14,actual_compiled_postimages_without_model_repeat=2,unchanged_native5_decoder_controls_repeated=0,retained_initialization_refusals_before_compiler_or_models=2,canonical_admission=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
 with ExitStack() as stack:
  central=Archive(proof,archive.stem,stack)
  for name in members:central.get(name)
 print(record['status'],size,digest,len(members))


if __name__=='__main__':main()
