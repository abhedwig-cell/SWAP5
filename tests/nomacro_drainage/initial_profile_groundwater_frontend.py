"""Exercise actual pressure/groundwater routes and retained hard boundaries."""
import argparse,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import experimental_project as e
from original_output_baseline import assignment
from initial_profile_groundwater_source_inverse import complete_inverse,CORE


def main():
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();complete_inverse();a.output.mkdir();original=json.loads((ROOT/'integration/f-ci/nomacro-complete01/INITIAL_PROFILE_GROUNDWATER_DISCOVERY_V1.json').read_text());inputs={x['case']:x for x in original['checks']};assert len(inputs)==20
 q=dict(status='RUNNING',actual_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),physical_core=CORE,actual_observer_normalized_source_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),checks=[],compiler_executions=0,model_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def load(path,authority=True,**flags):return e.auxiliary_magic(e.load(path,original_output=authority,time_step_policy='original-adaptive-day-seed-v1',**flags)).decode()
 def record(path,label,status,**extra):q['checks'].append(dict(label=label,status=status,input_root=str(path),input_inventory=e.inventory(path),**extra));save()
 try:
  for case,item in inputs.items():
   for initial,key in ((1,'pressure_input_root'),(2,'parent_input_root')):
    path=Path(item[key]);assert load(path)==item['actual_parent_codec'];record(path,case+'-initial'+str(initial),'INITIAL1_SELECTED' if initial==1 else 'INITIAL2_RETAINED',actual_native_codec=item['actual_parent_codec'])
  controls=[('field-'+key+'-'+str(value),key,value) for key,value in [('SWMACRO',1),('SWFROST',1),('SWSOPHY',1),('SWBR',1),('SWBBCFILE',1),('SWMETDETAIL',1),('SWHEA',0),('SWCALT',1),('SWDRA',2),('SWBOTB',2),('SWBOTB',3),('SWBOTB',4),('SWBOTB',7),('SWBOTB',9),('SWHYST',3),('SWSNOW',2),('SWSOLU',3),('SWKMEAN',0),('SWKMEAN',7),('NPRINTDAY',0),('NPRINTDAY',1441),('NPRINTDAY','1.5'),('PERIOD',-1),('PERIOD',367),('SWMONTH',2),('SWODAT',2),('SWRES',2),('FLPRINTDT','INVALID'),('IHWCKMODEL',2),('IHWCKMODEL',8)]]
  controls += [('duplicate-SWINCO',None,'\nSWINCO = 1\n'),('soils-db',None,"\nSWAP_SOILS_DB = 'foreign'\n"),('compatibility-output','AUTHORITY',False)]
  for case in ('water-h2-implicit-clock','cde-h1-snow-step','age-h2-monthly'):
   for index,(label,key,value) in enumerate(controls):
    path=a.output/(case+'-control-'+str(index));shutil.copytree(inputs[case]['pressure_input_root'],path);file=path/'swap.swp';text=file.read_text(encoding='cp1252');authority=key!='AUTHORITY'
    if key is None:text+=value
    elif key!='AUTHORITY':text=assignment(text,key,value) if re.search(r'(?mi)^\s*'+key+r'\s*=',text) else text+'\n'+key+' = '+str(value)+'\n'
    if key=='SWBBCFILE':
     table=re.search(r'(?mi)^\s*DATE1\s+GWLEVEL[^\n]*\n(.*?)^\* End of table',text,re.S);assert table;text=assignment(text,'BBCFIL',repr('groundwater'));(path/'groundwater.bbc').write_text('SWBOTB = 1\nDATE1 GWLEVEL\n'+table[1]+'* End of table\n',encoding='cp1252')
    file.write_text(text,encoding='cp1252')
    try:load(path,authority)
    except ValueError as error:record(path,case+'-'+label,'UNQUALIFIED_CROSS_REFUSED',original_output=authority,diagnostic=str(error))
    else:raise AssertionError('Unqualified pressure groundwater context selected: '+case+'-'+label)
  for initial,key in ((1,'pressure_input_root'),(2,'parent_input_root')):
   for flag in ('age_irrigation_source','age_direct_soil_source'):
    path=Path(inputs['age-h2-monthly'][key])
    try:load(path,**{flag:True})
    except ValueError as error:assert 'requires historical young-water source policy' in str(error);record(path,'age-initial'+str(initial)+'-'+flag,'UNQUALIFIED_CROSS_REFUSED',flags={flag:True},diagnostic=str(error))
    else:raise AssertionError('Unqualified positive incoming AGE policy selected')
  for case,key,value in [('age-h2-monthly','SWKIMPL',1),('age-h2-monthly','SWSNOW',1),('cde-h1-snow-step','SWKIMPL',1)]:
   path=a.output/(case+'-extra-'+key);shutil.copytree(inputs[case]['pressure_input_root'],path);file=path/'swap.swp';file.write_text(assignment(file.read_text(encoding='cp1252'),key,value),encoding='cp1252')
   try:load(path)
   except ValueError as error:record(path,case+'-extra-'+key,'UNQUALIFIED_CROSS_REFUSED',diagnostic=str(error))
   else:raise AssertionError('Unqualified implicit/Snow/AGE state cross selected')
  q.update(status='ACTUAL_TWENTY_PRESSURE_GROUNDWATER_NATIVE_ROUTES_RETAINED_PARENTS_AND_HARD_BOUNDARIES_PASS',new_selected=20,initial2_retained=20,unqualified_refusals=3*len(controls)+7);assert len(q['checks'])==40+q['unqualified_refusals']
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],len(q['checks']))


if __name__=='__main__':main()
