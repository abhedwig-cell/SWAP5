"""Exercise the actual output-clock owner without compiler or model execution."""
import argparse,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import experimental_project as e
import model7_terminal_water as terminal
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser()
 for key in ('base','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();checks=[]
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=checks,model_executions=0,compiler_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def check(label,edits,expected):
  folder=a.output/label;shutil.copytree(a.base,folder);path=folder/'swap.swp';text=path.read_text(encoding='cp1252')
  for key,value in edits.items():text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+str(value)+'\n'
  path.write_text(text,encoding='cp1252')
  try:
   project=e.load(folder,original_output=True,time_step_policy='original-adaptive-day-seed-v1');selected=terminal.metadata(project)
  except ValueError as error:
   assert expected=='REFUSED',(label,error);checks.append(dict(label=label,status=expected,diagnostic=str(error),inputs=e.inventory(folder)));return
  assert expected!='REFUSED',label
  assert selected is not None and selected['water_limit_cm']==1e-10
  assert selected.get('existing_output_trial_receipt_composed',False)==(expected=='CLOCK'),label
  if expected=='CLOCK':assert selected['existing_output_trial_water_limit_cm']==1e-10
  checks.append(dict(label=label,status=expected,inputs=e.inventory(folder)))
 save()
 try:
  for count in (1,2,3,24,1440):check('nprint-'+str(count),{'NPRINTDAY':count},'DENSE' if count==1 else 'CLOCK')
  check('perstep-no-reset',{'NPRINTDAY':1,'FLPRINTDT':'.TRUE.','SWRES':0},'CLOCK')
  check('monthly-dense',{'NPRINTDAY':1,'SWMONTH':1},'DENSE')
  for label,edits in [('zero',{'NPRINTDAY':0}),('negative',{'NPRINTDAY':-1}),('too-dense',{'NPRINTDAY':1441}),('fractional',{'NPRINTDAY':'2.5'}),('subdaily-monthly',{'SWMONTH':1}),('subdaily-odate',{'SWODAT':1}),('perstep-monthly',{'NPRINTDAY':1,'FLPRINTDT':'.TRUE.','SWRES':0,'SWMONTH':1}),('perstep-annual-reset',{'NPRINTDAY':1,'FLPRINTDT':'.TRUE.','SWRES':1})]:check(label,edits,'REFUSED')
  assert len(checks)==15;q['status']='ACTUAL_ANALYTICAL_OUTPUT_SEVEN_POSITIVE_EIGHT_BOUNDARY_REFUSALS_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'])


if __name__=='__main__':main()
