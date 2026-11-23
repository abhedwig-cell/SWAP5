"""Target one actual Snow9 water/CDE period with complete native cold windows."""
import argparse,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from explicit_bottom9_runtime import m,own
from explicit_bottom9_snow_history_source_v2 import complete_inverse,CORE,git
from analytical_hydraulic_archives import SHA
from prescribed_snow_boundary import enabled


def main():
 p=argparse.ArgumentParser()
 for name in ('input','reference-work','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();complete_inverse();a.output.mkdir()
 project=m.e.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1');s=m.e.switches((a.input/'swap.swp').read_text(encoding='cp1252'))
 assert enabled(project) and s['SWBOTB']==9 and s['SWSNOW']==1 and s['SWKIMPL']==s['SWDRA']==0 and s['SWHYST'] in (0,1,2) and s['SWSOLU'] in (0,1)
 head=git('rev-parse','HEAD').decode().strip();build=a.build_root/'bundle';kind='cde' if project.solute else 'water'
 q=dict(status='RUNNING',source=head,observer_source=head,composition_core=CORE,case='explicit9-snow-history'+str(s['SWHYST'])+'-'+kind,hysteresis=s['SWHYST'],kind=kind,optimization=a.optimization,days=35,build_root=str(build),input_root=str(a.input),input_inventory=m.e.inventory(a.input),canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 started=time.monotonic();save()
 try:
  command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
  with (a.output/'build.stdout').open('x') as stdout,(a.output/'build.stderr').open('x') as stderr:done=subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=300)
  q['build']=dict(command=command,returncode=done.returncode,actual_completion_head=git('rev-parse','HEAD').decode().strip());save();done.check_returncode()
  assert q['build']['actual_completion_head']==head
  q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes());m.validate_bundle(build,a.reference_work,project)
  windows=[(2,4),(7,9),(30,34)]
  q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',35,{35,*(d for pair in windows for d in pair)},600);q['cold']=[];save()
  for low,high in windows:q['cold'].append(own(build,a.reference_work,project,a.output/'trajectory',data,low,high,a.output/('own-'+str(low))));save()
  complete_inverse();assert git('rev-parse','HEAD').decode().strip()==head
  q.update(status='ACTUAL_EXPLICIT9_SNOW_HISTORY_CALENDAR_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS_NOT_ADMITTED',snow_maximum_stock_cm=max(r['stock_end_cm'][2] for r in data),snow_minimum_stock_cm=min(r['stock_end_cm'][2] for r in data),seconds=time.monotonic()-started)
 except Exception as error:q.update(status='FAILED',error=repr(error),seconds=time.monotonic()-started);raise
 finally:q['actual_completion_head']=git('rev-parse','HEAD').decode().strip();save()
 print(q['status'],kind,a.optimization,q['seconds'],flush=True)


if __name__=='__main__':main()
