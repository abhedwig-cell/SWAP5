"""Replay the literal pressure admission block on all actual archived inputs."""
import ast,json,types
from analytical_hydraulic_archives import SHA
from initial_profile_calendar_source_inverse import ROOT,CORE,ADAPTER,blob,norm
import experimental_project as e


def frontend(store):
 import initial_profile_calendar as selector
 import analytical_cde_calendar as calendar
 raw=blob(CORE,ADAPTER);assert norm((ROOT/ADAPTER).read_bytes())==raw
 function=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='inspect')
 nodes=[n for n in function.body if isinstance(n,ast.If) and ast.unparse(n.test)=="selected.get('SWINCO') == 1"];assert len(nodes)==1
 code=compile(ast.Module(body=nodes,type_ignores=[]),'literal-initial-profile-calendar-pressure-guard','exec')
 q=json.loads(store.get('profiles/initial-profile-calendar-frontend-v1/RESULT.json'));assert q['status']=='TWELVE_INITIAL1_TWELVE_INITIAL2_THIRTY_ONE_EXCLUDED_PRESSURE_CALENDAR_CROSSES_PASS' and len(q['checks'])==55
 allowed={e.switches((ROOT/('reference/swap-4.3.1/projects/'+name+'/swap.swp')).read_text(encoding='cp1252'))['SWINCO'] for name in ('1.hupselbrook','2.grassgrowth','4.salinitystress-04dS')};assert allowed=={2,3}
 saved=(selector.selection,calendar.input_context);counts={}
 selector.selection=types.FunctionType(saved[0].__code__,dict(saved[0].__globals__,Path=lambda value:value),argdefs=saved[0].__defaults__)
 calendar.input_context=types.FunctionType(saved[1].__code__,dict(saved[1].__globals__,Path=lambda value:value),argdefs=saved[1].__defaults__)
 try:
  for item in q['checks']:
   relative=item['input_root'].replace('\\','/').split('/evidence/',1)[1];folder=store.view('profiles/'+relative)
   for name,digest in item['input_inventory']:assert SHA((folder/name).read_bytes())==digest
   text=(folder/'swap.swp').read_text(encoding='cp1252');selected=e.switches(text);namespace=dict(vars(e),directory=folder,selected=selected,text=text,allowed={'SWINCO':set(allowed)},original_output=item.get('original_output',True))
   try:
    exec(code,namespace)
    if selected['SWINCO'] not in namespace['allowed']['SWINCO']:raise ValueError('Original initialization selector outside unchanged reference domain')
   except ValueError:assert item['status']=='UNQUALIFIED_PRESSURE_CALENDAR_CROSS_REFUSED'
   else:
    if selected['SWINCO']==1:assert item['status']=='NEW_INITIAL1_CALENDAR_SELECTED' and namespace['initial_calendar'] is not None and namespace['allowed']['SWINCO']=={1,2,3}
    else:assert item['status']=='PRIOR_INITIAL2_CALENDAR_RETAINED' and selected['SWINCO']==2
   counts[item['status']]=counts.get(item['status'],0)+1
 finally:selector.selection,calendar.input_context=saved
 assert counts==dict(NEW_INITIAL1_CALENDAR_SELECTED=12,PRIOR_INITIAL2_CALENDAR_RETAINED=12,UNQUALIFIED_PRESSURE_CALENDAR_CROSS_REFUSED=31)
 return dict(status='INDEPENDENT_55_ACTUAL_INPUTS_LITERAL_PRESSURE_GUARD_REPLAY_PASS',counts=counts,compiler_executions=0,model_executions=0)
