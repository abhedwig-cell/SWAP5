"""Independent complete 35day analytical Snow water/CDE ledgers and native decoding."""
import argparse,hashlib,json,subprocess,sys,zipfile
from decimal import Decimal,localcontext
from pathlib import Path
R=Path(__file__).resolve().parents[2];sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
import snow_undrained_forensics as frozen
from snow58_analytical_native import native
from ordinary_pond_evidence import physical
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--profile',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--reference-samples',type=Path);a=p.parse_args()
q=json.loads((a.profile/'RESULT.json').read_text());assert q['days']==35 and q['status'].endswith('PASS_NOT_ADMITTED') and q['observer_source']==q['actual_completion_head'] and q['source']==q['build']['actual_completion_head']
assert not subprocess.check_output(['git','diff',q['source'],q['observer_source'],'--','app','src','tools','reference'],cwd=R),'Changed execution dependency between actual compiler and observer'
build=Path(q['build_root']);inputs=Path(q['input_root']);meta=json.loads((build/'BUILD.json').read_text());assert SHA((build/'BUILD.json').read_bytes())==q['actual_BUILD_sha256'] and meta['identity']['original_output']['analytical_snow_models']==q['layer_models']
for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest==meta['inputs'][name]
decoder_path='tests/nomacro_drainage/snow58_analytical_native.py';decoder=subprocess.check_output(['git','show',q['observer_source']+':'+decoder_path],cwd=R);assert (R/decoder_path).read_bytes().replace(b'\r\n',b'\n')==decoder
text=(inputs/'swap.swp').read_text(encoding='cp1252');s={key:frozen.scalar(text,key) for key in ('SWKIMPL','SWSNOW','SWSOLU','SWHYST','SWBOTB','SWDRA','SWCFBS','NPRINTDAY','SWRES')};dz=frozen.geometry((inputs/'swap.swp').read_bytes(),meta['project']['nodes']);warm=a.profile/'trajectory'
rows=lambda root:[json.loads(line) for line in (root/'daily.jsonl').read_text().splitlines()]
data=rows(warm);assert len(data)==35 and [row['day'] for row in data]==list(range(1,36))
windows=[(2,4),(7,9),(30,34)];assert [(item['start'],item['end']) for item in q['cold']]==windows
global_max=Decimal(0)
with localcontext() as c:
 c.prec=60
 for row in data:
  d=lambda value:Decimal(str(value));residual=sum(map(d,row['stock_start_cm']))+sum(map(d,row['external_flux_cm'][:7]))-sum(map(d,row['external_flux_cm'][7:]))-sum(map(d,row['stock_end_cm']));assert abs(residual)<=Decimal('1e-10');global_max=max(global_max,abs(residual));assert row['external_flux_cm'][-1]==max(row['bottom_outward_cm'],0.) and row['external_flux_cm'][6]==max(-row['bottom_outward_cm'],0.)
def audit(root,observed):
 water=frozen.original.water(observed);soil=frozen.soil(root,len(observed));byday={row['day']:row for row in observed};seen=[]
 for path in sorted(root.glob('accepted-column-1-day-*.zip')):
  day=int(path.stem.rsplit('-',1)[1]);assert day in byday
  with zipfile.ZipFile(path) as z:
   m=json.loads(z.read('checkpoint.json'));assert m['binding']==meta['binding'] and m['receipt']==byday[day] and all(SHA(z.read(name))==digest for name,digest in m['files'].items());native(z.read('macro.bin'),byday[day],meta,s,dz)
  seen.append(day)
 chemical=None
 if s['SWSOLU']:
  from groundwater_snow_forensics import clock
  chemical=clock.ledger(observed,len(observed))
  class Files:
   def read(self,name):return (root/name).read_bytes()
  clock.daily(Files(),'',observed,meta['project']['nodes'])
 return dict(water=water,soil=soil,solute=chemical,native_samples=sorted(seen))
proof=audit(warm,data);assert proof['native_samples']==[2,4,7,9,30,34,35];cold=[]
for low,high in windows:
 root=a.profile/('own-'+str(low));actual=rows(root);assert physical(actual)==physical(data[low:high]);item=audit(root,actual);assert item['native_samples']==[high]
 with zipfile.ZipFile(warm/f'accepted-column-1-day-{high}.zip') as x,zipfile.ZipFile(root/f'accepted-column-1-day-{high}.zip') as y:assert all(x.read(name)==y.read(name) for name in ('macro.bin','result.end'))
 cold.append(item)
assert max(row['stock_end_cm'][2] for row in data)>0
sample_receipt=None
if a.reference_samples:
 sample=json.loads((a.reference_samples/'RESULT.json').read_text());assert sample['model']==q['layer_models'][0] and sample['optimization']==q['optimization'] and sample['model_periods']==0
 assert sample['profile_RESULT_sha256']==SHA((a.profile/'RESULT.json').read_bytes()) and sample['daily_sha256']==SHA((warm/'daily.jsonl').read_bytes())
 component=sample['component'];directory=Path(sample['component_profile']);assert json.loads((directory/'COMPONENT.json').read_text())==component and SHA((directory/component['executable']).read_bytes())==component['executable_sha256']
 assert all(item['returncode']==0 for item in component['compiler']) and component['optimization']==q['optimization']
 for filename,digest in component['original_rebuilt_sources'].items():assert SHA((directory/filename).read_bytes())==digest
 assert component['original_rebuilt_sources']['WC_K_models_04_11.f90']=='7910cd29c045037778bfffdc7e40a77802d70fb477e0afa78be426776bd26e27'
 observed_raw=(a.reference_samples/'sample.stdout').read_bytes();assert SHA(observed_raw)==sample['stdout_sha256'] and not (a.reference_samples/'sample.stderr').read_bytes()
 head_raw=(a.reference_samples/'actual-heads.txt').read_bytes();assert SHA(head_raw)==sample['head_input_sha256'] and list(map(float,head_raw.decode().splitlines()[1:]))==sample['heads']
 observed={}
 for line in observed_raw.decode().splitlines():
  if line.startswith('ACTUAL_ORIGINAL_HYDRAULIC_SAMPLE '):
   words=line.split();model,soil,index=map(int,words[1:4]);values=list(map(float,words[4:]));assert len(words)==14 and model==sample['model'] and soil in (1,2) and 1<=index<=len(sample['heads']) and values[0]==sample['heads'][index-1] and (soil,index) not in observed;observed[soil,index]=values
 assert len(observed)==2*len(sample['heads'])
 assert sample['actual_soil_input_sha256']==SHA((inputs/'swap.swp').read_bytes())
 for soil in (1,2):
  for index in range(1,len(sample['heads'])+1):assert observed[soil,index]==sample['observations_by_layer'][str(soil)][index-1]
 samples={soil:{row[0]:row for row in sample['observations_by_layer'][str(soil)]} for soil in (1,2)};residual=[]
 import math,re
 table=re.search(r'(?mi)^\s*ISUBLAY\s+ISOILLAY\s+HSUBLAY\s+NCOMP\s*\n(.*?)^\* End of table',text,re.S);assert table
 layers=[]
 for line in table[1].splitlines():
  values=line.split('!')[0].split()
  if values:
   assert len(values)==4 and int(values[1]) in (1,2) and int(values[3])>0;layers.extend([int(values[1])]*int(values[3]))
 assert len(layers)==len(dz)==meta['project']['nodes']
 for row in data:
  assert all(head in samples[soil] for soil,head in zip(layers,row['pressure_head_cm']))
  stock=math.fsum(samples[soil][head][1]*height for soil,head,height in zip(layers,row['pressure_head_cm'],dz));error=abs(stock-row['stock_end_cm'][0]);assert error<=1e-10;residual.append(error)
 sample_receipt=dict(actual_original_constitutive_rows=len(observed),all_actual_pressures_observed=True,maximum_original_theta_stock_difference_cm=max(residual),model_periods=0,raw_stdout_sha256=sample['stdout_sha256'])
if s['SWSOLU']:assert any(row['solute_ledger_mg_cm2'][3]>0 for row in data),'CDE incoming tracer source never active'
result=dict(status='ACTUAL_ANALYTICAL_SNOW35_ALL_NODE_GLOBAL_SOIL_SOLUTE_NATIVE_EXACT_COLD_INDEPENDENT_PASS_NOT_ADMITTED',producer=q['source'],observer_source=q['observer_source'],boundary=s['SWBOTB'],actual_bottom_outward_cm=[row['bottom_outward_cm'] for row in data],layer_models=q['layer_models'],kind=q['kind'],optimization=q['optimization'],days=35,warm=proof,cold=cold,actual_original_constitutive_samples=sample_receipt,decimal_global_maximum_absolute_residual_cm=str(global_max),absolute_water_limit_cm='1e-10',independent_native_reader_sha256=SHA(decoder),actual_BUILD_sha256=q['actual_BUILD_sha256'],compiler_executions=0,model_executions=0,canonical_admission=False)
with a.output.open('x') as stream:json.dump(result,stream,indent=2)
print(result['status'],q['kind'],q['layer_models'],str(global_max))
