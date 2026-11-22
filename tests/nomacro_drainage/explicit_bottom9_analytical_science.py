"""Independent nonlinear paired9 reference point, all-node Darcy, ledgers and native cold bytes."""
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
from explicit_bottom9_analytical_source_inverse import ANALYTICAL_CORE,complete_inverse,producer_epoch


def reference_point(model):
 # The source-controlled original component measured all real function calls;
 # this reads those original bytes, not a newly copied constitutive formula.
 import hashlib,subprocess
 assert model in (3,4,5,6,7,8,9,10,11)
 mixed=model==3;name='HYDRAULIC_ANALYTICAL_WINDOWS_CDE_RAW_V1' if mixed else 'HYDRAULIC_MODEL7_PRETERMINAL_RESEARCH_RAW_V1';base='02813169713f103b846ab95657e5c5f830bc77d4';folder='integration/f-ci/nomacro-complete01/'
 manifest=blob(base,folder+name+'.json');q=json.loads(manifest);chunks=[]
 for part in q['parts']:
  raw=git('show',base+':'+folder+part['file']);assert len(raw)==part['bytes'] and SHA(raw)==part['sha256'];chunks.append(raw)
 raw=b''.join(chunks);assert len(raw)==q['bytes'] and SHA(raw)==q['sha256'];observations=[];producers=[]
 with zipfile.ZipFile(io.BytesIO(raw)) as z:
  def member(path):
   value=z.read(path);item=q['members'][path];assert len(value)==item['bytes'] and SHA(value)==item['sha256'];return value
  for opt in ('O0','O2'):
   prefix=('profiles/hydraulic-mixed-layers-original-'+opt+'-v1') if mixed else ('profiles/hydraulic-constitutive-'+('model7-corrected' if model==7 else 'original')+'-'+opt+'-v1')
   result=json.loads(member(prefix+'/RESULT.json'));assert result['status']=='ACTUAL_ORIGINAL_HYDRAULIC_INTERFACES_OBSERVED_NO_ADMISSION';producers.append(result['source'])
   output=member(prefix+'/model'+str(7 if mixed else model)+'.stdout').decode()
   rows=[list(map(float,line.split()[1:])) for line in output.splitlines() if line.startswith('ACTUAL_ORIGINAL_HYDRAULIC ')]
   found=[row[5:] for row in rows if row[1]==model and row[2]==1 and row[5]==-10.] if mixed else [row[3:] for row in rows if row[0]==model and row[1]==1 and row[3]==-10.]
   assert found and all(row==found[0] for row in found);observations.append(found[0])
 assert observations[0]==observations[1]
 return observations[0],dict(original_archive=name,original_archive_sha256=q['sha256'],original_actual_producers=producers,actual_original_O0_O2_values_exact=True,model=model,soil=1,actual_original_values=observations[0],new_component_compilations=0)


def audit(profile,reference,postimage,locations=None):
 complete_inverse();q=json.loads((profile/'RESULT.json').read_text());kind=q['kind'];assert kind in ('water','cde') and q['layer_models'] and len(set(q['layer_models']))==1
 assert q['status']=='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_PHYSICAL_NATIVE_EXACT_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' and len(q['cold'])==3
 epoch=producer_epoch(q['source']);assert epoch=='analytical-paired'
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
 selected=identity['original_output'];assert selected['nprintday']==1 and selected['flprintdt'] is False and selected['swmonth']==selected['swodat']==0 and selected['requested_period']==1
 assert (build/'timecontrol.f90').read_text(encoding='cp1252')==boundary.render_timecontrol((reference/'build/swap-selected/timecontrol.f90').read_text(encoding='cp1252'))
 assert SHA((build/'headcalc.f90').read_text(encoding='cp1252').encode())=='155dd85c118026439cd837e5b7f2178c9cae99a536b3c5e27b9e751912ebe80c'
 source_epoch=ANALYTICAL_CORE
 for field,path in ((identity['host'],'app/hybrid_water/daily_host.py'),(identity['lower_boundary_receipt']['source_sha256'],'app/hybrid_water/prescribed_head_flux_boundary.py')):
  raw=blob(source_epoch,path);assert field in {SHA(raw),SHA(raw.replace(b'\n',b'\r\n'))},'Actual producer raw SOURCE digest differs from its complete committed epoch'

 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==35
 stdout=(profile/'trajectory/original/donor.stdout').read_text();measured=ledger(rows,kind,stdout);original_observations(stdout.encode(),rows,meta['project']['start_date'])
 text=(inputs/'swap.swp').read_text(encoding='cp1252');heads,initial=initialized_heads(text);actual=next(list(map(float,line.split()[3:])) for line in stdout.splitlines() if line.startswith('HYBRID_HYDRAULIC '));assert len(actual)==34 and actual==heads
 grid=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert grid;dz=[]
 for line in grid[1].splitlines():
  _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
 assert len(dz)==34
 if kind=='cde':
  assert rows[0]['solute_start_mg_cm2']>0 and sum(-row['solute_ledger_mg_cm2'][4] for row in rows)>0
 elif kind=='age':
  initial_age=next(tuple(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('HYBRID_AGE_CUMULATIVE '));assert abs(initial_age[0]-100*rows[0]['stock_start_cm'][0])<=8192*2.**-52*max(1.,*initial_age[:3]) and initial_age[1]==0
  assert sum(sum(row['age_effluent'][8:16]) for row in rows)>0
 model=q['layer_models'][0];point,original_point=reference_point(model);head,theta,capacity,conductivity=point[:4]
 assert head==-10. and 0<theta<.433878 and capacity>0 and 0<conductivity<83.24164
 table=re.search(r'(?mis)^[ \t]*ORES[ \t]+OSAT[^\n]*\n(.*?)^[ \t]*\* End of table',text);assert table
 parameters=[list(map(float,line.split())) for line in table[1].splitlines() if line.strip()]
 assert parameters==[[.02,.433878,.021645,.043290,1.348770,7.202077,83.24164,83.24164,-.01,1315.]]*2
 for label,expected in (('HBOT9',head),('QBOT9',-conductivity)):
  table=re.search(r'(?mis)^[ \t]*DATE9[AB][ \t]+'+label+r'[^\n]*\n(.*?)^[ \t]*\* End of table',text);assert table
  values=[float(line.split()[1]) for line in table[1].splitlines() if line.strip()];assert len(values)==2 and values==[expected]*2
 for label,expected in (('ALFA_2',[.005]*2),('NPAR_2',[1.5]*2),('OMEGA_1',[.8]*2),('H0',[-1e6]*2),('HA',[-10.]*2),('APAR',[-1.5]*2),('OMEGA_K',[.01]*2)):
  match=re.findall(r'(?mi)^[ \t]*'+label+r'[ \t]*=[ \t]*([^\r\n!]*)',text);assert len(match)==1 and list(map(float,match[0].split()))==expected
 assert sum(dz)==200.;continuity=[]
 for row in rows:
  # These measured controls use the actual original -10cm reference point.
  # A different pressure requires another original constitutive observation,
  # never an invented exact-zero or replacement mass tolerance.
  h=row['pressure_head_cm'];assert h==[head]*34 and row['stock_end_cm'][1:]==[0.]*5
  assert row['stock_start_cm']==row['stock_end_cm']==rows[0]['stock_start_cm'] and abs(row['stock_end_cm'][0]-theta*sum(dz))<=1e-10
  flux=row['external_flux_cm'];assert abs(flux[0]-conductivity)<=1e-10 and abs(flux[-1]-conductivity)<=1e-10 and max(map(abs,flux[1:-1]))==0
  faces=[-flux[0]]+[-conductivity*((h[i-1]-h[i])/(.5*(dz[i-1]+dz[i]))+1.) for i in range(1,34)]+[-row['bottom_outward_cm']]
  # Flux-top boundary owns the actual negative surface head rather than pond0.
  # The first face is prescribed infiltration; every interior and bottom face
  # is checked against the independent original constitutive K and gradients.
  residual=max(abs(faces[i+1]-faces[i]) for i in range(34));assert residual<=1e-10
  continuity.append(dict(day=row['day'],all_actual_node_Darcy_residual_cm_per_day_max=residual,actual_soil_stock_cm=row['stock_end_cm'][0],independent_original_theta_stock_cm=theta*sum(dz)))
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
 from explicit_bottom9_compiled_postimage import compare as compare_binary
 whole=compare_binary(build,counter)
 return dict(status='INDEPENDENT_NONLINEAR_PAIRED9_ORIGINAL_CONSTITUTIVE_POINT_ALL_NODE_DARCY_MASS_NATIVE_EXACT_COLD_COMPILED_POSTIMAGE_PASS_NOT_ADMITTED',original_constitutive_point=original_point,all_actual_node_Darcy=continuity,nonlinear_hydraulic_capacity_active=capacity>0,unsaturated_retention_active=theta<.433878,whole_actual_compiled_binary=whole,producer=q['source'],case=q['case'],optimization=q['optimization'],actual_days=35,initial_pressure=initial,measured=measured,native=sorted(native,key=lambda item:item['day']),cold=cold,whole_compiled_postimage=compiled,compiler_executions=0,model_executions=0,canonical_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','postimage','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work,a.postimage)
 with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
 print(q['status'],q['case'],q['optimization'])
