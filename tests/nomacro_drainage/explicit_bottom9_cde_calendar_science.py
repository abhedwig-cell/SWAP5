"""Independent CDE9 calendar science; actual state, unchanged equations and cold bytes."""
import argparse,ast,io,json,math,re,struct,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from explicit_bottom9_source_inverse import BASE,CORE,complete_inverse,blob,norm,git,producer_epoch,PRE_CLOCK,CLOCK_ONLY,CDE_CORE
from analytical_hydraulic_archives import SHA
from initial_profile_groundwater_science import ledger
from initial_profile_age_science import native as age_native
from initial_pressure_profile_science import initialized_heads,PROVIDER
from implicit_conductivity_forensics import output_calendar,original_observations,general_checkpoint
from analytical_calendar_native_state import decode,terminal_terms
from original_output_files import compare as compare_outputs
from initial_profile_calendar_postimage import compare as compare_postimage
import prescribed_head_flux_boundary as boundary

from explicit_bottom9_cde_calendar_inputs import CASES


def calendar_sources(build,reference,selected):
 assert selected['paired_head_flux_cde_calendar'] and selected['cde_interval_output']
 clock=selected.get('cde_clock_output',False)
 import cde_clock_output,cde_interval_output
 original=(reference/'build/swap-selected/integral.f90').read_text(encoding='cp1252')
 watstor=(reference/'build/swap-selected/watstor.f90').read_text(encoding='cp1252')
 if clock:expected=boundary.render_output_trial(cde_clock_output.render_integral(original,watstor,selected),original,watstor)
 else:expected=cde_interval_output.render_integral(original,selected)
 assert (build/'integral.f90').read_text(encoding='cp1252')==expected
 head=(build/'headcalc.f90').read_text(encoding='cp1252')
 if clock:
  for anchor in ('   use MOD_integral,only:hybrid_output_trial_residual\n','\n         if(abs(hybrid_output_trial_residual())>1d-10)flnonconv=.true.'):
   assert head.count(anchor)==1;head=head.replace(anchor,'',1)
 assert SHA(head.encode())=='155dd85c118026439cd837e5b7f2178c9cae99a536b3c5e27b9e751912ebe80c','Whole unchanged prescribed9 HeadCalc differs'
 # Fixed actual old daily postimage 1a769b... plus the unchanged original
 # CDE interval instrumenter yields this complete source postimage. This checks
 # every line, including the original transport equations and six RHS owners.
 assert SHA((build/'solute.f90').read_text(encoding='cp1252').encode())=='769d70ef719465578723da7ef15e588d8d50283ec9cb612b5285c30c9a1d553e'
 for generated,path in [('original_cde_output_state.f90','cde_interval_output_state.f90'),('cde_interval_receipt.f90','cde_interval_receipt.f90')]:
  assert norm((build/generated).read_bytes())==blob(BASE,'app/hybrid_water/'+path)
 assert norm((ROOT/'app/hybrid_water/cde_interval_source.py').read_bytes())==blob(BASE,'app/hybrid_water/cde_interval_source.py')
 time=(reference/'build/swap-selected/timecontrol.f90').read_text(encoding='cp1252')
 if clock:
  # Evaluate only the unchanged, pure TimeControl construction in the frozen
  # admitted CDE owner. Captured writes go to memory; no model or files execute.
  raw=blob(BASE,'app/hybrid_water/cde_clock_output.py');tree=ast.parse(raw)
  fn=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='apply_build')
  starts=[i for i,n in enumerate(fn.body) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='original_time' for t in n.targets)]
  ends=[i for i,n in enumerate(fn.body) if isinstance(n,ast.Expr) and ast.unparse(n).startswith("(output / 'timecontrol.f90').write_text(")]
  assert len(starts)==len(ends)==1 and starts[0]<ends[0]
  class Capture:
   def __init__(self):self.values={}
   def __truediv__(self,name):assert name=='timecontrol.f90';return self
   def write_text(self,value,encoding):assert encoding=='cp1252' and not self.values;self.values['time']=value
  class Provider:
   def __truediv__(self,name):
    assert name=='swap-selected/timecontrol.f90';return reference/('build/'+name)
  output=Capture();namespace=dict(vars(cde_clock_output),donor_build=Provider(),output=output,selected=selected,is_snow=False)
  fragment=ast.Module(body=fn.body[starts[0]:ends[0]+1],type_ignores=[])
  exec(compile(ast.fix_missing_locations(fragment),'<frozen-pure-CDE-timecontrol>','exec'),namespace)
  time=output.values['time']
 assert (build/'timecontrol.f90').read_text(encoding='cp1252')==boundary.render_timecontrol(time)
 return dict(whole_HeadCalc_unchanged_except_original28term_prescribed_flux_trial=clock,whole_solute_original_equations_and_existing_interval_instrumentation_exact=True,whole_integral_and_timecontrol_exact=True,private_state_and_daily_flux_receipt_exact_frozen_parent=True,new_state_or_codec=False)


def audit(profile,reference,postimage,locations=None):
 complete_inverse();q=json.loads((profile/'RESULT.json').read_text());kind=q['kind'];assert kind=='cde' and q['case'] in CASES;distributed=q['case']=='cde-distributed-subdaily'
 assert q['status']=='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_PHYSICAL_NATIVE_EXACT_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' and len(q['cold'])==3
 epoch=producer_epoch(q['source']);assert epoch=='cde-calendar'
 readers=('tests/nomacro_scheduled_subsurface/cde_interval_runtime.py','tests/nomacro_drainage/initial_state_composition_science.py','tests/nomacro_drainage/initial_profile_groundwater_science.py','tests/nomacro_drainage/initial_profile_age_science.py','tests/nomacro_drainage/initial_profile_age_ledger.py','tests/nomacro_drainage/initial_pressure_profile_science.py','tests/nomacro_drainage/analytical_calendar_native_state.py','tests/nomacro_scheduled_subsurface/implicit_conductivity_forensics.py','tests/nomacro_scheduled_subsurface/original_output_files.py')
 for name in readers:assert norm((ROOT/name).read_bytes())==blob(BASE,name),name
 inputs=locations['inputs'] if locations else Path(q['input_root']);build=locations['build'] if locations else Path(q['build_root']);meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];assert SHA((build/'BUILD.json').read_bytes())==q['trajectory']['build_sha256']
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 for name,digest in PROVIDER.items():assert SHA(norm((reference/'build/swap-selected'/name).read_bytes()))==digest
 for key in ('donor_flags','kernel_flags'):assert '-'+q['optimization'] in identity[key] and '-ffp-contract=off' in identity[key]
 for role,digest in meta['executable_sha256'].items():
  paths=[p for p in (build/('day_'+role),build/('day_'+role+'.exe')) if p.is_file()];assert len(paths)==1 and SHA(paths[0].read_bytes())==digest
 lower=identity['lower_boundary_receipt'];assert lower['policy']==boundary.POLICY and lower['prescribed_external_flux_unchanged'] and lower['all_actual_node_storage_included'] and not lower['groundwater_reaction_substituted']
 assert (build/'hybrid_step_budget.f90').read_text(encoding='cp1252')==boundary.render_budget((ROOT/'app/hybrid_water/hybrid_step_budget.f90').read_text(encoding='cp1252'),9)
 selected=identity['original_output'];source_proof=calendar_sources(build,reference,selected);source_epoch=CDE_CORE
 for field,path in ((identity['host'],'app/hybrid_water/daily_host.py'),(identity['lower_boundary_receipt']['source_sha256'],'app/hybrid_water/prescribed_head_flux_boundary.py')):
  raw=blob(source_epoch,path);assert field in {SHA(raw),SHA(raw.replace(b'\n',b'\r\n'))},'Actual producer raw SOURCE digest differs from its complete committed epoch'

 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==35
 stdout=(profile/'trajectory/original/donor.stdout').read_text();measured=ledger(rows,kind,stdout)
 from cde_interval_runtime import audit_daily
 daily_observed=audit_daily(profile/'trajectory',35,34);
 original_observations(stdout.encode(),rows,meta['project']['start_date'])
 text=(inputs/'swap.swp').read_text(encoding='cp1252')
 if distributed:
  from initial_state_composition_science import initial_heads
  heads,initial=initial_heads(text,2)
 else:heads,initial=initialized_heads(text)
 actual=next(list(map(float,line.split()[3:])) for line in stdout.splitlines() if line.startswith('HYBRID_HYDRAULIC '));assert len(actual)==34 and actual==heads
 grid=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert grid;dz=[]
 for line in grid[1].splitlines():
  _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
 assert len(dz)==34
 if kind=='cde':
  assert rows[0]['solute_start_mg_cm2']>0 and sum(-row['solute_ledger_mg_cm2'][4] for row in rows)>0
 elif kind=='age':
  initial_age=next(tuple(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('HYBRID_AGE_CUMULATIVE '));assert abs(initial_age[0]-100*rows[0]['stock_start_cm'][0])<=8192*2.**-52*max(1.,*initial_age[:3]) and initial_age[1]==0
  assert sum(sum(row['age_effluent'][8:16]) for row in rows)>0
 if distributed:
  continuity=[]
  drain=(inputs/'swap.dra').read_text(encoding='cp1252')
  assert re.search(r'(?m)^\s*SWDIVD\s*=\s*1\b',drain) and re.search(r'(?m)^\s*DRAMET\s*=\s*1\b',drain)
  assert all(re.search(r'(?m)^\s*'+key+r'\s*=\s*0\b',drain) for key in ('SWDISLAY','SWDIVDINF','SWTOPNRSRF'))
  assert re.search(r'(?m)^\s*LM1\s*=\s*30\.0\b',drain) and re.search(r'(?m)^\s*COFANI\s*=\s*1\.0\s+1\.0\b',drain)
  assert sum(dz)==200.
  archive=reference/'distribution/SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP';assert SHA(archive.read_bytes())=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
  with zipfile.ZipFile(io.BytesIO(archive.read_bytes())) as source_zip:
   for name in ('MOD_drainage.f90','drainage.f90','divdra.f90'):
    keys=[key for key in source_zip.namelist() if key.replace('\\','/').rsplit('/',1)[-1].lower()==name.lower()];assert len(keys)==1
    assert norm((reference/'build/swap-selected'/name).read_bytes())==norm(source_zip.read(keys[0])),name
  module=(reference/'build/swap-selected/MOD_drainage.f90').read_text(encoding='cp1252')
  assert re.search(r'(?mi)^.*::[ \t]*swnrsrf[ \t]*=[ \t]*0[ \t]*!',module) and re.search(r'(?mi)^.*::[ \t]*nrlevs[ \t]*=[ \t]*1[ \t]*!',module)
  assert not re.search(r'(?m)^[ \t]*SWNRSRF[ \t]*=',drain)
 
  for row in rows:
   assert row['stock_start_cm'][0]==row['stock_end_cm'][0]==rows[0]['stock_start_cm'][0]
   h=row['pressure_head_cm'];pond=row['stock_end_cm'][1];assert min(h)>=0 and h[-1]==0 and .5<pond<10 and row['groundwater_cm']==pond
   actual=row['external_flux_cm'];assert abs(actual[0]-1.01)<=1e-10 and abs(actual[-1]-1.)<=1e-10 and abs(actual[13]-.01)<=1e-10
   assert max(abs(v) for i,v in enumerate(actual) if i not in (0,13,15))==0
   assert abs(row['drainage_outward_cm']-.01)<=1e-10 and abs(row['bottom_outward_cm']-1.)<=1e-10
   lateral=[.01*height/200 for height in dz]
   faces=[-((pond-h[0])/(.5*dz[0])+1.)]+[-((h[i-1]-h[i])/(.5*(dz[i-1]+dz[i]))+1.) for i in range(1,34)]+[-1.]
   residual=[faces[i+1]-faces[i]-lateral[i] for i in range(34)]
   assert max(map(abs,residual))<=1e-10 and abs(faces[0]+1.01)<=1e-10
   continuity.append(dict(day=row['day'],independent_final_state_Darcy_sink_node_residual_cm_per_day_max=max(map(abs,residual)),last_node_residual_cm_per_day=residual[-1],actual_positive_lateral_cm=row['drainage_outward_cm']))
  if kind=='cde':assert sum(row['solute_ledger_mg_cm2'][5] for row in rows)>0
 else:
  for row in rows:
   assert row['stock_start_cm']==row['stock_end_cm']==rows[0]['stock_start_cm'] and row['pressure_head_cm']==[0.]*34 and row['stock_end_cm'][1]==0
   assert abs(row['external_flux_cm'][0]-1.)<=1e-10 and abs(row['external_flux_cm'][-1]-1.)<=1e-10 and max(map(abs,row['external_flux_cm'][1:-1]))==0
 native=[]
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.stem.split('-')[-1]);row=rows[day-1]
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
   assert set(z.namelist())=={'checkpoint.json','result.end','macro.bin'};saved=json.loads(z.read('checkpoint.json'));assert saved['binding']==meta['binding'] and saved['receipt']==row and set(saved['files'])=={'macro.bin','result.end'}
   for name,digest in saved['files'].items():assert SHA(z.read(name))==digest
   raw=z.read('macro.bin');assert raw[:8]==q['native_codec'].encode()
   if kind=='water':observed=general_checkpoint(path.read_bytes(),meta,row,{**identity['original_output'],'swhyst':0},dz)
   elif kind=='age':observed=age_native(raw,row,meta,dz)
   else:
    assert raw[:8] in (b'S5CIC001',b'S5CCC001')
    magic,nn,clock,dt,canopy,t,year=struct.unpack_from('<8si4di',raw)
    from datetime import date
    assert nn==34 and clock==(date.fromisoformat(meta['project']['start_date'])-date(1900,1,1)).days+1+day and 0<dt<=1 and canopy==row['stock_end_cm'][3] and math.isfinite(t) and 1<=year<=9999
    observed=output_calendar(raw,34,row,identity['original_output'],meta['project']['start_date'],True)
    stock=struct.unpack_from('<36d',raw,48);assert all(math.isfinite(v) and v>=0 for v in stock) and stock[-1]==row['solute_end_mg_cm2']
   state,header=decode(raw,(build/'integral.f90').read_text(encoding='cp1252'),34);terms=terminal_terms(state,row['stock_end_cm']);assert abs(sum(terms))<=1e-10
   end=z.read('result.end');records=[];offset=0
   while offset<len(end):
    size=struct.unpack_from('<i',end,offset)[0];assert 0<=size<=len(end)-offset-8 and struct.unpack_from('<i',end,offset+4+size)[0]==size;records.append(end[offset+4:offset+4+size]);offset+=size+8
   assert offset==len(end) and records[:3]==[struct.pack('<i',v) for v in (1,0,34)] and list(struct.unpack('<34d',records[3]))==row['pressure_head_cm'] and struct.unpack('<d',records[4])[0]==row['stock_end_cm'][1]
  native.append(dict(day=day,registered_transport_observer=observed,calendar_header=list(header),calendar_28term_residual_cm=sum(terms),actual_END_pressure_exact=True))
 assert {item['day'] for item in native}=={2,4,19,23,30,34,35}
 fields=('stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm','groundwater_cm','drainage_outward_cm','bottom_outward_cm')+ (('solute_start_mg_cm2','solute_end_mg_cm2','solute_ledger_mg_cm2') if kind=='cde' else ('age_state_cm_day','age_start_cm_day','age_end_cm_day','age_ledger_cm_day','age_effluent') if kind=='age' else ())
 cold=[]
 for item in q['cold']:
  start,end=item['start'],item['end'];directory=profile/('own-'+str(start));own=[json.loads(line) for line in (directory/'daily.jsonl').read_text().splitlines()];assert len(own)==end-start
  for a,b in zip(own,rows[start:end]):assert all(a[field]==b[field] for field in fields)
  with zipfile.ZipFile(io.BytesIO((profile/f'trajectory/accepted-column-1-day-{end}.zip').read_bytes())) as warm,zipfile.ZipFile(io.BytesIO((directory/f'accepted-column-1-day-{end}.zip').read_bytes())) as restarted:
   for name in ('macro.bin','result.end'):assert warm.read(name)==restarted.read(name)
  daily_cold=audit_daily(directory,end-start,34)
  outputs=compare_outputs(profile/'trajectory/original',directory/'original',identity['original_output'],start,end,meta['project']['start_date']);assert outputs==item['exact_user_output'];cold.append(dict(start=start,end=end,complete_native_byte_exact=True,physical_exact=True,actual_user_output=outputs,actual_daily_CDE=daily_cold))
 if distributed:
  post=json.loads((postimage/'RESULT.json').read_text());assert post['status']=='ACTUAL_INITIAL1_BUILD_ONLY_COUNTERPART_OF_INITIAL2_DISTRIBUTED_DRAIN_REFERENCE_COMPILED_POSTIMAGE_PASS' and (post['reference_profile']==locations['original_profile_path'] if locations else Path(post['reference_profile'])==profile) and post['reference_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes()) and post['model_executions']==0 and post['reference_initial_selector']==2 and post['counterpart_initial_selector']==1
  counter=locations['counter'] if locations else Path(post['build_root']);counter_inputs=locations['counter_inputs'] if locations else Path(post['input_root']);compiled=compare_postimage(counter,build);assert compiled==post['existing_compiled_Fortran_provider_ABI_observer']
  from explicit_bottom9_compiled_postimage import compare as compare_binary
  whole=compare_binary(counter,build);assert whole==post['actual_complete_compiled_bytes']
 else:
  post=json.loads((postimage/'RESULT.json').read_text());assert post['status']=='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_INITIAL2_WHOLE_COMPILED_POSTIMAGE_NATIVE_ABI_PASS_NO_MODEL_REPLAY' and (post['initial1_profile']==locations['original_profile_path'] if locations else Path(post['initial1_profile'])==profile) and post['initial1_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes()) and post['model_executions']==0
  counter=locations['counter'] if locations else Path(post['build_root']);counter_inputs=locations['counter_inputs'] if locations else Path(post['input_root']);compiled=compare_postimage(counter,build);assert compiled==post['postimage']
 from original_output_baseline import assignment
 for name,digest in post['input_inventory']:assert SHA((counter_inputs/name).read_bytes())==digest
 assert assignment((counter_inputs/'swap.swp').read_bytes().decode('cp1252'),'SWINCO',2 if distributed else 1).encode('cp1252')==(inputs/'swap.swp').read_bytes()
 for name,digest in q['input_inventory']:
  if name!='swap.swp':assert (counter_inputs/name).read_bytes()==(inputs/name).read_bytes()
 from explicit_bottom9_compiled_postimage import compare as compare_binary
 whole=compare_binary(counter,build) if distributed else compare_binary(build,counter)
 return dict(status='INDEPENDENT_EXPLICIT9_CDE_CALENDAR_DAILY_LEDGERS_PRIVATE_NATIVE_EOF_EXACT_COLD_WHOLE_COMPILED_PASS_NOT_ADMITTED',source_conformance=source_proof,actual_daily_CDE=daily_observed,distributed_drainage=distributed,all_node_Darcy_sink=continuity if distributed else [],whole_compiled_binary=whole,producer=q['source'],case=q['case'],optimization=q['optimization'],actual_days=35,initial_pressure=initial,measured=measured,native=sorted(native,key=lambda item:item['day']),cold=cold,whole_compiled_postimage=compiled,compiler_executions=0,model_executions=0,canonical_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','postimage','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work,a.postimage)
 with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
 print(q['status'],q['case'],q['optimization'])
