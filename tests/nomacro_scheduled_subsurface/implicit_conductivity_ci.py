"""Dependency-selected implicit conductivity state/composition qualification."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import implicit_conductivity_runtime as c

# solute, hysteresis, bottom, Kmean, perstep, mode, format, reset, full, controls
CASES={
 'water-head':(0,0,5,1,False,'explicit',3,1,True,True),
 'water-air-history':(0,1,8,2,True,'monthly',2,0,True,True),
 'water-groundwater':(0,0,1,5,False,'explicit',3,1,True,True),
 'water-groundwater-history':(0,2,1,2,False,'periodic',0,0,True,True),
 'cde-head':(1,0,5,3,True,'explicit',3,1,True,True),
 'cde-air-history':(1,1,8,2,False,'explicit',2,1,False,False),
 'cde-groundwater-history':(1,2,1,4,False,'daily',3,0,True,True),
 'age-head-history':(2,2,5,6,True,'explicit',3,1,True,True),
 'age-air-history':(2,1,8,2,False,'monthly',1,0,False,False),
 'age-groundwater-history':(2,1,1,3,True,'explicit',3,1,True,True),
 'water-head-numerical-pair':(0,0,5,2,False,'explicit',3,1,False,False),
}


def arguments(case):
 sol,hys,bot,k,step,mode,fmt,reset,_,_=case
 return ['--solute',str(sol),'--hysteresis',str(hys),'--bottom',str(bot),'--kmean',str(k),*(['--perstep'] if step else []),'--mode',mode,'--format',str(fmt),'--reset',str(reset)]


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output=a.output.resolve();a.output.mkdir()
 if not (a.reference_work/'PREPARED.json').exists():c.m.user_prepare.prepare(a.reference_work)
 c.m.user_prepare.validate(a.reference_work)
 q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=c.ROOT,text=True).strip(),optimization=a.optimization,cases={},controls={},selection='Eleven actual numerical/physical boundary contexts; eight full1096day periods only after all current-source short/native/domain/active gates. Original unchanged numerical formula providers are not requalified as fresh independent science.',expected_seconds=600,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 def run(script,target,args):
  cmd=[sys.executable,'-B',str(Path(__file__).with_name(script)),'--reference-work',str(a.reference_work),'--output',str(target),*args]
  t=time.perf_counter();r=subprocess.run(cmd,cwd=c.ROOT,capture_output=True,text=True,timeout=600)
  (a.output/(target.name+'.stdout')).write_text(r.stdout,encoding='utf8');(a.output/(target.name+'.stderr')).write_text(r.stderr,encoding='utf8')
  item=dict(command=cmd,seconds=time.perf_counter()-t,returncode=r.returncode)
  q.setdefault('executions',[]).append(item);save();r.check_returncode()
  return json.loads((target/'RESULT.json').read_text(encoding='utf8'))
 save()
 try:
  for name,case in CASES.items():
   root=a.output/('short-'+name);item=run('implicit_conductivity_runtime.py',root,arguments(case)+['--optimization',a.optimization])
   assert item['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS'
   q['cases'][name]=dict(short_root=str(root),short=item,input_root=item['input_root'],build_root=item['build_root']);save();print(name,'SHORT_PASS',flush=True)
  for name,case in CASES.items():
   if not case[-1]:continue
   root=a.output/('controls-'+name);item=run('implicit_conductivity_controls.py',root,['--profile-root',q['cases'][name]['short_root']])
   assert item['status']=='IMPLICIT_CONDUCTIVITY_NUMERICAL_NATIVE_TRANSACTION_DOMAIN_PASS'
   q['controls'][name]=dict(root=str(root),report=item);save();print(name,'CONTROLS_PASS',flush=True)
  from daily_coupling import CoupledDailyColumn
  original=Path(q['cases']['water-head']['short_root'])/'trajectory/accepted-column-1-day-4.zip'
  other=q['cases']['water-head-numerical-pair'];project=c.m.e.load(Path(other['input_root']),original_output=True)
  c.m.validate_bundle(Path(other['build_root']),a.reference_work,project)
  digest=c.m.sha(original)
  try:CoupledDailyColumn(Path(other['build_root']),a.reference_work,a.output/'foreign-numerical-adoption',project,'implicit',origin=original,day=4,adopt_native=True)
  except ValueError as error:
   assert str(error)=='Foreign source, build, project or coupling origin'
   q['actual_foreign_numerical_origin']=dict(status='REFUSED',only_original_numerical_input_changed='SWKMEAN1to2',error=str(error),original_unchanged=c.m.sha(original)==digest)
  else:raise AssertionError('Actual foreign immutable numerical checkpoint accepted')
  q['all_selected_short_native_active_gates_precede_full']=True;save()
  for name,case in CASES.items():
   if not case[-2]:continue
   old=q['cases'][name];root=a.output/('full-'+name)
   item=run('implicit_conductivity_runtime.py',root,arguments(case)+['--optimization',a.optimization,'--phase','full','--reuse-build',old['build_root'],'--existing-input',old['input_root']])
   assert item['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_FULL_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS'
   old.update(full_root=str(root),full=item);save();print(name,'FULL_PASS',flush=True)
  q['status']='ELEVEN_IMPLICIT_CONDUCTIVITY_SHORT_EIGHT_FULL_ALL_NATIVE_ACTIVE_POLICY_PASS';save()
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
