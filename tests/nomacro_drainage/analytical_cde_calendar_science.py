"""Independently read exact original CDE calendar stock, flux, native and cold bytes."""
import argparse,ast,io,json,math,struct,subprocess,sys,zipfile
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
COMPOSED_CORE='379673548d90b13421b5b1e2db6e928c676b11ed'
FINAL_CORE='1f869b2fbbe385c29790cd7f719df87b85d83750'
CASES={
 'model7-periodic6':(1,6,'periodic'),'model7-clock6':(1,6,'clock'),'model7-perstep6':(1,6,'perstep'),
 'vapor8-periodic6':(1,6,'periodic'),'vapor8-monthly6':(1,6,'monthly'),
 'mixed7-8-clock6':(1,6,'clock'),'mixed7-8-perstep6':(1,6,'perstep'),
 'vapor8-periodic5':(1,5,'periodic'),'vapor8-monthly5':(1,5,'monthly'),
 'mixed7-8-clock8':(1,8,'clock'),'mixed7-8-perstep8':(1,8,'perstep'),
 'vapor8-explicit-undrained5':(0,5,'explicit'),
 'vapor11-periodic-undrained6':(0,6,'periodic'),'mixed7-8-clock-undrained8':(0,8,'clock')}
BOUNDARY_PARENTS={6:'356fdea44df04ecb97f68936be0102c36b63f730d5c63950c8ad0ce453c313df',5:'86846f45207441207b24d71954b28ad4690a0a5ab6aca17883ecd3c1fb4a997d',8:'5f416dd85126383e39f2211f394b18590b1420cfbc2c49c408f7b4ec89de73d2'}
BOUNDARY_CLOCK_PARENTS={6:'3dcf72d8fcf977fb74ad7d53ff68774df07983602a1a3452d40e8d6be257f9f4',5:'96c401edf095e41113897afcdc4b4fd9454ddb104c3d570b47217e899f49a0be',8:'977c6c52429b2929900e311d963541fe04f17d13c102ab4a2b061d8cb4302928'}
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
 assert q['case'] in CASES
 drain,bottom,mode=CASES[q['case']]
 core=NATIVE6_CORE if q['case']=='vapor8-periodic6' else FIRST_CORE if q['case']=='model7-periodic6' else CLOCK_CORE if q['case'].startswith('model7-') else COMPOSED_CORE
 epochs={core,COMPOSED_CORE,FINAL_CORE}
 matched=[epoch for epoch in epochs if not git('diff',epoch,q['source'],'--','app','src','tools/solute','tools/vq','reference')]
 assert len(matched)==1,'Unreviewed actual analytical CDE composition producer'
 build=locations['build'] if locations else Path(q['build_root']);inputs=locations['inputs'] if locations else Path(q['input_root']);meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];selected=identity['original_output'];nodes=meta['project']['nodes'];magic=q['native_codec'].encode();assert magic in (b'S5CIC001',b'S5CCC001',b'S5HCC006') and selected['kind']=='cde'
 if mode=='periodic':assert selected['period']==5
 elif mode=='monthly':assert selected['swmonth']==1 and selected['swres']==0
 elif mode=='explicit':assert selected['swodat']==1 and selected['swres']==0
 else:assert selected['period']==1 and selected['cde_clock_output'] and (selected['nprintday']>1 or selected['flprintdt']) and bool(selected['flprintdt'])==(mode=='perstep')
 assert selected['swdra']==drain
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
   expected_models=[7,8] if q['case'].startswith('mixed7-8-') else [11 if q['case'].startswith('vapor11-') else 8]*layers
   assert models==expected_models and flags==[int(m>=8) for m in models]
   expected=[6,nodes,layers,0,1,0,0,0,0,0,1,2,drain,bottom]+models+flags;packed=struct.pack('<'+str(len(expected))+'i',*expected)
   assert raw[48:48+2*len(packed)]==packed+packed and struct.unpack_from('<i',raw,8)[0]==nodes
   parent=raw[:48]+raw[48+2*len(packed):]
  details=output_calendar(parent,nodes,rows[day-1],selected,meta['project']['start_date'],True);samples.append(dict(day=day,calendar_header=details['calendar_header'],private_stock_exact=True))
 expected_days={q['days'],2,4,19,23,30,34}|({199,201,364} if q['days']==367 else set())
 assert {sample['day'] for sample in samples}==expected_days and rows[-1]['solute_end_mg_cm2']>0
 source=git('show',BASE+':app/hybrid_water/model7_terminal_water.py');tree=ast.parse(source);constants={}
 for n in tree.body:
  if isinstance(n,ast.Assign) and len(n.targets)==1 and isinstance(n.targets[0],ast.Name) and n.targets[0].id in ('IMPORT','GUARD','SEARCH','HEAD_PARENT_SHA'):constants[n.targets[0].id]=ast.literal_eval(n.value)
 actual=(build/'headcalc.f90').read_bytes().replace(b'\r\n',b'\n')
 guard=constants['GUARD']
 if (drain,bottom)!=(1,6):
  # Evaluate only the frozen literal guard renderer for the independently
  # observed domain. No producer input or project identity is substituted.
  tree=ast.parse(git('show',BASE+':app/hybrid_water/vapor_boundary_composition.py'))
  functions=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='terminal_guard'];assert len(functions)==1
  namespace=dict(context=lambda _:dict(drainage=drain,bottom=bottom))
  exec(compile(ast.Module(body=functions,type_ignores=[]),'frozen-qualified-boundary-terminal-guard','exec'),namespace)
  guard=namespace['terminal_guard'](None,guard)
 for part in (constants['IMPORT'],guard,constants['SEARCH']):
  part=part.encode('cp1252');assert actual.count(part)==1;actual=actual.replace(part,b'',1)
 if mode in ('clock','perstep'):
  code=git('show',CLOCK_CORE+':app/hybrid_water/analytical_cde_calendar.py');tree=ast.parse(code);namespace={}
  for n in tree.body:
   if isinstance(n,ast.Assign) and len(n.targets)==1 and isinstance(n.targets[0],ast.Name) and n.targets[0].id in ('HEAD_IMPORT','HEAD_DECL','HEAD_GUARD','CLOCK6_PARENT_SHA'):namespace[n.targets[0].id]=ast.literal_eval(n.value)
  functions=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='head_guard'];assert len(functions)==1;exec(compile(ast.Module(body=functions,type_ignores=[]),'frozen-literal-CDE-clock-source','exec'),namespace)
  expected_parent=namespace['CLOCK6_PARENT_SHA'] if (drain,bottom)==(1,6) else BOUNDARY_CLOCK_PARENTS[bottom]
  assert SHA(actual)==expected_parent
  for part in (namespace['HEAD_IMPORT'],namespace['HEAD_DECL'],namespace['head_guard'](bottom)):
   raw=part.encode('cp1252');assert actual.count(raw)==1;actual=actual.replace(raw,b'',1)
 expected_parent=constants['HEAD_PARENT_SHA'] if (drain,bottom)==(1,6) else BOUNDARY_PARENTS[bottom]
 assert SHA(actual)==expected_parent,'Actual complete original qualified model7/boundary HeadCalc differs'
 assert (build/'original_cde_output_state.f90').read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':app/hybrid_water/cde_interval_output_state.f90')
 result.update(status='INDEPENDENT_ORIGINAL_ANALYTICAL_CDE_CALENDAR6_FIXED_MASS_CALENDAR_PRIVATE_STATE_EXACT_COLD_PASS',producer=q['source'],kind='cde',optimization=q['optimization'],native_codec=magic.decode(),actual_original_daily_increment_rows=daily['actual_days'],integrated_actual_chemical_residual_mg_cm2=daily['integrated_actual_chemical_residual_mg_cm2'],native_calendar_samples=sorted(samples,key=lambda v:v['day']),complete_qualified_model7_HeadCalc_parent_unchanged=True,literal_CDE_private_sampro0_rounderr_provider_unchanged=True,compiler_executions=0,model_executions=0,canonical_admission=False)
 return result


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],q['optimization'],q['native_codec'])
