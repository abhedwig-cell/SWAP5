"""Independent Snow-vapor custody and literal qualified ledger/cold body."""
import argparse,ast,hashlib,io,json,math,struct,subprocess,sys,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_drainage'))
import model7_capacity_forensics as prior

CORE='6e77aeb82'
BASE='8e27dd9eb0f633050d2d82d00d28992435c313cb'
READERS='e079d1554041c831cd0ab609835e2e79bf3c31a1'
PATH='tests/nomacro_drainage/model7_capacity_forensics.py'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)


def shared_ledger_cold():
 raw=git('show',READERS+':'+PATH)
 assert (ROOT/PATH).read_bytes().replace(b'\r\n',b'\n')==raw
 functions=[n for n in ast.parse(raw.decode()).body if isinstance(n,ast.FunctionDef) and n.name=='audit'];assert len(functions)==1
 body=functions[0].body
 def assignment(node,name):return isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id==name for t in node.targets)
 first=next(i for i,n in enumerate(body) if assignment(n,'rows'))
 phase=next(i for i,n in enumerate(body[first:],first) if isinstance(n,ast.If) and isinstance(n.test,ast.Name) and n.test.id=='terminal')
 cold=next(n for n in body[phase+1:] if isinstance(n,ast.If) and n.orelse)
 assert len(cold.orelse)==1 and ast.unparse(cold.orelse[0].test)=='not failed'
 selected=body[first:phase]+cold.orelse[0].body
 class Codec(ast.NodeTransformer):
  changes=0
  def visit_Constant(self,node):
   if node.value in (b'S5IOC001',b'S5IOW001'):
    self.changes+=1;return ast.copy_location(ast.Constant(b'S5HSC004' if node.value==b'S5IOC001' else b'S5HSW004'),node)
   return node
 tree=ast.parse('def read(profile,meta,q,build):\n failed=censored=False\n')
 role=Codec();tree.body[0].body += [role.visit(n) for n in selected]
 assert role.changes==2
 tree.body[0].body += ast.parse("return dict(days=len(rows),water_daily_max=str(maximum),CDE_daily_max=str(chemical),CDE_every_prefix_max=str(prefix),observed_global_water_prefix=str(waterprefix),global_water_prefix_is_owning_gate=False,cold_windows=len(q['own']))").body
 namespace=dict(vars(prior));exec(compile(ast.fix_missing_locations(tree),PATH,'exec'),namespace)
 return namespace['read']


def audit(profile,reference,locations=None):
 q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_SNOW_VAPOR_WATER_CDE_POSTIMAGE_SHORT_OR_FULL_EXACT_COLD_PASS_NOT_ADMITTED'
 assert not git('diff',CORE,q['source'],'--','app','src','tools/solute','tools/vq','reference'),q['source']
 build=locations['build'] if locations else Path(q['build_root']);inputs=locations['inputs'] if locations else Path(q['input_root'])
 meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];policy=identity['hydraulic_vapor']
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 for role,digest in meta['executable_sha256'].items():
  actual=[path for path in (build/('day_'+role),build/('day_'+role+'.exe')) if path.is_file()]
  assert len(actual)==1 and SHA(actual[0].read_bytes())==digest
 for field in ('donor_flags','kernel_flags'):assert '-'+q['optimization'] in identity[field]
 assert policy['snow_composition']['native_domain_version']==4 and policy['snow_composition']['fixed_absolute_terminal_water_limit_cm']==1e-10
 assert policy['native_codec']==('S5HSC004' if q['kind']=='cde' else 'S5HSW004')
 models=q['layer_models']*policy['numlay'] if len(q['layer_models'])==1 else q['layer_models']
 assert models==policy['models'] and q['vapor_flags']==policy['SWVAPOR']
 expected='ddaf8cd9d1effe893fca68d92fbd242285bce6de50ba84fb864f22978df49861' if 7 in models else '9ad54cbf7887b0a6dc6555fa56ddd5486a5d96829af1bd437e0e8f341ca66fa8'
 assert SHA((build/'WC_K_models_04_11.f90').read_bytes().replace(b'\r\n',b'\n'))==expected==policy['corrected_lf_sha256']
 native=git('show',BASE+':app/hybrid_water/hydraulic_vapor_native.f90').decode('cp1252')
 assert SHA(native.encode('cp1252'))=='a181df32399d64a4052f4e8d3d11133bb7388fd890c8f0e9139594bbc29877b0'
 for before,after in [('swkimpl/=0.or.swsophy/=0.or.swsnow/=0','swkimpl/=0.or.swsophy/=0.or.swsnow/=1'),('expected(1:14)=[3,','expected(1:14)=[4,')]:
  assert native.count(before)==1;native=native.replace(before,after,1)
 assert (build/'hydraulic_vapor_native.f90').read_bytes().replace(b'\r\n',b'\n')==native.encode('cp1252')
 assert SHA(native.encode('cp1252'))==policy['native_domain_source_sha256']
 terminal=(build/'snow_vapor_terminal_water_receipt.f90').read_bytes().replace(b'\r\n',b'\n')
 assert terminal==git('show',BASE+':app/hybrid_water/terminal_water_receipt.f90') and SHA(terminal)==prior.RECEIPT
 frozen=git('show',BASE+':app/hybrid_water/model7_terminal_water.py');namespace={};exec(compile(frozen,'model7_terminal_water.py','exec'),namespace)
 imported='   use hybrid_terminal_water_receipt, only: terminal_water_residual\n   use variables, only: tcum\n'
 guard='\n         if(tcum+dt>=1d0-1d-8)then\n            if(abs(terminal_water_residual())>1d-10)flnonconv=.true.\n         end if'
 daily=git('show',BASE+':app/hybrid_water/daily_host.py').decode()
 assert guard in [node.value for node in ast.walk(ast.parse(daily)) if isinstance(node,ast.Constant) and isinstance(node.value,str)]
 head=(build/'headcalc.f90').read_text(encoding='cp1252')
 for part in (imported,guard,namespace['SEARCH']):assert head.count(part)==1;head=head.replace(part,'',1)
 assert SHA(head.encode('cp1252'))==prior.HEAD
 assert (build/'original_output_thermal_domain.f90').read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':app/hybrid_water/original_output_thermal_domain.f90')
 for owner,filename in (('micro_lookup_state','RWU_micro.f90'),('oxygen_lookup_state','oxygenstress.f90')):
  raw=git('show','5b8373d0809c25e24415f4d5dc01784a92ff481e:app/hybrid_water/'+owner+'.py');namespace={};exec(compile(raw,owner+'.py','exec'),namespace)
  assert (build/filename).read_text(encoding='cp1252')==namespace['render']((reference/'build/swap-selected'/filename).read_text(encoding='cp1252'))
 normalized=dict(q,own=q['cold']);result=shared_ledger_cold()(profile,meta,normalized,build)
 assert result['days']==q['days'] and result['cold_windows']==(7 if q['days']==1096 else 3)
 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()]
 stocks=0;checkpoints=0
 values=[4,meta['project']['nodes'],policy['numlay'],0,int(q['kind']=='cde'),0,0,1,0,0,1,2,1,6]+models+[f if model>=8 else 0 for model,f in zip(models,policy['SWVAPOR'])]
 domain=struct.pack('<'+str(len(values))+'i',*values)
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
   aux=z.read('macro.bin');assert aux[:8]==policy['native_codec'].encode() and aux[48:48+2*len(domain)]==domain+domain
   if q['kind']=='cde':
    state=struct.unpack_from('<'+str(meta['project']['nodes']+2)+'d',aux,48+2*len(domain))
    assert all(math.isfinite(v) and v>=0 for v in state) and state[-1]==rows[day-1]['solute_end_mg_cm2'];stocks+=1
  checkpoints+=1
 assert checkpoints==(14 if q['days']==1096 else 7)
 result.update(status='INDEPENDENT_ORIGINAL_SNOW_VAPOR_SOURCE_PROVIDER_WATER_CDE_NATIVE_OUTPUT_PASS',producer=q['source'],kind=q['kind'],optimization=q['optimization'],layer_models=models,vapor_flags=policy['SWVAPOR'],native_checkpoints=checkpoints,exact_private_CDE_stocks=stocks,literal_qualified_mass_and_cold_body=READERS,literal_existing_Snow_terminal_phase=True,complete_HeadCalc_inverse=True,complete_qualified_constitutive_source=True,complete_vapor_native_domain_inverse=True,complete_original_Snow_receipt=True,compiler_executions=0,model_executions=0,canonical_admission=False)
 return result


if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();result=audit(a.profile,a.reference_work)
 with a.output.open('x') as stream:json.dump(result,stream,indent=2);stream.write('\n')
 print(result['status'],result['days'],result['cold_windows'])
