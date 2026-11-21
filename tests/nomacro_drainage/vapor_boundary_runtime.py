"""Target actual unchanged-process vapor boundary builds and exact cold state."""
import argparse,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
import original_output_matrix as original
from water_snow_groundwater_period import cold
m=original.m


def main():
 p=argparse.ArgumentParser()
 for key in ('input','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--days',type=int,choices=(35,367),required=True);a=p.parse_args();a.output.mkdir()
 project=m.e.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1');q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),kind='cde' if project.solute else 'water',optimization=a.optimization,days=a.days,input_root=str(a.input),input_inventory=m.e.inventory(a.input),build_root=str(a.build_root/'bundle'),canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  build=a.build_root/'bundle';command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
  start=time.perf_counter();result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(result.stdout);(a.output/'build.stderr').write_text(result.stderr);q['build']=dict(command=command,returncode=result.returncode,seconds=time.perf_counter()-start);save();result.check_returncode()
  meta,_=m.validate_bundle(build,a.reference_work,project);assert meta['identity']['hydraulic_vapor']['boundary_composition']['native_domain_version']==5
  windows=[(2,4),(19,23),(30,34)]+([(199,201),(364,367)] if a.days==367 else []);cuts={a.days}|{day for pair in windows for day in pair}
  full=a.output/'trajectory';q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,a.days,cuts,300);q['cold']=[];save()
  for start,end in windows:q['cold'].append(cold(build,a.reference_work,project,full,data,start,end,a.output/('own-'+str(start))));save()
  q['status']='ACTUAL_VAPOR_BOUNDARY_NATIVE5_WATER_CDE_ORIGINAL_OUTPUT_EXACT_COLD_PASS_NOT_ADMITTED'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],q['kind'],a.optimization,a.days,flush=True)


if __name__=='__main__':main()
