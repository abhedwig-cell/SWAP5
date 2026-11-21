"""Independently read actual Frost archive bytes and whole compiled postimages."""
import argparse,io,json,math,struct,sys,zipfile
from contextlib import ExitStack
from decimal import Decimal,localcontext
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import Archive,SHA
from initial_profile_frost_source_inverse import complete_inverse,CORE,git
from initial_profile_frost_science import frost_history
from initial_pressure_profile_science import initialized_heads,PROVIDER
from initial_profile_calendar_postimage import compare
from frost_cde_drainage_model_forensics import audit as explicit
from implicit_frost_science import frozen_model
from experimental_project import switches


def audit(store,role,projection,reference):
 profile=store.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text());expected=role['science'];inputs=store.view(role['inputs']);item=projection[q['build_root']];build=store.view(item['archive_prefix'])
 assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
 assert q['phase']=='short' and len(q['own'])==3 and 'PASS_NOT_ADMITTED' in q['status'] and not git('diff',CORE,q['source'],'--','app','src','tools/solute','tools/vq','reference')
 text=(inputs/'swap.swp').read_text(encoding='cp1252');s=switches(text);assert s['SWINCO']==s['SWFROST']==s['SWSNOW']==1 and s['SWHYST']==2 and s['SWKIMPL'] in (0,1)
 locations=dict(bundle=build,inputs=inputs,warm=profile/'trajectory',cold=lambda day:profile/('own-'+str(day)))
 result=(frozen_model() if s['SWKIMPL'] else explicit)(profile,reference,locations=locations)
 for key,value in result.items():
  if key!='status':assert expected[key]==value,('Original scientific observation differs',key)
 for name,digest in PROVIDER.items():assert SHA((reference/('build/swap-selected/'+name)).read_bytes().replace(b'\r\n',b'\n'))==digest
 original=(ROOT/'reference/swap-4.3.1/source-archives/SWAP.ZIP').read_bytes();assert SHA(original)=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
 with zipfile.ZipFile(io.BytesIO(original)) as z:writer=z.read('SWAP/swapoutput.f90')
 assert (reference/'build/swap-selected/swapoutput.f90').read_bytes().replace(b'\r\n',b'\n')==writer.replace(b'\r\n',b'\n')
 warm=profile/'trajectory';stdout=(warm/'original/donor.stdout').read_text();heads,initial=initialized_heads(text)
 actual=next(list(map(float,line.split()[3:])) for line in stdout.splitlines() if line.startswith('HYBRID_HYDRAULIC '));assert len(actual)==34 and actual==heads and initial==expected['original_initial_profile']
 meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];codec=('S5FIC002' if q['kind']=='cde' else 'S5FIW002') if s['SWKIMPL'] else ('S5FDC001' if q['kind']=='cde' else 'S5FDW001');checkpoints=[];scanning=False;rates={}
 if s['SWKIMPL']:
  assert identity['implicit_conductivity']['implicit_frost_composition'] is True and identity['implicit_conductivity']['examined_ksat_interpolation'] is False
  from implicit_frost_surface_conductivity import restore
  from implicit_frost_source_guard import TERMINAL_PARTS,EXPLICIT_FROST_TIME
  from lower_boundary_receipt import render_headcalc
  from ordinary_pond_source_guard import HEADS
  source=restore((build/'headcalc.f90').read_text(encoding='cp1252'))
  for part in TERMINAL_PARTS:assert source.count(part)==1;source=source.replace(part,'',1)
  assert SHA(render_headcalc(source,8).encode('cp1252'))==HEADS['water']
  from groundwater_snow_retry import inverse,TIME_TEMPLATE
  from implicit_conductivity_retry import time_source
  from implicit_pond_event import time_source as event
  source=inverse((build/'timecontrol.f90').read_text(encoding='cp1252'),lambda value:event(time_source(value)),TIME_TEMPLATE);assert SHA(source.encode('cp1252'))==EXPLICIT_FROST_TIME
  from ordinary_implicit_pond_switch import actual_source
  actual_source((build/'boundtop.f90').read_bytes(),True)
  for line in stdout.splitlines():
   if line.startswith('HYBRID_FROST_ROOT_NATIVE '):
    clock,a,b=map(float,line.split()[1:]);rates.setdefault(clock,set()).add((a,b))
  rows=[json.loads(line,parse_float=Decimal) for line in (warm/'daily.jsonl').read_text().splitlines()]
  with localcontext() as context:
   context.prec=80;accumulated=[Decimal(0)]*len(rows[0]['external_flux_cm']);maximum=Decimal(0)
   for row in rows:
    accumulated=[a+b for a,b in zip(accumulated,row['external_flux_cm'])];residual=sum(rows[0]['stock_start_cm'])-sum(row['stock_end_cm'])+sum(accumulated[:7])-sum(accumulated[7:]);maximum=max(maximum,abs(residual))
  assert str(maximum)==expected['water_prefix_max_decimal'] and expected['absolute_global_water_prefix_is_owning_acceptance_gate'] is False
 for path in warm.glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:native=z.read('macro.bin');history=frost_history(z.read('result.end'),q['kind'])
  assert native[:8].decode()==codec;scanning|=any(value!=-1 for value in history['index']) or any(value!=1.0 for value in history['fhyst'])
  if s['SWKIMPL']:
   header=struct.unpack('<16i',native[-96:-32]);values=struct.unpack('<4d',native[-32:]);assert list(header[:8])==list(header[8:])==[4,34,int(q['kind']=='cde'),1,2,6,1,0]
   assert values[:2]==values[2:] and all(map(math.isfinite,values)) and rates.get(identity['original_output']['original_output_epoch']+day)=={values[:2]}
  checkpoints.append(dict(day=day,actual_native_codec=codec,actual_history_mode=2))
 assert scanning and sorted(checkpoints,key=lambda row:row['day'])==expected['native_checkpoints'] and len(checkpoints)==7
 return dict(status='CENTRAL_ACTUAL_ORIGINAL_PRESSURE_FROST_FIXED_MASS_HEADS_HISTORY_NATIVE_AND_SOURCE_PASS',literal_frozen_science=result,exact_initial_pressure_nodes=34,original_initial_profile=initial,native_checkpoints=checkpoints,actual_private_root_native_samples=7 if s['SWKIMPL'] else 0,global_water_prefix_diagnostic_only=bool(s['SWKIMPL']),compiler_executions=0,model_executions=0)


def read(proof,names):
 complete_inverse();observations=[];postimages=[]
 with ExitStack() as stack:
  provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
  for name in names:
   store=Archive(proof,name,stack);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));portable='UBUNTU' in name
   class Reference:
    def __truediv__(self,key):
     assert key.startswith('build/');return (store if portable else provider).view('original-provider-build/'+key[6:])
   for role in store.record['roles']:observations.append(dict(archive=name,profile=role['profile'],science=audit(store,role,projection,Reference())))
   for prefix in store.record['postimages']:
    q=json.loads(store.get(prefix+'/RESULT.json'));assert q['status']=='ACTUAL_ORIGINAL_PRESSURE_FROST_INITIAL2_WHOLE_COMPILED_POSTIMAGE_AND_NATIVE_ABI_PASS_NO_MODEL_REPLAY' and not git('diff',CORE,q['source'],'--','app','src','tools/solute','tools/vq','reference')
    prior=projection[q['initial1_build_root']];baseline=projection[q['build_root']]
    for item in (prior,baseline):assert SHA(store.get(item['archive_prefix']+'/BUILD.json'))==item['actual_BUILD_sha256']
    result=compare(store.view(baseline['archive_prefix']),store.view(prior['archive_prefix']));assert result==q['postimage'];postimages.append(dict(archive=name,profile=prefix,postimage=result))
 return dict(status='CENTRAL_ORIGINAL_PRESSURE_FROST_SCIENCE_AND_WHOLE_COMPILED_POSTIMAGES_PASS',contexts=len(observations),exact_cold_windows=3*len(observations),native_checkpoints=7*len(observations),compiler_postimages=len(postimages),observations=observations,postimages=postimages,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--names',nargs='+',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=read(a.proof,a.names)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],q['contexts'],q['compiler_postimages'])
