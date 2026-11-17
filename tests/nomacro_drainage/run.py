"""Actual original tabulated drainage trajectory and native continuation gates."""
import argparse,importlib.util,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
import drainage_table_cases as cases,user_prepare
spec=importlib.util.spec_from_file_location('original_mixtures',ROOT/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--configuration',choices=cases.KEYS,required=True);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--short-only',action='store_true');a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=a.reference_work.resolve()
 if not (ref/'PREPARED.json').exists():user_prepare.prepare(ref)
 user_prepare.validate(ref);case=out/'input';changes=cases.create(case,a.configuration);project=m.e.load(case);reports={};events=[];result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),configuration=a.configuration,selected_physical_controls=changes,profiles=reports,events=events,science='NOT_QUALIFIED')
 def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 save()
 for opt in ('O0','O2'):
  build=out/(opt+'-build');cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(case),'--reference-work',str(ref),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)];start=time.perf_counter();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);events.append(dict(command=cmd,seconds=time.perf_counter()-start,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));save();assert r.returncode==0,r.stderr
  short=out/(opt+'-short');brief,rows=m.trajectory(build,ref,project,short,5,{2,4},30);brief['own']=m.own(build,ref,project,short,rows,2,4,out/(opt+'-short-own'));reports[opt]=dict(short=brief);save();print(a.configuration,opt,'SHORT_EXACT_NATIVE_PASS',flush=True)
  if a.short_only:continue
  full=out/(opt+'-full');r,rows=m.trajectory(build,ref,project,full,1096,{2,4,199,201,365,367,530,532},60);r['short']=brief;reports[opt]=r;save();r['own']=[m.own(build,ref,project,full,rows,start,end,out/(opt+'-own'+str(start))) for start,end in ((2,4),(199,201),(365,367),(530,532))];r['drainage_signed_exposure']=dict(days_positive=sum(row['drainage_outward_cm']>0 for row in rows),days_negative=sum(row['drainage_outward_cm']<0 for row in rows));save();print(a.configuration,opt,'FULL_BALANCE_NATIVE_PASS',flush=True)
 result['status']='SHORT_TABULATED_DRAINAGE_O0_O2_PASS' if a.short_only else 'FULL_TABULATED_DRAINAGE_NATIVE_O0_O2_PASS_EXTERNAL_NOT_YET_QUALIFIED';save()


if __name__=='__main__':main()
