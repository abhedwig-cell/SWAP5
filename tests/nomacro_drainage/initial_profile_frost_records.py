"""Replay the literal pressure guard against every byte-preserved Frost input."""
import ast,json,types
from analytical_hydraulic_archives import SHA
from initial_profile_frost_source_inverse import ROOT,CORE,ADAPTER,blob,norm
import experimental_project as e


def frontend(store):
 import initial_profile_frost as frost
 import initial_profile_calendar as calendar
 raw=blob(CORE,ADAPTER);assert norm((ROOT/ADAPTER).read_bytes())==raw
 function=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='inspect')
 nodes=[n for n in function.body if isinstance(n,ast.If) and ast.unparse(n.test)=="selected.get('SWINCO') == 1"];assert len(nodes)==1
 code=compile(ast.Module(body=nodes,type_ignores=[]),'literal-initial-pressure-frost-guard','exec')
 q=json.loads(store.get('profiles/initial-profile-frost-frontend-v3/RESULT.json'));assert q['status']=='ACTUAL_INITIAL_PRESSURE_FROST_NATIVE_SELECTION_AND_HARD_BOUNDARIES_PASS' and len(q['checks'])==66 and q['selected']==q['retained']==4 and q['refused']==58
 saved=(frost.selection,calendar.selection);counts={}
 for module,original in zip((frost,calendar),saved):module.selection=types.FunctionType(original.__code__,dict(original.__globals__,Path=lambda value:value),argdefs=original.__defaults__)
 try:
  for item in q['checks']:
   relative=item['input_root'].replace('\\','/').split('/evidence/',1)[1]
   # Windows resolved these two requested trailing-dot directory names to
   # their actual dotless names. Map only these measured storage locations;
   # every original input byte is still independently matched below.
   aliases={f'initial-profile-frost-frontend-v3/{case}-field-FLPRINTDT-.TRUE.':f'initial-profile-frost-frontend-v3/{case}-field-FLPRINTDT-.TRUE' for case in ('explicit-water','implicit-cde')}
   folder=store.view('profiles/'+aliases.get(relative,relative))
   for name,digest in item['input_inventory']:assert SHA((folder/name).read_bytes())==digest
   text=(folder/'swap.swp').read_text(encoding='cp1252');namespace=dict(vars(e),directory=folder,text=text,allowed={'SWINCO':{2,3}},original_output=item.get('original_output',True))
   try:
    selected=e.switches(text);namespace['selected']=selected;exec(code,namespace)
    if selected['SWINCO'] not in namespace['allowed']['SWINCO']:raise ValueError('Unqualified original initialization')
   except ValueError:assert item['status']=='UNQUALIFIED_CROSS_REFUSED'
   else:
    if selected['SWINCO']==1:assert item['status']=='INITIAL1_SELECTED' and namespace['initial_frost'] is not None
    else:assert item['status']=='INITIAL2_RETAINED' and selected['SWINCO']==2
   counts[item['status']]=counts.get(item['status'],0)+1
 finally:frost.selection,calendar.selection=saved
 assert counts==dict(INITIAL1_SELECTED=4,INITIAL2_RETAINED=4,UNQUALIFIED_CROSS_REFUSED=58)
 return dict(status='INDEPENDENT_66_ACTUAL_INPUT_LITERAL_PRESSURE_FROST_GUARD_REPLAY_PASS',counts=counts,compiler_executions=0,model_executions=0)
