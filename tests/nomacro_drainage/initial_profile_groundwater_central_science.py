"""Reread actual archived AGE science, user outputs and compiled postimages."""
import argparse,ast,json,types
from contextlib import ExitStack
from pathlib import Path,PurePosixPath
from analytical_hydraulic_archives import Archive,SHA
from frost_cde_drainage_science import View
from initial_profile_groundwater_source_inverse import ROOT,BASE,CORE,ADAPTER,complete_inverse,git,blob,norm
from initial_profile_groundwater_science import audit
from initial_profile_groundwater_preserve import POST,SCI
from initial_profile_calendar_postimage import compare
from original_output_baseline import assignment
from original_output_files import compare as outputs
import experimental_project as e


class ReadView(View):
 @property
 def suffix(self):return PurePosixPath(self.path).suffix
 def __truediv__(self,name):return ReadView(self.store,self.path+'/'+str(name))
 def glob(self,pattern):return [ReadView(item.store,item.path) for item in super().glob(pattern)]


def frontend(store):
 import initial_profile_groundwater as groundwater
 import initial_profile_age as age
 import initial_profile_calendar as calendar
 import initial_profile_frost as frost
 complete_inverse();assert norm((ROOT/ADAPTER).read_bytes())==blob(CORE,ADAPTER)
 source=ast.parse(blob(CORE,ADAPTER))
 inspect=next(n for n in source.body if isinstance(n,ast.FunctionDef) and n.name=='inspect')
 nodes=[n for n in inspect.body if isinstance(n,ast.If) and ast.unparse(n.test)=="selected.get('SWINCO') == 1"];assert len(nodes)==1
 pressure=compile(ast.Module(body=nodes,type_ignores=[]),'literal-groundwater-pressure-guard','exec')
 # Replay the exact incoming-policy condition. Its AGE report field is
 # assigned literally from SWSOLU=2 in the unchanged inspect function.
 assert any(isinstance(n,ast.If) and ast.unparse(n)=="if selected['SWSOLU'] == 2:\n    report['age'] = True" for n in inspect.body)
 load=next(n for n in source.body if isinstance(n,ast.FunctionDef) and n.name=='load')
 nodes=[n for n in load.body if isinstance(n,ast.If) and ast.unparse(n.test)=="report.get('age') and report['boundary']['SWBOTB'] == 1 and (age_irrigation_source or age_direct_soil_source)"];assert len(nodes)==1
 policy=compile(ast.Module(body=nodes,type_ignores=[]),'literal-AGE-groundwater-incoming-policy','exec')
 q=json.loads(store.get('profiles/initial-profile-groundwater-frontend-v1/RESULT.json'));assert q['status']=='ACTUAL_TWENTY_PRESSURE_GROUNDWATER_NATIVE_ROUTES_RETAINED_PARENTS_AND_HARD_BOUNDARIES_PASS' and len(q['checks'])==146
 saved=[(module,module.selection) for module in (groundwater,age,calendar,frost)];counts={}
 for module,original in saved:module.selection=types.FunctionType(original.__code__,dict(original.__globals__,Path=lambda value:value),argdefs=original.__defaults__)
 try:
  for item in q['checks']:
   relative=item['input_root'].replace('\\','/').split('/evidence/',1)[1];folder=store.view('profiles/'+relative)
   for name,digest in item['input_inventory']:assert SHA((folder/name).read_bytes())==digest
   text=(folder/'swap.swp').read_text(encoding='cp1252');flags=item.get('flags',{})
   namespace=dict(vars(e),directory=folder,text=text,allowed={'SWINCO':{2,3}},original_output=item.get('original_output',True),age_irrigation_source=flags.get('age_irrigation_source',False),age_direct_soil_source=flags.get('age_direct_soil_source',False))
   try:
    selected=e.switches(text);namespace.update(selected=selected,report=dict(age=selected['SWSOLU']==2,boundary={'SWBOTB':selected['SWBOTB']}));exec(policy,namespace);exec(pressure,namespace)
    if selected['SWINCO'] not in namespace['allowed']['SWINCO']:raise ValueError('Unqualified original initialization')
   except ValueError:assert item['status']=='UNQUALIFIED_CROSS_REFUSED',item['label']
   else:
    if selected['SWINCO']==1:assert item['status']=='INITIAL1_SELECTED' and namespace['initial_groundwater'] is not None
    else:assert item['status']=='INITIAL2_RETAINED' and selected['SWINCO']==2
   counts[item['status']]=counts.get(item['status'],0)+1
 finally:
  for module,original in saved:module.selection=original
 assert counts==dict(INITIAL1_SELECTED=20,INITIAL2_RETAINED=20,UNQUALIFIED_CROSS_REFUSED=106)
 return dict(status='INDEPENDENT_146_BYTE_PRESERVED_INPUTS_LITERAL_PRESSURE_AND_AGE_GROUNDWATER_POLICY_PASS',counts=counts,compiler_executions=0,model_executions=0)


def read(proof,names):
 complete_inverse();observations=[];postimages=[];dispatch=None
 path='tests/nomacro_scheduled_subsurface/original_output_files.py';assert norm((ROOT/path).read_bytes())==blob(BASE,path)
 with ExitStack() as stack:
  provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
  for name in names:
   store=Archive(proof,name,stack);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));portable='UBUNTU' in name
   if not portable:dispatch=frontend(store)
   class Reference:
    def __truediv__(self,key):
     assert key.startswith('build/');return (store if portable else provider).view('original-provider-build/'+key[6:])
   for role in store.record['roles']:
    profile=ReadView(store,role['profile']);q=json.loads((profile/'RESULT.json').read_text());item=projection[q['build_root']];build=store.view(item['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
    actual=audit(profile,Reference(),locations=dict(inputs=store.view(role['inputs']),build=build));assert actual==role['science'] and actual['status']==SCI
    from initial_profile_groundwater_activity import audit as activity
    active=activity(profile,store.view(role['inputs']),Reference());assert active==role['activity']
    meta=json.loads((build/'BUILD.json').read_text());selected=meta['identity']['original_output'];start_date=meta['project']['start_date'];user=[]
    for cold in q['cold']:
     result=outputs(profile/'trajectory/original',profile/('own-'+str(cold['start']))/'original',selected,cold['start'],cold['end'],start_date);assert result==cold['exact_user_output'];user.append(result)
    observations.append(dict(archive=name,profile=role['profile'],science=actual,activity=active,independent_actual_user_output_comparisons=user))
   for prefix in store.record['postimages']:
    q=json.loads(store.get(prefix+'/RESULT.json'));assert q['status']==POST and not git('diff',CORE,q['source'],'--','app','src','tools/solute','tools/vq','reference')
    prior=projection[q['initial1_build_root']];baseline=projection[q['build_root']];role=next(role for role in store.record['roles'] if json.loads(store.get(role['profile']+'/RESULT.json'))['build_root']==q['initial1_build_root'])
    raw=store.get(role['profile']+'/RESULT.json');assert SHA(raw)==q['initial1_RESULT_sha256'];relative=('inputs/'+q['input_root'].rsplit('/',1)[1]) if portable else 'profiles/'+q['input_root'].replace('\\','/').split('/evidence/',1)[1];inputs=store.view(relative);original=store.view(role['inputs'])
    for filename,digest in q['input_inventory']:assert SHA((inputs/filename).read_bytes())==digest
    assert assignment((inputs/'swap.swp').read_bytes().decode('cp1252'),'SWINCO',1).encode('cp1252')==(original/'swap.swp').read_bytes()
    for filename,digest in json.loads(raw)['input_inventory']:
     if filename!='swap.swp':assert (inputs/filename).read_bytes()==(original/filename).read_bytes()
    for item in (prior,baseline):assert SHA(store.get(item['archive_prefix']+'/BUILD.json'))==item['actual_BUILD_sha256']
    result=compare(store.view(baseline['archive_prefix']),store.view(prior['archive_prefix']));assert result==q['postimage'];postimages.append(dict(archive=name,profile=prefix,postimage=result))
 return dict(status='CENTRAL_ORIGINAL_PRESSURE_GROUNDWATER_HEADS_LEDGERS_ACTIVE_INVENTORIES_NATIVE_USER_OUTPUT_AND_WHOLE_POSTIMAGES_PASS',contexts=len(observations),exact_cold_windows=3*len(observations),native_checkpoints=7*len(observations),compiler_postimages=len(postimages),observations=observations,postimages=postimages,frontend=dispatch,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--names',nargs='+',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=read(a.proof,a.names)
 with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
 print(q['status'],q['contexts'],q['compiler_postimages'])
