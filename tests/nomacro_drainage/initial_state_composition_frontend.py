"""Execute the bounded state guard on ten actual new routes and excluded crosses."""
import argparse,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage'),str(ROOT/'app/hybrid_water')]
import experimental_project as e
from original_output_baseline import assignment
from initial_state_composition_inputs import CASES
CODECS={'hys1-water':'S5IHW001','hys2-water':'S5IHW001','hys1-cde':'S5IHC001','hys2-cde':'S5IHC001','implicit-water':'S5IOW001','implicit-cde':'S5IOC001','snow-vapor-water':'S5HSW004','snow-vapor-cde':'S5HSC004','implicit-snow-water':'S5IRW001','implicit-snow-cde':'S5IRC003'}


def main():
 p=argparse.ArgumentParser()
 for key in ('inputs','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=[],compiler_executions=0,model_executions=0)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def load(path,authority=True):
  project=e.load(path,original_output=authority);return e.auxiliary_magic(project).decode()
 def record(folder,label,status,authority=True,**other):q['checks'].append(dict(input_root=str(folder),input_inventory=e.inventory(folder),label=label,status=status,original_output=authority,**other));save()
 def mutate(label,case,edits):
  folder=a.output/label;shutil.copytree(a.inputs/case,folder);p=folder/'swap.swp';text=p.read_text(encoding='cp1252')
  for key,value in edits.items():text=assignment(text,key,value)
  p.write_text(text,encoding='cp1252');return folder
 try:
  for case in CASES:
   folder=a.inputs/case;magic=load(folder);assert magic==CODECS[case];record(folder,case,'NEW_STATE_PROFILE_SELECTED',codec=magic)
   for initial in (2,3):
    folder=mutate(case+'-initial'+str(initial),case,dict(SWINCO=initial));magic=load(folder);assert magic==CODECS[case];record(folder,case+'-initial'+str(initial),'INITIAL2_OR_3_ROUTE_RETAINED',codec=magic)
  crosses=[('hys-snow','hys1-water',dict(SWSNOW=1)),('hys-implicit','hys1-water',dict(SWKIMPL=1)),('hys-undrained','hys1-water',dict(SWDRA=0)),('hys-head5','hys1-water',dict(SWBOTB=5)),('snow-undrained','snow-vapor-water',dict(SWDRA=0)),('snow-air8','snow-vapor-water',dict(SWBOTB=8)),('implicit-air8','implicit-water',dict(SWBOTB=8)),('implicit-undrained','implicit-water',dict(SWDRA=0)),('implicit-snow-free6','implicit-snow-water',dict(SWBOTB=6)),('implicit-snow-history','implicit-snow-water',dict(SWHYST=1))]
  common=[(key,'implicit-cde',{key:value}) for key,value in [('SWFROST',1),('SWSOLU',2),('SWBR',1),('SWBOTB',1),('SWBOTB',7),('SWBBCFILE',1),('SWMETDETAIL',1),('SWHEA',0),('SWCALT',1),('NPRINTDAY',2),('PERIOD',2),('SWMONTH',1),('SWODAT',1),('SWRES',0),('FLPRINTDT','.TRUE.')]]
  for i,(label,case,edits) in enumerate(crosses+common):
   folder=mutate('refusal-'+str(i),case,edits)
   try:load(folder)
   except ValueError as error:record(folder,label,'UNQUALIFIED_STATE_CROSS_REFUSED',diagnostic=str(error))
   else:raise AssertionError('Unqualified state cross accepted: '+label)
  folder=a.inputs/'implicit-cde'
  try:load(folder,False)
  except ValueError as error:record(folder,'compatibility-output','UNQUALIFIED_STATE_CROSS_REFUSED',False,diagnostic=str(error))
  else:raise AssertionError('Compatibility output admitted new state profile')
  assert len(q['checks'])==56;q['status']='TEN_NEW_TWENTY_INITIAL2_OR3_TWENTY_SIX_STATE_REFUSALS_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],len(q['checks']))


if __name__=='__main__':main()
