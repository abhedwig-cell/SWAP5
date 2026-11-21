"""Read actual compiled root refusals through the unchanged original decoder."""
import io,json,struct,types,zipfile
from analytical_hydraulic_archives import SHA
from initial_state_composition_source_inverse import ROOT,BASE,git
import implicit_snow_forensics as parent


def native_controls(store,role,projection,controls):
 path='tests/nomacro_drainage/implicit_snow_forensics.py'
 assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':'+path)
 decode=types.FunctionType(parent.native.__code__,dict(parent.native.__globals__,ROOT_CODECS={**parent.ROOT_CODECS,'S5IRC003':'S5ITC001'}))
 q=json.loads(store.get(role['profile']+'/RESULT.json'));item=projection[q['build_root']];build=json.loads(store.get(item['archive_prefix']+'/BUILD.json'));selected=build['identity']['original_output'];r=json.loads(store.get(controls+'/RESULT.json'))
 assert r['status']=='ACTUAL_COMPILED_DENSE_DAILY_CDE_ROOT_NATIVE3_28_REFUSALS_PASS' and r['expected_compiled_refusals']==len(r['refusals'])==28 and r['accepted_model_days']==0
 assert r['actual_BUILD_sha256']==SHA(store.get(item['archive_prefix']+'/BUILD.json'))
 source=store.get(role['profile']+'/trajectory/accepted-column-1-day-4.zip');assert SHA(source)==r['original_checkpoint_sha256']
 with zipfile.ZipFile(io.BytesIO(source)) as z:good=z.read('macro.bin')
 row=json.loads(store.get(role['profile']+'/trajectory/daily.jsonl').decode().splitlines()[3]);swp=store.get(role['inputs']+'/swap.swp').decode('cp1252');selectors={k:parent.scalar(swp,k) for k in ('SWKIMPL','SWSNOW','SWSOLU','SWHYST','SWBOTB','SWDRA')};decode(good,row,build,selected,selectors)
 expected={'parent-codec','other-water-codec','missing-tail','truncated-tail','extra-tail'}|{'foreign-'+c for c in ('S5IRC001','S5IRC002','S5HSC004')}|{p+str(i) for p in ('domain-','domain-witness-') for i in range(8)}|{p+str(i) for p in ('nan-','value-witness-') for i in range(2)}
 assert {v['attack'] for v in r['refusals']}==expected
 for item in r['refusals']:
  prefix=controls+'/'+item['attack']+'/';bad=store.get(prefix+'origin/macro.bin');assert bad!=good and item['status']=='REFUSED' and item['authority']=='compiled_native'
  try:decode(bad,row,build,selected,selectors)
  except (ValueError,struct.error,UnicodeError):pass
  else:raise AssertionError('Original independent decoder accepted actual malformed root payload')
  names=sorted(n for n in store.names if n.startswith(prefix));stderr='\n'.join(store.get(n).decode('utf8',errors='replace').replace('\r\n','\n') for n in names if n.endswith('/donor.stderr'))
  assert stderr==item['diagnostic'] and 'ERROR STOP' in stderr and not any('/accepted-' in n for n in names)
  assert all('HYBRID_READY' not in store.get(n).decode('utf8',errors='replace') for n in names if n.endswith('/donor.stdout'))
 return dict(status='INDEPENDENT_ACTUAL_ROOT_NATIVE3_ALL28_PAYLOADS_COMPILED_ERRORS_NO_READY_NO_DAYS_PASS',actual_compiled_refusals=28,independent_actual_payload_refusals=28,actual_BUILD_sha256=r['actual_BUILD_sha256'],compiler_executions=0,model_executions=0)


def transactions(store,role,projection,prefix):
 import implicit_snow_recovery_forensics as previous
 path='tests/nomacro_drainage/implicit_snow_recovery_forensics.py'
 assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':'+path)
 q=json.loads(store.get(role['profile']+'/RESULT.json'));entry=projection[q['build_root']];r=json.loads(store.get(prefix+'/RESULT.json'));assert r['status']=='ACTUAL_DENSE_DAILY_CDE_ROOT_NATIVE3_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS' and r['actual_BUILD_sha256']==SHA(store.get(entry['archive_prefix']+'/BUILD.json')) and r['initial_selector']==1
 assert all(r['observations'][k] is True for k in ('discard_no_day_advance','replay_exact','accept_exact','recovered_next_day_exact','origin_unchanged'))
 with zipfile.ZipFile(io.BytesIO(store.get(prefix+'/external/accepted-column-1-day-5.zip'))) as z:published=json.loads(z.read('checkpoint.json'))
 source=published['binding']['external_daily']['source_sha256'];raw=git('show',BASE+':app/hybrid_water/daily_coupling.py');assert source in (SHA(raw),SHA(raw.replace(b'\n',b'\r\n')))
 decode=types.FunctionType(parent.native.__code__,dict(parent.native.__globals__,ROOT_CODECS={**parent.ROOT_CODECS,'S5IRC003':'S5ITC001'}))
 namespace=dict(previous.checkpoint.__globals__,native=decode,zipfile=types.SimpleNamespace(ZipFile=lambda path:zipfile.ZipFile(io.BytesIO(path.read_bytes()))))
 checkpoint=types.FunctionType(previous.checkpoint.__code__,namespace,argdefs=previous.checkpoint.__defaults__)
 namespace=dict(previous.transaction_payloads.__globals__,checkpoint=checkpoint,read=lambda path:json.loads(path.read_text()),digest=lambda path:SHA(path.read_bytes()))
 exact=types.FunctionType(previous.transaction_payloads.__code__,namespace)
 result=exact(store.view(prefix),store.view(role['profile']),store.view(entry['archive_prefix']),store.view(role['inputs']),source)
 result.update(native_codec='S5IRC003',actual_prepared_days=3,actual_committed_days=1,actual_discarded_days=2,compiler_executions=0,model_executions=0)
 return result
