"""Selected actual full/native/short/reference qualification, resumable by phase."""
from pathlib import Path
import argparse,importlib.util,json,subprocess,sys,time,zipfile
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('mixtures',ROOT/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from local_wetting_time import POLICY
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--phase',choices=('short','full'),required=True);a=p.parse_args();out=a.output.resolve()
 if a.phase=='short':out.mkdir(parents=True,exist_ok=False);m.fixtures(out/'inputs')
 result=json.loads((out/'RESULT.json').read_text()) if (out/'RESULT.json').exists() else dict(source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),policy=POLICY,water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10,tolerances_changed=False,science='NOT_QUALIFIED',cases={})
 def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2))
 for key in ('water-surface-history','chemical-surface-history'):
  project=m.e.load(out/'inputs'/key,time_step_policy=POLICY);record=result['cases'].setdefault(key,{})
  for opt in ('O0','O2'):
   build=out/(key+'-'+opt+'-build');item=record.setdefault(opt,{})
   if a.phase=='short':
    cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(project.input_directory),'--experimental-time-step-policy',POLICY,'--reference-work',str(a.reference_work),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
    start=time.perf_counter();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180);(out/(key+'-'+opt+'.build-log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr;item['build']=dict(command=cmd,seconds=time.perf_counter()-start)
    item['short'],data=m.trajectory(build,a.reference_work,project,out/(key+'-'+opt+'-short'),215,{4,6,211,213,215},30)
    item['short']['own']=[m.own(build,a.reference_work,project,out/(key+'-'+opt+'-short'),data,s,e,out/(key+'-'+opt+'-short-own'+str(s))) for s,e in ((4,6),(211,213),(213,215))]
   else:
    full=out/(key+'-'+opt+'-full');item['full'],data=m.trajectory(build,a.reference_work,project,full,1096,{2,4,6,199,201,211,213,215,365,367,530,532,1094,1096},30)
    item['full']['own']=[m.own(build,a.reference_work,project,full,data,s,e,out/(key+'-'+opt+'-own'+str(s))) for s,e in ((2,4),(4,6),(199,201),(211,213),(213,215),(365,367),(530,532),(1094,1096))]
   save();print(key,opt,a.phase,'PASS',flush=True)
 save()
if __name__=='__main__':main()
