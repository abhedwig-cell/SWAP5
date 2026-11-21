"""Reread real frontend inputs and execute the sole changed literal guard."""
import ast,json,re,sys
from pathlib import Path
from analytical_hydraulic_archives import SHA
from initial_pressure_profile_source_inverse import ROOT,CORE,PATH,git
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import experimental_project as e
from initial_pressure_profile_science import CODECS


def frontend(store):
 raw=git('show',CORE+':'+PATH);function=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='inspect');nodes=[n for n in function.body if isinstance(n,ast.If) and ast.unparse(n.test)=="selected.get('SWINCO') == 1"];assert len(nodes)==1
 code=compile(ast.Module(body=nodes,type_ignores=[]),'literal-qualified-initialization-guard','exec')
 q=json.loads(store.get('profiles/initial-pressure-profile-frontend-v1/RESULT.json'));assert len(q['checks'])==35
 counts={}
 for item in q['checks']:
  path=item['input_root'].replace('\\','/')
  if '/evidence/' in path:folder=store.view('profiles/'+path.split('/evidence/',1)[1])
  else:assert '/reference/swap-4.3.1/projects/' in path;folder=ROOT/'reference/swap-4.3.1/projects'/path.split('/reference/swap-4.3.1/projects/',1)[1]
  for name,digest in item['input_inventory']:assert SHA((folder/name).read_bytes())==digest
  text=(folder/'swap.swp').read_text(encoding='cp1252');selected=e.switches(text);namespace=dict(vars(e),selected=selected,text=text,allowed={},original_output=item['label']!='compatibility-output')
  try:exec(code,namespace)
  except ValueError:assert item['status']=='UNQUALIFIED_PROFILE_COMPOSITION_REFUSED'
  else:
   if item['status']=='NEW_PROFILE_SELECTED':assert namespace['allowed']['SWINCO']=={1,2,3} and item['codec']==CODECS[item['label']].decode()
   elif item['status']=='PRIOR_INITIALIZATION_PRESERVED':assert selected['SWINCO']==item['SWINCO'] and selected['SWINCO'] in (2,3) and not namespace['allowed']
   else:
    assert item['status']=='ORIGINAL_UNIMPLEMENTED_PHYSICS_REFUSED' and 'Original hydraulic model3 with physical oxygen stress2 is explicitly not implemented' in item['diagnostic']
    models=re.findall(r'(?mi)^[ \t]*iHWCKmodel[ \t]*=[ \t]*([^!\r\n]+)',text);assert len(models)==1 and list(map(int,models[0].split()))==[3,3]
    assert any(e.switches((folder/name).read_text(encoding='cp1252')).get('SWOXYGEN')==2 for name,digest in item['input_inventory'] if name.lower().endswith('.crp'))
  counts[item['status']]=counts.get(item['status'],0)+1
 assert counts=={'NEW_PROFILE_SELECTED':4,'PRIOR_INITIALIZATION_PRESERVED':3,'UNQUALIFIED_PROFILE_COMPOSITION_REFUSED':27,'ORIGINAL_UNIMPLEMENTED_PHYSICS_REFUSED':1}
 return dict(status='INDEPENDENT_ALL35_ACTUAL_FRONTEND_INPUTS_AND_LITERAL_NEW_GUARD_REPLAY_PASS',counts=counts,old_complete_inspect_body_preserved_by_whole_AST_inverse=True,compiler_executions=0,model_executions=0)
