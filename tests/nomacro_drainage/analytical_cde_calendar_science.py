"""Independently read exact original CDE calendar stock, flux, native and cold bytes."""
import ast,io,json,math,struct,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from initial_pressure_profile_science import ledger_cold,PROVIDER
from analytical_hydraulic_archives import SHA
from implicit_conductivity_forensics import output_calendar
from cde_interval_runtime import audit_daily
BASE='5c0cba9fbbd93ffb482199016f392e53e371e095'
FIRST_CORE='443c6b432a3f75695dbab0e0b66389638d7f94c0'
CLOCK_CORE='b16249855004a00b54efe5203287ba321b61594c'
NATIVE6_CORE='1510278b9ad56b03273c6d6e2284b1360f57849c'
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)


def cadence_ledger_cold(magic):
 import initial_pressure_profile_science as original
 import original_output_files as output
 from default_model_grammar_science import OutputView
 path='tests/nomacro_drainage/initial_pressure_profile_science.py';raw=git('show',BASE+':'+path)
 assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==raw
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='ledger_cold'];assert len(nodes)==1
 function=nodes[0];positions=[i for i,n in enumerate(function.body) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='codec' for t in n.targets)];assert len(positions)==1
 # The already qualified analytical/calendar reader replaces only the daily
 # DATE-window output tail with the literal existing DATETIME-aware comparator.
 # All conserved mass, actual physical/native and cold assertions stay intact.
 statements=ast.parse("""selected=body[first:phase]+cold.orelse[0].body
loops=[n for n in ast.walk(ast.Module(body=selected,type_ignores=[])) if isinstance(n,ast.For) and isinstance(n.target,ast.Name) and n.target.id=='own']
assert len(loops)==1
loop=loops[0]
assert isinstance(loop.body[-3],ast.Assign) and isinstance(loop.body[-2],ast.Assign) and isinstance(loop.body[-1],ast.Assert)
assert ast.unparse(loop.body[-1].test)=="binary((cold / 'original/result_output.bin').read_bytes())[1:] == expected"
loop.body[-3:]=ast.parse("exact_output_interval(warm/'original',cold/'original',meta['identity']['original_output'],start,end,meta['project']['start_date'])").body
""").body
 function.body[positions[0]:positions[0]]=statements
 additions=[n for n in function.body if isinstance(n,ast.AugAssign) and ast.unparse(n.target)=='tree.body[0].body' and isinstance(n.value,ast.ListComp)];assert len(additions)==1
 generator=additions[0].value.generators[0];assert ast.unparse(generator.iter)=='body[first:phase] + cold.orelse[0].body';generator.iter=ast.Name(id='selected',ctx=ast.Load())
 assignments=[n for n in function.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='namespace' for t in n.targets)];assert len(assignments)==1
 assignments[0].value.keywords.append(ast.keyword(arg='exact_output_interval',value=ast.Name(id='exact_output_interval',ctx=ast.Load())))
 for path in ('tests/nomacro_scheduled_subsurface/original_output_files.py','tests/nomacro_drainage/default_model_grammar_science.py'):
  assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':'+path)
 def exact_output_interval(full,cold,selected,start,end,date):return output.compare(OutputView(full),OutputView(cold),selected,start,end,date)
 namespace=dict(vars(original),exact_output_interval=exact_output_interval);exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),'literal-original-CDE-ledger-with-qualified-cadence-comparator','exec'),namespace)
 return namespace['ledger_cold'](magic)


def audit(profile,reference,locations=None):
 q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_ANALYTICAL_CDE_CALENDAR_FIXED_MASS_NATIVE_EXACT_COLD_PASS_NOT_ADMITTED' and q['days'] in (35,367)
 core=NATIVE6_CORE if q['case']=='vapor8-periodic6' else FIRST_CORE if q['case']=='model7-periodic6' else CLOCK_CORE
 assert q['case'] in ('model7-periodic6','model7-clock6','model7-perstep6','vapor8-periodic6')
 assert not git('diff',core,q['source'],'--','app','src','tools/solute','tools/vq','reference'),'Unreviewed actual analytical CDE composition producer'
 build=locations['build'] if locations else Path(q['build_root']);inputs=locations['inputs'] if locations else Path(q['input_root']);meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];selected=identity['original_output'];nodes=meta['project']['nodes'];magic=q['native_codec'].encode();assert magic in (b'S5CIC001',b'S5CCC001',b'S5HCC006') and selected['kind']=='cde'
 if magic in (b'S5CIC001',b'S5HCC006'):assert selected['period']==5
 else:assert selected['period']==1 and selected['analytical_bottom6_calendar'] and selected['cde_clock_output'] and (selected['nprintday']>1 or selected['flprintdt'])
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 for name,digest in PROVIDER.items():assert SHA((reference/('build/swap-selected/'+name)).read_bytes().replace(b'\r\n',b'\n'))==digest
 for field in ('donor_flags','kernel_flags'):assert '-'+q['optimization'] in identity[field]
 for role in ('donor','kernel'):
  paths=[p for p in (build/('day_'+role),build/('day_'+role+'.exe')) if p.is_file()];assert len(paths)==1 and SHA(paths[0].read_bytes())==meta['executable_sha256'][role]
 for path in ('tests/nomacro_drainage/initial_pressure_profile_science.py','tests/nomacro_scheduled_subsurface/implicit_conductivity_forensics.py','tests/nomacro_scheduled_subsurface/cde_interval_runtime.py'):
  assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':'+path),'Frozen independent original reader changed'
 result=cadence_ledger_cold(magic)(profile,meta,dict(q,own=q['cold']),build)
 # Literal original observed six-RHS increments, with every prefix and day
 # checked at their existing absolute1e-10 chemical bound.
 daily=audit_daily(profile/'trajectory',q['days'],nodes)
 rows=[json.loads(v) for v in (profile/'trajectory/daily.jsonl').read_text().splitlines()];samples=[]
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:raw=z.read('macro.bin')
  assert raw[:8]==magic;parent=raw
  if magic==b'S5HCC006':
   vapor=identity['hydraulic_vapor'];layers=vapor['numlay'];models=vapor['models'];flags=[f if m>=8 else 0 for m,f in zip(models,vapor['SWVAPOR'])]
   # Decode actual duplicated native6 integers independently. The read-only
   # parent view removes only that verified wrapper, leaving every conserved
   # stock/calendar/private-state byte exact for the literal old decoder.
   expected=[6,nodes,layers,0,1,0,0,0,0,0,1,2,1,6]+models+flags;packed=struct.pack('<'+str(len(expected))+'i',*expected)
   assert raw[48:48+2*len(packed)]==packed+packed and struct.unpack_from('<i',raw,8)[0]==nodes
   parent=raw[:48]+raw[48+2*len(packed):]
  details=output_calendar(parent,nodes,rows[day-1],selected,meta['project']['start_date'],True);samples.append(dict(day=day,calendar_header=details['calendar_header'],private_stock_exact=True))
 assert len(samples)==(11 if q['days']==367 else 7) and rows[-1]['solute_end_mg_cm2']>0
 source=git('show',BASE+':app/hybrid_water/model7_terminal_water.py');tree=ast.parse(source);constants={}
 for n in tree.body:
  if isinstance(n,ast.Assign) and len(n.targets)==1 and isinstance(n.targets[0],ast.Name) and n.targets[0].id in ('IMPORT','GUARD','SEARCH','HEAD_PARENT_SHA'):constants[n.targets[0].id]=ast.literal_eval(n.value)
 actual=(build/'headcalc.f90').read_bytes().replace(b'\r\n',b'\n')
 for key in ('IMPORT','GUARD','SEARCH'):
  part=constants[key].encode('cp1252');assert actual.count(part)==1;actual=actual.replace(part,b'',1)
 if magic==b'S5CCC001':
  code=git('show',CLOCK_CORE+':app/hybrid_water/analytical_cde_calendar.py');tree=ast.parse(code);namespace={}
  for n in tree.body:
   if isinstance(n,ast.Assign) and len(n.targets)==1 and isinstance(n.targets[0],ast.Name) and n.targets[0].id in ('HEAD_IMPORT','HEAD_DECL','HEAD_GUARD','CLOCK6_PARENT_SHA'):namespace[n.targets[0].id]=ast.literal_eval(n.value)
  functions=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='head_guard'];assert len(functions)==1;exec(compile(ast.Module(body=functions,type_ignores=[]),'frozen-literal-CDE-clock-source','exec'),namespace)
  assert SHA(actual)==namespace['CLOCK6_PARENT_SHA']
  for part in (namespace['HEAD_IMPORT'],namespace['HEAD_DECL'],namespace['head_guard'](6)):
   raw=part.encode('cp1252');assert actual.count(raw)==1;actual=actual.replace(raw,b'',1)
 assert SHA(actual)==constants['HEAD_PARENT_SHA'],'Actual complete original qualified model7 HeadCalc differs'
 assert (build/'original_cde_output_state.f90').read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':app/hybrid_water/cde_interval_output_state.f90')
 result.update(status='INDEPENDENT_ORIGINAL_ANALYTICAL_CDE_CALENDAR6_FIXED_MASS_CALENDAR_PRIVATE_STATE_EXACT_COLD_PASS',producer=q['source'],kind='cde',optimization=q['optimization'],native_codec=magic.decode(),actual_original_daily_increment_rows=daily['actual_days'],integrated_actual_chemical_residual_mg_cm2=daily['integrated_actual_chemical_residual_mg_cm2'],native_calendar_samples=sorted(samples,key=lambda v:v['day']),complete_qualified_model7_HeadCalc_parent_unchanged=True,literal_CDE_private_sampro0_rounderr_provider_unchanged=True,compiler_executions=0,model_executions=0,canonical_admission=False)
 return result
