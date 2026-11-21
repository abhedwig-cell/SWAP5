"""Exercise actual native5 admission bounds and preserve prior native3/4 routes."""
import argparse,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import experimental_project as e
import hydraulic_vapor as vapor
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser()
 for key in ('evidence','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=[],model_executions=0,compiler_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def load(folder):return e.load(folder,original_output=True,time_step_policy='original-adaptive-day-seed-v1')
 def mutated(base,label,edits):
  folder=a.output/label;shutil.copytree(base,folder);path=folder/'swap.swp';text=path.read_text(encoding='cp1252')
  for key,value in edits.items():text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+str(value)+'\n'
  path.write_text(text,encoding='cp1252');return folder
 save()
 try:
  prior=a.evidence/'vapor-boundary-original-dispatch-v1';old=json.loads((prior/'RESULT.json').read_text());assert len(old['cases'])==24
  for item in old['cases']:
   folder=prior/item['label'];project=load(folder);codec=e.auxiliary_magic(project);assert codec==(b'S5HBC005' if item['solute'] else b'S5HBW005')
   assert e.inventory(folder)==tuple(map(tuple,item['input_inventory']));q['checks'].append(dict(label=item['label'],status='ORIGINAL_REFUSAL_NOW_SELECTED_NATIVE5',codec=codec.decode(),input_root=str(folder),input_inventory=e.inventory(folder)))
  base=prior/'models8-solute0-dra0-bottom6'
  for label,edits,expected in [('prior-native3',{'SWDRA':1},b'S5HVW003'),('prior-native4',{'SWDRA':1,'SWSNOW':1},b'S5HSW004')]:
   folder=mutated(base,label,edits);project=load(folder);assert e.auxiliary_magic(project)==expected;q['checks'].append(dict(label=label,status='PRIOR_NATIVE_CODEC_PRESERVED',codec=expected.decode(),input_root=str(folder),input_inventory=e.inventory(folder)))
  for label,edits in [('ignored-model1',{'iHWCKmodel':1}),('ignored-model7',{'iHWCKmodel':7}),('inactive-flags',{'SWVAPOR':'0 0'})]:
   folder=mutated(base,label,edits);project=load(folder);assert vapor.describe(project) is None;q['checks'].append(dict(label=label,status='HISTORICAL_INACTIVE_VAPOR_PRESERVED',input_root=str(folder),input_inventory=e.inventory(folder)))
  negatives=[('bottom-'+str(b),{'SWBOTB':b}) for b in (0,1,2,3,4,7,9)]
  negatives += [('drainage2',{'SWDRA':2}),('Snow-drainage0',{'SWSNOW':1}),('Snow-bottom5',{'SWSNOW':1,'SWDRA':1,'SWBOTB':5})]
  negatives += [(key+'='+str(value),{key:value}) for key,value in [('SWHYST',1),('SWHYST',2),('SWFROST',1),('SWKIMPL',1),('SWMACRO',1),('SWBR',1),('SWMETDETAIL',1),('SWHEA',0),('SWCALT',1),('SWSOLU',2),('NPRINTDAY',2),('SWMONTH',1),('SWODAT',1),('PERIOD',5),('SWRES',0),('FLPRINTDT','.TRUE.')]]
  for index,(label,edits) in enumerate(negatives):
   folder=mutated(base,'negative-'+str(index),edits)
   try:project=load(folder);e.auxiliary_magic(project)
   except ValueError as error:q['checks'].append(dict(label=label,status='UNQUALIFIED_COMPOSITION_REFUSED',diagnostic=str(error),input_root=str(folder),input_inventory=e.inventory(folder)))
   else:raise AssertionError('Unqualified vapor boundary accepted: '+label)
  assert len(q['checks'])==55;q['status']='ACTUAL_VAPOR_BOUNDARY_24_SELECTED_26_REFUSED_TWO_PRIOR_THREE_INACTIVE_CONTROLS_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],len(q['checks']),flush=True)


if __name__=='__main__':main()
