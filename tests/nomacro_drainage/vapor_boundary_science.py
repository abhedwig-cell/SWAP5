"""Independent boundary-native, literal old ledger/cold and trial-flux audit."""
import argparse,ast,io,json,math,struct,subprocess,sys,zipfile
from decimal import Decimal,localcontext
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import model7_capacity_forensics as inherited
from analytical_hydraulic_archives import SHA
BASE='70bae8871ec71b3c0969a6628cae596354f9c2e8'
CORE='9cde60cff60e1a0b2d4a21019e69eefb1007bd8b'
GUARD_CORE='c1e1dd81382926053a42cda6260874483dab37b1'
READERS='e079d1554041c831cd0ab609835e2e79bf3c31a1'
git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)


def ledger_cold():
 path='tests/nomacro_drainage/model7_capacity_forensics.py';raw=git('show',READERS+':'+path);assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==raw
 function=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='audit');body=function.body
 first=next(i for i,n in enumerate(body) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='rows' for t in n.targets))
 phase=next(i for i,n in enumerate(body[first:],first) if isinstance(n,ast.If) and isinstance(n.test,ast.Name) and n.test.id=='terminal')
 cold=next(n for n in body[phase+1:] if isinstance(n,ast.If) and n.orelse);assert len(cold.orelse)==1 and ast.unparse(cold.orelse[0].test)=='not failed'
 selected=body[first:phase]+cold.orelse[0].body
 class Codec(ast.NodeTransformer):
  changes=0
  def visit_Constant(self,node):
   if node.value in (b'S5IOC001',b'S5IOW001'):
    self.changes+=1;return ast.copy_location(ast.Constant(b'S5HBC005' if node.value==b'S5IOC001' else b'S5HBW005'),node)
   return node
 codec=Codec();tree=ast.parse('def read(profile,meta,q,build):\n failed=censored=False\n');tree.body[0].body += [codec.visit(n) for n in selected];assert codec.changes==2
 tree.body[0].body += ast.parse("return dict(days=len(rows),cold_windows=len(q['own']),water_daily_max=str(maximum),CDE_daily_max=str(chemical),CDE_every_prefix_max=str(prefix),observed_global_water_prefix=str(waterprefix),global_water_prefix_is_owning_gate=False)").body
 namespace=dict(vars(inherited));exec(compile(ast.fix_missing_locations(tree),path,'exec'),namespace);return namespace['read']


def audit(profile,reference,locations=None):
 q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_VAPOR_BOUNDARY_NATIVE5_WATER_CDE_ORIGINAL_OUTPUT_EXACT_COLD_PASS_NOT_ADMITTED'
 explicit=bool(git('diff',CORE,q['source'],'--','app','src','tools/solute','tools/vq','reference'))
 if explicit:
  assert not git('diff',GUARD_CORE,q['source'],'--','app','src','tools/solute','tools/vq','reference')
  assert git('diff','--name-only',CORE,GUARD_CORE,'--','app','src','tools/solute','tools/vq','reference').decode().splitlines()==['app/hybrid_water/vapor_boundary_composition.py']
 build=locations['build'] if locations else Path(q['build_root']);inputs=locations['inputs'] if locations else Path(q['input_root']);meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];vapor=identity['hydraulic_vapor'];boundary=vapor['boundary_composition'];bottom=boundary['bottom'];solute=q['kind']=='cde'
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 for role,digest in meta['executable_sha256'].items():
  files=[p for p in (build/('day_'+role),build/('day_'+role+'.exe')) if p.is_file()];assert len(files)==1 and SHA(files[0].read_bytes())==digest
 for field in ('donor_flags','kernel_flags'):assert '-'+q['optimization'] in identity[field]
 policy=identity['model7_terminal_water'];assert policy['water_limit_cm']==boundary['fixed_absolute_water_limit_cm']==1e-10
 # Recover the entire previously qualified terminal source; every term and
 # summation statement is literal. Optional qbot comes directly from the
 # already qualified HeadCalc Darcy/soil-air trial owner.
 private=(build/'model7_terminal_water_receipt.f90').read_text(encoding='cp1252');inverse=private
 edits=[('ivolbeg,ipondbeg,issnowbeg,isicbeg,swkimpl,swbotb\n','ivolbeg,ipondbeg,issnowbeg,isicbeg,swkimpl\n'),('swmacro/=0.or.swsnow/=0.or.(swdra/=0.and.swdra/=1).or.(swbotb/=5.and.swbotb/=6.and.swbotb/=8).or.swfrost/=0.or.swhyst/=0.or.swkimpl/=0','swmacro/=0.or.swsnow/=0.or.swdra/=1.or.swfrost/=0.or.swhyst/=0.or.swkimpl/=0'),('  use ieee_arithmetic, only: ieee_is_finite\n',''),('subroutine model7_terminal_water_terms(terms,boundary_flux)','subroutine model7_terminal_water_terms(terms)'),('    real(8), intent(in), optional :: boundary_flux\n',''),("    if(present(boundary_flux))then\n      if(.not.ieee_is_finite(boundary_flux))error stop 'Nonfinite analytical boundary trial receipt'\n      qbotts=boundary_flux*dt\n    end if\n",''),('function model7_terminal_water_residual(boundary_flux) result(residual)','function model7_terminal_water_residual() result(residual)'),('call model7_terminal_water_terms(terms,boundary_flux)','call model7_terminal_water_terms(terms)')]
 for before,after in edits:
  assert inverse.count(before)==(2 if before=='    real(8), intent(in), optional :: boundary_flux\n' else 1);inverse=inverse.replace(before,after)
 namespace={'__file__':str(ROOT/'app/hybrid_water/model7_terminal_water.py')};exec(compile(git('show',BASE+':app/hybrid_water/model7_terminal_water.py'),'old-terminal-owner','exec'),namespace);assert inverse==namespace['source']()
 head=(build/'headcalc.f90').read_text(encoding='cp1252');guard=namespace['GUARD']
 if bottom==8 and explicit:
  opening=guard.replace('model7_terminal_water_residual()','model7_terminal_water_residual(-kmean(NN+1)*hgrad(NN+1))');closed=guard.replace('model7_terminal_water_residual()','model7_terminal_water_residual(0d0)');guard='\n         if(flboth)then'+opening+'\n         else'+closed+'\n         end if'
 elif bottom in (5,8):guard=guard.replace('model7_terminal_water_residual()','model7_terminal_water_residual('+('-kmean(NN+1)*hgrad(NN+1)' if bottom==5 else 'merge(-kmean(NN+1)*hgrad(NN+1),0d0,flboth)')+')')
 for part in (namespace['IMPORT'],guard,namespace['SEARCH']):assert head.count(part)==1;head=head.replace(part,'',1)
 parents={6:'356fdea44df04ecb97f68936be0102c36b63f730d5c63950c8ad0ce453c313df',5:'86846f45207441207b24d71954b28ad4690a0a5ab6aca17883ecd3c1fb4a997d',8:'5f416dd85126383e39f2211f394b18590b1420cfbc2c49c408f7b4ec89de73d2'}
 assert SHA(head.encode('cp1252'))==policy['complete_before_guard_HeadCalc_sha256']==parents[bottom]
 for path in ('app/hybrid_water/daily_host.py','app/hybrid_water/lower_boundary_receipt.py'):assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':'+path)
 native=(build/'hydraulic_vapor_native.f90').read_text(encoding='cp1252')
 for after,before in [('.or.(swdra/=0.and.swdra/=1).or.(swbotb/=5.and.swbotb/=6.and.swbotb/=8).or.(swdra==1.and.swbotb==6))','.or.swdra/=1.or.swbotb/=6)'),('expected(1:14)=[5,','expected(1:14)=[3,')]:assert native.count(after)==1;native=native.replace(after,before,1)
 assert SHA(native.encode('cp1252'))=='a181df32399d64a4052f4e8d3d11133bb7388fd890c8f0e9139594bbc29877b0'
 expected='ddaf8cd9d1effe893fca68d92fbd242285bce6de50ba84fb864f22978df49861' if vapor['existing_model7_capacity_composed'] else '9ad54cbf7887b0a6dc6555fa56ddd5486a5d96829af1bd437e0e8f341ca66fa8';assert SHA((build/'WC_K_models_04_11.f90').read_bytes().replace(b'\r\n',b'\n'))==expected
 result=ledger_cold()(profile,meta,dict(q,own=q['cold']),build)
 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];observed={};latest=None
 for line in (profile/'trajectory/original/donor.stdout').read_text().splitlines():
  if line.startswith('MODEL7_TERMINAL_WATER_TERMS '):latest=list(map(float,line.split()[1:]));assert len(latest)==28
  elif line.startswith('ORIGINAL_DAILY_RECEIPT ') and latest is not None:observed[int(line.split()[1])]=latest;latest=None
 assert set(observed)==set(range(1,q['days']+1));maximum=Decimal(0);boundary_phase_days=0
 with localcontext() as context:
  context.prec=80
  for row in rows:
   trial=observed[row['day']];maximum=max(maximum,abs(sum(Decimal.from_float(v) for v in trial)));assert maximum<=Decimal('1e-10')
   f=row['external_flux_cm'];expected=f[:7]+[-v for v in f[7:]]+row['stock_start_cm']+[-v for v in row['stock_end_cm']];different={i for i,(a,b) in enumerate(zip(trial,expected)) if a!=b}
   assert different<=({6,7,15,25} if bottom in (5,8) else {7,25})
   if different&{6,15}:boundary_phase_days+=1
   if different&{7,25}:
    assert trial[7]>expected[7] and trial[25]<expected[25]<=0
    rounding=sum(Decimal.from_float(math.ulp(v))/2 for v in (trial[7],expected[7],trial[25],expected[25]));assert abs(sum(Decimal.from_float(trial[i])-Decimal.from_float(expected[i]) for i in (7,25)))<=rounding
 samples=0;stocks=0;nodes=meta['project']['nodes'];layers=vapor['numlay'];domain=[5,nodes,layers,0,int(solute),0,0,0,0,0,1,2,boundary['drainage'],bottom]+vapor['models']+[f if m>=8 else 0 for m,f in zip(vapor['models'],vapor['SWVAPOR'])];packed=struct.pack('<'+str(len(domain))+'i',*domain)
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:aux=z.read('macro.bin')
  assert aux[:8]==(b'S5HBC005' if solute else b'S5HBW005') and aux[48:48+2*len(packed)]==packed+packed;samples+=1
  if solute:
   saved=struct.unpack_from('<'+str(nodes+2)+'d',aux,48+2*len(packed));assert all(math.isfinite(v) and v>=0 for v in saved);assert saved[-1]==rows[day-1]['solute_end_mg_cm2'];stocks+=1
 result.update(status='INDEPENDENT_VAPOR_BOUNDARY_NATIVE5_LITERAL_SOURCE_WATER_CDE_TRIAL_AND_PUBLIC_MASS_EXACT_COLD_OUTPUT_PASS',producer=q['source'],kind=q['kind'],optimization=q['optimization'],native_checkpoints=samples,exact_private_CDE_stocks=stocks,trial_water_max=str(maximum),trial_Darcy_and_later_public_Fluxes_phase_difference_days=boundary_phase_days,all_other_trial_terms_exact_except_qualified_canopy_phase=True,private_Darcy_trial_not_rebound_to_public_Fluxes_reconstruction=True,CDE_initial_stock=rows[0].get('solute_start_mg_cm2'),original_native3_body_inverse=True,original_terminal_whole_body_inverse=True,compiler_executions=0,model_executions=0,canonical_admission=False);return result


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],q['days'],q['cold_windows'])
