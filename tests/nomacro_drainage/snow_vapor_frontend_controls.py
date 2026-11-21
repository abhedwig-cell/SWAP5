"""Confirm the actual Snow-vapor dispatch and retained unsupported boundaries."""
import argparse,json,shutil,subprocess,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import experimental_project as e
from hydraulic_vapor import describe
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser()
 p.add_argument('--evidence',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=[],model_executions=0,compiler_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def load(folder):return e.load(folder,original_output=True,time_step_policy='original-adaptive-day-seed-v1')
 def inputs(base,label,edits):
  folder=a.output/label;shutil.copytree(base,folder);path=folder/'swap.swp';text=path.read_text(encoding='cp1252')
  for key,value in edits.items():text=assignment(text,key,value)
  path.write_text(text,encoding='cp1252');return folder
 save()
 try:
  for kind,opt in (('water','O0'),('cde','O2')):
   base=a.evidence/f'snow-vapor-{kind}-{opt}-v3/input'
   for index,(models,flags) in enumerate((('8','1 1'),('9','1 1'),('10','1 1'),('11','1 1'),('7 8','1 1'),('8 7','1 1'),('8 11','1 0'),('11 8','0 1'))):
    folder=inputs(base,f'{kind}-positive-{index}',{'iHWCKmodel':models,'SWVAPOR':flags});project=load(folder)
    assert describe(project) is not None and e.auxiliary_magic(project)==(b'S5HSC004' if project.solute else b'S5HSW004')
    q['checks'].append(dict(role=f'{kind}-positive-{index}',status='ACTUAL_SELECTED_NATIVE4',input_inventory=e.inventory(folder)));save()
   mutations=[('SWVAPOR','2 1'),('SWVAPOR','-1 1'),('SWVAPOR','1'),('SWVAPOR','1 1 1'),('SWVAPOR','.TRUE. 1'),('iHWCKmodel','8 12'),('iHWCKmodel','8 8 8'),('iHWCKmodel','8 X'),('SWKIMPL',1),('SWFROST',1),('SWHYST',1),('SWDRA',2),('SWBOTB',1),('SWBR',1),('SWMETDETAIL',1),('SWHEA',0),('SWCALT',1),('SWMACRO',1),('SWSOLU',2),('NPRINTDAY',2),('SWMONTH',1),('SWODAT',1),('PERIOD',2),('FLPRINTDT','.TRUE.')]
   for index,(key,value) in enumerate(mutations):
    folder=inputs(base,f'{kind}-negative-{index}',{key:value})
    try:load(folder)
    except ValueError as error:q['checks'].append(dict(role=f'{kind}-{key}={value}',status='REFUSED_BEFORE_BUILD',diagnostic=str(error),input_inventory=e.inventory(folder)))
    else:raise AssertionError('Unsupported Snow vapor accepted: '+key+'='+str(value))
    save()
   for label,models,flags in (('model1','1','1 1'),('ignored-model7','7 8','1 0'),('all-off','8','0 0')):
    folder=inputs(base,f'{kind}-inactive-{label}',{'iHWCKmodel':models,'SWVAPOR':flags});project=load(folder)
    assert describe(project) is None and e.auxiliary_magic(project)==(b'S5ITC001' if project.solute else b'S5ITW001')
    q['checks'].append(dict(role=f'{kind}-inactive-{label}',status='HISTORICAL_INACTIVE_FLAGS_PRESERVED',input_inventory=e.inventory(folder)));save()
   folder=inputs(base,f'{kind}-prior-NoSnow',{'SWSNOW':0});project=load(folder)
   assert describe(project) is not None and e.auxiliary_magic(project)==(b'S5HVC003' if project.solute else b'S5HVW003')
   q['checks'].append(dict(role=f'{kind}-prior-NoSnow',status='PRIOR_NATIVE3_PRESERVED',input_inventory=e.inventory(folder)));save()
  assert len(q['checks'])==72;q['status']='ACTUAL_SNOW_VAPOR_72_DISPATCH_BOUNDS_AND_PRIOR_CODEC_CONTROLS_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],len(q['checks']),flush=True)


if __name__=='__main__':main()
