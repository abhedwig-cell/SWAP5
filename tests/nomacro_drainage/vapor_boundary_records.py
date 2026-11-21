"""Independently rebuild native5 attacks and inspect actual archived dispatch."""
import io,json,struct,types,zipfile
from analytical_hydraulic_archives import SHA
from ordinary_pond_verify import git,SURFACES
CORE='9cde60cff60e1a0b2d4a21019e69eefb1007bd8b'


def native(store,role,prefix):
 profile=store.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text());projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));build=store.view(projection[q['build_root']]['archive_prefix']);meta=json.loads((build/'BUILD.json').read_text());v=meta['identity']['hydraulic_vapor'];b=v['boundary_composition'];chemical=q['kind']=='cde'
 controls=json.loads(store.get(prefix+'/RESULT.json'));assert controls['actual_BUILD_sha256']==SHA((build/'BUILD.json').read_bytes()) and controls['status']=='ACTUAL_VAPOR_BOUNDARY_NATIVE5_49_TYPED_REFUSALS_AND_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS'
 assert not git('diff',CORE,controls['source'],'--',*SURFACES)
 checkpoint=(profile/'trajectory/accepted-column-1-day-4.zip').read_bytes();assert SHA(checkpoint)==controls['checkpoint_sha256']
 with zipfile.ZipFile(io.BytesIO(checkpoint)) as z:good=z.read('macro.bin')
 values=[5,meta['project']['nodes'],v['numlay'],0,int(chemical),0,0,0,0,0,1,2,b['drainage'],b['bottom']]+v['models']+[f if m>=8 else 0 for m,f in zip(v['models'],v['SWVAPOR'])];header=struct.pack('<'+str(len(values))+'i',*values);assert good[48:48+2*len(header)]==header+header and good.count(header+header)==1
 attacks={}
 for witness in (False,True):
  for index,value in enumerate(values):
   raw=bytearray(good);struct.pack_into('<i',raw,48+4*index,value+1)
   if not witness:struct.pack_into('<i',raw,48+len(header)+4*index,value+1)
   attacks['vapor'+('-witness-' if witness else '-domain-')+str(index)]=bytes(raw)
 for magic in (b'S5HVW003',b'S5HVC003',b'S5HSW004',b'S5HSC004',b'S5IOW001',b'S5IOC001',b'S5HBW004',b'S5HBC004',b'S5HBW005' if chemical else b'S5HBC005'):attacks[magic.decode()]=magic+good[8:]
 for size in (0,48,48+2*len(header)-1,len(good)-1):attacks['truncated-'+str(size)]=good[:size]
 assert len(attacks)==49 and set(attacks)=={r['label'] for r in controls['refusals']}
 assert store.get(prefix+'/positive/origin/macro.bin')==good and not store.get(prefix+'/positive/original/donor.stderr')
 positive=store.get(prefix+'/positive/original/donor.stdout');assert b'HYBRID_READY' in positive and b'HYBRID_DAY_RETURN' not in positive
 for item in controls['refusals']:
  root=prefix+'/'+item['label'];assert store.get(root+'/origin/macro.bin')==attacks[item['label']]
  stdout=store.get(root+'/original/donor.stdout');stderr=store.get(root+'/original/donor.stderr').decode(errors='replace');assert item['returncode']!=0 and stderr==item['diagnostic'] and b'HYBRID_READY' not in stdout and b'HYBRID_DAY_RETURN' not in stdout
 assert controls['native_control_accepted_model_days']==0 and controls['external_transaction_worker_prepares']==3 and controls['external_transaction_commits']==1 and controls['positive_original_native_startup']
 assert controls['transactions']==dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True)
 return dict(kind=q['kind'],optimization=q['optimization'],drainage=b['drainage'],bottom=b['bottom'],actual_compiled_refusals=49,actual_mutant_bytes_independently_rebuilt=True,native_control_accepted_model_days=0,external_transaction_contexts=1)


def frontend(store):
 from hydraulic_vapor import selection
 from vapor_boundary_composition import selected_context
 from experimental_project import switches
 selected=types.FunctionType(selection.__code__,dict(selection.__globals__,Path=lambda value:value));q=json.loads(store.get('profiles/vapor-boundary-frontend-v1/RESULT.json'));assert len(q['checks'])==55;counts={}
 assert not git('diff',CORE,q['source'],'--',*SURFACES)
 for item in q['checks']:
  path=item['input_root'].replace('\\','/').split('/evidence/',1)[1];folder=store.view('profiles/'+path)
  for name,digest in item['input_inventory']:assert SHA((folder/name).read_bytes())==digest
  try:
   context=switches((folder/'swap.swp').read_text(encoding='cp1252'));actual=selected(folder,context,True)
  except ValueError:assert item['status']=='UNQUALIFIED_COMPOSITION_REFUSED'
  else:
   assert item['status']!='UNQUALIFIED_COMPOSITION_REFUSED'
   if item['status']=='ORIGINAL_REFUSAL_NOW_SELECTED_NATIVE5':assert actual and selected_context(context) is not None and item['codec']==('S5HBC005' if context['SWSOLU'] else 'S5HBW005')
   elif item['status']=='PRIOR_NATIVE_CODEC_PRESERVED':assert actual and selected_context(context) is None and item['codec']==('S5HSW004' if context['SWSNOW'] else 'S5HVW003')
   else:assert item['status']=='HISTORICAL_INACTIVE_VAPOR_PRESERVED' and actual is None
  counts[item['status']]=counts.get(item['status'],0)+1
 assert counts=={'ORIGINAL_REFUSAL_NOW_SELECTED_NATIVE5':24,'PRIOR_NATIVE_CODEC_PRESERVED':2,'HISTORICAL_INACTIVE_VAPOR_PRESERVED':3,'UNQUALIFIED_COMPOSITION_REFUSED':26};return counts


def unselected(store,proof,stack):
 from analytical_hydraulic_archives import Archive
 from vapor_boundary_unselected_postimage import identity_changes
 from calendar_publisher import publisher_equivalence
 from ordinary_pond_verify import blob
 projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));results={}
 for codec in ('native3','native4'):
  prefix='profiles/vapor-boundary-unselected-'+codec+'-O0-v1';q=json.loads(store.get(prefix+'/RESULT.json'));assert q['model_executions']==0
  old_store=Archive(proof,q['archive'],stack);assert old_store.record['sha256']==q['old_archive_sha256'];prior=json.loads(old_store.get(q['old_profile']+'/RESULT.json'));old_projection=json.loads(old_store.get('COMPILED_PROJECTION_V1.json'));old=old_store.view(old_projection[prior['build_root']]['archive_prefix']);new=store.view(projection[q['build_root']]['archive_prefix'])
  before=json.loads((old/'BUILD.json').read_text());actual=json.loads((new/'BUILD.json').read_text());assert prior['source']==q['old_producer'] and SHA(old_store.get(q['old_profile']+'/RESULT.json'))==q['old_RESULT_sha256']
  for field in ('donor_objects','donor_flags','kernel_flags'):assert before['identity'][field]==actual['identity'][field]
  left={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in old.glob('*.f90')};right={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in new.glob('*.f90')};assert left==right
  changes=identity_changes(before['identity'],actual['identity']);expected={'hydraulic_vapor.source_sha256','restart_publisher.library_sha256'}|({'model7_terminal_water.source_sha256','original_output.source_sha256'} if codec=='native3' else {'original_output.ordinary_owner_sha256','cde_native_receipt.source_sha256','cde_native_receipt.optional_native_prefixes.S5HBC005'});assert set(changes)==expected
  sources={'hydraulic_vapor.source_sha256':'app/hybrid_water/hydraulic_vapor.py'}
  if codec=='native3':sources.update({'model7_terminal_water.source_sha256':'app/hybrid_water/model7_terminal_water.py','original_output.source_sha256':'app/hybrid_water/original_output.py'})
  else:sources.update({'original_output.ordinary_owner_sha256':'app/hybrid_water/original_output.py','cde_native_receipt.source_sha256':'app/hybrid_water/cde_native_receipt.py'})
  for field,path in sources.items():
   def value(meta):
    v=meta['identity']
    for part in field.split('.'):v=v[part]
    return v
   assert value(before)==SHA(blob(prior['source'],path)) and value(actual)==SHA(blob(CORE,path))
  exact=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda value:value));pe=exact(old/'restart_publish.dll',new/'restart_publish.dll')
  if codec=='native3':assert q['status'].startswith('ACTUAL_UNSELECTED_NATIVE3_OR_NATIVE4_COMPLETE') and q['identity_changes']==changes and q['publisher_equivalence']==pe
  else:
   assert q['status']=='FAILED' and q['error']=="ValueError('Actual postimage compiler identity keys differ')"
   recovered=json.loads(store.get('observations/VAPOR_BOUNDARY_NATIVE4_UNSELECTED_POSTIMAGE_RECOVERED_V1.json'));assert recovered['original_failed_RESULT_sha256']==SHA(store.get(prefix+'/RESULT.json')) and recovered['actual_BUILD_sha256']==SHA((new/'BUILD.json').read_bytes()) and recovered['identity_changes']==changes and recovered['publisher_equivalence']==pe and recovered['compiler_executions']==recovered['model_executions']==0
  results[codec]=dict(whole_Fortran_provider_flags_exact=True,only_source_and_exact_new5_descriptor_and_PE_identity_changes=changes,publisher_equivalence=pe,original_producer_preserved=True,model_executions=0)
 return results


