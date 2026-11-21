"""Read actual original pressure/AGE sources, moments, complete native and cold bytes."""
import argparse,ast,hashlib,io,json,math,re,struct,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from initial_profile_age_source_inverse import BASE,CORE,complete_inverse,git,blob,norm
from initial_profile_age_ledger import read as ledger
from initial_pressure_profile_science import initialized_heads,PROVIDER
from analytical_hydraulic_archives import SHA
from experimental_project import switches
import implicit_conductivity_forensics as calendar


def native(raw,row,meta,dz):
 n=meta['project']['nodes'];assert raw[:8]==b'S5IOA001' and struct.unpack_from('<i',raw,8)[0]==n
 clock,step,canopy=struct.unpack_from('<3d',raw,12);selected=meta['identity']['original_output'];assert clock==selected['original_output_epoch']+row['day'] and 0<step<=1 and canopy>=0 and all(map(math.isfinite,(clock,step,canopy)))
 positions=[];offset=0;marker=struct.pack('<2i',1,n)
 while (offset:=raw.find(marker,offset))>=0:
  if offset+160<=len(raw):
   h=struct.unpack_from('<20i',raw,offset)
   if raw[offset:offset+80]==raw[offset+80:offset+160] and 0<=h[2]<=5 and h[3]==6068+10*n+(3*n+3)*h[2]:positions.append((offset,h))
  offset+=1
 assert len(positions)==1;at,h=positions[0];end=at+160+16*h[3];levels=h[2];doubles=3*n+41+levels;age_bytes=8*doubles+20;assert end+age_bytes==len(raw)
 # Execute every frozen common-calendar numerical assertion on the full
 # original stream. Adapt exactly its water-only EOF equality to the
 # independently decoded existing AGE tail; no byte/value/codec projection.
 path='tests/nomacro_scheduled_subsurface/implicit_conductivity_forensics.py';source=blob(BASE,path);assert norm((ROOT/path).read_bytes())==source
 function=next(node for node in ast.parse(source).body if isinstance(node,ast.FunctionDef) and node.name=='output_calendar')
 class AgeEOF(ast.NodeTransformer):
  count=0
  def visit_Compare(self,node):
   if ast.unparse(node)=='end == len(raw)':self.count+=1;return ast.copy_location(ast.parse('end + AGE_BYTES == len(raw)',mode='eval').body,node)
   return self.generic_visit(node)
 change=AgeEOF();function=change.visit(function);assert change.count==1
 namespace=dict(vars(calendar),AGE_BYTES=age_bytes);exec(compile(ast.fix_missing_locations(ast.Module(body=[function],type_ignores=[])),path,'exec'),namespace);common=namespace['output_calendar'](raw,n,row,selected,meta['project']['start_date'],False);assert common['calendar_end']==end
 values=struct.unpack_from('<'+str(doubles)+'d',raw,end);assert all(map(math.isfinite,values));bulk,ages,output=values[:n],values[n:2*n],values[2*n:3*n];assert min(*bulk,*ages,*output)>=0
 index=3*n;stock,pondage,previouspondage=values[index:index+3];index+=3;parameters=values[index:index+3];index+=3;cumulative=values[index:index+8];index+=8
 assert parameters==(0.,0.,0.) and min(stock,pondage,previouspondage)>=0 and list(cumulative)==row['age_state_cm_day'][3:]
 index+=5+levels+3;water=values[index:index+8];index+=8;amount=values[index:index+8];index+=8;totals=values[index:index+3];index+=3;assert index==doubles
 assert list(totals)==row['age_state_cm_day'][:3] and stock==row['age_state_cm_day'][1] and list(water)==row['age_effluent'][:8] and list(amount)==row['age_effluent'][8:16] and min(*water,*amount)>=0
 limit=8192*2.**-52*max(1.,*map(abs,totals));assert len(dz)==n and all(0<=value<=1e12/height for value,height in zip(bulk,dz))
 assert abs(math.fsum(value*height for value,height in zip(bulk,dz))-totals[0])<=limit and abs(row['stock_end_cm'][1]*previouspondage-stock)<=limit
 day,period,cumulative_reset,interval_reset=struct.unpack_from('<idii',raw,end+8*doubles);assert day==row['day'] and period==struct.unpack_from('<d',raw,end-8)[0] and cumulative_reset in (0,1) and interval_reset in (0,1)
 return dict(day=day,actual_native_codec='S5IOA001',calendar_header=common['calendar_header'],existing_private_AGE_tail_bytes=age_bytes,exact_private_amount_moment_effluent_state=True,complete_EOF_checked=True)


def audit(profile,reference,locations=None):
 complete_inverse();q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_PRESSURE_AGE_EXISTING_NATIVE_EXACT_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED' and q['days']==35 and len(q['cold'])==3 and not git('diff',CORE,q['source'],'--','app','src','tools/solute','tools/vq','reference')
 inputs=locations['inputs'] if locations else Path(q['input_root']);build=locations['build'] if locations else Path(q['build_root']);meta=json.loads((build/'BUILD.json').read_text());assert SHA((build/'BUILD.json').read_bytes())==q['trajectory']['build_sha256'];identity=meta['identity'];text=(inputs/'swap.swp').read_text(encoding='cp1252');s=switches(text)
 assert s['SWINCO']==1 and s['SWSOLU']==2 and s['SWKIMPL']==s['SWFROST']==s['SWSNOW']==s['SWHYST']==0 and identity['original_output']['native_codec']=='S5IOA001'
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 for name,digest in PROVIDER.items():assert SHA(norm((reference/('build/swap-selected/'+name)).read_bytes()))==digest
 for field in ('donor_flags','kernel_flags'):assert '-'+q['optimization'] in identity[field] and '-ffp-contract=off' in identity[field]
 for role,digest in meta['executable_sha256'].items():
  paths=[path for path in (build/('day_'+role),build/('day_'+role+'.exe')) if path.is_file()];assert len(paths)==1 and SHA(paths[0].read_bytes())==digest
 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==35;stdout=(profile/'trajectory/original/donor.stdout').read_text();initial=next(tuple(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('HYBRID_AGE_CUMULATIVE '));result=ledger(rows,initial)
 heads,details=initialized_heads(text);actual=next(list(map(float,line.split()[3:])) for line in stdout.splitlines() if line.startswith('HYBRID_HYDRAULIC '));assert len(actual)==34 and actual==heads
 assert abs(initial[0]-100.*rows[0]['stock_start_cm'][0])<=8192*2.**-52*max(1.,*initial[:3]) and initial[1]==0
 grid=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert grid;dz=[]
 for line in grid[1].splitlines():
  _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
 samples=[]
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
   saved=json.loads(z.read('checkpoint.json'));assert saved['binding']==meta['binding'] and saved['receipt']==rows[day-1]
   for name,digest in saved['files'].items():assert SHA(z.read(name))==digest
   calendar.sequential_records(z.read('result.end'));samples.append(native(z.read('macro.bin'),rows[day-1],meta,dz))
 assert {sample['day'] for sample in samples}=={2,4,19,23,30,34,35}
 fields=('stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm','groundwater_cm','drainage_outward_cm','bottom_outward_cm','age_state_cm_day','age_start_cm_day','age_end_cm_day','age_ledger_cm_day','age_effluent')
 for cold in q['cold']:
  start,end=cold['start'],cold['end'];directory=profile/('own-'+str(start));actual=[json.loads(line) for line in (directory/'daily.jsonl').read_text().splitlines()];assert len(actual)==end-start
  for a,b in zip(actual,rows[start:end]):assert all(a[field]==b[field] for field in fields)
  with zipfile.ZipFile(io.BytesIO((profile/f'trajectory/accepted-column-1-day-{end}.zip').read_bytes())) as warm,zipfile.ZipFile(io.BytesIO((directory/f'accepted-column-1-day-{end}.zip').read_bytes())) as own:
   for name in ('macro.bin','result.end'):assert warm.read(name)==own.read(name)
  assert all(value['exact'] for value in cold['exact_user_output'].values()) and cold['origin_unchanged'] is True
 result.update(status='INDEPENDENT_ORIGINAL_PRESSURE_AGE_FIXED_WATER_AMOUNT_MOMENT_NATIVE_EXACT_COLD_PASS',producer=q['source'],case=q['case'],optimization=q['optimization'],exact_initial_pressure_nodes=34,original_initial_profile=details,initial_soil_AGE_days=100,initial_AGE_state=list(initial),native_checkpoints=sorted(samples,key=lambda value:value['day']),exact_cold_windows=3,compiler_executions=0,model_executions=0,canonical_admission=False,whole_compiled_initial2_postimages_still_required=True)
 return result


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work)
 with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
 print(q['status'],q['case'],q['optimization'])
