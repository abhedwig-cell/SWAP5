"""Target the original pressure/AGE seam using existing hosts and cold observers."""
import argparse,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
import original_output_matrix as original
CASES=('dense-plain','dense-surface','dense-subsurface-interval','periodic-plain','monthly-subsurface','subdaily-surface','explicit-plain','annual-plain','dense-mean1-plain','dense-mean6-plain')


def main():
 p=argparse.ArgumentParser()
 for key in ('input','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--case',choices=CASES,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),case=a.case,optimization=a.optimization,days=35,input_root=str(a.input),input_inventory=original.m.e.inventory(a.input),build_root=str(a.build_root/'bundle'),canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  # This load must go through the actual public guard. The current guard
  # still refuses this next batch; no test-only route or input rebinding.
  project=original.m.e.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1');s=original.m.e.switches((a.input/'swap.swp').read_text(encoding='cp1252'))
  assert project.age and not project.solute and not project.macro and s['SWINCO']==1 and s['SWSOLU']==2
  for key,value in dict(SWKIMPL=0,SWFROST=0,SWSNOW=0,SWHYST=0,SWDRA=1,SWBOTB=6).items():assert s[key]==value
  q['native_codec']=original.m.e.auxiliary_magic(project).decode();assert q['native_codec']=='S5IOA001';build=a.build_root/'bundle'
  command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
  started=time.perf_counter();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=240);(a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);q['build']=dict(command=command,returncode=r.returncode,seconds=time.perf_counter()-started);save();r.check_returncode()
  meta,_=original.m.validate_bundle(build,a.reference_work,project);q['actual_original_output_metadata']=meta['identity']['original_output'];q['trajectory'],data=original.m.trajectory(build,a.reference_work,project,a.output/'trajectory',35,{2,4,19,23,30,34,35},600);q['cold']=[];save()
  for start,end in ((2,4),(19,23),(30,34)):q['cold'].append(original.own(build,a.reference_work,project,a.output/'trajectory',data,start,end,a.output/('own-'+str(start))));save()
  q['status']='ACTUAL_ORIGINAL_PRESSURE_AGE_EXISTING_NATIVE_EXACT_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],a.case,a.optimization,flush=True)


if __name__=='__main__':main()
