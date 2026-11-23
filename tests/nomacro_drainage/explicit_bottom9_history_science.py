"""Read actual paired9 hydraulic histories, raw native state and ledgers."""
import argparse,hashlib,json,math,re,struct,sys,zipfile
from datetime import date
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from explicit_bottom9_source_inverse import git,blob,norm
from analytical_hydraulic_archives import SHA
from initial_profile_groundwater_science import ledger
from implicit_conductivity_forensics import output_calendar,original_observations
from initial_pressure_profile_science import initialized_heads
from output_hysteresis_baseline import history
from original_output_files import compare

PARENT='46eef99fbd6e5343c1cf7661ae5188549d555990'
CORE='cc33a863437ca3cf34cade7d6f2aba9c32729f22'
HYSTERESIS_SHA='e6f5e4744e0a393a9e890abc0aaedaead91fe0128d84c9a7f8864b381c4c2fb8'


def native(wire,meta,row,selected,dz):
 n=meta['project']['nodes'];chemical=selected['kind']=='cde'
 assert wire[:8]==(b'S5IHC001' if chemical else b'S5IHW001')
 nodes,clock,step,canopy=struct.unpack_from('<i3d',wire,8)
 epoch=(date.fromisoformat(meta['project']['start_date'])-date(1900,1,1)).days+1
 assert nodes==n and clock==epoch+row['day'] and math.isfinite(step) and 0<step<=1 and canopy==row['stock_end_cm'][3] and canopy>=0
 domain=struct.pack('<7i',2,n,0,selected['swhyst'],int(chemical),selected['swdra'],9)
 assert wire.count(domain+domain)==1,'Foreign actual paired history domain/witness'
 at=wire.index(domain+domain)
 calendar=output_calendar(wire,n,row,selected,meta['project']['start_date'],chemical)
 assert calendar['calendar_offset']==at+56,'Paired history/calendar overlap or gap'
 # The existing unmodified donor serializes the actual accepted hydraulic
 # vector. Locate its complete receipt-bound pressure prefix unambiguously;
 # read the complete 5*n+4 payload and check every field and the node stock.
 prefix=struct.pack('<'+str(n)+'d',*row['pressure_head_cm'])
 assert wire[:at].count(prefix)==1,'Actual hydraulic receipt prefix missing or ambiguous'
 offset=wire.index(prefix);end=offset+8*(5*n+4)
 assert 48<=offset<end<=at
 state=struct.unpack_from('<'+str(5*n+4)+'d',wire,offset)
 assert all(map(math.isfinite,state)) and min(state[n:5*n+2])>=0 and state[-1]>=0
 assert list(state[:n])==row['pressure_head_cm'] and state[-2]==row['groundwater_cm'] and state[-1]==row['stock_end_cm'][0]
 assert len(dz)==n and abs(math.fsum(a*b for a,b in zip(state[n:2*n],dz))-state[-1])<=1e-10
 return dict(actual_domain_offset=at,hydraulic_state_offset=offset,calendar_offset=at+56,actual_native_bytes=len(wire),all_hydraulic_values=list(state))


def checkpoint(path,meta,row,selected,dz):
 with zipfile.ZipFile(path) as z:
  assert set(z.namelist())=={'checkpoint.json','result.end','macro.bin'}
  q=json.loads(z.read('checkpoint.json'));assert q['schema']=='swap5-hybrid-water-checkpoint-3' and q['binding']==meta['binding'] and q['receipt']==row
  assert set(q['files'])=={'result.end','macro.bin'}
  for name,digest in q['files'].items():assert SHA(z.read(name))==digest
  end=history(z.read('result.end'));assert end['mode']==selected['swhyst'] and end['nodes']==len(dz)
  assert end['h']==row['pressure_head_cm'] and end['pond']==row['stock_end_cm'][1]
  assert all(v in (-1,1) for v in end['index']) and all(math.isfinite(v) for name in ('delp','fhyst','hm1') for v in end[name])
  return dict(day=row['day'],native=native(z.read('macro.bin'),meta,row,selected,dz),actual_original_scanning_history=end)


def audit(profile,reference):
 for name in ['initial_profile_groundwater_science.py','initial_pressure_profile_science.py']:
  path='tests/nomacro_drainage/'+name;assert norm((ROOT/path).read_bytes())==blob(PARENT,path)
 for name in ['implicit_conductivity_forensics.py','output_hysteresis_baseline.py']:
  path='tests/nomacro_scheduled_subsurface/'+name;assert norm((ROOT/path).read_bytes())==blob(PARENT,path)
 q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_EXPLICIT9_HYSTERESIS_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS_NOT_ADMITTED'
 assert q['days']==35 and len(q['cold'])==3 and not git('diff',CORE,q['source'],'--','app','src','tools','reference')
 inputs=Path(q['input_root']);build=Path(q['build_root']);meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity']
 assert SHA((build/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']==q['trajectory']['build_sha256']
 assert q['build']['actual_completion_head']==q['source'] and q['build']['returncode']==0
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 assert SHA(norm((reference/'build/swap-selected/hysteresis.f90').read_bytes()))==HYSTERESIS_SHA
 for role,digest in meta['executable_sha256'].items():
  paths=[p for p in (build/('day_'+role),build/('day_'+role+'.exe')) if p.is_file()];assert len(paths)==1 and SHA(paths[0].read_bytes())==digest
 text=(inputs/'swap.swp').read_text(encoding='cp1252')
 def one(key):
  rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([+-]?[0-9]+)[ \t]*(?:!.*)?$',text);assert len(rows)==1
  return int(rows[0])
 assert one('SWBOTB')==9 and one('SWHYST')==q['hysteresis'] and one('SWHYST') in (1,2) and one('SWSNOW')==one('SWKIMPL')==one('SWFROST')==one('SWMACRO')==0
 assert one('SWSOLU')==int(q['kind']=='cde') and one('SWINCO')==1
 selected=dict(identity['original_output'],swdra=one('SWDRA'));assert selected['paired_boundary']==9 and selected['domain_version']==2 and selected['domain_bytes']==56
 assert SHA(norm((build/'original_output_hysteresis_domain.f90').read_bytes()))==selected['domain_source_sha256']
 heads,initial=initialized_heads(text)
 grid=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert grid;dz=[]
 for line in grid[1].splitlines():
  _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==35
 stdout=(profile/'trajectory/original/donor.stdout').read_text();actual=next(list(map(float,line.split()[3:])) for line in stdout.splitlines() if line.startswith('HYBRID_HYDRAULIC '));assert actual==heads
 measured=ledger(rows,q['kind'],stdout);original_observations(stdout.encode(),rows,meta['project']['start_date'])
 samples=[]
 for day in (2,4,19,23,30,34,35):samples.append(checkpoint(profile/'trajectory'/('accepted-column-1-day-'+str(day)+'.zip'),meta,rows[day-1],selected,dz))
 cold=[]
 for low,high in ((2,4),(19,23),(30,34)):
  out=profile/('own-'+str(low));continuation=[json.loads(line) for line in (out/'daily.jsonl').read_text().splitlines()]
  assert [row['revision'] for row in continuation]==list(range(1,high-low+1))
  physical=lambda values:[{key:value for key,value in row.items() if key!='revision'} for row in values]
  assert physical(continuation)==physical(rows[low:high])
  for day in (high,):
   warm=profile/'trajectory'/('accepted-column-1-day-'+str(day)+'.zip');fresh=out/warm.name
   with zipfile.ZipFile(warm) as a,zipfile.ZipFile(fresh) as b:
    for name in ('result.end','macro.bin'):assert a.read(name)==b.read(name)
  cold.append(compare(profile/'trajectory/original',out/'original',selected,low,high,meta['project']['start_date']))
 return dict(status='ORIGINAL_HISTORY9_LEDGER_SCANNING_WHOLE_NATIVE_COLD_OUTPUT_INDEPENDENT_PASS_NOT_ADMITTED',kind=q['kind'],hysteresis=q['hysteresis'],optimization=q['optimization'],days=35,native_samples=samples,exact_cold_windows=3,cold_original_output=cold,ledgers=measured,actual_compiler_producer=q['source'],canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--profile',type=Path,required=True);p.add_argument('--reference',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.profile,a.reference)
 with a.output.open('x') as f:json.dump(q,f,indent=2)
 print(q['status'],q['kind'],q['hysteresis'],q['optimization'])
