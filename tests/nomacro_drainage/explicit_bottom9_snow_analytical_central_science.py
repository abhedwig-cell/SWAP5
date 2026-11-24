"""Independent read-only original analytical Snow archive and native guard auditor."""
import argparse,hashlib,json,math,re,struct,subprocess,sys,zipfile
from contextlib import ExitStack
from decimal import Decimal,localcontext
from pathlib import Path
R=Path(__file__).resolve().parents[2];P=R/'integration/f-ci/nomacro-complete01'
sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface')]
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from explicit_bottom9_snow_analytical_native import native
import snow_undrained_forensics as frozen
from ordinary_pond_evidence import physical
from explicit_bottom9_compiled_postimage import compare as compiled_compare
def norm(path):return str(path).replace(chr(92),'/').rstrip('/')
class Pool:
 def __init__(self,stack):self.stack=stack;self.stores={};self.locations={}
 def store(self,name):
  if name not in self.stores:self.stores[name]=Archive(P,name,self.stack)
  return self.stores[name]
 def view(self,name,prefix):return ReadView(self.store(name),prefix)
 def add(self,path,name,prefix):self.locations[norm(path)]=(name,prefix.rstrip('/'))
 def resolve(self,path):
  path=norm(path);matches=[key for key in self.locations if path==key or path.startswith(key+'/')];assert matches,'Missing actual archive location '+path
  key=max(matches,key=len);name,prefix=self.locations[key];tail=path[len(key):].lstrip('/');return self.view(name,'/'.join(x for x in (prefix,tail) if x))
def read(view):return json.loads(view.read_text())
def rows(view):return [json.loads(line) for line in (view/'daily.jsonl').read_text().splitlines()]
def source_files(view):return {path.relative_to(view).as_posix():path for path in view.rglob('*') if path.is_file() and path.suffix.lower() in ('.f90','.f','.for','.inc')}
def build(pool,path,expected):
 view=pool.resolve(path);raw=(view/'BUILD.json').read_bytes();assert SHA(raw)==expected;meta=json.loads(raw)
 for name,digest in meta['identity']['donor_generated'].items():assert SHA((view/name).read_bytes())==digest,'Changed actual generated source '+name
 for role,stem in (('donor','day_donor'),('kernel','day_kernel')):
  candidates=[view/(stem+suffix) for suffix in ('','.exe') if (view/(stem+suffix)).is_file()];assert len(candidates)==1 and SHA(candidates[0].read_bytes())==meta['executable_sha256'][role]
 for field in ('donor_flags','kernel_flags'):assert {'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(meta['identity'][field])
 return view,meta
def checkpoints(root,data,meta,s,dz):
 byday={row['day']:row for row in data};seen=[]
 for path in root.glob('accepted-column-1-day-*.zip'):
  day=int(path.stem.rsplit('-',1)[1]);assert day in byday
  import io
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
   assert set(z.namelist())=={'checkpoint.json','macro.bin','result.end'};q=json.loads(z.read('checkpoint.json'))
   assert q['binding']==meta['binding'] and q['receipt']==byday[day] and all(SHA(z.read(name))==digest for name,digest in q['files'].items())
   native(z.read('macro.bin'),byday[day],meta,s,dz);frozen.original.sequential_records(z.read('result.end'))
  seen.append(day)
 return sorted(seen)
def exact_native(a,b):
 import io
 with zipfile.ZipFile(io.BytesIO(a.read_bytes())) as left,zipfile.ZipFile(io.BytesIO(b.read_bytes())) as right:
  assert all(left.read(name)==right.read(name) for name in ('macro.bin','result.end'))
def actual_ledger(root,data):
 water=frozen.original.water(data);records=[]
 for line in (root/'original/donor.stdout').read_text().splitlines():
  if not line.startswith('HYBRID_SNOW_SOIL_RECEIPT '):continue
  row=list(map(float,line.split()[1:]));assert len(row)==29 and all(map(math.isfinite,row))
  residual=math.fsum(row[12:19]+[-value for value in row[19:28]]+row[6:12]+[-value for value in row[:6]])
  assert abs(residual)<=1e-10 and abs(row[-1])<=1e-10 and row[2:6]==row[8:12]==[0.]*4;records.append(row)
 assert len(records)==len(data)
 soil=dict(actual_days=len(data),maximum_absolute_residual_cm=max(abs(row[-1]) for row in records));peak=Decimal(0)
 with localcontext() as context:
  context.prec=60
  for row in data:
   d=lambda value:Decimal(str(value));residual=sum(map(d,row['stock_start_cm']))+sum(map(d,row['external_flux_cm'][:7]))-sum(map(d,row['external_flux_cm'][7:]))-sum(map(d,row['stock_end_cm']))
   assert abs(residual)<=Decimal('1e-10') and row['external_flux_cm'][-1]==0 and row['pressure_head_cm'][-1]==-1005.;peak=max(peak,abs(residual))
 chemical=None
 if 'solute_ledger_mg_cm2' in data[0]:
  from groundwater_snow_forensics import clock
  chemical=clock.ledger(data,len(data))
  class Files:
   def read(self,name):return (root/name).read_bytes()
  clock.daily(Files(),'',data,len(data[0]['pressure_head_cm']))
 return dict(water=water,soil=soil,solute=chemical,decimal_global_maximum_absolute_residual_cm=str(peak))
def sample_stock(pool,location,profile,q,inputs,full,dz):
 folder=pool.resolve(location);sample=read(folder/'RESULT.json');assert sample['profile_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes()) and sample['daily_sha256']==SHA((profile/'trajectory/daily.jsonl').read_bytes()) and sample['actual_soil_input_sha256']==SHA((inputs/'swap.swp').read_bytes()) and sample['model_periods']==0
 component=sample['component'];directory=pool.resolve(sample['component_profile']);assert read(directory/'COMPONENT.json')==component and SHA((directory/component['executable']).read_bytes())==component['executable_sha256']
 assert all(item['returncode']==0 for item in component['compiler']) and component['optimization']==q['optimization'] and component['original_rebuilt_sources']['WC_K_models_04_11.f90']=='7910cd29c045037778bfffdc7e40a77802d70fb477e0afa78be426776bd26e27'
 for name,digest in component['original_rebuilt_sources'].items():assert SHA((directory/name).read_bytes())==digest
 raw=(folder/'sample.stdout').read_bytes();assert SHA(raw)==sample['stdout_sha256'] and not (folder/'sample.stderr').read_bytes();head_raw=(folder/'actual-heads.txt').read_bytes();assert SHA(head_raw)==sample['head_input_sha256']
 observed={}
 for line in raw.decode().splitlines():
  if not line.startswith('ACTUAL_ORIGINAL_HYDRAULIC_SAMPLE '):continue
  words=line.split();model,soil,index=map(int,words[1:4]);values=list(map(float,words[4:]));assert len(words)==14 and model==q['layer_models'][0] and soil in (1,2) and 1<=index<=len(sample['heads']) and values[0]==sample['heads'][index-1] and all(map(math.isfinite,values)) and (soil,index) not in observed;observed[soil,index]=values
 assert len(observed)==2*len(sample['heads'])
 for soil in (1,2):
  for index in range(1,len(sample['heads'])+1):assert observed[soil,index]==sample['observations_by_layer'][str(soil)][index-1]
 table=re.search(r'(?mi)^\s*ISUBLAY\s+ISOILLAY\s+HSUBLAY\s+NCOMP\s*\n(.*?)^\* End of table', (inputs/'swap.swp').read_bytes().decode('cp1252'),re.S);assert table;layers=[]
 for line in table[1].splitlines():
  fields=line.split('!')[0].split()
  if fields:assert len(fields)==4 and int(fields[1]) in (1,2);layers.extend([int(fields[1])]*int(fields[3]))
 assert len(layers)==len(dz)
 lookup={soil:{row[0]:row for row in sample['observations_by_layer'][str(soil)]} for soil in (1,2)};errors=[]
 for row in full:
  stock=math.fsum(lookup[layer][head][1]*height for layer,head,height in zip(layers,row['pressure_head_cm'],dz));error=abs(stock-row['stock_end_cm'][0]);assert error<=1e-10;errors.append(error)
 return dict(actual_original_constitutive_rows=len(observed),maximum_original_theta_stock_error_cm=max(errors),component_actual_source=component['source'],actual_sample_source=sample['source'])


def startup_controls(pool,location,profile,q,meta,s,dz,root_controls=False):
 root=pool.resolve(location);record=read(root/'RESULT.json');key='refusals' if root_controls else 'compiled_refusals';expected=25 if root_controls else 17
 assert record['actual_compiler_producer']==q['source'] and record['actual_BUILD_sha256']==q['actual_BUILD_sha256'] and record['accepted_model_days']==0 and record['compiler_executions']==0 and len(record[key])==expected
 actual=rows(profile/'trajectory');day=4 if root_controls else 2;row=actual[day-1];seen=set()
 for item in record[key]:
  label=item['attack'];assert label not in seen;seen.add(label);prefix=root/label;stream=prefix/'original' if root_controls else prefix
  stdout=(stream/'donor.stdout').read_bytes();stderr=(stream/'donor.stderr').read_bytes();assert b'HYBRID_READY' not in stdout and b'HYBRID_DAY_RETURN' not in stdout and b'ERROR STOP' in stderr
  raw=(prefix/'origin/macro.bin').read_bytes()
  if not root_controls:assert SHA(raw)==item['actual_raw_sha256'] and item['identical_raw_typed_refusal']
  try:native(raw,row,meta,s,dz)
  except (AssertionError,ValueError,struct.error):pass
  else:raise AssertionError('Independent native decoder accepted original compiled malformed payload '+label)
 positive=root/('positive-startup/original' if root_controls else 'genuine-own-positive');assert b'HYBRID_READY' in (positive/'donor.stdout').read_bytes() and not (positive/'donor.stderr').read_bytes()
 return dict(actual_compiled_refusals=expected,actual_positive_compiled_ready=True,accepted_model_days=0,actual_compiler_producer=q['source'])
def positive(pool,item):
 profile=pool.resolve(item['profile']);q=read(profile/'RESULT.json');assert q['days']==35 and q['status'].endswith('PASS_NOT_ADMITTED') and q['source']==q['actual_completion_head']==q['build']['actual_completion_head']==item['producer']
 bundle,meta=build(pool,q['build_root'],q['actual_BUILD_sha256']);inputs=pool.resolve(q['input_root'])
 assert {name:SHA((inputs/name).read_bytes()) for name,_ in q['input_inventory']}==dict(q['input_inventory'])==meta['inputs']
 text=(inputs/'swap.swp').read_bytes().decode('cp1252');s={key:frozen.scalar(text,key) for key in ('SWKIMPL','SWSNOW','SWSOLU','SWHYST','SWBOTB','SWDRA','SWCFBS','NPRINTDAY','SWRES')}
 assert s['SWBOTB']==9 and s['SWKIMPL']==s['SWHYST']==s['SWDRA']==0 and s['SWSNOW']==1 and s['SWSOLU']==int(q['kind']=='cde') and meta['identity']['original_output']['analytical_snow_models']==q['layer_models']==[item['model']]*2
 dz=frozen.geometry((inputs/'swap.swp').read_bytes(),meta['project']['nodes']);warm=profile/'trajectory';data=rows(warm);assert len(data)==35 and [row['day'] for row in data]==list(range(1,36))
 ledger=actual_ledger(warm,data);assert checkpoints(warm,data,meta,s,dz)==[2,4,7,9,30,34,35] and max(row['stock_end_cm'][2] for row in data)>0
 windows=[(2,4),(7,9),(30,34)];assert [(entry['start'],entry['end']) for entry in q['cold']]==windows
 for low,high in windows:
  root=profile/('own-'+str(low));actual=rows(root);assert physical(actual)==physical(data[low:high]);actual_ledger(root,actual);assert checkpoints(root,actual,meta,s,dz)==[high];exact_native(root/f'accepted-column-1-day-{high}.zip',warm/f'accepted-column-1-day-{high}.zip')
 if q['kind']=='cde':assert any(row['solute_ledger_mg_cm2'][3]>0 for row in data)
 post=pool.resolve(item['current_complete_initial2_postimage']);counter=read(post/'RESULT.json');assert counter['source']==counter['actual_compiler_start_HEAD']==counter['actual_compiler_end_HEAD']=='505954d2943b3f7f478efbb617c53f53dc5f5126' and counter['initial1_source']==q['source'] and counter['profile_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes())
 current,currentmeta=build(pool,counter['build_root'],counter['actual_initial2_BUILD_sha256']);old_sources,new_sources=source_files(bundle),source_files(current);assert old_sources and old_sources.keys()==new_sources.keys()
 for name,path in old_sources.items():assert path.read_bytes().replace(b'\r\n',b'\n')==new_sources[name].read_bytes().replace(b'\r\n',b'\n')
 compiled=compiled_compare(bundle,current)
 samples=sample_stock(pool,item['original_samples'],profile,q,inputs,data,dz)
 malformed=startup_controls(pool,item['model_native_controls'],profile,q,meta,s,dz);root_malformed=startup_controls(pool,item['root_native_controls'],profile,q,meta,s,dz,True) if item['root_native_controls'] else None;transactions=None
 if item['transactions']:
  transactions=read(pool.resolve(item['transactions'])/'RESULT.json');assert transactions['actual_compiler_producer']==q['source'] and transactions['actual_BUILD_sha256']==q['actual_BUILD_sha256'] and transactions['compiler_executions']==0 and transactions['transactions']==dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True)
 return dict(status='CENTRAL_ORIGINAL_ANALYTICAL_SNOW35_ALL_NODE_NATIVE_COLD_ORIGINAL_TTUTIL_CURRENT_INITIAL2_POSTIMAGE_PASS',model=item['model'],kind=q['kind'],optimization=q['optimization'],actual_full35_producer=q['source'],actual_days=35,actual_native_checkpoints=7,actual_exact_cold_windows=3,original_full35_period_replayed=False,absolute_water_limit_cm='1e-10',ledger=ledger,original_constitutive_observations=samples,compiled_model_native_controls=malformed,compiled_root_native_controls=root_malformed,actual_external_transactions=transactions,compiled_files=len(compiled['files']),actual_BUILD_sha256=q['actual_BUILD_sha256'])


def pe_bytes(before,after):
 path='tests/nomacro_drainage/calendar_publisher.py';raw=(R/path).read_bytes().replace(b'\r\n',b'\n');assert raw==subprocess.check_output(['git','show','505954d2943b3f7f478efbb617c53f53dc5f5126:'+path],cwd=R)
 source=raw.decode();old='    left=Path(before).read_bytes();right=Path(after).read_bytes()';new='    left=before;right=after';assert source.count(old)==1;source=source.replace(old,new,1)
 namespace={};exec(compile(source,path+'::explicit_original_bytes_reader','exec'),namespace)
 return namespace['publisher_equivalence'](before,after)


def guard(pool,item,original_item):
 profile=pool.resolve(item['current_guard_bridge']);q=read(profile/'RESULT.json');assert q['status'].startswith('ACTUAL_CURRENT_NATIVE_NO_VAPOR_GUARD') and q['source']==q['actual_completion_head']==item['actual_current_compiler_producer']
 original=pool.resolve(original_item['profile']);oldq=read(original/'RESULT.json');assert q['original_full35_source']==oldq['source'] and q['original_full35_RESULT_sha256']==SHA((original/'RESULT.json').read_bytes()) and not q['original_full35_period_replayed'] and not q['checkpoint_binding_rewritten']
 old,oldmeta=build(pool,oldq['build_root'],oldq['actual_BUILD_sha256']);current,meta=build(pool,q['build_root'],q['actual_BUILD_sha256']);assert oldmeta['inputs']==meta['inputs']
 contract=json.loads((P/'EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_VAPOR_DOMAIN_GUARD_CONTRACT_V1.json').read_text());left,right=source_files(old),source_files(current);assert left and left.keys()==right.keys();changed=[]
 for name,path in left.items():
  before=path.read_bytes().replace(b'\r\n',b'\n');after=right[name].read_bytes().replace(b'\r\n',b'\n')
  if before==after:continue
  assert Path(name).name in ('macropore.f90','snow_undrained_root_state.f90')
  for edit in reversed(contract['literal_edits']):
   old_text,new_text=edit['before'].encode(),edit['after'].encode();assert after.count(new_text)==1;after=after.replace(new_text,old_text,1)
  assert after==before;changed.append(name)
 assert {Path(name).name for name in changed}=={'macropore.f90','snow_undrained_root_state.f90'}
 suffixes={'.o','.mod','.smod','.exe','.dll','.so','.a'}
 binaries=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and (p.suffix.lower() in suffixes or p.name in ('day_donor','day_kernel'))}
 a,b=binaries(old),binaries(current);assert a and a.keys()==b.keys();binary_changed=[];permitted={'macropore.o','hybrid_snow_analytical_native.mod','day_donor.exe','day_donor'}
 for name,path in a.items():
  before,after=path.read_bytes(),b[name].read_bytes()
  if before==after:continue
  if Path(name).name in permitted:binary_changed.append(name)
  else:pe_bytes(before,after)
 assert 'macropore.o' in {Path(name).name for name in binary_changed}
 for field in ('donor_objects','donor_modules','ttutil_modules','ttutil_library','donor_flags','kernel_flags','kernel_sources'):assert oldmeta['identity'][field]==meta['identity'][field]
 inputs=pool.resolve(q['input_root']);assert {name:SHA((inputs/name).read_bytes()) for name,_ in q['input_inventory']}==dict(q['input_inventory'])==meta['inputs'];text=(inputs/'swap.swp').read_bytes().decode('cp1252')
 s={key:frozen.scalar(text,key) for key in ('SWKIMPL','SWSNOW','SWSOLU','SWHYST','SWBOTB','SWDRA','SWCFBS','NPRINTDAY','SWRES')};dz=frozen.geometry((inputs/'swap.swp').read_bytes(),meta['project']['nodes'])
 full=rows(original/'trajectory');warm=rows(profile/'trajectory');cold=rows(profile/'own-4');assert len(full)==35 and len(warm)==4 and len(cold)==3 and physical(warm)==physical(full[:4]) and physical(cold)==physical(full[4:7])
 warm_ledger=actual_ledger(profile/'trajectory',warm);cold_ledger=actual_ledger(profile/'own-4',cold)
 assert checkpoints(profile/'trajectory',warm,meta,s,dz)==[2,4] and checkpoints(profile/'own-4',cold,meta,s,dz)==[7]
 for day in (2,4):exact_native(profile/f'trajectory/accepted-column-1-day-{day}.zip',original/f'trajectory/accepted-column-1-day-{day}.zip')
 exact_native(profile/'own-4/accepted-column-1-day-7.zip',original/'trajectory/accepted-column-1-day-7.zip')
 if oldq['kind']=='cde':assert any(row['solute_ledger_mg_cm2'][3]>0 for row in cold)
 refusal=None
 if item['model']==11:
  control=pool.resolve(item['compiled_foreign_active_vapor_refusal']);negative=read(control/'RESULT.json');assert negative['status']=='ACTUAL_CURRENT_COMPILED_NO_VAPOR_NATIVE_OWN_POSITIVE_AND_FOREIGN_ACTIVE_VAPOR_REFUSAL_PASS' and negative['actual_compiler_producer']==q['source'] and negative['actual_BUILD_sha256']==q['actual_BUILD_sha256'] and negative['accepted_model_days']==negative['compiler_executions']==0
  for label,good in (('own-positive',True),('foreign-active-vapor-private-input',False)):
   stdout=(control/label/'donor.stdout').read_bytes();stderr=(control/label/'donor.stderr').read_bytes();assert b'HYBRID_DAY_RETURN' not in stdout
   assert (b'HYBRID_READY' in stdout and not stderr) if good else (b'HYBRID_READY' not in stdout and b'Active vapor cannot use analytical Snow native' in stderr)
  refusal=dict(actual_compiler_producer=negative['actual_compiler_producer'],actual_observer_source=negative['actual_observer_source'],accepted_model_days=0)
 return dict(status='CENTRAL_CURRENT_NO_VAPOR_NATIVE_PRECONDITION_WARM4_COLD4_7_ALL_UNAFFECTED_SOURCE_COMPILED_PHYSICAL_NATIVE_PASS',model=item['model'],kind=item['kind'],optimization=item['optimization'],actual_current_compiler_producer=q['source'],actual_original_full35_producer=oldq['source'],actual_current_warm_days=4,actual_current_cold_window=[4,7],warm_ledger=warm_ledger,cold_ledger=cold_ledger,actual_changed_generated_source=changed,actual_changed_compiled_native_closure=binary_changed,unaffected_compiled_files=len(a)-len(binary_changed),foreign_active_vapor_refusal=refusal,old_checkpoints_rebound=False,full35_periods_replayed=0)


def legacy(pool,store,optimization):
 entry=next(item for item in store.record['legacy_model1'] if item['optimization']==optimization);record=json.loads(store.get(entry['path']));assert record['status']=='ALL4_CURRENT_MODEL1_SNOW_HISTORY_CALENDARS_SOURCE_COMPILED_AND_NATIVE_FORMAT_PRESERVED' and len(record['contexts'])==4
 out=[]
 for item in record['contexts']:
  q=read(pool.resolve(item['result']));assert q['current_source']=='505954d2943b3f7f478efbb617c53f53dc5f5126' and q['model_executions']==0
  parent=pool.store(q['original_archive'].removesuffix('.zip'));original_raw=parent.get(q['original_profile_member']);assert SHA(original_raw)==q['original_profile_sha256'];original=json.loads(original_raw)
  projection=json.loads(parent.get('COMPILED_PROJECTION_V1.json'));old=ReadView(parent,projection[original['build_root']]['archive_prefix']);assert SHA((old/'BUILD.json').read_bytes())==q['original_BUILD_sha256']
  current,meta=build(pool,q['build_root'],q['actual_BUILD_sha256']);left,right=source_files(old),source_files(current);assert left and left.keys()==right.keys()
  for name,path in left.items():assert path.read_bytes().replace(b'\r\n',b'\n')==right[name].read_bytes().replace(b'\r\n',b'\n')
  oldmeta=read(old/'BUILD.json');assert oldmeta['identity']['original_output']['native_codec']==meta['identity']['original_output']['native_codec'] and 'analytical_snow_models' not in meta['identity']['original_output']
  for field in ('donor_objects','donor_modules','ttutil_modules','ttutil_library','donor_flags','kernel_flags'):assert oldmeta['identity'][field]==meta['identity'][field]
  compiled=compiled_compare(old,current);out.append(dict(label=q['label'],actual_compiler_source=q['current_source'],original_compiler_source=q['original_source'],actual_BUILD_sha256=q['actual_BUILD_sha256'],generated_source_files=len(left),whole_compiled_files=len(compiled['files']),native_codec=q['native_codec'],model_executions=0))
 return out


def audit(platform,optimization,guard_mode=False,legacy_mode=False):
 from types import SimpleNamespace
 a=SimpleNamespace(platform=platform,optimization=optimization,guard=guard_mode,legacy=legacy_mode)
 with ExitStack() as stack:
  pool=Pool(stack)
  if a.platform=='Ubuntu':
   name='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_UBUNTU_'+a.optimization+'_ORIGINAL_V2';store=pool.store(name);prefix='';pool.add('/home/runner/work/_temp/proof',name,'');pool.add('/home/runner/work/_temp/builds',name,'compiled/builds');pool.add('/home/runner/work/_temp/provider/build',name,'original-provider-build');batch=json.loads(store.get('BATCH.json'))
  else:
   name='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_WINDOWS_POSITIVE505_RAW_V1';store=pool.store(name);locations=json.loads(store.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json'))
   for path,entry in locations.items():pool.add(path,entry['archive'],entry['prefix'])
   entry=next(item for item in store.record['batches'] if item['optimization']==a.optimization);batch=json.loads(store.get(entry['path']))
  assert batch['source']==batch['actual_completion_head']=='505954d2943b3f7f478efbb617c53f53dc5f5126' and batch['status'].startswith('ALL6_') and len(batch['contexts'])==6
  out=[]
  if a.legacy:
   assert a.platform=='Windows';out=legacy(pool,store,a.optimization);status='ALL4_CENTRAL_CURRENT_MODEL1_UNAFFECTED_SOURCE_WHOLE_COMPILED_AND_NATIVE_FORMAT_PRESERVATION_PASS'
  elif a.guard:
   if a.platform=='Ubuntu':
    guard_name='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_GUARD_UBUNTU_'+a.optimization+'_ORIGINAL_V1';guard_store=pool.store(guard_name);pool.add('/home/runner/work/_temp/guard-proof',guard_name,'');pool.add('/home/runner/work/_temp/guard-builds',guard_name,'compiled/guard-builds');current_batch=json.loads(guard_store.get('BATCH.json'))
   else:
    guard_name='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_CURRENT_GUARD_WINDOWS_RAW_V1';guard_store=pool.store(guard_name)
    for path,entry in json.loads(guard_store.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')).items():pool.add(path,entry['archive'],entry['prefix'])
    entry=next(item for item in guard_store.record['batches'] if item['optimization']==a.optimization);current_batch=json.loads(guard_store.get(entry['path']))
   assert current_batch['source']==current_batch['actual_completion_head']=='134760c0583a5eb31bdcaf1af0f5f2c4386c15fa' and current_batch['status'].startswith('ALL6_CURRENT_NO_VAPOR') and len(current_batch['contexts'])==6
   for item in current_batch['contexts']:
    original=next(old for old in batch['contexts'] if (old['model'],old['kind'])==(item['model'],item['kind']));result=guard(pool,item,original);out.append(result)
   status='ALL6_CURRENT_NO_VAPOR_NATIVE_PRECONDITION_CENTRAL_SOURCE_COMPILED_PHYSICAL_NATIVE_EXACT_COLD_AND_REFUSALS_PASS_NOT_ADMITTED'
  else:
   for item in batch['contexts']:
    result=positive(pool,item);out.append(result)
   status='ALL6_ORIGINAL_ANALYTICAL_SNOW_CENTRAL_INDEPENDENT_POSITIVE_SOURCE_NATIVE_COLD_CURRENT_INITIAL2_ORIGINAL_TTUTIL_PASS_NOT_ADMITTED'
  record=dict(status=status,platform=a.platform,optimization=a.optimization,contexts=out,compiler_executions=0,model_executions=0,original_producers_retained=True,original_checkpoint_bindings_rewritten=False,canonical_admission=False)
  return record


def main():
 p=argparse.ArgumentParser();p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--guard',action='store_true');p.add_argument('--legacy',action='store_true');a=p.parse_args()
 record=audit(a.platform,a.optimization,a.guard,a.legacy)
 with a.output.open('x') as stream:json.dump(record,stream,indent=2)
 print(record['status'],a.platform,a.optimization,flush=True)


if __name__=='__main__':main()

