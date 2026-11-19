"""Actual sixth original mean in water/history after implicit AGE exclusion."""
from pathlib import Path
import argparse,json,subprocess,sys,time
import implicit_conductivity_runtime as c


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=c.ROOT,text=True).strip(),optimization=a.optimization,selection='Original SWKMEAN6 weighted harmonic on actual water SWHYST2 head5 perstep. The earlier sixth-mean AGE prototype is unqualified; this closes the selected nonAGE numerical mean coverage with real full/native water execution.',executions=[])
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  for phase in ('short','full'):
   root=a.output/phase;args=['--solute','0','--hysteresis','2','--bottom','5','--kmean','6','--perstep','--mode','explicit','--format','3','--reset','1','--phase',phase]
   if phase=='full':args += ['--existing-input',q['short']['input_root'],'--reuse-build',q['short']['build_root']]
   command=[sys.executable,'-B',str(Path(__file__).with_name('implicit_conductivity_runtime.py')),'--reference-work',str(a.reference_work),'--output',str(root),'--optimization',a.optimization,*args]
   start=time.perf_counter();result=subprocess.run(command,cwd=c.ROOT,capture_output=True,text=True,timeout=600);(a.output/(phase+'.stdout')).write_text(result.stdout);(a.output/(phase+'.stderr')).write_text(result.stderr);q['executions'].append(dict(command=command,seconds=time.perf_counter()-start,returncode=result.returncode));save();result.check_returncode()
   report=json.loads((root/'RESULT.json').read_text());assert report['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_'+phase.upper()+'_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS';q[phase]=report;q[phase+'_root']=str(root);save();print(phase,'ACTUAL_WEIGHTED_HARMONIC_WATER_HISTORY_NATIVE_PASS',flush=True)
  q['status']='ACTUAL_WEIGHTED_HARMONIC_WATER_HISTORY_SHORT_FULL_COMPLETE_NATIVE_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
