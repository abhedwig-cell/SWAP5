"""Complete bounded original corrected frost/snow/history owner qualification."""
import argparse,hashlib,importlib.util,json,math,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water')]
import frost_cases,user_prepare

def module(name,path):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
m=module('original_mixtures','tests/nomacro_mixtures/run.py');checks=module('pond_controls','tests/nomacro_pond_history/run.py')


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--configuration',choices=frost_cases.KEYS,required=True);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--short-only',action='store_true');a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);reference=a.reference_work.resolve()
 if not (reference/'PREPARED.json').exists():user_prepare.prepare(reference)
 user_prepare.validate(reference);case=out/'input';changes=frost_cases.create(case,a.configuration);project=m.e.load(case);reports={};events=[]
 result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),configuration=a.configuration,selected_physical_controls=changes,profiles=reports,events=events,science='NOT_QUALIFIED',water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10)
 def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 save()
 for opt in ('O0','O2'):
  build=out/(opt+'-build');cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(case),'--reference-work',str(reference),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
  t=time.perf_counter();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);events.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));save();assert r.returncode==0,r.stderr
  short=out/(opt+'-short');brief,rows=m.trajectory(build,reference,project,short,5,{2,4},30);brief['own']=m.own(build,reference,project,short,rows,2,4,out/(opt+'-short-own'));reports[opt]=dict(short=brief);save();print(a.configuration,opt,'SHORT_EXACT_NATIVE_PASS',flush=True)
  if a.short_only:continue
  full=out/(opt+'-full');r,rows=m.trajectory(build,reference,project,full,1096,{2,4,199,201,365,367,530,532,1096},60);r['short']=brief;reports[opt]=r;save()
  r['own']=[m.own(build,reference,project,full,rows,start,end,out/(opt+f'-own{start}')) for start,end in ((2,4),(199,201),(365,367),(530,532))]
  actual=[]
  for line in (full/'original/donor.stdout').read_text().splitlines():
   if line.startswith('HYBRID_FROST_WITNESS '):
    v=list(map(float,line.split()[1:]));assert len(v)==6 and all(map(math.isfinite,v)) and 0<=v[0]<=v[1]<=1;actual.append(v)
  assert len(actual)==1097
  initial=actual.pop(0);assert initial[-1]==0 and all(v[-1]==1 for v in actual)
  r['frost_witness']=dict(initial_original_uncomputed_diagnostic=initial,actual_daily_original_records=len(actual),minimum_rfcp=min(v[0] for v in actual),days_with_reduction=sum(v[0]<1 for v in actual),days_with_zero_factor=sum(v[0]==0 for v in actual),original_front_nodes=sorted(set(int(v[2]) for v in actual)),actual_records=actual)
  winter=[day for day,v in enumerate(actual,1) if v[0]<1 and day<100]
  crop=[day for day,v in enumerate(actual,1) if v[0]<1 and 170<=day<=200]
  assert winter and crop,'No actual positive frost activation in winter/crop pulse'
  from qualify_surface_schedule import windows
  r['active_frost_exact_native_windows']=windows(build,reference,project,out/(opt+'-active-frost'),rows,opt,
        cuts=(winter[0]-1,crop[0]-1),compare_full=True)
  r['active_frost_exact_native_windows']['event_scope']='Actual original partial frost reduction during winter and active crop pulses'
  if project.solute:r['frost_witness']['total_original_frost_uptake_reduction_cm']=sum(row['uptake_terms_cm'][5] for row in rows)
  controlout=out/(opt+'-controls');controlout.mkdir();r['controls']=checks.controls(build,reference,project,controlout,full,rows,policy_key='frost_reference');save();print(a.configuration,opt,'FULL_NATIVE_AND_TRANSACTIONS_PASS',flush=True)
 result['status']='SHORT_BOUNDED_FROST_O0_O2_PASS' if a.short_only else 'COMPLETE_BOUNDED_FROST_O0_O2_PASS';save()


if __name__=='__main__':main()
