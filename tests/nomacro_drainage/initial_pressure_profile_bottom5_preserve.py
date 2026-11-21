"""Append only the two new undrained prescribed-head initialization contexts."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);a=p.parse_args();ev=a.evidence;proof=ROOT/'integration/f-ci/nomacro-complete01';files={};projection={};roles=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for item in path.rglob('*'):
   assert not item.is_symlink()
   if item.is_file():name=prefix+'/'+item.relative_to(path).as_posix();assert name not in files;files[name]=item
 for opt in ('O0','O2'):
  name='initial-pressure-head5-undrained-cde-'+opt+'-v1';profile=ev/name;q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_INITIAL_PRESSURE_PROFILE_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED' and q['days']==35 and len(q['cold'])==3
  independent=json.loads((ev/(name+'-INDEPENDENT.json')).read_text());assert independent['cold_windows']==3 and independent['exact_private_CDE_stocks']==7 and independent['CDE_initial_stock']>0
  tree(profile,'profiles/'+name);build=Path(q['build_root']);tree(build,'compiled/'+name);projection[q['build_root']]=dict(archive_prefix='compiled/'+name,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()));roles.append(dict(profile='profiles/'+name,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),independent='observations/'+name+'-INDEPENDENT.json',kind='cde'))
 tree(ev/'initial-pressure-profile-bottom5-continuation-inputs-v1','profiles/initial-pressure-profile-bottom5-continuation-inputs-v1')
 for path in ev.iterdir():
  if path.is_file() and path.name.lower().startswith(('initial-pressure-head5-','initial_pressure_profile_bottom5','initial_pressure_profile_continuation')):files['observations/'+path.name]=path
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode()};members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()};members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()});archive=proof/'HYDRAULIC_INITIAL_PRESSURE_BOTTOM5_WINDOWS_RAW_V1.zip';assert not archive.exists() and not archive.with_suffix('.json').exists()
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for name,path in sorted(files.items()):z.write(path,name)
  for name,raw in sorted(extra.items()):z.writestr(name,raw)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 size=archive.stat().st_size;digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_TWO_NEW_UNDRAINED_BOTTOM5_INITIAL_PRESSURE_CONTEXTS_SEALED_NOT_ADMITTED',runtime='9e19329049ef92705fdca98948b4c4c1baba2ffa',parent_archive_sha256='3e6b9995ec97781060d32d1bad8fb557e4903dd73f10b4946a3b8100c3d3ce59',archive=archive.name,bytes=size,sha256=digest,parts=[dict(file=archive.name,bytes=size,sha256=digest)],members=members,roles=roles,new_short35_contexts=2,new_exact_cold_windows=6,new_native_checkpoints=14,new_private_CDE_stocks=14,sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),old_archives_or_receipts_rewritten=False,canonical_admission=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],size,digest,len(members))


if __name__=='__main__':main()
