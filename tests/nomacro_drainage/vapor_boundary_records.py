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


