"""Independently read original initial heads, ledgers and whole native owners."""
import argparse,io,json,math,re,struct,sys,zipfile
from decimal import Decimal,localcontext
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from initial_profile_groundwater_source_inverse import CORE,complete_inverse,git,blob,norm
from initial_pressure_profile_science import initialized_heads,PROVIDER
from initial_profile_age_ledger import read as age_ledger
from analytical_hydraulic_archives import SHA
from experimental_project import switches
import implicit_conductivity_forensics as original
import groundwater_water_forensics as water
import water_snow_groundwater_forensics as snow_water
import groundwater_interval_forensics as cde
import groundwater_snow_forensics as snow_cde
import groundwater_chemical_verify as daily_cde
import age_groundwater_verify as age
FROST='84e815a0ba9f59a2d56fe838a3b13361ad8670a2'
READERS=('tests/nomacro_scheduled_subsurface/implicit_conductivity_forensics.py','tests/nomacro_scheduled_subsurface/groundwater_water_forensics.py','tests/nomacro_drainage/water_snow_groundwater_forensics.py','tests/nomacro_drainage/groundwater_interval_forensics.py','tests/nomacro_drainage/groundwater_snow_forensics.py','tests/nomacro_scheduled_subsurface/groundwater_chemical_verify.py','tests/nomacro_scheduled_subsurface/age_groundwater_verify.py')


def native(raw,row,meta,s,dz):
 selected=meta['identity']['original_output'];n=meta['project']['nodes'];kind=s['SWSOLU']
 if kind==0:
  if s['SWSNOW']:detail=list(snow_water.native(raw,row,meta,s,dz))
  else:detail=water.native(raw,row,meta,selected,dz,s['SWKIMPL'])
 elif kind==2:detail=age.native(raw,row,n,selected,meta['project']['start_date'],dz)
 elif s['SWSNOW']:detail=snow_cde.native(raw,row,meta,selected)
 elif selected.get('groundwater_cde_interval') or selected.get('groundwater_cde_clock'):detail=cde.native(raw,row,meta,selected)
 else:
  daily_cde.native(raw,row,n,'S5GWC001');detail=original.output_calendar(raw,n,row,selected,meta['project']['start_date'],True)
 return dict(day=row['day'],actual_native_codec=raw[:8].decode(),literal_frozen_native_observer=True,details=detail)


def ledger(rows,kind,stdout):
 D=lambda value:Decimal.from_float(float(value));maximum=Decimal(0);prefix=Decimal(0);chemical=Decimal(0);cprefix=Decimal(0);flow=[Decimal(0)]*16;chem=[Decimal(0)]*6;previous=None
 with localcontext() as context:
  context.prec=100
  for day,row in enumerate(rows,1):
   assert row['day']==day and row['committed'] is True and len(row['stock_start_cm'])==len(row['stock_end_cm'])==6 and len(row['external_flux_cm'])==16
   assert all(math.isfinite(value) for value in (*row['stock_start_cm'],*row['stock_end_cm'],*row['external_flux_cm'],*row['pressure_head_cm']))
   if previous is not None:assert previous==row['stock_start_cm']
   previous=row['stock_end_cm'];start,end=list(map(D,row['stock_start_cm'])),list(map(D,row['stock_end_cm']));actual=list(map(D,row['external_flux_cm']));residual=sum(start)-sum(end)+sum(actual[:7])-sum(actual[7:]);maximum=max(maximum,abs(residual))
   assert max(abs(residual),*(abs(D(row[field])) for field in ('kernel_residual_cm','independent_residual_cm','integrated_guard_residual_cm')))<=D(1e-10)
   flow=[a+b for a,b in zip(flow,actual)];prefix=max(prefix,abs(sum(map(D,rows[0]['stock_start_cm']))-sum(end)+sum(flow[:7])-sum(flow[7:])))
   if kind=='cde':
    values=list(map(D,row['solute_ledger_mg_cm2']));a,b=D(row['solute_start_mg_cm2']),D(row['solute_end_mg_cm2']);residual=b-a-sum(values[2:5])+sum(values[5:8]);chemical=max(chemical,abs(residual));assert abs(residual)<=D(1e-10)
    chem=[x+y for x,y in zip(chem,values[2:8])];residual=b-D(rows[0]['solute_start_mg_cm2'])-sum(chem[:3])+sum(chem[3:]);cprefix=max(cprefix,abs(residual));assert abs(residual)<=D(1e-10)
 result=dict(water_daily_max_decimal=str(maximum),additional_water_every_prefix_max_decimal=str(prefix),additional_absolute_global_water_prefix_is_owning_gate=False,CDE_daily_max_decimal=str(chemical),CDE_every_prefix_max_decimal=str(cprefix),water_and_CDE_absolute_limit=1e-10)
 if kind=='age':
  initial=next(tuple(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('HYBRID_AGE_CUMULATIVE '));result['AGE']=age_ledger(rows,initial)
 return result


def audit(profile,reference,locations=None):
 complete_inverse()
 for path in READERS:assert norm((ROOT/path).read_bytes())==blob(FROST,path),'Changed literal admitted native observer'
 q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_PRESSURE_GROUNDWATER_PHYSICAL_NATIVE_EXACT_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' and q['days']==35 and len(q['cold'])==3 and not git('diff',CORE,q['source'],'--','app','src','tools/solute','tools/vq','reference')
 inputs=locations['inputs'] if locations else Path(q['input_root']);build=locations['build'] if locations else Path(q['build_root']);meta=json.loads((build/'BUILD.json').read_text());assert SHA((build/'BUILD.json').read_bytes())==q['trajectory']['build_sha256'];identity=meta['identity'];text=(inputs/'swap.swp').read_text(encoding='cp1252');s=switches(text);assert s['SWINCO']==s['SWBOTB']==1 and s['SWMACRO']==s['SWFROST']==s['SWSOPHY']==0 and ('water','cde','age')[s['SWSOLU']]==q['kind']
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 for name,digest in PROVIDER.items():assert SHA(norm((reference/('build/swap-selected/'+name)).read_bytes()))==digest
 for field in ('donor_flags','kernel_flags'):assert '-'+q['optimization'] in identity[field] and '-ffp-contract=off' in identity[field]
 for role,digest in meta['executable_sha256'].items():
  paths=[p for p in (build/('day_'+role),build/('day_'+role+'.exe')) if p.is_file()];assert len(paths)==1 and SHA(paths[0].read_bytes())==digest
 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==35;stdout=(profile/'trajectory/original/donor.stdout').read_text();heads,initial=initialized_heads(text);actual=next(list(map(float,line.split()[3:])) for line in stdout.splitlines() if line.startswith('HYBRID_HYDRAULIC '));assert len(actual)==34 and actual==heads
 grid=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert grid;dz=[]
 for line in grid[1].splitlines():
  _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
 # switches() intentionally returns SW* switches, while the frozen Snow
 # observer also consumes the actual non-SW NPRINTDAY input. Read that
 # integer directly from the byte-inventoried descriptor, without changing
 # any model input, metadata, codec or native value.
 printdays=re.findall(r'(?mi)^[ \t]*NPRINTDAY[ \t]*=[ \t]*([+-]?[0-9]+)[ \t]*(?:!.*)?$',text);assert len(printdays)==1;s={**s,'NPRINTDAY':int(printdays[0])}
 measured=ledger(rows,q['kind'],stdout);original.original_observations(stdout.encode(),rows,meta['project']['start_date']);samples=[]
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
   saved=json.loads(z.read('checkpoint.json'));assert saved['binding']==meta['binding'] and saved['receipt']==rows[day-1]
   for name,digest in saved['files'].items():assert SHA(z.read(name))==digest
   original.sequential_records(z.read('result.end'));raw=z.read('macro.bin');assert raw[:8].decode()==q['native_codec'];samples.append(native(raw,rows[day-1],meta,s,dz))
 assert {sample['day'] for sample in samples}=={2,4,19,23,30,34,35}
 fields=('stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm','groundwater_cm','drainage_outward_cm','bottom_outward_cm')
 if q['kind']=='cde':fields+=('solute_start_mg_cm2','solute_end_mg_cm2','solute_ledger_mg_cm2')
 if q['kind']=='age':fields+=('age_state_cm_day','age_start_cm_day','age_end_cm_day','age_ledger_cm_day','age_effluent')
 for cold in q['cold']:
  start,end=cold['start'],cold['end'];directory=profile/('own-'+str(start));actual=[json.loads(line) for line in (directory/'daily.jsonl').read_text().splitlines()];assert len(actual)==end-start
  for a,b in zip(actual,rows[start:end]):assert all(a[field]==b[field] for field in fields)
  with zipfile.ZipFile(io.BytesIO((profile/f'trajectory/accepted-column-1-day-{end}.zip').read_bytes())) as warm,zipfile.ZipFile(io.BytesIO((directory/f'accepted-column-1-day-{end}.zip').read_bytes())) as own:
   for name in ('macro.bin','result.end'):assert warm.read(name)==own.read(name)
  assert all(value['exact'] for value in cold['exact_user_output'].values()) and cold['origin_unchanged'] is True
 return dict(status='INDEPENDENT_ORIGINAL_PRESSURE_GROUNDWATER_HEADS_FIXED_LEDGERS_LITERAL_NATIVE_EXACT_COLD_PASS',producer=q['source'],case=q['case'],kind=q['kind'],optimization=q['optimization'],actual_days=35,exact_initial_pressure_nodes=34,original_initial_profile=initial,measured_ledgers=measured,native_checkpoints=sorted(samples,key=lambda value:value['day']),exact_cold_windows=3,compiler_executions=0,model_executions=0,canonical_admission=False,whole_compiled_initial2_postimages_still_required=True)


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work)
 with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
 print(q['status'],q['case'],q['optimization'])
