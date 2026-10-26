#!/usr/bin/env python3
"""Build the ordinary native project bundle; reuse verified current providers."""
import argparse,hashlib,json,os,shlex,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--native-water',action='store_true');ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--optimization',choices=['O0','O2'],required=True)
 ap.add_argument('--physical-build',type=Path);ap.add_argument('--crop-reader',type=Path);ap.add_argument('--root-reader',type=Path)
 a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 events=[]
 def run(cmd,cwd,category):
  cmd=list(map(str,cmd));start=time.perf_counter();r=subprocess.run(cmd,cwd=cwd,capture_output=True);i=len(events)
  for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
  events.append(dict(command=cmd,category=category,seconds=time.perf_counter()-start,returncode=r.returncode));save()
  if r.returncode:raise RuntimeError(r.stdout.decode(errors='replace')+r.stderr.decode(errors='replace'))
 def save():(out/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 base=a.physical_build.resolve() if a.physical_build else out/'shared'
 if a.physical_build is None:
  run([sys.executable,ROOT/'tools/solute/build_crop_column.py','--output',base,'--optimization',a.optimization],ROOT,'cold_physical_build')
 physical=json.loads((base/'build-complete.json').read_text())
 assert physical['status']=='BUILT' and physical['provider_count']==194
 assert '-'+a.optimization in physical['flags'] and '-fcheck=all' in physical['flags']
 assert sha(base/'swap5_solute_column')==physical['executable_sha256']
 assert all(sha(ROOT/p)==h for p,h in physical['input_sha256'].items())
 assert all(sha(base/p)==h for p,h in physical['generated_input_sha256'].items())
 objects=[Path(e['command'][-1])for e in physical['events'] if e['category']=='compile' and not e['command'][-3].endswith('/app/solute_crop/main.f90')]
 assert len(objects)==193
 artifacts={str(p):sha(p)for p in objects+[base/'libttutil.a']+list(base.glob('*.mod'))}
 flags=[f for f in physical['flags']if not f.startswith('-J')]+['-I'+str(base)]
 fc=physical['compiler_command'];assert subprocess.check_output(fc+['--version'],text=True).splitlines()[0]==physical['compiler']
 common=[ROOT/'tools/solute/build_project.py',ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64',ROOT/'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64']
 def native(name,sources,marker):
  folder=out/name;folder.mkdir();exe=folder/('swap5_'+name)
  run(fc+flags+['-J'+str(folder),*sources,base/'libttutil.a','-o',exe],folder,'native_compile_link')
  meta=dict(status='BUILT',candidate=candidate,compiler_command=fc,compiler=physical['compiler'],flags=flags+['-J'+str(folder)],
    input_sha256={str(p.relative_to(ROOT)):sha(p)for p in sources+common},generated_input_sha256={},
    application_providers=len(sources),original_input_providers=153,executable_sha256=sha(exe),
    source_build=physical,reused_archive_sha256=artifacts[str(base/'libttutil.a')],marker=marker)
  (folder/'build-complete.json').write_text(json.dumps(meta,indent=2)+'\n');return exe
 project_reader=native('read_project',[ROOT/'src/crop/mod_crop_rotation_calendar.f90',ROOT/'app/solute_crop/read_swp_project.f90'],'SWP_NATIVE_PROJECT_PREPARED')
 crop=a.crop_reader.resolve()if a.crop_reader else native('read_crop',[ROOT/p for p in [
  'src/crop/mod_crop_fixed_phenology.f90','src/crop/mod_crop_rotation_calendar.f90','src/crop/mod_wofost_rate_table.f90',
  'src/crop/mod_crop_et_canopy_view_provider.f90','src/crop/mod_crop_root_depth_dvs.f90','src/process/mod_reference_et_demand_process.f90',
  'app/solute_crop/read_swp_crop.f90']],'SWP_NATIVE_SIMPLE_CROP_PREPARED')
 root=a.root_reader.resolve()if a.root_reader else native('read_root',[ROOT/'app/solute_crop/read_swp_root.f90'],'SWP_NATIVE_ROOT_IMPORTED')
 for exe in [crop,root]:
  meta=json.loads((exe.parent/'build-complete.json').read_text());assert meta['status']=='BUILT' and sha(exe)==meta['executable_sha256']
  assert all(sha(ROOT/p)==h for p,h in meta['input_sha256'].items())
 column=out/'column';column.mkdir();exe=column/'swap5_solute_project';driver=ROOT/('app/solute_project/main_water.f90'if a.native_water else'app/solute_project/main.f90')
 heat_reader=ROOT/'app/solute_column/read_swp_heat.f90'
 extra=[ROOT/p for p in ['app/solute_column/read_swp_macro_geometry.f90','app/solute_column/read_swp_macro_initial.f90','app/solute_column/read_swp_macro_configuration.f90','app/solute_column/macro_water_restart.f90']]if a.native_water else[]
 run(fc+flags+['-J'+str(column),*extra,heat_reader,driver,*objects,base/'libttutil.a','-o',exe],column,'project_compile_link')
 if a.native_water:
  if len(fc)!=1:raise ValueError('native source reader requires a compiler executable wrapper')
  macro_build=out/'read_macro'
  run([sys.executable,ROOT/'tools/solute/build_macro_geometry_reader.py','--initial-state','--fc',fc[0],
    '--input-build',base,'--optimization',a.optimization,'--output',macro_build],ROOT,'native_macro_reader')
 inputs={p:h for p,h in physical['input_sha256'].items()if p!='app/solute_crop/main.f90'}
 inputs.update({str(p.relative_to(ROOT)):sha(p)for p in [driver,heat_reader,*extra,*common]})
 meta=dict(status='BUILT',candidate=candidate,compiler_command=fc,compiler=physical['compiler'],flags=flags+['-J'+str(column)],
  provider_count=194,reused_provider_objects=193,input_sha256=inputs,generated_input_sha256={},
  source_build=physical,reused_artifact_sha256=artifacts,executable_sha256=sha(exe),events=events)
 assert all(sha(ROOT/p)==h for p,h in inputs.items())and all(sha(Path(p))==h for p,h in artifacts.items())
 (column/'build-complete.json').write_text(json.dumps(meta,indent=2)+'\n')
 bundle=dict(schema=1,status='BUILT',optimization=a.optimization,project_reader=str(project_reader),crop_reader=str(crop),root_reader=str(root),exe=str(exe),
  executable_sha256={str(p):sha(p)for p in [project_reader,crop,root,exe]},physical_build=physical)
 if a.native_water:
  bundle['native_water']=True;bundle['macro_reader']=str(macro_build/'swap5_read_macro_initial')
  bundle['executable_sha256'][bundle['macro_reader']]=sha(Path(bundle['macro_reader']))
 (out/'bundle.json').write_text(json.dumps(bundle,indent=2)+'\n');print(json.dumps(dict(status='BUILT',reused_providers=193)))
if __name__=='__main__':main()
