"""One real paired9/hysteresis35 period and three complete cold windows."""
import argparse,json,struct,subprocess,sys,time,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from explicit_bottom9_runtime import m,own
from explicit_bottom9_source_inverse import git
from analytical_hydraulic_archives import SHA
from prescribed_history_boundary import enabled
from original_output_hysteresis import metadata
from output_hysteresis_baseline import history

CORE='cc33a863437ca3cf34cade7d6f2aba9c32729f22'


def main():
 p=argparse.ArgumentParser()
 for key in ('input','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
 assert not git('diff',CORE,'--','app','src','tools','reference'),'Unreviewed actual paired history execution source'
 assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','reference','tests')
 project=m.e.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1');s=m.e.switches((a.input/'swap.swp').read_text(encoding='cp1252'))
 assert enabled(project) and s['SWBOTB']==9 and s['SWHYST'] in (1,2) and s['SWKIMPL']==s['SWSNOW']==s['SWFROST']==0 and s['SWSOLU'] in (0,1)
 head=git('rev-parse','HEAD').decode().strip();a.output.mkdir();build=a.build_root/'bundle';kind='cde' if project.solute else 'water'
 q=dict(status='RUNNING',source=head,observer_source=head,composition_core=CORE,kind=kind,hysteresis=s['SWHYST'],optimization=a.optimization,days=35,build_root=str(build),input_root=str(a.input),input_inventory=m.e.inventory(a.input),actual_original_output_metadata=metadata(project),canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 started=time.perf_counter();save()
 try:
  command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
  with (a.output/'build.stdout').open('x') as stdout,(a.output/'build.stderr').open('x') as stderr:done=subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=300)
  q['build']=dict(command=command,returncode=done.returncode,actual_completion_head=git('rev-parse','HEAD').decode().strip());save();done.check_returncode()
  assert q['build']['actual_completion_head']==head,'Actual producer changed during compilation'
  q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes());m.validate_bundle(build,a.reference_work,project)
  windows=((2,4),(19,23),(30,34));cuts={35,*(d for pair in windows for d in pair)}
  q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',35,cuts,600);q['cold']=[];save()
  observations={};header=struct.pack('<7i',2,project.nodes,0,s['SWHYST'],s['SWSOLU'],s['SWDRA'],9)
  for day in sorted(cuts):
   with zipfile.ZipFile(a.output/'trajectory'/('accepted-column-1-day-'+str(day)+'.zip')) as z:
    wire=z.read('macro.bin');assert wire.count(header+header)==1
    observations[str(day)]=dict(actual_history=history(z.read('result.end')),native_domain_offset=wire.index(header+header),actual_native_codec=wire[:8].decode(),native_domain_bytes=56)
  q['actual_history_observations']=observations;save()
  for low,high in windows:q['cold'].append(own(build,a.reference_work,project,a.output/'trajectory',data,low,high,a.output/('own-'+str(low))));save()
  q.update(status='ACTUAL_EXPLICIT9_HYSTERESIS_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS_NOT_ADMITTED',seconds=time.perf_counter()-started)
 except Exception as error:q.update(status='FAILED',error=repr(error),seconds=time.perf_counter()-started);raise
 finally:save()
 print(q['status'],kind,s['SWHYST'],a.optimization,q['seconds'],flush=True)


if __name__=='__main__':main()
