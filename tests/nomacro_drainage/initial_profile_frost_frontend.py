"""Exercise actual pressure/Frost input boundaries without compiling or running."""
import argparse,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import experimental_project as e
from initial_profile_frost import selection
from initial_profile_frost_source_inverse import complete_inverse
from original_output_baseline import assignment
CASES={'explicit-water':'S5FDW001','explicit-cde':'S5FDC001','implicit-water':'S5FIW002','implicit-cde':'S5FIC002'}


def main():
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();complete_inverse();a.output.mkdir()
 source=a.evidence/'initial-profile-frost-original-dispatch-v1';q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=[],compiler_executions=0,model_executions=0)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def load(path,authority=True):return e.auxiliary_magic(e.load(path,original_output=authority,time_step_policy='original-adaptive-event-closure-v1')).decode()
 def record(path,label,status,**extra):q['checks'].append(dict(label=label,status=status,input_root=str(path),input_inventory=e.inventory(path),**extra));save()
 try:
  for case,codec in CASES.items():
   for initial in (1,2):
    path=source/(case+'-initial'+str(initial));assert load(path)==codec
    assert (selection(path) is not None)==(initial==1)
    record(path,case+'-initial'+str(initial),'INITIAL1_SELECTED' if initial==1 else 'INITIAL2_RETAINED',codec=codec)
  edits=[(key,value) for key,value in [('SWMACRO',1),('SWSOLU',2),('SWHYST',0),('SWHYST',1),('SWSNOW',0),('SWHEA',0),('SWCALT',1),('SWSOPHY',1),('SWDRA',0),('SWBOTB',5),('SWBOTB',7),('SWBOTB',8),('SWBBCFILE',1),('SWMETDETAIL',1),('SWBR',1),('SWKIMPL',2),('NPRINTDAY',0),('NPRINTDAY','1.5'),('PERIOD',2),('SWMONTH',1),('SWODAT',1),('SWRES',0),('FLPRINTDT','.TRUE.'),('IHWCKMODEL',8)]]
  controls=[('field-'+key+'-'+str(value),key,value) for key,value in edits]
  controls += [('duplicate-SWINCO',None,'\nSWINCO = 1\n'),('duplicate-model',None,'\nIHWCKMODEL = 1\n'),('soils-db',None,"\nSWAP_SOILS_DB = 'foreign'\n"),('drain-divd0','DRAIN',0),('compatibility-output','AUTHORITY',False)]
  for case in ('explicit-water','implicit-cde'):
   for label,key,value in controls:
    path=a.output/(case+'-'+label);shutil.copytree(source/(case+'-initial1'),path);file=path/'swap.swp';text=file.read_text(encoding='cp1252');authority=key!='AUTHORITY'
    if key=='DRAIN':
     drain=path/'swap.dra';drain.write_text(assignment(drain.read_text(encoding='cp1252'),'SWDIVD',value),encoding='cp1252')
    elif key!='AUTHORITY':
     if key is None:
      if label=='duplicate-model' and not re.search(r'(?mi)^\s*IHWCKMODEL\s*=',text):value=value*2
      changed=text+value
     else:changed=assignment(text,key,value) if re.search(r'(?mi)^\s*'+key+r'\s*=',text) else text+'\n'+key+' = '+str(value)+'\n'
     file.write_text(changed,encoding='cp1252')
    try:context=selection(path,authority)
    except ValueError:context=None
    assert context is None,'Unqualified pressure/Frost context selected: '+label
    try:load(path,authority)
    except ValueError as error:record(path,case+'-'+label,'UNQUALIFIED_CROSS_REFUSED',diagnostic=str(error),original_output=authority)
    else:raise AssertionError('Unqualified pressure/Frost input admitted: '+case+'-'+label)
  assert len(q['checks'])==8+2*len(controls);q.update(status='ACTUAL_INITIAL_PRESSURE_FROST_NATIVE_SELECTION_AND_HARD_BOUNDARIES_PASS',selected=4,retained=4,refused=2*len(controls))
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],len(q['checks']))


if __name__=='__main__':main()
