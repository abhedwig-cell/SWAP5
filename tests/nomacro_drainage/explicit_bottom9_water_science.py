"""Independently read actual explicit9 controls; never count a deadline refusal."""
import argparse,io,json,re,struct,zipfile
from pathlib import Path
from explicit_bottom9_source_inverse import ROOT,BASE,CORE,complete_inverse,blob,norm,git
from analytical_hydraulic_archives import SHA
from initial_profile_groundwater_science import ledger
from implicit_conductivity_forensics import general_checkpoint,original_observations
from analytical_calendar_native_state import decode,terminal_terms
import prescribed_head_flux_boundary as boundary


def audit(profile,reference):
 complete_inverse();q=json.loads((profile/'RESULT.json').read_text(encoding='utf8'))
 assert not git('diff',CORE,q['source'],'--','app','src','tools/solute','tools/vq','reference')
 for name in ('initial_profile_groundwater_science.py','analytical_calendar_native_state.py'):
  path='tests/nomacro_drainage/'+name;assert norm((ROOT/path).read_bytes())==blob(BASE,path)
 path='tests/nomacro_scheduled_subsurface/implicit_conductivity_forensics.py';assert norm((ROOT/path).read_bytes())==blob(BASE,path)
 inputs=Path(q['input_root']);build=Path(q['build_root']);meta=json.loads((build/'BUILD.json').read_text(encoding='utf8'));identity=meta['identity']
 for name,digest in q['input_inventory'].items():assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 for role,digest in meta['executable_sha256'].items():
  files=[p for p in (build/('day_'+role),build/('day_'+role+'.exe')) if p.is_file()];assert len(files)==1 and SHA(files[0].read_bytes())==digest
 assert identity['lower_boundary_receipt']['policy']==boundary.POLICY and identity['lower_boundary_receipt']['prescribed_external_flux_unchanged'] is True
 assert identity['lower_boundary_receipt']['all_actual_node_storage_included'] is True and identity['lower_boundary_receipt']['groundwater_reaction_substituted'] is False
 assert (build/'hybrid_step_budget.f90').read_text(encoding='cp1252')==boundary.render_budget((ROOT/'app/hybrid_water/hybrid_step_budget.f90').read_text(encoding='cp1252'),9)
 assert (build/'timecontrol.f90').read_text(encoding='cp1252')==boundary.render_timecontrol((reference/'build/swap-selected/timecontrol.f90').read_text(encoding='cp1252'))
 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()]
 if q['case']=='incompatible':
  assert [event['returncode'] for event in q['events']]==[0,1] and not rows
  assert not list((profile/'trajectory').glob('accepted-column-*-day-*.zip'))
  assert 'ERROR STOP Implicit original retry reached clock resolution' in (profile/'trajectory/original/donor.stderr').read_text(encoding='utf8')
  assert q['events'][-1]['seconds']<60 and q['status']!='ACTUAL_WALL_CAP_NOT_A_SCIENTIFIC_REFUSAL'
  return dict(status='ACTUAL_INCOMPATIBLE_PAIRED_FORCING_ORIGINAL_CLOCK_RESOLUTION_REFUSAL_NO_COMMITTED_DAY',producer=q['source'],accepted_days=0,deadline_counted_as_refusal=False,compiler_executions=0,model_executions=0,canonical_admission=False)
 assert [event['returncode'] for event in q['events']]==[0,0] and len(rows)==35 and all(row['committed'] for row in rows)
 text=(inputs/'swap.swp').read_text(encoding='cp1252');grid=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert grid;dz=[]
 for line in grid[1].splitlines():
  _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
 assert len(dz)==meta['project']['nodes']==34
 stdout=(profile/'trajectory/original/donor.stdout').read_text(encoding='utf8');measured=ledger(rows,'water',stdout);original_observations(stdout.encode(),rows,meta['project']['start_date'])
 native=[];selected={**identity['original_output'],'swhyst':0}
 for path in sorted((profile/'trajectory').glob('accepted-column-1-day-*.zip')):
  day=int(path.name.split('-')[-1].split('.')[0]);row=rows[day-1];raw=path.read_bytes();observed=general_checkpoint(raw,meta,row,selected,dz)
  with zipfile.ZipFile(io.BytesIO(raw)) as z:
   state,header=decode(z.read('macro.bin'),(build/'integral.f90').read_text(encoding='cp1252'),34)
   terms=terminal_terms(state,row['stock_end_cm']);assert abs(sum(terms))<=1e-10
   end=z.read('result.end');records=[];offset=0
   while offset<len(end):
    size=struct.unpack_from('<i',end,offset)[0];assert 0<=size<=len(end)-offset-8 and struct.unpack_from('<i',end,offset+4+size)[0]==size;records.append(end[offset+4:offset+4+size]);offset+=size+8
   assert offset==len(end) and records[:3]==[struct.pack('<i',value) for value in (1,0,34)]
   assert list(struct.unpack('<34d',records[3]))==row['pressure_head_cm'] and struct.unpack('<d',records[4])[0]==row['stock_end_cm'][1]
  native.append(dict(day=day,registered_native_observer=observed,complete_original_calendar_header=list(header),independent_calendar_28term_residual_cm=sum(terms),actual_END_pressure_exact=True))
 assert native
 maximum_head=max(abs(value) for row in rows for value in row['pressure_head_cm'])
 if q['case']=='unitgradient':
  for row in rows:
   assert row['stock_start_cm']==row['stock_end_cm']==rows[0]['stock_start_cm']
   assert row['pressure_head_cm'][-1]==0.0 and abs(row['external_flux_cm'][0]-1.)<=1e-10 and abs(row['external_flux_cm'][-1]-1.)<=1e-10
   assert max(map(abs,row['external_flux_cm'][1:-1]))==0.0
 elif q['case']=='hydrostatic':
  assert all(max(map(abs,row['external_flux_cm']))==0.0 and row['stock_start_cm']==row['stock_end_cm'] for row in rows)
 else:raise AssertionError('Unregistered explicit9 water control')
 return dict(status='INDEPENDENT_EXPLICIT9_FIRST_WATER_SOURCE_STOCK_LEDGER_REGISTERED_NATIVE_PASS_NOT_ADMITTED',producer=q['source'],case=q['case'],optimization=q['optimization'],actual_days=35,measured=measured,native=native,maximum_pressure_magnitude_cm_diagnostic_only=maximum_head,compiler_executions=0,model_executions=0,cold_windows_still_required=True,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();result=audit(a.profile,a.reference_work)
 with a.output.open('x',encoding='utf8') as out:json.dump(result,out,indent=2);out.write('\n')
 print(result['status'])
