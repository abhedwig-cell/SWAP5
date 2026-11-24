"""Prepare one original-parameter analytical Snow batch, preserving numeric spelling."""
import hashlib,json,re,subprocess,sys,zipfile
from pathlib import Path
R=Path('C:/Users/Veldh012/swap5-nomacro-scheduled-chemical01');E=Path(__file__).parent;P=R/'integration/f-ci/nomacro-complete01';sys.path.insert(0,str(R/'app/hybrid_water'))
import experimental_project as project
SHA=lambda raw:hashlib.sha256(raw).hexdigest();head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip();root=E/'explicit-bottom9-snow-analytical-inputs-v1';root.mkdir();archives={}
for name in ('EXPLICIT_BOTTOM9_ANALYTICAL_INPUTS_V1','EXPLICIT_BOTTOM9_SNOW_INPUTS_V1','EXPLICIT_BOTTOM9_SNOW_HISTORY_CALENDAR_INPUTS_V3'):
 q=json.loads((P/(name+'.json')).read_text());raw=(P/(name+'.zip')).read_bytes();assert len(raw)==q['bytes'] and SHA(raw)==q['sha256'];archives[name]=(zipfile.ZipFile(P/(name+'.zip')),q)
def role(name,prefix):
 z,q=archives[name];files={}
 for item in z.namelist():
  if item.startswith(prefix+'/'):
   raw=z.read(item);assert len(raw)==q['members'][item]['bytes'] and SHA(raw)==q['members'][item]['sha256'];files[Path(item).name]=raw
 assert len(files)==10;return files
def assign(raw,key,value):
 pattern=rb'(?mi)^([ \t]*'+key.encode()+rb'[ \t]*=[ \t]*)[^!\r\n]*';result,count=re.subn(pattern,lambda m:m[1]+value.encode()+b' ',raw)
 if count==0:result=raw+b'\r\n'+key.encode()+b' = '+value.encode()+b'\r\n'
 assert count in (0,1);return result
cases=[];files={}
for model in (3,7,11):
 for kind in ('water','cde'):
  hydraulic=role('EXPLICIT_BOTTOM9_ANALYTICAL_INPUTS_V1','model'+str(model)+'-'+kind+'-initial1')
  base=role('EXPLICIT_BOTTOM9_SNOW_INPUTS_V1',kind+'-initial1') if kind=='water' else role('EXPLICIT_BOTTOM9_SNOW_HISTORY_CALENDAR_INPUTS_V3','cde-initial1-hys2-step-reset')
  raw=assign(base['swap.swp'],'SWHYST','0');changes=[]
  for key in ('IHWCKMODEL','OSAT','ORES','ALFA','NPAR','LEXP','H_ENPR','KSATFIT','KSAT','KSATEXM','ELAS','ALFA_2','NPAR_2','OMEGA_1','H0','HA','APAR','OMEGA_K','SWVAPOR'):
   values=re.findall(rb'(?mi)^[ \t]*'+key.encode()+rb'[ \t]*=[ \t]*([^!\r\n]*)',hydraulic['swap.swp']);assert len(values)<=1
   if values:
    value=values[0].strip().decode('cp1252');raw=assign(raw,key,value);changes.append(dict(field=key,exact_original_numeric_spelling=value))
  base['swap.swp']=raw
  if model==7:
   old=E/'explicit-bottom9-snow-analytical-preflight-inputs-v1'/('snow-analytical7-'+kind+'-initial1')
   assert {name:SHA(value) for name,value in base.items()}=={path.name:SHA(path.read_bytes()) for path in old.iterdir() if path.is_file()}
  for initial in (1,2):
   label='model'+str(model)+'-'+kind+'-initial'+str(initial);folder=root/label;folder.mkdir()
   for name,value in base.items():
    if initial==2 and name=='swap.swp':
     value,count=re.subn(rb'(?mi)^([ \t]*SWINCO[ \t]*=[ \t]*)1\b',lambda m:m[1]+b'2',value);assert count==1
    (folder/name).write_bytes(value);files[label+'/'+name]=value
   actual=project.load(folder,original_output=True,time_step_policy='original-adaptive-day-seed-v1')
   from model7_capacity import analytical_models
   assert analytical_models(actual)==(model,model) and actual.solute==(kind=='cde')
   cases.append(dict(role=label,model=model,kind=kind,initial=initial,parameters=changes,actual_native_codec=project.auxiliary_magic(actual).decode(),input_inventory={n:SHA((folder/n).read_bytes()) for n in base}))
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip()==head
name='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_INPUTS_V1';archive=P/(name+'.zip');assert not archive.exists()
with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
 for key,raw in sorted(files.items()):z.writestr(key,raw)
raw=archive.read_bytes();record=dict(status='ACTUAL_ORIGINAL_PARAMETER_SNOW_ANALYTICAL_3_7_11_WATER_CDE_INPUTS_PREPARED_NO_MODELS',source=head,archive=archive.name,bytes=len(raw),sha256=SHA(raw),members={k:dict(bytes=len(v),sha256=SHA(v)) for k,v in files.items()},roles=[x['role'] for x in cases],cases=cases,parent_input_archives={k:q['sha256'] for k,(_,q) in archives.items()},model7_preflight_inputs_exactly_preserved=True,compiler_executions=0,model_executions=0,canonical_admission=False)
(P/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n');print(record['status'],len(files),len(raw),record['sha256'])
