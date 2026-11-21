"""Reread actual frontend inventories and execute the literal bounded guard."""
import ast,json
from analytical_hydraulic_archives import SHA
from initial_state_composition_source_inverse import CORE,ADAPTER,git
import experimental_project as e


def frontend(store):
 q=json.loads(store.get('profiles/initial-state-composition-frontend-v1/RESULT.json'));assert q['status']=='TEN_NEW_TWENTY_INITIAL2_OR3_TWENTY_SIX_STATE_REFUSALS_PASS' and len(q['checks'])==56
 raw=git('show',CORE+':'+ADAPTER);function=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='inspect');nodes=[n for n in function.body if isinstance(n,ast.If) and ast.unparse(n.test)=="selected.get('SWINCO') == 1"];assert len(nodes)==1;code=compile(ast.Module(body=nodes,type_ignores=[]),'literal-original-state-composition-guard','exec');counts={}
 for item in q['checks']:
  relative=item['input_root'].replace('\\','/').split('/evidence/',1)[1];folder=store.view('profiles/'+relative)
  for name,digest in item['input_inventory']:assert SHA((folder/name).read_bytes())==digest
  text=(folder/'swap.swp').read_text(encoding='cp1252');selected=e.switches(text);namespace=dict(vars(e),selected=selected,text=text,allowed={},original_output=item['original_output'])
  try:exec(code,namespace)
  except ValueError:assert item['status']=='UNQUALIFIED_STATE_CROSS_REFUSED'
  else:
   if selected['SWINCO']==1:assert item['status']=='NEW_STATE_PROFILE_SELECTED' and namespace['allowed']['SWINCO']=={1,2,3}
   else:assert item['status']=='INITIAL2_OR_3_ROUTE_RETAINED' and selected['SWINCO'] in (2,3) and not namespace['allowed']
  counts[item['status']]=counts.get(item['status'],0)+1
 assert counts==dict(NEW_STATE_PROFILE_SELECTED=10,INITIAL2_OR_3_ROUTE_RETAINED=20,UNQUALIFIED_STATE_CROSS_REFUSED=26)
 return dict(status='INDEPENDENT_ALL56_ACTUAL_INPUTS_LITERAL_STATE_GUARD_REPLAY_PASS',counts=counts,compiler_executions=0,model_executions=0)
