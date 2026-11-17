"""Full literal original comparison, paired baseline cost and pulse transactions."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,shutil,subprocess,sys,time
from run import ROOT,m,POLICY
from irrigation_pulse_time import POLICY as PREVIOUS_POLICY
spec=importlib.util.spec_from_file_location('history',ROOT/'tests/nomacro_pond_history/run.py');history=importlib.util.module_from_spec(spec);spec.loader.exec_module(history)
from daily_coupling import CoupledDailyColumn
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();r=json.loads((out/'RESULT.json').read_text());result={'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'cases':{},'tolerances_changed':False,'science':'NOT_QUALIFIED'}
 extra=out/'finish-controls';extra.mkdir()
 def save():(out/'FINISH.json').write_text(json.dumps(result,indent=2))
 for key in ('water-surface-history','chemical-surface-history'):
  record=result['cases'][key]={};case=out/'inputs'/key;project=m.e.load(case,time_step_policy=POLICY)
  build=out/(key+'-O2-build');full=out/(key+'-O2-full');meta,_=m.validate_bundle(build,a.reference_work,project);data=m.rows(full)
  # Reference input files come from the actual worker, never its output deck.
  literal=extra/(key+'-literal-input');literal.mkdir()
  for name in meta['inputs']:shutil.copy2(full/'original'/name,literal/name)
  record['reference']=m.reference_run(literal,a.reference_work,extra/(key+'-original431'),full,20)
  assert record['reference']['status']=='COMPLETE_DIAGNOSTIC_REFERENCE'
  assert all(m.sha(literal/n)==m.sha(extra/(key+'-original431')/n) for n in meta['inputs'])
  record['literal_executed_inputs_exact']=True
  for opt in ('O0','O2'):
   b=out/(key+'-'+opt+'-build');f=out/(key+'-'+opt+'-full');folder=extra/(key+'-'+opt+'-controls');folder.mkdir()
   record[opt]=history.controls(b,a.reference_work,project,folder,f,m.rows(f))
   newmeta,_=m.validate_bundle(b,a.reference_work,project)
   for attack in ('missing','foreign','resolution'):
    foreign=extra/(key+'-'+opt+'-'+attack);shutil.copytree(b,foreign)
    v=json.loads((foreign/'BUILD.json').read_text())
    if attack=='missing':v['identity'].pop('local_wetting_time')
    elif attack=='foreign':v['identity']['local_wetting_time']['policy']='foreign'
    else:v['identity']['local_wetting_time']['maximum_supply_depth_cm']=1
    (foreign/'BUILD.json').write_text(json.dumps(v))
    try:m.validate_bundle(foreign,a.reference_work,project)
    except ValueError as e:assert 'local wetting' in str(e)
    else:raise AssertionError('Foreign pulse metadata admitted')
   # Real pulse-day prepare/discard/replay, accept and disk recovery.
   column=CoupledDailyColumn(b,a.reference_work,extra/(key+'-'+opt+'-external-pulse'),project,'pulse',origin=f/'accepted-column-1-day-4.zip',day=4,adopt_native=True)
   first=column.prepare();column.discard(first);again=column.prepare();assert first.budget==again.budget;column.accept(again)
   assert m.physical([{k:v for k,v in again.budget.items() if k!='candidate_only'}|{'committed':True}])==m.physical([m.rows(f)[4]])
   recovered=CoupledDailyColumn(b,a.reference_work,extra/(key+'-'+opt+'-external-pulse-recovered'),project,'pulse',origin=column.checkpoint,day=5)
   nextday=recovered.prepare();assert m.physical([{k:v for k,v in nextday.budget.items() if k!='candidate_only'}|{'committed':True}])==m.physical([m.rows(f)[5]]);recovered.discard(nextday)
   record[opt]['pulse_discard_replay_and_recovery_exact']=True;record[opt]['pulse_metadata_refusals']=3
  baseline=m.e.load(case,time_step_policy=PREVIOUS_POLICY);b=extra/(key+'-baseline-build');command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(case),'--experimental-time-step-policy',PREVIOUS_POLICY,'--reference-work',str(a.reference_work),'--build-only','--kernel-opt','O2','--donor-opt','O2','--output',str(b)]
  start=time.perf_counter();z=subprocess.run(command,capture_output=True,text=True,timeout=180);(out/(key+'.baseline-log')).write_text(z.stdout+z.stderr);assert z.returncode==0,z.stderr
  f=extra/(key+'-baseline-full');record['baseline_build']=dict(command=command,seconds=time.perf_counter()-start)
  record['baseline_full'],old=m.trajectory(b,a.reference_work,baseline,f,1096,{2,4,6,199,201,365,367,530,532,1094,1096},30)
  record['baseline_full']['own']=m.own(b,a.reference_work,baseline,f,old,4,6,extra/(key+'-baseline-own4'))
  record['O2_full_cost_ratio']=r['cases'][key]['O2']['full']['model_seconds']/record['baseline_full']['model_seconds']
  record['dry_initial2_exact_to_baseline']=m.physical(old[:2])==m.physical(data[:2]);assert record['dry_initial2_exact_to_baseline']
  record['full_O0_O2_physical_exact']=m.physical(m.rows(out/(key+'-O0-full')))==m.physical(data)
  # Different policies are bound even though their native field layout agrees.
  try:m.h.verify_checkpoint(f/'accepted-column-1-day-4.zip',4,meta['binding'],extra/(key+'-foreign-origin'))
  except ValueError:record['cross_policy_checkpoint_refused']=True
  else:raise AssertionError('Cross-policy checkpoint rebound')
  save();print(key,'LITERAL_REFERENCE_TRANSACTION_POLICY_AND_COST_PASS',flush=True)
 result['status']='FULL_LITERAL_REFERENCE_PULSE_TRANSACTION_AND_PAIRED_COST_PASS';save()
if __name__=='__main__':main()
