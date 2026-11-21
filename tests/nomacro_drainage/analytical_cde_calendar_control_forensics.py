"""Rebuild actual archived mutations and inspect compiled refusals and replay."""
import ast,io,json,struct,types,zipfile
from analytical_hydraulic_archives import SHA
from analytical_cde_calendar_source_inverse import ROOT,BASE,CORE,PREVIOUS_CORE,blob,git,SURFACES
from analytical_cde_calendar_science import CASES,NATIVE6_CORE


def frontend(store):
 import analytical_cde_calendar as selected
 path='app/hybrid_water/analytical_cde_calendar.py';assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==blob(CORE,path)
 observer=types.FunctionType(selected.input_context.__code__,dict(selected.input_context.__globals__,Path=lambda value:value),argdefs=selected.input_context.__defaults__)
 q=json.loads(store.get('profiles/analytical-cde-calendar-frontend-v2/RESULT.json'));assert q['status']=='FOURTEEN_CALENDAR_ROUTES_AND_TWENTY_FIVE_EXCLUDED_CROSSES_PASS' and len(q['checks'])==39 and q['compiler_executions']==q['model_executions']==0
 assert not git('diff',PREVIOUS_CORE,q['source'],'--',*SURFACES)
 counts={}
 for item in q['checks']:
  relative=item['input_root'].replace('\\','/').split('/evidence/',1)[1];folder=store.view('profiles/'+relative)
  for name,digest in item['input_inventory']:assert SHA((folder/name).read_bytes())==digest
  actual=observer(folder,True)
  if item['status']=='BOUNDED_CALENDAR_SELECTED':
   assert actual is not None
   expected='S5HCC006' if actual['vapor'] else 'S5CCC001' if actual['clock'] else 'S5CIC001';assert expected==item['codec']
  else:assert item['status']=='UNQUALIFIED_CALENDAR_CROSS_REFUSED' and actual is None and item['diagnostic']
  counts[item['status']]=counts.get(item['status'],0)+1
 assert counts=={'BOUNDED_CALENDAR_SELECTED':14,'UNQUALIFIED_CALENDAR_CROSS_REFUSED':25};return counts


def native(store,role,prefix):
 import vapor_boundary_records as parent
 path='tests/nomacro_drainage/vapor_boundary_records.py';raw=blob(BASE,path);assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==raw
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='native'];assert len(nodes)==1;function=nodes[0]
 assignments=[n for n in function.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='b' for t in n.targets)];assert len(assignments)==1 and ast.unparse(assignments[0].value)=="v['boundary_composition']"
 assignments[0].value=ast.parse("calendar_domain(q['case'])",mode='eval').body
 values=[n for n in function.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='values' for t in n.targets)];assert len(values)==1 and values[0].value.left.left.elts[0].value==5;values[0].value.left.left.elts[0].value=6
 loops=[n for n in function.body if isinstance(n,ast.For) and isinstance(n.target,ast.Name) and n.target.id=='magic'];assert len(loops)==1 and len(loops[0].iter.elts)==9
 loops[0].iter.elts += [ast.Constant(v) for v in (b'S5HBC005',b'S5CIC001',b'S5CCC001')]
 for n in ast.walk(function):
  if isinstance(n,ast.Constant) and n.value==49:n.value=52
  elif isinstance(n,ast.Constant) and n.value=='ACTUAL_VAPOR_BOUNDARY_NATIVE5_49_TYPED_REFUSALS_AND_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS':n.value='ACTUAL_CDE_CALENDAR_VAPOR_NATIVE6_52_TYPED_REFUSALS_AND_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS'
 controls=json.loads(store.get(prefix+'/RESULT.json'));epochs=[epoch for epoch in (NATIVE6_CORE,PREVIOUS_CORE,CORE) if not git('diff',epoch,controls['source'],'--',*SURFACES)];assert len(epochs)==1
 namespace=dict(vars(parent),CORE=epochs[0],calendar_domain=lambda case:dict(zip(('drainage','bottom'),CASES[case][:2])))
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace)
 return namespace['native'](store,role,prefix)


def parent_calendar(store,role,projection,prefix):
 import cde_interval_runtime as matrix
 path='tests/nomacro_scheduled_subsurface/cde_interval_controls.py';raw=blob(BASE,path);assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==raw
 function=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='native')
 q=json.loads(store.get(role['profile']+'/RESULT.json'));build=projection[q['build_root']]['archive_prefix'];meta=json.loads(store.get(build+'/BUILD.json'));selected=meta['identity']['original_output'];n=meta['project']['nodes'];r=json.loads(store.get(prefix+'/RESULT.json'))
 assert r['status']=='LITERAL_ORIGINAL_CDE_CALENDAR_PRIVATE_AND_POLICY_NATIVE_REFUSALS_ON_ACTUAL_VAPOR6_PASS' and r['actual_compiled_refusals']==len(r['checks'])==47 and r['accepted_model_days']==r['compiler_executions']==0 and r['actual_BUILD_sha256']==SHA(store.get(build+'/BUILD.json'))
 with zipfile.ZipFile(io.BytesIO(store.get(role['profile']+'/trajectory/accepted-column-1-day-4.zip'))) as z:good=z.read('macro.bin')
 first=next(i for i,node in enumerate(function.body) if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='attacks' for t in node.targets))
 last=next(i for i,node in enumerate(function.body) if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='checks' for t in node.targets))
 loops=[node for node in function.body if isinstance(node,ast.For) and isinstance(node.target,ast.Name) and node.target.id=='attack'];assert len(loops)==1
 loop=loops[0];start=next(i for i,node in enumerate(loop.body) if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='raw' for t in node.targets));end=next(i for i,node in enumerate(loop.body) if isinstance(node,ast.Expr) and ast.unparse(node.value)=='path.write_bytes(raw)')
 mutations=loop.body[start:end];assert ast.unparse(mutations[0])=='raw = bytearray(path.read_bytes())';mutations[0]=ast.parse('raw=bytearray(good)').body[0]
 class Shape(ast.NodeTransformer):
  def visit_Attribute(self,node):return ast.copy_location(ast.Name(id='actual_nodes',ctx=ast.Load()),node) if isinstance(node.value,ast.Name) and node.value.id=='project' and node.attr=='nodes' else self.generic_visit(node)
  def visit_Call(self,node):return ast.copy_location(ast.Constant(b'S5HCC006'),node) if isinstance(node.func,ast.Name) and node.func.id=='magic' else self.generic_visit(node)
 generated=ast.Module(body=function.body[first:last]+ast.parse('rebuilt={}').body+[ast.For(target=ast.Name(id='attack',ctx=ast.Store()),iter=ast.Name(id='attacks',ctx=ast.Load()),body=mutations+ast.parse('rebuilt[attack]=bytes(raw)').body,orelse=[])],type_ignores=[])
 namespace=dict(struct=struct,matrix=matrix,selected=selected,actual_nodes=n,good=good);exec(compile(ast.fix_missing_locations(Shape().visit(generated)),path,'exec'),namespace)
 expected=namespace['rebuilt'];assert len(expected)==47 and set(expected)=={item['attack'] for item in r['checks']}
 for item in r['checks']:
  root=prefix+'/actual/'+item['attack'];assert store.get(root+'/origin/macro.bin')==expected[item['attack']]!=good and item['status']=='REFUSED'
  names=[name for name in store.names if name.startswith(root+'/')];diagnostic='\n'.join(store.get(name).decode('utf8',errors='replace') for name in sorted(names) if name.endswith('/donor.stderr'))
  assert diagnostic.replace('\r\n','\n')==item['diagnostic'].replace('\r\n','\n') and 'ERROR STOP' in diagnostic and not any('/accepted-' in name for name in names)
  assert all(b'HYBRID_READY' not in store.get(name) and b'HYBRID_DAY_RETURN' not in store.get(name) for name in names if name.endswith('/donor.stdout'))
 return dict(actual_compiled_refusals=47,actual_mutant_bytes_independently_rebuilt=True,accepted_model_days=0,compiler_executions=0,model_executions=0)


def transactions(store,role,projection,prefix):
 import implicit_snow_recovery_forensics as parent
 from implicit_conductivity_forensics import output_calendar
 path='tests/nomacro_drainage/implicit_snow_recovery_forensics.py';assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==blob(BASE,path)
 q=json.loads(store.get(role['profile']+'/RESULT.json'));entry=projection[q['build_root']];r=json.loads(store.get(prefix+'/RESULT.json'));assert r['external_transaction_worker_prepares']==3 and r['external_transaction_commits']==1 and all(r['transactions'].values())
 def decode(raw,row,build,selected,selectors):
  n=build['project']['nodes'];v=build['identity']['hydraulic_vapor'];dra,bottom=CASES[q['case']][:2];models=v['models'];flags=[f if m>=8 else 0 for m,f in zip(models,v['SWVAPOR'])]
  assert raw[:8]==b'S5HCC006' and struct.unpack_from('<i',raw,8)[0]==n
  domain=[6,n,v['numlay'],0,1,0,0,0,0,0,1,2,dra,bottom]+models+flags;packed=struct.pack('<'+str(len(domain))+'i',*domain);assert raw[48:48+2*len(packed)]==packed+packed
  return output_calendar(raw[:48]+raw[48+2*len(packed):],n,row,selected,build['project']['start_date'],True)
 namespace=dict(parent.checkpoint.__globals__,native=decode,zipfile=types.SimpleNamespace(ZipFile=lambda path:zipfile.ZipFile(io.BytesIO(path.read_bytes()))))
 checkpoint=types.FunctionType(parent.checkpoint.__code__,namespace,argdefs=parent.checkpoint.__defaults__)
 namespace=dict(parent.transaction_payloads.__globals__,checkpoint=checkpoint,read=lambda path:json.loads(path.read_text()),digest=lambda path:SHA(path.read_bytes()))
 exact=types.FunctionType(parent.transaction_payloads.__code__,namespace)
 with zipfile.ZipFile(io.BytesIO(store.get(prefix+'/transactions/external/accepted-column-1-day-5.zip'))) as z:source=json.loads(z.read('checkpoint.json'))['binding']['external_daily']['source_sha256']
 raw=blob(BASE,'app/hybrid_water/daily_coupling.py');assert source in (SHA(raw),SHA(raw.replace(b'\n',b'\r\n')))
 result=exact(store.view(prefix+'/transactions'),store.view(role['profile']),store.view(entry['archive_prefix']),store.view(role['inputs']),source)
 result.update(actual_prepared_days=3,actual_committed_days=1,actual_discarded_days=2,compiler_executions=0,model_executions=0);return result
