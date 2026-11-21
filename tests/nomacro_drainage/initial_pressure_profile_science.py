"""Independently read original initialization, unchanged mass and exact cold bytes."""
import argparse,ast,io,json,math,re,struct,subprocess,sys,zipfile
from decimal import Decimal,localcontext
from pathlib import Path,PureWindowsPath
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import model7_capacity_forensics as inherited
from analytical_hydraulic_archives import SHA
from initial_pressure_profile_source_inverse import BASE,CORE,PATH,SURFACES,git,complete_inverse
READERS='e079d1554041c831cd0ab609835e2e79bf3c31a1'
CODECS={'head5-undrained-cde':b'S5HBC005','closed-vapor-cde':b'S5HBC005','saturated-vapor-cde':b'S5HVC003','nonhydrostatic-water':b'S5IOW001','legacy-zih-water':b'S5IOW001'}
PROVIDER={'functions.f90':'c33ee3145daf0f0276448433090128104890d2bf5f71d79146d98639e524a661','readswap.f90':'e6fc217798d3f0424641c61b92fb8831fcdeb78c19670def00695b82ab8e80fe','soilwater.f90':'d5926b6c30fba3177c261c9a24ef828dd9cd6b3dfb952b07ef00800ebd42415d','swap_base.f90':'af54d6c6eafd2954f228be9a50ba92e7cefa231658d34de247d5b3b68aa58dab'}


def ledger_cold(magic):
 path='tests/nomacro_drainage/model7_capacity_forensics.py';raw=git('show',READERS+':'+path);assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==raw
 function=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='audit');body=function.body
 first=next(i for i,n in enumerate(body) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='rows' for t in n.targets))
 phase=next(i for i,n in enumerate(body[first:],first) if isinstance(n,ast.If) and isinstance(n.test,ast.Name) and n.test.id=='terminal')
 cold=next(n for n in body[phase+1:] if isinstance(n,ast.If) and n.orelse);assert len(cold.orelse)==1 and ast.unparse(cold.orelse[0].test)=='not failed'
 class Codec(ast.NodeTransformer):
  changes=0
  def visit_Constant(self,node):
   if node.value in (b'S5IOC001',b'S5IOW001'):self.changes+=1;return ast.copy_location(ast.Constant(magic),node)
   return node
 codec=Codec();tree=ast.parse('def read(profile,meta,q,build):\n failed=censored=False\n');tree.body[0].body += [codec.visit(n) for n in body[first:phase]+cold.orelse[0].body];assert codec.changes==2
 tree.body[0].body += ast.parse("return dict(days=len(rows),cold_windows=len(q['own']),water_daily_max=str(maximum),CDE_daily_max=str(chemical),CDE_every_prefix_max=str(prefix),extra_global_water_prefix=str(waterprefix),global_water_prefix_is_owning_gate=False)").body
 namespace=dict(vars(inherited));exec(compile(ast.fix_missing_locations(tree),path,'exec'),namespace);return namespace['read']


def initialized_heads(text):
 table=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert table
 z=[];last_dz=None
 for line in table[1].splitlines():
  _,_,height,count=line.split();count=int(count);dz=float(height)/count
  for _ in range(count):z.append(-.5*dz if not z else z[-1]-.5*(last_dz+dz));last_dz=dz
 legacy=re.search(r'(?mi)^[ \t]*H[ \t]*=[ \t]*([^!\r\n]+)',text)
 if legacy:
  depths=re.search(r'(?mi)^[ \t]*ZI[ \t]*=[ \t]*([^!\r\n]+)',text);assert depths
  points=list(zip(map(lambda x:abs(float(x)),depths[1].split()),map(float,legacy[1].split())))
 else:
  table=re.search(r'(?mi)^[ \t]*HTB[ \t]*=[ \t]*\n(.*?)^\* End of table',text,re.S);assert table
  points=[(abs(float(a)),float(b)) for a,b in (line.split() for line in table[1].splitlines() if line.strip())]
 assert len(points)>=2 and all(a[0]<b[0] for a,b in zip(points,points[1:]))
 # Independent evaluation of the pinned original afgen_2 and SoilWater(1).
 # This observer never supplies or changes a model pressure/state value.
 h=[]
 for node in z:
  x=abs(node)
  if x<=points[0][0]:y=points[0][1]
  elif x>points[-1][0]:y=points[-1][1]
  else:
   a,b=next((a,b) for a,b in zip(points,points[1:]) if b[0]>=x)
   slope=(b[1]-a[1])/(b[0]-a[0]);y=a[1]+(x-a[0])*slope
  h.append(y)
 saturated=0
 if h[-1]>-1e-5:
  i=len(h)-1
  while h[i]>-1e-5 and i>0:i-=1
  if h[i]<-1e-5:
   gwl=z[i+1]+h[i+1]/(h[i+1]-h[i])*(z[i]-z[i+1])
   for j in range(i+1,len(h)):h[j]=gwl-z[j];saturated+=1
 return h,dict(legacy_ZI_H=bool(legacy),profile_knots=[list(p) for p in points],saturated_nodes_reinitialized_by_original=saturated)


def audit(profile,reference,locations=None):
 q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_INITIAL_PRESSURE_PROFILE_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED' and q['days']==35
 assert not git('diff',CORE,q['source'],'--',*SURFACES)
 build=locations['build'] if locations else Path(q['build_root']);inputs=locations['inputs'] if locations else Path(q['input_root']);case=PureWindowsPath(q['input_root']).name;magic=CODECS[case]
 meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];nodes=meta['project']['nodes']
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 for name,digest in PROVIDER.items():assert SHA((reference/('build/swap-selected/'+name)).read_bytes().replace(b'\r\n',b'\n'))==digest
 for name,start,end in [('readswap.f90','! --- initial water conditions','! --- ponding'),('soilwater.f90','         if (swinco == 1) then','         if (swinco == 2) then')]:
  original=git('show',BASE+':reference/swap-4.3.1/b1_11_frost_source/SWAP/'+name).decode();actual=(reference/('build/swap-selected/'+name)).read_text(encoding='cp1252');fragment=lambda s:s[s.index(start):s.index(end,s.index(start))];assert fragment(original.replace('\r\n','\n'))==fragment(actual.replace('\r\n','\n'))
 for field in ('donor_flags','kernel_flags'):assert '-'+q['optimization'] in identity[field]
 for role,digest in meta['executable_sha256'].items():
  files=[p for p in (build/('day_'+role),build/('day_'+role+'.exe')) if p.is_file()];assert len(files)==1 and SHA(files[0].read_bytes())==digest
 result=ledger_cold(magic)(profile,meta,dict(q,own=q['cold']),build)
 text=(inputs/'swap.swp').read_text(encoding='cp1252');expected,initial=initialized_heads(text);from experimental_project import switches;selectors=switches(text);lines=(profile/'trajectory/original/donor.stdout').read_text().splitlines();actual=next(list(map(float,line.split()[3:])) for line in lines if line.startswith('HYBRID_HYDRAULIC '));assert len(actual)==nodes and actual==expected,'Original supplied pressure profile was not initialized exactly'
 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];samples=stocks=0
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:aux=z.read('macro.bin')
  assert aux[:8]==magic;samples+=1
  if q['kind']=='cde':
   vapor=identity['hydraulic_vapor'];domain=[5 if magic==b'S5HBC005' else 3,nodes,vapor['numlay'],0,1,0,0,0,0,0,1,2,selectors['SWDRA'],selectors['SWBOTB']]+vapor['models']+[f if m>=8 else 0 for m,f in zip(vapor['models'],vapor['SWVAPOR'])];packed=struct.pack('<'+str(len(domain))+'i',*domain);assert aux[48:48+2*len(packed)]==packed+packed
   saved=struct.unpack_from('<'+str(nodes+2)+'d',aux,48+2*len(packed));assert all(math.isfinite(v) and v>=0 for v in saved) and saved[-1]==rows[day-1]['solute_end_mg_cm2'];stocks+=1
 result.update(status='INDEPENDENT_ORIGINAL_PRESSURE_PROFILE_INITIAL_HEADS_SOURCE_FIXED_WATER_CDE_NATIVE_EXACT_COLD_PASS',producer=q['source'],kind=q['kind'],optimization=q['optimization'],case=case,exact_initial_pressure_nodes=nodes,initial_profile=initial,native_checkpoints=samples,exact_private_CDE_stocks=stocks,native_codec=magic.decode(),CDE_initial_stock=rows[0].get('solute_start_mg_cm2'),compiler_executions=0,model_executions=0,canonical_admission=False)
 return result


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],q['case'],q['optimization'])
