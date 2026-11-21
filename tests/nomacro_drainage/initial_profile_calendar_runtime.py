"""Run original pressure/calendar state compositions with exact cold restarts."""
import argparse,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
import original_output_matrix as original
from water_snow_groundwater_period import cold
from initial_profile_calendar_inputs import CASES
m=original.m


def main():
 p=argparse.ArgumentParser()
 for key in ('input','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--existing-build',type=Path);p.add_argument('--original-build-observation',type=Path)
 p.add_argument('--case',choices=CASES,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),case=a.case,optimization=a.optimization,days=35,input_root=str(a.input),input_inventory=m.e.inventory(a.input),build_root=str(a.build_root/'bundle'),canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  project=m.e.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1');assert not project.age and not project.macro and m.e.switches((a.input/'swap.swp').read_text(encoding='cp1252'))['SWINCO']==1
  q['kind']='cde' if project.solute else 'water';build=a.existing_build or a.build_root/'bundle';q['build_root']=str(build)
  cmd=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
  if a.existing_build:
   assert a.original_build_observation is not None
   prior=json.loads(a.original_build_observation.read_text());assert prior['status']=='FAILED' and prior['build']['returncode']==0 and Path(prior['build_root'])==build and prior['input_inventory']==json.loads(json.dumps(q['input_inventory']))
   import hashlib
   q.update(build=prior['build'],existing_compiled_build_reused=True,original_build_producer=prior['source'],original_failed_build_observation_sha256=hashlib.sha256(a.original_build_observation.read_bytes()).hexdigest(),actual_original_BUILD_sha256=hashlib.sha256((build/'BUILD.json').read_bytes()).hexdigest(),fresh_compilations=0)
   save()
  else:
   assert a.original_build_observation is None
   t=time.perf_counter();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);q['build']=dict(command=cmd,returncode=r.returncode,seconds=time.perf_counter()-t);save();r.check_returncode()
  meta,_=m.validate_bundle(build,a.reference_work,project);q['native_codec']=m.e.auxiliary_magic(project).decode();q['actual_output_metadata']=meta['identity']['original_output'];save()
  windows=[(2,4),(19,23),(30,34)];cuts={35}|{day for pair in windows for day in pair};full=a.output/'trajectory';q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,35,cuts,600);q['cold']=[];save()
  for start,end in windows:q['cold'].append(cold(build,a.reference_work,project,full,data,start,end,a.output/('own-'+str(start))));save()
  q['status']='ACTUAL_ORIGINAL_INITIAL_PROFILE_CALENDAR_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],a.case,a.optimization,q['native_codec'],flush=True)


if __name__=='__main__':main()
