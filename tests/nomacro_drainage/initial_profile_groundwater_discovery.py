"""Measure original pressure/prescribed groundwater gaps without model runs."""
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import experimental_project as e
import implicit_conductivity_runtime as original
import age_groundwater_runtime as age
from original_output_baseline import assignment
from initial_pressure_profile_science import initialized_heads,PROVIDER
PARENT='84e815a0ba9f59a2d56fe838a3b13361ad8670a2'
# The input-generating implementations are existing canonical owners. This
# discovery records actual dispatch only, never new scientific admission.
FIXTURES=('implicit_conductivity_runtime','age_groundwater_runtime','age_perstep_runtime')
CASES=(
 ('water-explicit-daily',0,0,0,0,False,'daily',1,1,1),
 ('water-h2-periodic',0,2,0,0,False,'periodic',1,1,1),
 ('water-h1-monthly',0,1,0,0,False,'monthly',1,0,1),
 ('water-h1-step-off',0,1,0,0,True,'explicit',1,0,0),
 ('water-h2-implicit-clock',0,2,0,1,False,'periodic',3,1,1),
 ('water-snow-daily',0,0,1,0,False,'daily',1,1,1),
 ('water-h2-snow-monthly',0,2,1,0,False,'monthly',1,1,1),
 ('water-h1-snow-implicit-step',0,1,1,1,True,'explicit',1,1,1),
 ('cde-explicit-daily',1,0,0,0,False,'daily',1,1,1),
 ('cde-h2-periodic',1,2,0,0,False,'periodic',1,1,1),
 ('cde-h1-monthly',1,1,0,0,False,'monthly',1,0,1),
 ('cde-h1-step-off',1,1,0,0,True,'explicit',1,0,0),
 ('cde-h2-implicit-clock',1,2,0,1,False,'periodic',3,1,1),
 ('cde-snow-monthly',1,0,1,0,False,'monthly',1,1,1),
 ('cde-h2-snow-periodic',1,2,1,0,False,'periodic',1,0,0),
 ('cde-h1-snow-step',1,1,1,0,True,'explicit',1,1,1),
 ('age-explicit-daily',2,0,0,0,False,'daily',1,1,1),
 ('age-h2-monthly',2,2,0,0,False,'monthly',1,1,1),
 ('age-h1-subdaily',2,1,0,0,False,'periodic',3,0,0),
 ('age-explicit-step',2,0,0,0,True,'explicit',1,0,1),
)


def fixture(path,spec):
 label,solute,hys,snow,implicit,step,mode,npd,reset,drain=spec
 if solute==2:age.fixture(path,hys,step,'periodic' if mode=='daily' else mode,3,reset,npd,drain,source='surface')
 else:original.fixture(path,solute,hys,1,step,4,mode,3,reset,npd)
 control=path/'swap.swp';text=control.read_text(encoding='cp1252')
 for key,value in dict(SWKIMPL=implicit,SWSNOW=snow,SWDRA=drain,PERIOD=1 if mode=='daily' else 3).items():text=assignment(text,key,value)
 control.write_text(text,encoding='cp1252')


def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
 for name in FIXTURES:
  path='tests/nomacro_scheduled_subsurface/'+name+'.py';assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',PARENT+':'+path],cwd=ROOT)
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),required_previous_canonical=PARENT,checks=[],compiler_executions=0,model_executions=0,implementation_changed=False,canonical_admission=False,dispatch_observation_only=True,individual_parent_scientific_qualification_claimed=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 try:
  for spec in CASES:
   label=spec[0];parent=a.output/(label+'-initial2');fixture(parent,spec);text=(parent/'swap.swp').read_text(encoding='cp1252');assert e.switches(text)['SWINCO']==2
   item=dict(case=label,parent_input_root=str(parent),parent_inventory=e.inventory(parent),selectors=e.switches(text));q['checks'].append(item)
   try:project=e.load(parent,original_output=True,time_step_policy='original-adaptive-day-seed-v1');item.update(parent_selected=True,actual_parent_codec=e.auxiliary_magic(project).decode())
   except ValueError as error:item.update(parent_selected=False,actual_parent_refusal=str(error));save();continue
   candidate=a.output/(label+'-initial1');shutil.copytree(parent,candidate);(candidate/'swap.swp').write_text(assignment(text,'SWINCO',1),encoding='cp1252');changed=(candidate/'swap.swp').read_text(encoding='cp1252');heads,initial=initialized_heads(changed)
   item.update(pressure_input_root=str(candidate),pressure_inventory=e.inventory(candidate),exact_original_initial_pressure_nodes=len(heads),original_initial_profile=initial)
   try:new=e.load(candidate,original_output=True,time_step_policy='original-adaptive-day-seed-v1');item.update(pressure_selected=True,actual_pressure_codec=e.auxiliary_magic(new).decode())
   except ValueError as error:item.update(pressure_selected=False,actual_pressure_refusal=str(error))
   save()
  q.update(status='ACTUAL_TWENTY_EXISTING_PRESCRIBED_GROUNDWATER_PARENT_AND_PRESSURE_DISPATCH_OBSERVATIONS_COMPLETE',provider_source_pins=PROVIDER,parents_selected=sum(item['parent_selected'] for item in q['checks']),pressure_refused=sum(item.get('pressure_selected') is False for item in q['checks']))
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],q.get('parents_selected'),q.get('pressure_refused'))


if __name__=='__main__':main()
