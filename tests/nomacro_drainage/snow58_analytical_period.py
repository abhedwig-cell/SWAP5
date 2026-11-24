"""One actual full Snow5/8 context, optionally using its untouched short build."""
import argparse,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from explicit_bottom9_runtime import m,own
from snow58_analytical_source import complete_inverse,git,CORE
from analytical_snow_undrained import selection
from model7_capacity import analytical_models
from analytical_hydraulic_archives import SHA


def main():
 p=argparse.ArgumentParser()
 for name in ('input','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--build-root',type=Path);p.add_argument('--reuse-profile',type=Path)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();assert bool(a.build_root)!=bool(a.reuse_profile)
 complete_inverse();head=git('rev-parse','HEAD').decode().strip();a.output.mkdir()
 project=m.e.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1');selected=selection(a.input,True);assert selected
 kind='cde' if project.solute else 'water';models=analytical_models(project);assert models==tuple(selected['models'])
 build=a.build_root/'bundle' if a.build_root else None
 q=dict(status='RUNNING',source=head,observer_source=head,composition_core=CORE,case='snow58-'+str(selected['bottom'])+'-'+str(list(models))+'-'+kind,kind=kind,layer_models=list(models),optimization=a.optimization,days=35,input_root=str(a.input),input_inventory=m.e.inventory(a.input),canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 start=time.perf_counter();save()
 try:
  if a.reuse_profile:
   old=json.loads((a.reuse_profile/'RESULT.json').read_text());assert old['status']=='ACTUAL_SNOW58_ANALYTICAL_PHYSICAL_NATIVE_COLD_PREFLIGHT_PASS_NOT_ADMITTED' and old['days']==2 and old['optimization']==a.optimization and old['layer_models']==list(models) and old['kind']==kind
   assert dict(old['input_inventory'])==dict(q['input_inventory']) and not git('diff',old['source'],head,'--','app','src','tools','reference'),'Changed execution dependency; short compiled build cannot be reused'
   build=Path(old['build_root']);assert SHA((build/'BUILD.json').read_bytes())==old['actual_BUILD_sha256'];q.update(source=old['source'],build=old['build'],reused_original_short_profile=str(a.reuse_profile),reused_original_short_profile_sha256=SHA((a.reuse_profile/'RESULT.json').read_bytes()),original_BUILD_or_binding_rewritten=False)
  else:
   command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
   with (a.output/'build.stdout').open('x') as stdout,(a.output/'build.stderr').open('x') as stderr:done=subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=300)
   q['build']=dict(command=command,returncode=done.returncode,actual_completion_head=git('rev-parse','HEAD').decode().strip());save();done.check_returncode();assert q['build']['actual_completion_head']==head
  q.update(build_root=str(build),actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()));m.validate_bundle(build,a.reference_work,project);save()
  q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',35,{2,4,7,9,30,34,35},600);q['cold']=[];save()
  for low,high in ((2,4),(7,9),(30,34)):
   q['cold'].append(own(build,a.reference_work,project,a.output/'trajectory',data,low,high,a.output/('own-'+str(low))));save()
  complete_inverse();assert git('rev-parse','HEAD').decode().strip()==head
  q.update(status='ACTUAL_SNOW58_ANALYTICAL_PHYSICAL_NATIVE_COLD_PREFLIGHT_PASS_NOT_ADMITTED',actual_bottom_outward_cm=[row['bottom_outward_cm'] for row in data],seconds=time.perf_counter()-start)
 except Exception as error:q.update(status='FAILED',error=repr(error),seconds=time.perf_counter()-start);raise
 finally:q['actual_completion_head']=git('rev-parse','HEAD').decode().strip();save()
 print(q['status'],q['source'],q['observer_source'],kind,a.optimization,q['seconds'],flush=True)


if __name__=='__main__':main()
