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
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)


def audit(profile,reference,locations=None):
 q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_ANALYTICAL_CDE_CALENDAR_FIXED_MASS_NATIVE_EXACT_COLD_PASS_NOT_ADMITTED' and q['days'] in (35,367)
 core=FIRST_CORE if q['case']=='model7-periodic6' else CLOCK_CORE
 assert q['case'] in ('model7-periodic6','model7-clock6','model7-perstep6')
 assert not git('diff',core,q['source'],'--','app','src','tools/solute','tools/vq','reference'),'Unreviewed actual analytical CDE composition producer'
 build=locations['build'] if locations else Path(q['build_root']);inputs=locations['inputs'] if locations else Path(q['input_root']);meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];selected=identity['original_output'];nodes=meta['project']['nodes'];magic=q['native_codec'].encode();assert magic in (b'S5CIC001',b'S5CCC001') and selected['kind']=='cde'
 if magic==b'S5CIC001':assert selected['period']==5
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
 result=ledger_cold(magic)(profile,meta,dict(q,own=q['cold']),build)
 # Literal original observed six-RHS increments, with every prefix and day
 # checked at their existing absolute1e-10 chemical bound.
 daily=audit_daily(profile/'trajectory',q['days'],nodes)
 rows=[json.loads(v) for v in (profile/'trajectory/daily.jsonl').read_text().splitlines()];samples=[]
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:raw=z.read('macro.bin')
  assert raw[:8]==magic;details=output_calendar(raw,nodes,rows[day-1],selected,meta['project']['start_date'],True);samples.append(dict(day=day,calendar_header=details['calendar_header'],private_stock_exact=True))
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
