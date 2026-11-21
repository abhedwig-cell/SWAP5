"""Retain actual current cross-boundary dispatch refusals before implementation."""
import argparse,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import experimental_project as e
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser()
 for key in ('base','output','reference-work'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),cases=[],source_inventory={},model_executions=0,compiler_executions=0,original_cross_domain_reader_observed=False,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  for filename in ('readswap.f90','boundbottom.f90','drainage.f90','WC_K_models_04_11.f90'):
   path=a.reference_work/'build/swap-selected'/filename;raw=path.read_bytes();(a.output/filename).write_bytes(raw);q['source_inventory'][filename]=hashlib.sha256(raw).hexdigest()
  for models in ('8','11','7 8'):
   for solute in (0,1):
    for drain,bottom in ((0,6),(1,5),(1,8),(0,5)):
     label=f'models{models.replace(" ","-")}-solute{solute}-dra{drain}-bottom{bottom}';folder=a.output/label;shutil.copytree(a.base,folder);path=folder/'swap.swp';text=path.read_text(encoding='cp1252')
     for key,value in dict(iHWCKmodel=models,SWVAPOR='1 1',SWSOLU=solute,SWDRA=drain,SWBOTB=bottom,NPRINTDAY=1,SWMONTH=0,SWODAT=0,SWRES=1,PERIOD=1,FLPRINTDT='.FALSE.').items():text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+str(value)+'\n'
     path.write_text(text,encoding='cp1252')
     try:e.load(folder,original_output=True,time_step_policy='original-adaptive-day-seed-v1')
     except ValueError as error:
      assert 'Active original vapor requires qualified explicit daily water/CDE' in str(error),(label,error)
      q['cases'].append(dict(label=label,status='ACTUAL_CURRENT_FRONTEND_REFUSED',diagnostic=str(error),models=models,solute=solute,drainage=drain,bottom=bottom,input_inventory=e.inventory(folder)))
     else:raise AssertionError('Previously refused boundary already accepted: '+label)
  assert len(q['cases'])==24;q['status']='TWENTY_FOUR_ACTUAL_VAPOR_BOUNDARY_COMPOSITION_REFUSALS_RETAINED_NO_SCIENTIFIC_CLAIM'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'])


if __name__=='__main__':main()
