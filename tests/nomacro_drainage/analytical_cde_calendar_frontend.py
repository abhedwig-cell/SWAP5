"""Observe actual bounded calendar selection and excluded process compositions."""
import argparse,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import experimental_project as e
from original_output_baseline import assignment
from analytical_cde_calendar_inputs import CASES


def main():
 p=argparse.ArgumentParser()
 for key in ('inputs','continuation-inputs','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=[],compiler_executions=0,model_executions=0)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def load(path):return e.auxiliary_magic(e.load(path,original_output=True,time_step_policy='original-adaptive-day-seed-v1')).decode()
 def record(path,label,status,**other):q['checks'].append(dict(label=label,status=status,input_root=str(path),input_inventory=e.inventory(path),**other));save()
 try:
  for case in CASES:
   folder=(a.inputs if (a.inputs/case).is_dir() else a.continuation_inputs)/case
   expected='S5CCC001' if case in ('model7-clock6','model7-perstep6') else 'S5CIC001' if case=='model7-periodic6' else 'S5HCC006'
   assert load(folder)==expected;record(folder,case,'BOUNDED_CALENDAR_SELECTED',codec=expected)
  mutations=[('clock-monthly','mixed7-8-clock6',dict(SWMONTH=1)),('clock-explicit','mixed7-8-clock6',dict(SWODAT=1)),('perstep-reset','mixed7-8-perstep6',dict(SWRES=1))]
  mutations += [(key+'-'+str(value),'vapor8-periodic6',{key:value}) for key,value in [('SWKIMPL',1),('SWSNOW',1),('SWFROST',1),('SWHYST',1),('SWINCO',1),('SWBOTB',1),('SWBOTB',7),('SWBR',1),('SWMETDETAIL',1),('SWSOLU',2),('SWHEA',0),('SWCALT',1),('SWMACRO',1),('NPRINTDAY',0),('NPRINTDAY',1441),('NPRINTDAY','1.5'),('PERIOD',-1),('PERIOD',367),('SWMONTH',2),('SWODAT',2),('SWRES',2),('FLPRINTDT','INVALID')]]
  for index,(label,case,edits) in enumerate(mutations):
   folder=a.output/('refusal-'+str(index));shutil.copytree(a.inputs/case,folder);path=folder/'swap.swp';text=path.read_text(encoding='cp1252')
   for key,value in edits.items():text=assignment(text,key,value)
   path.write_text(text,encoding='cp1252')
   try:load(folder)
   except ValueError as error:record(folder,label,'UNQUALIFIED_CALENDAR_CROSS_REFUSED',diagnostic=str(error))
   else:raise AssertionError('Unqualified calendar cross selected: '+label)
  assert len(q['checks'])==39;q['status']='FOURTEEN_CALENDAR_ROUTES_AND_TWENTY_FIVE_EXCLUDED_CROSSES_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],len(q['checks']))


if __name__=='__main__':main()
