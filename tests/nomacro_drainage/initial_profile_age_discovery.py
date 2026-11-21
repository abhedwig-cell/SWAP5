"""Measure the next original pressure/AGE guard gap without builds or model runs."""
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import experimental_project as e
import age_calendar,age_clock,age_schedule
from original_output_baseline import assignment
from initial_pressure_profile_science import initialized_heads,PROVIDER


def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=[],compiler_executions=0,model_executions=0,implementation_changed=False,canonical_admission=False,dispatch_observation_only=True,individual_parent_scientific_qualification_claimed=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 try:
  specs=[('dense-'+kind,lambda path,k=kind:age_calendar.fixture(path,k,1,0)) for kind in ('plain','surface','subsurface-interval')]
  specs += [('periodic-plain',lambda path:age_calendar.fixture(path,'plain',3,0)),('monthly-subsurface',lambda path:age_schedule.fixture(path,'subsurface-interval','monthly')),('subdaily-surface',lambda path:age_clock.fixture(path,'surface','subdaily',3))]
  specs += [('explicit-plain',lambda path:age_schedule.fixture(path,'plain','explicit')),('annual-plain',lambda path:age_clock.fixture(path,'plain','annual',1))]
  def mean_fixture(path,mean):
   age_calendar.fixture(path,'plain',1,0);control=path/'swap.swp';control.write_text(assignment(control.read_text(encoding='cp1252'),'SWKMEAN',mean),encoding='cp1252')
  specs += [('dense-mean'+str(mean)+'-plain',lambda path,m=mean:mean_fixture(path,m)) for mean in (1,6)]
  for label,fixture in specs:
   parent=a.output/(label+'-initial2');fixture(parent);file=parent/'swap.swp';text=file.read_text(encoding='cp1252');assert e.switches(text)['SWINCO']==2
   project=e.load(parent,original_output=True,time_step_policy='original-adaptive-day-seed-v1');codec=e.auxiliary_magic(project).decode();assert project.age and not project.macro
   candidate=a.output/(label+'-initial1');shutil.copytree(parent,candidate);(candidate/'swap.swp').write_text(assignment(text,'SWINCO',1),encoding='cp1252');changed=(candidate/'swap.swp').read_text(encoding='cp1252');heads,initial=initialized_heads(changed)
   try:e.load(candidate,original_output=True,time_step_policy='original-adaptive-day-seed-v1')
   except ValueError as error:refusal=str(error)
   else:raise AssertionError('Original pressure/AGE already admitted: '+label)
   assert 'pressure-profile initialization' in refusal
   q['checks'].append(dict(case=label,parent_input_root=str(parent),parent_inventory=e.inventory(parent),actual_parent_codec=codec,parent_selected=True,pressure_input_root=str(candidate),pressure_inventory=e.inventory(candidate),actual_pressure_refusal=refusal,exact_original_initial_pressure_nodes=len(heads),original_initial_profile=initial,selectors=e.switches(text)));save()
  q['provider_source_pins']=PROVIDER
  q['unchanged_AGE_owners']={name:hashlib.sha256((ROOT/('app/hybrid_water/'+name)).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for name in ('conserved_original_age.py','age_output_calendar.py','age_output_schedule.py','age_output_clock.py','age_irrigation_source.py','age_direct_soil_source.py')}
  q['status']='TEN_EXISTING_AGE_PARENTS_SELECT_INITIAL2_AND_REFUSE_ORIGINAL_PRESSURE_INITIAL1_BEFORE_BUILD'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],len(q['checks']))


if __name__=='__main__':main()
