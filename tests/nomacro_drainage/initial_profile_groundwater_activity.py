"""Read actual scanning, Snow and nonzero transported inventories, without runs."""
import argparse,io,json,math,struct,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from initial_profile_groundwater_source_inverse import complete_inverse,blob,norm
from analytical_hydraulic_archives import SHA
from experimental_project import switches
from output_hysteresis_baseline import history
from initial_profile_frost_science import frost_history
FROST='84e815a0ba9f59a2d56fe838a3b13361ad8670a2'


def end_history(raw,snow,mode):
 records=[];offset=0
 while offset<len(raw):
  size=struct.unpack_from('<i',raw,offset)[0];assert 0<=size<=len(raw)-offset-8 and struct.unpack_from('<i',raw,offset+size+4)[0]==size
  records.append(raw[offset+4:offset+4+size]);offset+=size+8
 values=iter(records);take=lambda fmt:struct.unpack('<'+fmt,next(values));integer=lambda:take('i')[0]
 assert integer()==1 and integer()==0;nodes=integer();assert nodes==34
 h=list(take(str(nodes)+'d'));pond=take('d')[0];assert integer()==snow;snow_state=[take('d')[0],take('d')[0]] if snow else []
 assert all(math.isfinite(v) and v>=0 for v in snow_state)
 evaporation=integer();assert evaporation in (0,1,2)
 for _ in range(evaporation):take('d')
 assert integer()==mode and mode in (1,2);index=list(take(str(nodes)+'i'));assert all(v in (-1,1) for v in index)
 arrays=[list(take(str(nodes)+'d')) for _ in range(3)];assert all(math.isfinite(v) for v in (*h,pond,*[v for a in arrays for v in a]))
 return dict(nodes=nodes,mode=mode,index=index,delp=arrays[0],fhyst=arrays[1],hm1=arrays[2],h=h,pond=pond),snow_state


def audit(profile,inputs,reference):
 complete_inverse()
 for path in ('tests/nomacro_scheduled_subsurface/output_hysteresis_baseline.py','tests/nomacro_drainage/initial_profile_frost_science.py'):assert norm((ROOT/path).read_bytes())==blob(FROST,path)
 source=(ROOT/'reference/swap-4.3.1/source-archives/SWAP.ZIP').read_bytes();assert SHA(source)=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
 with zipfile.ZipFile(io.BytesIO(source)) as z:writer=z.read('SWAP/swapoutput.f90')
 assert norm((reference/'build/swap-selected/swapoutput.f90').read_bytes())==norm(writer)
 q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_PRESSURE_GROUNDWATER_PHYSICAL_NATIVE_EXACT_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 text=(inputs/'swap.swp').read_text(encoding='cp1252');s=switches(text);rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==35;active=False;observed=[]
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  if not s['SWHYST']:continue
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:raw=z.read('result.end')
  actual,snow=end_history(raw,s['SWSNOW'],s['SWHYST']);assert actual['h']==rows[day-1]['pressure_head_cm']
  if not s['SWSNOW']:assert actual==history(raw)
  elif s['SWHYST']==2:
   previous=frost_history(raw,q['kind'])
   for key in ('index','delp','fhyst','hm1'):assert actual[key]==list(previous[key])
   assert snow==list(previous['actual_Snow_state'])
  scanning=any(v!=(1 if s['SWHYST']==1 else -1) for v in actual['index']) or any(v!=1. for v in actual['fhyst']);active|=scanning
  observed.append(dict(day=day,scanning_or_reversal=scanning,history=actual,actual_Snow_state=snow))
 if s['SWHYST']:assert active and {x['day'] for x in observed}=={2,4,19,23,30,34,35},'No actual initial-pressure groundwater scanning/reversal observed'
 snow_max=max(row['stock_end_cm'][2] for row in rows)
 if s['SWSNOW']:assert snow_max>0,'Selected Snow interaction never had positive Snow'
 chemical=max(row['solute_end_mg_cm2'] for row in rows) if q['kind']=='cde' else None
 if q['kind']=='cde':assert chemical>0,'CDE interaction never transported positive inventory'
 initial_age=None
 if q['kind']=='age':
  stdout=(profile/'trajectory/original/donor.stdout').read_text();initial=next(list(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('HYBRID_AGE_CUMULATIVE '))
  limit=8192*2.**-52*max(1.,*map(abs,initial[:3]));assert abs(initial[0]-100.*rows[0]['stock_start_cm'][0])<=limit and initial[1]==0 and initial[0]>0
  initial_age=dict(actual_soil_moment_cm_day=initial[0],soil_water_cm=rows[0]['stock_start_cm'][0],expected_uniform_soil_AGE_days=100,pond_moment_cm_day=initial[1])
 return dict(status='ACTUAL_PRESSURE_GROUNDWATER_ACTIVE_HISTORY_SNOW_AND_TRANSPORT_INVENTORIES_PASS',producer=q['source'],case=q['case'],optimization=q['optimization'],actual_hysteresis_scanning_or_reversal=active,history_checkpoints=observed,maximum_Snow_stock_cm=snow_max,maximum_CDE_stock_mg_cm2=chemical,original_AGE_initialization=initial_age,original_complete_writer_sha256=SHA(norm(writer)),compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for name in ('profile','input','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.input,a.reference_work)
 with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
 print(q['status'],q['case'],q['optimization'])
