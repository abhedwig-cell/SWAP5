"""Exercise real bounded profile admission and literal prior initialization routes."""
import argparse,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import experimental_project as e
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser();p.add_argument('--input-record',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir();selected=json.loads(a.input_record.read_text())['selected_inputs'];q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=[],compiler_executions=0,model_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def load(folder,original_output=True):return e.load(folder,original_output=original_output,time_step_policy='original-adaptive-day-seed-v1')
 def record(folder,label,status,**extra):q['checks'].append(dict(label=label,status=status,input_root=str(folder),input_inventory=e.inventory(folder),**extra));save()
 def mutate(label,edits):
  out=a.output/label;shutil.copytree(Path(selected['nonhydrostatic-water']),out);path=out/'swap.swp';text=path.read_text(encoding='cp1252')
  for key,value in edits.items():text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+str(value)+'\n'
  path.write_text(text,encoding='cp1252');return out
 save()
 try:
  for case,path in selected.items():
   folder=Path(path);project=load(folder);assert e.inspect(folder,original_output=True)['selectors']['SWINCO']==1;record(folder,case,'NEW_PROFILE_SELECTED',codec=e.auxiliary_magic(project).decode())
  for name in ('1.hupselbrook','2.grassgrowth','4.salinitystress-04dS'):
   folder=ROOT/'reference/swap-4.3.1/projects'/name;actual=e.inspect(folder,original_output=True);assert actual['selectors']['SWINCO']==(3 if name.startswith('4.') else 2);record(folder,name,'PRIOR_INITIALIZATION_PRESERVED',SWINCO=actual['selectors']['SWINCO'])
  negatives=[('bottom-'+str(b),{'SWBOTB':b}) for b in (0,1,2,3,4,7,9)]
  negatives += [(key+'='+str(value),{key:value}) for key,value in [('SWSOLU',2),('SWHYST',1),('SWHYST',2),('SWSNOW',1),('SWFROST',1),('SWHEA',0),('SWCALT',1),('SWKIMPL',1),('SWDRA',2),('SWBBCFILE',1),('SWMETDETAIL',1),('SWBR',1),('SWMACRO',1),('NPRINTDAY',2),('PERIOD',0),('SWMONTH',1),('SWODAT',1),('SWRES',0),('FLPRINTDT','.TRUE.')]]
  for i,(label,edits) in enumerate(negatives):
   folder=mutate('negative-'+str(i),edits)
   try:load(folder)
   except ValueError as error:record(folder,label,'UNQUALIFIED_PROFILE_COMPOSITION_REFUSED',diagnostic=str(error))
   else:raise AssertionError('Unqualified initial pressure profile accepted: '+label)
  folder=Path(selected['nonhydrostatic-water'])
  try:load(folder,False)
  except ValueError as error:record(folder,'compatibility-output','UNQUALIFIED_PROFILE_COMPOSITION_REFUSED',diagnostic=str(error))
  else:raise AssertionError('Compatibility output admitted new profile')
  folder=mutate('model3-oxygen2',{'iHWCKmodel':'3 3'})
  try:load(folder)
  except ValueError as error:assert 'Original hydraulic model3 with physical oxygen stress2 is explicitly not implemented' in str(error);record(folder,'model3-oxygen2','ORIGINAL_UNIMPLEMENTED_PHYSICS_REFUSED',diagnostic=str(error))
  else:raise AssertionError('Unimplemented original physical oxygen admitted')
  assert len(q['checks'])==35;q['status']='ACTUAL_FOUR_NEW_THREE_PRIOR_TWENTY_EIGHT_PROFILE_REFUSALS_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],len(q['checks']))


if __name__=='__main__':main()
