"""Independently reconstruct actual calendar mutants and bounded dispatch."""
import ast,io,json,struct,types,zipfile
from analytical_hydraulic_archives import SHA


def native(store,role,prefix):
 profile=store.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text());projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));compiled=store.view(projection[q['build_root']]['archive_prefix'])
 controls=json.loads(store.get(prefix+'/RESULT.json'));assert controls['status']=='ACTUAL_ANALYTICAL_OUTPUT_24_NATIVE_REFUSALS_AND_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS'
 assert controls['actual_BUILD_sha256']==SHA((compiled/'BUILD.json').read_bytes())
 checkpoint=(profile/'trajectory/accepted-column-1-day-4.zip').read_bytes()
 with zipfile.ZipFile(io.BytesIO(checkpoint)) as z:good=z.read('macro.bin')
 assert good[:8]==b'S5HVW003';nodes=json.loads((compiled/'BUILD.json').read_text())['project']['nodes'];starts=[]
 pattern=struct.pack('<3i',1,nodes,1);at=good.find(pattern)
 while at>=0:
  if at+160<=len(good):
   header=struct.unpack_from('<20i',good,at);n=header[3]
   if n>100 and at+160+16*n<=len(good) and good[at:at+80]==good[at+80:at+160]:starts.append(at)
  at=good.find(pattern,at+1)
 assert len(starts)==1;at=starts[0];header=struct.unpack_from('<20i',good,at);n=header[3]
 for item in controls['native_refusals']:
  attack=item['attack'];raw=bytearray(good)
  def integer(index,value,witness=True):
   struct.pack_into('<i',raw,at+4*index,value)
   if witness:struct.pack_into('<i',raw,at+80+4*index,value)
  def value(index,v,witness=True):
   struct.pack_into('<d',raw,at+160+8*index,v)
   if witness:struct.pack_into('<d',raw,at+160+8*n+8*index,v)
  if attack.startswith('old'):raw[:8]=('S5AGE'+attack[-3:]).encode()
  elif attack=='foreign-kind':raw[:8]=b'S5IOC001'
  elif attack=='truncated':raw=raw[:-1]
  elif attack=='trailing':raw+=b'x'
  elif attack=='header-witness':integer(7,header[7]+1,False)
  elif attack=='shape':integer(1,nodes+1)
  elif attack=='policy':integer(4,header[4]+1)
  elif attack=='negative-day':integer(6,-1)
  elif attack=='foreign-day':integer(6,5)
  elif attack=='negative-counter':integer(7,-1)
  elif attack=='changed-counter':integer(7,header[7]+1 if header[4]==0 or header[19] else header[4])
  elif attack=='print-counter':integer(8,header[8]+1)
  elif attack=='zero-pointer':integer(9,0)
  elif attack=='overflow-pointer':integer(10,2147483647)
  elif attack=='future-pointer':integer(10,100)
  elif attack=='flag-domain':integer(12,2)
  elif attack=='short-flag':integer(18,1-header[18])
  elif attack=='step-flag':integer(19,1-header[19])
  elif attack=='nonfinite':value(0,float('nan'))
  elif attack=='value-witness':value(0,123.,False)
  elif attack=='negative-period':value(n-1,-1.)
  else:raise AssertionError(attack)
  root=store.view(prefix+'/native/'+attack);assert (root/'origin/macro.bin').read_bytes()==raw
  stderr=(root/'original/donor.stderr').read_text();stdout=(root/'original/donor.stdout').read_bytes()
  assert item['status']=='REFUSED' and item['diagnostic']==stderr and 'ERROR STOP' in stderr and b'HYBRID_READY' not in stdout and b'HYBRID_DAY_RETURN' not in stdout
 assert len({v['attack'] for v in controls['native_refusals']})==24
 assert controls['transactions']==dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True)
 return dict(compiled_refusals=24,actual_mutants_independently_rebuilt=True,external_transaction_contexts=1)


def frontend(store):
 from original_output import selection
 from ordinary_pond_verify import ROOT,blob,norm
 selected=types.FunctionType(selection.__code__,dict(selection.__globals__,Path=lambda path:path))
 path='app/hybrid_water/model7_terminal_water.py';raw=norm((ROOT/path).read_bytes());tree=ast.parse(raw)
 functions=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='clock_selection'];assert len(functions)==1
 function=functions[0];assert ast.unparse(function.body[0])=='from original_output import selection';function.body.pop(0)
 namespace=dict(selection=selected);exec(compile(ast.fix_missing_locations(ast.Module(body=functions,type_ignores=[])),path,'exec'),namespace);clock=namespace['clock_selection']
 prefix='profiles/analytical-calendar-frontend-v1/';q=json.loads(store.get(prefix+'RESULT.json'));assert len(q['checks'])==15
 counts={}
 for item in q['checks']:
  folder=store.view(prefix+item['label'])
  for name,digest in item['inputs']:assert SHA((folder/name).read_bytes())==digest
  project=types.SimpleNamespace(original_output=True,macro=False,input_directory=folder,time_step_policy='original-adaptive-day-seed-v1',solute=False,age=False)
  try:actual=clock(project)
  except ValueError:assert item['status']=='REFUSED'
  else:assert (actual is not None)==(item['status']=='CLOCK') and item['status']!='REFUSED'
  counts[item['status']]=counts.get(item['status'],0)+1
 assert counts=={'DENSE':2,'CLOCK':5,'REFUSED':8};return counts
