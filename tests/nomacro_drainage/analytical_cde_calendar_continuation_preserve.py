"""Seal selector-repair builds and later observations without rewriting old raw."""
import argparse,json,subprocess,zipfile
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from analytical_cde_calendar_source_inverse import CORE,PREVIOUS_CORE,complete_inverse
ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);a=p.parse_args();ev=a.evidence;proof=ROOT/'integration/f-ci/nomacro-complete01';complete_inverse();files={};projection={};roles=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for item in sorted(path.rglob('*')):
   assert not item.is_symlink()
   if item.is_file():name=prefix+'/'+item.relative_to(path).as_posix();assert name not in files;files[name]=item
 for path in sorted(ev.glob('analytical-cde-calendar-unselected-*')):
  if not path.is_dir():continue
  q=json.loads((path/'RESULT.json').read_text());assert q['status']!='RUNNING' and q['model_executions']==0;build=Path(q['build_root']);tree(path,'profiles/'+path.name);tree(build,'compiled/'+path.name)
  projection[str(build)]=dict(archive_prefix='compiled/'+path.name,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()) if (build/'BUILD.json').is_file() else None)
  roles.append(dict(profile='profiles/'+path.name,inputs='profiles/'+path.name+'/input',codec=q['codec'],status=q['status']))
 assert len(roles)==8
 with ExitStack() as stack:
  old=Archive(proof,'ANALYTICAL_CDE_CALENDAR_WINDOWS_RAW_V1',stack)
  for path in sorted(ev.iterdir()):
   if not path.is_file() or not path.name.lower().startswith(('analytical_cde_calendar','analytical-cde-calendar')):continue
   name='observations/'+path.name;raw=path.read_bytes()
   if name in old.names:
    assert raw==old.get(name),'An original sealed observation was modified';continue
   files[name]=path
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode()}
 for path in sorted((ROOT/'tests/nomacro_drainage').glob('analytical_cde_calendar*.py')):extra['controller-current/tests/nomacro_drainage/'+path.name]=path.read_bytes()
 path='app/hybrid_water/model7_terminal_water.py'
 for epoch in (PREVIOUS_CORE,'1f869b2fbbe385c29790cd7f719df87b85d83750',CORE):extra['source-history/'+epoch+'/'+path]=subprocess.check_output(['git','show',epoch+':'+path],cwd=ROOT)
 extra['SOURCE_CUSTODY_V1.json']=(json.dumps(dict(runtime=CORE,prior_composed_runtime=PREVIOUS_CORE,whole_correction='Exactly one if selected is None:return None guard; complete original module restored when removed',model_periods_repeated=0,original_raw_rewritten=False),indent=2)+'\n').encode()
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()};members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()})
 name='ANALYTICAL_CDE_CALENDAR_POSTIMAGE_RAW_V1';archive=proof/(name+'.zip');assert not archive.exists() and not archive.with_suffix('.json').exists()
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for key,path in sorted(files.items()):z.write(path,key)
  for key,raw in sorted(extra.items()):z.writestr(key,raw)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for key,item in members.items():raw=z.read(key);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 size=archive.stat().st_size;digest=SHA(archive.read_bytes());assert size<90*1024*1024
 record=dict(status='ACTUAL_DENSE_SELECTOR_REPAIR_AND_FIVE_COMPLETE_COMPILED_POSTIMAGES_CUSTODY_SEALED_NOT_ADMITTED',archive=archive.name,bytes=size,sha256=digest,parts=[dict(file=archive.name,bytes=size,sha256=digest)],members=members,roles=roles,runtime=CORE,sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),original_main_Windows_raw_unchanged=True,actual_postimage_build_observations=8,successful_final_representative_postimages=5,model_executions=0,canonical_admission=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],size,digest,len(members))


if __name__=='__main__':main()
