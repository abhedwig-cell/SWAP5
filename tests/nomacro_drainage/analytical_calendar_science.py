"""Independent literal mass/cold audit plus real original interval-state proof."""
import argparse,ast,hashlib,io,json,math,subprocess,sys,zipfile
from decimal import Decimal,localcontext
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_drainage'))
import model7_capacity_forensics as inherited
from analytical_calendar_native_state import decode,terminal_terms
from default_model_grammar_science import OutputView
import original_output_files as output_files
CORE='102e95eb6d33107b81ab06576707fe0be9b215e2'
BASE='bd9426711347a1bd7694d39e5c65345db0e25406'
READERS='e079d1554041c831cd0ab609835e2e79bf3c31a1'
PATH='tests/nomacro_drainage/model7_capacity_forensics.py'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)


def shared_ledger_cold(vapor):
 raw=git('show',READERS+':'+PATH);assert (ROOT/PATH).read_bytes().replace(b'\r\n',b'\n')==raw
 functions=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='audit'];assert len(functions)==1;body=functions[0].body
 def assigns(node,name):return isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id==name for t in node.targets)
 first=next(i for i,n in enumerate(body) if assigns(n,'rows'))
 phase=next(i for i,n in enumerate(body[first:],first) if isinstance(n,ast.If) and isinstance(n.test,ast.Name) and n.test.id=='terminal')
 cold=next(n for n in body[phase+1:] if isinstance(n,ast.If) and n.orelse);assert len(cold.orelse)==1 and ast.unparse(cold.orelse[0].test)=='not failed'
 selected=body[first:phase]+cold.orelse[0].body
 # The qualified daily reader's half-open DATE window is not the qualified
 # subdaily DATETIME window. Preserve exact original bytes through the literal
 # existing cadence-aware comparator; keep all mass, physical and native tests.
 loops=[node for node in ast.walk(ast.Module(body=selected,type_ignores=[])) if isinstance(node,ast.For) and isinstance(node.target,ast.Name) and node.target.id=='own']
 assert len(loops)==1;loop=loops[0]
 assert isinstance(loop.body[-3],ast.Assign) and isinstance(loop.body[-2],ast.Assign) and isinstance(loop.body[-1],ast.Assert)
 assert ast.unparse(loop.body[-1].test)=="binary((cold / 'original/result_output.bin').read_bytes())[1:] == expected"
 loop.body[-3:]=ast.parse("output_reports.append(exact_output_interval(warm/'original',cold/'original',meta['identity']['original_output'],start,end,meta['project']['start_date']))").body
 class Codec(ast.NodeTransformer):
  changes=0
  def visit_Constant(self,node):
   if vapor and node.value==b'S5IOW001':self.changes+=1;return ast.copy_location(ast.Constant(b'S5HVW003'),node)
   return node
 role=Codec();tree=ast.parse('def read(profile,meta,q,build):\n failed=censored=False\n output_reports=[]\n');tree.body[0].body += [role.visit(n) for n in selected];assert role.changes==int(vapor)
 tree.body[0].body += ast.parse("return dict(days=len(rows),water_daily_max=str(maximum),observed_global_water_prefix=str(waterprefix),global_water_prefix_is_owning_gate=False,cold_windows=len(q['own']),exact_original_output=output_reports)").body
 path='tests/nomacro_scheduled_subsurface/original_output_files.py';assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':'+path)
 def exact_output_interval(full,cold,selected,start,end,date):return output_files.compare(OutputView(full),OutputView(cold),selected,start,end,date)
 namespace=dict(vars(inherited),exact_output_interval=exact_output_interval);exec(compile(ast.fix_missing_locations(tree),PATH,'exec'),namespace);return namespace['read']


def audit(profile,reference,locations=None,original_monthly=False):
 q=json.loads((profile/'RESULT.json').read_text())
 if original_monthly:
  assert q['status']=='ACTUAL_EXISTING_NOSNOW_VAPOR_MONTHLY_35DAY_TWO_EXACT_COLD_POSTIMAGE_PASS_NOT_ADMITTED' and q['source']=='208c25624268589b5f26cbc10f2113aca4276ae6'
  assert not git('diff',BASE,q['source'],'--','app','src','tools/solute','tools/vq','reference')
 else:
  assert q['status']=='ACTUAL_ORIGINAL_ANALYTICAL_WATER_OUTPUT_CLOCK_AND_TERMINAL_COMPOSITION_POSTIMAGE_EXACT_COLD_PASS_NOT_ADMITTED'
  assert not git('diff',CORE,q['source'],'--','app','src','tools/solute','tools/vq','reference')
 build=locations['build'] if locations else Path(q['build_root']);inputs=locations['inputs'] if locations else Path(q['input_root'])
 meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];nodes=meta['project']['nodes'];assert q['kind']=='water'
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 for role,digest in meta['executable_sha256'].items():
  files=[p for p in (build/('day_'+role),build/('day_'+role+'.exe')) if p.is_file()];assert len(files)==1 and SHA(files[0].read_bytes())==digest
 for field in ('donor_flags','kernel_flags'):assert '-'+q['optimization'] in identity[field]
 policy=identity['model7_terminal_water'];assert policy['water_limit_cm']==1e-10
 namespace={'__file__':str(ROOT/'app/hybrid_water/model7_terminal_water.py')};exec(compile(git('show',BASE+':app/hybrid_water/model7_terminal_water.py'),'model7_terminal_water.py','exec'),namespace)
 private=(build/'model7_terminal_water_receipt.f90').read_text(encoding='cp1252');assert private==namespace['source']()
 head=(build/'headcalc.f90').read_text(encoding='cp1252')
 for part in (namespace['IMPORT'],namespace['GUARD'],namespace['SEARCH']):assert head.count(part)==1;head=head.replace(part,'',1)
 clock=policy.get('existing_output_trial_receipt_composed',False)
 if clock:
  assert SHA(head.encode('cp1252'))=='07493a79f44c3d1ca6b3a28d79198f0a1319dc5b664d4ff3465dca1dfdd23e18'
  parent=ast.parse(git('show',BASE+':app/hybrid_water/original_output.py'))
  literals=[n.value for n in ast.walk(parent) if isinstance(n,ast.Constant) and isinstance(n.value,str)]
  for part in ('   use MOD_integral,only:hybrid_output_trial_residual\n','\n         if(abs(hybrid_output_trial_residual())>1d-10)flnonconv=.true.'):
   assert part in literals and head.count(part)==1;head=head.replace(part,'',1)
  assert policy['existing_output_trial_water_limit_cm']==1e-10 and policy['existing_output_trial_unchanged']
 assert SHA(head.encode('cp1252'))==inherited.HEAD
 vapor=bool(identity.get('hydraulic_vapor'));codec=b'S5HVW003' if vapor else b'S5IOW001'
 if vapor:
  v=identity['hydraulic_vapor'];expected='ddaf8cd9d1effe893fca68d92fbd242285bce6de50ba84fb864f22978df49861' if v['existing_model7_capacity_composed'] else '9ad54cbf7887b0a6dc6555fa56ddd5486a5d96829af1bd437e0e8f341ca66fa8'
  assert SHA((build/'WC_K_models_04_11.f90').read_bytes().replace(b'\r\n',b'\n'))==v['corrected_lf_sha256']==expected
 elif identity.get('model7_capacity'):
  assert SHA((build/'WC_K_models_04_11.f90').read_bytes().replace(b'\r\n',b'\n'))=='7910cd29c045037778bfffdc7e40a77802d70fb477e0afa78be426776bd26e27'
 else:assert 'WC_K_models_04_11.o' in identity['donor_objects']
 result=shared_ledger_cold(vapor)(profile,meta,dict(q,own=q['cold']),build);assert result['days']==q['days']
 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];observed={};latest=None
 for line in (profile/'trajectory/original/donor.stdout').read_text().splitlines():
  if line.startswith('MODEL7_TERMINAL_WATER_TERMS '):latest=list(map(float,line.split()[1:]));assert len(latest)==28
  elif line.startswith('ORIGINAL_DAILY_RECEIPT ') and latest is not None:observed[int(line.split()[1])]=latest;latest=None
 assert set(observed)==set(range(1,q['days']+1))
 maximum=Decimal(0)
 with localcontext() as context:
  context.prec=80
  for values in observed.values():
   residual=abs(sum(Decimal.from_float(value) for value in values));maximum=max(maximum,residual);assert residual<=Decimal('1e-10')
 checkpoints=0;transfers=0;source=(build/'integral.f90').read_text(encoding='cp1252')
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0]);row=rows[day-1]
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
   raw=z.read('macro.bin');assert raw[:8]==codec
  state,header=decode(raw,source,nodes);assert header[6]==day
  expected=terminal_terms(state,row['stock_end_cm']);trial=observed[day]
  differences={i for i,(a,b) in enumerate(zip(trial,expected)) if a!=b}
  if differences:
   assert differences<={7,25} and trial[7]>=expected[7] and trial[25]<=expected[25]<=0
   assert expected[7]==-(-trial[7]+(expected[25]-trial[25]))
   with localcontext() as context:
    context.prec=80;rounding=sum(Decimal.from_float(math.ulp(v))/2 for v in (trial[7],expected[7],trial[25],expected[25]))
    assert abs(sum(Decimal.from_float(trial[i])-Decimal.from_float(expected[i]) for i in (7,25)))<=rounding
   transfers+=1
  checkpoints+=1
 result.update(status='INDEPENDENT_ORIGINAL_ANALYTICAL_OUTPUT_CLOCK_SOURCE_PROVIDER_DAY_AND_INTERVAL_MASS_NATIVE_COLD_OUTPUT_PASS',producer=q['source'],case=q.get('case','original-monthly-vapor8'),optimization=q['optimization'],clock_trial_composed=clock,complete_HeadCalc_inverse=True,unchanged_terminal_provider=True,terminal_interval_daily_observations=len(observed),terminal_interval_max=str(maximum),native_checkpoints=checkpoints,all28_native_interval_terms_exact_except_qualified_canopy_phase=True,canopy_phase_transfers=transfers,private_interval_not_rebound_to_public_day=True,scientific_mass_and_cold_body=READERS,compiler_executions=0,model_executions=0,canonical_admission=False)
 return result


if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work)
 with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
 print(q['status'],q['days'],q['cold_windows'])
