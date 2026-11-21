"""Check bounded pressure calendars, old hydrostatic routes and excluded crosses."""
import argparse,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import experimental_project as e
from original_output_baseline import assignment
from initial_profile_calendar_science import CODECS


def main():
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
 inputs=json.loads((a.evidence/'INITIAL_PROFILE_CALENDAR_FIRST_FRONTEND_V1.json').read_text())['cases'];q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=[],compiler_executions=0,model_executions=0)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def load(path,authority=True):return e.auxiliary_magic(e.load(path,original_output=authority,time_step_policy='original-adaptive-day-seed-v1')).decode()
 def record(path,label,status,**other):q['checks'].append(dict(label=label,status=status,input_root=str(path),input_inventory=e.inventory(path),**other));save()
 def mutate(label,case,edits):
  folder=a.output/label;shutil.copytree(inputs[case]['input_root'],folder);p=folder/'swap.swp';text=p.read_text(encoding='cp1252')
  for key,value in edits.items():text=assignment(text,key,value)
  p.write_text(text,encoding='cp1252');return folder
 try:
  for case,codec in CODECS.items():
   folder=Path(inputs[case]['input_root']);assert load(folder)==codec;record(folder,case,'NEW_INITIAL1_CALENDAR_SELECTED',codec=codec)
   folder=mutate(case+'-initial2',case,dict(SWINCO=2));assert load(folder)==codec;record(folder,case+'-initial2','PRIOR_INITIAL2_CALENDAR_RETAINED',codec=codec)
  mutations=[('history-with-snow','hys1-clock-water',dict(SWSNOW=1)),('history-with-implicit','hys1-clock-water',dict(SWKIMPL=1)),('history-water-head5','hys1-clock-water',dict(SWBOTB=5)),('history-CDE-bottom6','hys2-periodic-cde',dict(SWBOTB=6)),('snow-explicit-bottom8','snow-monthly-cde',dict(SWBOTB=8)),('implicit-bottom8','implicit-monthly-cde',dict(SWBOTB=8)),('implicit-snow-history','implicit-snow-clock-cde',dict(SWHYST=1)),('inactive-vapor-undrained-CDE','vapor-dra0-explicit5-cde',dict(SWVAPOR='0 0')),('clock-monthly','analytic-clock6-cde',dict(SWMONTH=1)),('clock-explicit','analytic-clock6-cde',dict(SWODAT=1)),('perstep-reset','implicit-perstep-water',dict(SWRES=1))]
  mutations += [(key+'-'+str(value),'analytic-clock6-cde',{key:value}) for key,value in [('SWMACRO',1),('SWSOLU',2),('SWFROST',1),('SWHEA',0),('SWCALT',1),('SWMETDETAIL',1),('SWBR',1),('SWBOTB',1),('SWBOTB',7),('NPRINTDAY',0),('NPRINTDAY',1441),('NPRINTDAY','1.5'),('PERIOD',-1),('PERIOD',367),('SWMONTH',2),('SWODAT',2),('SWRES',2),('FLPRINTDT','INVALID'),('SWINCO',0)]]
  for index,(label,case,edits) in enumerate(mutations):
   folder=mutate('refusal-'+str(index),case,edits)
   try:load(folder)
   except ValueError as error:record(folder,label,'UNQUALIFIED_PRESSURE_CALENDAR_CROSS_REFUSED',diagnostic=str(error))
   else:raise AssertionError('Unqualified pressure calendar selected: '+label)
  folder=Path(inputs['analytic-clock6-cde']['input_root'])
  try:load(folder,False)
  except ValueError as error:record(folder,'compatibility-output','UNQUALIFIED_PRESSURE_CALENDAR_CROSS_REFUSED',diagnostic=str(error),original_output=False)
  else:raise AssertionError('Compatibility output admitted pressure/calendar composition')
  assert len(q['checks'])==55;q['status']='TWELVE_INITIAL1_TWELVE_INITIAL2_THIRTY_ONE_EXCLUDED_PRESSURE_CALENDAR_CROSSES_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],len(q['checks']))


if __name__=='__main__':main()
