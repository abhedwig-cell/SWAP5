"""Independent original last-node water drainage with unchanged all-node equations."""
import argparse,io,json,math,re,struct,sys,zipfile
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

def audit(profile,reference,postimage,locations=None):
 complete_inverse();q=json.loads((profile/'RESULT.json').read_text());kind=q['kind'];assert kind=='water' and q['case']=='water-last-node-drainage'
 assert q['status']=='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_PHYSICAL_NATIVE_EXACT_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' and len(q['cold'])==3
 epoch=producer_epoch(q['source']);assert epoch in ('last-node-admission','cde-calendar')
 readers=('tests/nomacro_drainage/initial_profile_groundwater_science.py','tests/nomacro_drainage/initial_profile_age_science.py','tests/nomacro_drainage/initial_profile_age_ledger.py','tests/nomacro_drainage/initial_pressure_profile_science.py','tests/nomacro_drainage/analytical_calendar_native_state.py','tests/nomacro_scheduled_subsurface/implicit_conductivity_forensics.py','tests/nomacro_scheduled_subsurface/original_output_files.py')
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
 time_source=(reference/'build/swap-selected/timecontrol.f90').read_text(encoding='cp1252')
 selected=identity['original_output']
 assert selected['nprintday']==1 and selected['flprintdt'] is False and selected['swmonth']==selected['swodat']==0 and selected['requested_period']==1
 if selected['nprintday']>1 or selected['flprintdt']:
  assert epoch in ('composed-clock','cde-calendar')
  from age_output_clock import render_timecontrol
  time_source=render_timecontrol(time_source)
  import original_output
  original_integral=(reference/'build/swap-selected/integral.f90').read_text(encoding='cp1252');watstor=(reference/'build/swap-selected/watstor.f90').read_text(encoding='cp1252')
  expected_integral=boundary.render_output_trial(original_output.render_integral(original_integral,watstor,selected),original_integral,watstor)
  assert (build/'integral.f90').read_text(encoding='cp1252')==expected_integral
 assert (build/'timecontrol.f90').read_text(encoding='cp1252')==boundary.render_timecontrol(time_source)
 source_epoch={'pre-clock':PRE_CLOCK,'clock-only':CLOCK_ONLY,'composed-clock':CORE,'cde-calendar':CDE_CORE,'last-node-admission':CORE}[epoch]
 for field,path in ((identity['host'],'app/hybrid_water/daily_host.py'),(identity['lower_boundary_receipt']['source_sha256'],'app/hybrid_water/prescribed_head_flux_boundary.py')):
  raw=blob(source_epoch,path);assert field in {SHA(raw),SHA(raw.replace(b'\n',b'\r\n'))},'Actual producer raw SOURCE digest differs from its complete committed epoch'

 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==35
 stdout=(profile/'trajectory/original/donor.stdout').read_text();measured=ledger(rows,kind,stdout);original_observations(stdout.encode(),rows,meta['project']['start_date'])
 text=(inputs/'swap.swp').read_text(encoding='cp1252');heads,initial=initialized_heads(text);actual=next(list(map(float,line.split()[3:])) for line in stdout.splitlines() if line.startswith('HYBRID_HYDRAULIC '));assert len(actual)==34 and actual==heads
 grid=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert grid;dz=[]
 for line in grid[1].splitlines():
  _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
 assert len(dz)==34
 hydraulic=re.search(r'(?mis)^[ \t]*ORES[ \t]+OSAT[^\n]*\n(.*?)^[ \t]*\* End of table',text);assert hydraulic
 parameters=[list(map(float,line.split())) for line in hydraulic[1].splitlines() if line.strip() and not line.lstrip().startswith('*')]
 assert len(parameters)==2 and all(len(row)==10 and row[6]==row[7]==1. and row[8]==0 for row in parameters)
 for axis,expected in [('DATE9A[ \t]+HBOT9',1.25),('DATE9B[ \t]+QBOT9',-.75)]:
  table=re.search(r'(?mis)^[ \t]*'+axis+r'[^\n]*\n(.*?)^[ \t]*\* End of table',text);assert table
  actual=[float(line.split()[1]) for line in table[1].splitlines() if line.strip() and not line.lstrip().startswith('*')];assert actual and all(v==expected for v in actual)
 if kind=='cde':
  assert rows[0]['solute_start_mg_cm2']>0 and sum(-row['solute_ledger_mg_cm2'][4] for row in rows)>0
 elif kind=='age':
  initial_age=next(tuple(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('HYBRID_AGE_CUMULATIVE '));assert abs(initial_age[0]-100*rows[0]['stock_start_cm'][0])<=8192*2.**-52*max(1.,*initial_age[:3]) and initial_age[1]==0
  assert sum(sum(row['age_effluent'][8:16]) for row in rows)>0
 continuity=[]
 drain=(inputs/'swap.dra').read_text(encoding='cp1252')
 assert re.search(r'(?m)^\s*SWDIVD\s*=\s*0\b',drain) and re.search(r'(?m)^\s*DRAMET\s*=\s*1\b',drain)
 archive=reference/'distribution/SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP';assert SHA(archive.read_bytes())=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
 with zipfile.ZipFile(io.BytesIO(archive.read_bytes())) as original:
  assert norm((reference/'build/swap-selected/drainage.f90').read_bytes())==norm(original.read('SWAP/drainage.f90'))
 original_drain=(reference/'build/swap-selected/drainage.f90').read_text(encoding='cp1252')
 assert 'qdra(level,numnod) = qdrain(level)' in original_drain and 'swdivd == 0 .AND. swsolu > 0' in original_drain
 with zipfile.ZipFile(io.BytesIO(archive.read_bytes())) as original:
  assert norm((reference/'build/swap-selected/boundbottom.f90').read_bytes())==norm(original.read('SWAP/boundbottom.f90'))
 hydraulic=[list(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('HYBRID_HYDRAULIC ')];assert len(hydraulic)==36
 for row,accepted in zip(rows,hydraulic[1:]):
  assert row['stock_start_cm']==row['stock_end_cm']==rows[0]['stock_start_cm']
  flux=row['external_flux_cm'];h=row['pressure_head_cm'];pond=row['stock_end_cm'][1]
  assert accepted[2:]==h and h[:-1]==[0.]*33 and min(h)>=0
  actual_qbot=accepted[1]
  assert h[-1]==1.25-(actual_qbot+1.)*.5*dz[-1],'Literal original BoundBottom equation differs; actual AFGEN flux is retained'
  assert pond==0 and abs(flux[0]-1.)<=1e-10 and abs(flux[-1]-.75)<=1e-10 and abs(flux[13]-.25)<=1e-10
  assert max(abs(value) for i,value in enumerate(flux) if i not in (0,13,15))==0
  assert abs(row['drainage_outward_cm']-.25)<=1e-10 and abs(row['bottom_outward_cm']-.75)<=1e-10
  faces=[-((pond-h[0])/(.5*dz[0])+1.)]+[-((h[i-1]-h[i])/(.5*(dz[i-1]+dz[i]))+1.) for i in range(1,34)]+[actual_qbot]
  lateral=[0.]*33+[.25];residual=[faces[i+1]-faces[i]-lateral[i] for i in range(34)]
  assert max(map(abs,residual))<=1e-10
  continuity.append(dict(day=row['day'],all_actual_node_Darcy_and_sink_residual_cm_per_day_max=max(map(abs,residual)),last_node_lateral_cm=.25,declared_prescribed_bottom_flux_cm=-.75,actual_original_AFGEN_bottom_flux_cm=actual_qbot,actual_last_pressure_cm=h[-1],literal_original_BoundBottom_pressure_equation_exact=True))
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
    assert raw[:8]==b'S5IOC001';observed=output_calendar(raw,34,row,identity['original_output'],meta['project']['start_date'],True)
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
  outputs=compare_outputs(profile/'trajectory/original',directory/'original',identity['original_output'],start,end,meta['project']['start_date']);assert outputs==item['exact_user_output'];cold.append(dict(start=start,end=end,complete_native_byte_exact=True,physical_exact=True,actual_user_output=outputs))
 post=json.loads((postimage/'RESULT.json').read_text());assert post['status']=='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_INITIAL2_WHOLE_COMPILED_POSTIMAGE_NATIVE_ABI_PASS_NO_MODEL_REPLAY' and (post['initial1_profile']==locations['original_profile_path'] if locations else Path(post['initial1_profile'])==profile) and post['initial1_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes()) and post['model_executions']==0
 counter=locations['counter'] if locations else Path(post['build_root']);counter_inputs=locations['counter_inputs'] if locations else Path(post['input_root']);compiled=compare_postimage(counter,build);assert compiled==post['postimage']
 from original_output_baseline import assignment
 for name,digest in post['input_inventory']:assert SHA((counter_inputs/name).read_bytes())==digest
 assert assignment((counter_inputs/'swap.swp').read_bytes().decode('cp1252'),'SWINCO',1).encode('cp1252')==(inputs/'swap.swp').read_bytes()
 for name,digest in q['input_inventory']:
  if name!='swap.swp':assert (counter_inputs/name).read_bytes()==(inputs/name).read_bytes()
 return dict(status='INDEPENDENT_EXPLICIT9_ORIGINAL_LAST_NODE_DRAINAGE_ALL_NODE_DARCY_LEDGER_NATIVE_COLD_COMPILED_PASS_NOT_ADMITTED',producer=q['source'],case=q['case'],optimization=q['optimization'],actual_days=35,initial_pressure=initial,measured=measured,independent_final_Darcy_sink_continuity=continuity,native=sorted(native,key=lambda item:item['day']),cold=cold,whole_compiled_postimage=compiled,compiler_executions=0,model_executions=0,canonical_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','postimage','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work,a.postimage)
 with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
 print(q['status'],q['case'],q['optimization'])
