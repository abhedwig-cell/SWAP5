"""Exercise actual pressure/AGE inputs, retained policies and hard boundaries."""
import argparse,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import experimental_project as e
from original_output_baseline import assignment
from initial_profile_age_source_inverse import complete_inverse


def main():
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();complete_inverse();a.output.mkdir();original=json.loads((a.evidence/'initial-profile-age-original-dispatch-v2/RESULT.json').read_text());assert len(original['checks'])==10
 inputs={item['case']:item for item in original['checks']};q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=[],compiler_executions=0,model_executions=0)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def load(path,authority=True,**flags):return e.auxiliary_magic(e.load(path,original_output=authority,time_step_policy='original-adaptive-day-seed-v1',**flags)).decode()
 def record(path,label,status,**extra):q['checks'].append(dict(label=label,status=status,input_root=str(path),input_inventory=e.inventory(path),**extra));save()
 try:
  for case,item in inputs.items():
   for initial,key in ((1,'pressure_input_root'),(2,'parent_input_root')):
    path=Path(item[key]);assert load(path)=='S5IOA001';record(path,case+'-initial'+str(initial),'INITIAL1_SELECTED' if initial==1 else 'INITIAL2_RETAINED')
  for flag,codec in [('age_irrigation_source','S5AIO001'),('age_direct_soil_source','S5DIO001')]:
   path=Path(inputs['dense-surface']['parent_input_root']);assert load(path,**{flag:True})==codec;record(path,flag+'-initial2','PRIOR_EXPLICIT_SOURCE_POLICY_RETAINED',flags={flag:True},codec=codec)
   path=Path(inputs['dense-surface']['pressure_input_root'])
   try:load(path,**{flag:True})
   except ValueError as error:assert 'excludes explicit incoming-age source policies' in str(error);record(path,flag+'-initial1','UNQUALIFIED_CROSS_REFUSED',flags={flag:True},diagnostic=str(error))
   else:raise AssertionError('Unqualified explicit AGE policy selected')
  controls=[('field-'+key+'-'+str(value),key,value) for key,value in [('SWMACRO',1),('SWKIMPL',1),('SWSOPHY',1),('SWFROST',1),('SWSNOW',1),('SWHYST',1),('SWHYST',2),('SWHEA',0),('SWCALT',1),('SWDRA',0),('SWDRA',2),('SWBOTB',1),('SWBOTB',5),('SWBOTB',7),('SWBOTB',8),('SWBR',1),('SWBBCFILE',1),('SWMETDETAIL',1),('SWKMEAN',0),('SWKMEAN',7),('NPRINTDAY',0),('NPRINTDAY',1441),('NPRINTDAY','1.5'),('PERIOD',-1),('PERIOD',367),('SWMONTH',2),('SWODAT',2),('SWRES',2),('FLPRINTDT','.TRUE.'),('FLPRINTDT','INVALID'),('IHWCKMODEL',8)]]
  controls += [('duplicate-SWINCO',None,'\nSWINCO = 1\n'),('soils-db',None,"\nSWAP_SOILS_DB = 'foreign'\n"),('compatibility-output','AUTHORITY',False)]
  for case in ('dense-plain','monthly-subsurface'):
   for index,(label,key,value) in enumerate(controls):
    path=a.output/(case+'-control-'+str(index));shutil.copytree(inputs[case]['pressure_input_root'],path);file=path/'swap.swp';text=file.read_text(encoding='cp1252');authority=key!='AUTHORITY'
    if key is None:file.write_text(text+value,encoding='cp1252')
    elif key!='AUTHORITY':file.write_text(assignment(text,key,value) if re.search(r'(?mi)^\s*'+key+r'\s*=',text) else text+'\n'+key+' = '+str(value)+'\n',encoding='cp1252')
    try:load(path,authority)
    except ValueError as error:record(path,case+'-'+label,'UNQUALIFIED_CROSS_REFUSED',original_output=authority,diagnostic=str(error))
    else:raise AssertionError('Unqualified pressure/AGE input admitted: '+case+'-'+label)
  q.update(status='ACTUAL_ORIGINAL_PRESSURE_AGE_NATIVE_DISPATCH_AND_HARD_BOUNDARIES_PASS',new_selected=10,initial2_retained=10,prior_explicit_policies_retained=2,unqualified_refusals=2+2*len(controls));assert len(q['checks'])==24+2*len(controls)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],len(q['checks']))


if __name__=='__main__':main()
