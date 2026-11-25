"""Independent original-byte budgets, native frames, cold/output and refusal audit."""
import hashlib,io,json,math,struct,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from explicit_bottom9_archive_science import ReadView
from frost_calendar_state_probe import budgets
from frost_history_state_central import original_history
from original_output_files import compare
from frost_boundary_archive_science import physical

def read(path):return json.loads(path.read_text())
def native(raw,meta,case):
 nodes=meta['project']['nodes'];solute=int(case['kind']=='cde');hys=case['hysteresis']
 magic={('water',0):b'S5BCW001',('cde',0):b'S5BCC001',('water',1):b'S5BCW002',('cde',1):b'S5BCC002'}[(case['kind'],case['implicit'])]
 assert raw[:8]==magic==meta['identity']['original_output']['native_codec'].encode()
 header=struct.pack('<10i',1,nodes,0,solute,hys,1,1,1,1,2);assert raw.count(header+header)==1
 header=struct.pack('<4i',1,nodes,solute,7);assert raw.count(header+header)==1;values=struct.unpack_from('<7d',raw,raw.index(header+header)+32);assert all(math.isfinite(x) and x>=0 for x in values)
 if solute:
  n=20+nodes;header=struct.pack('<3i',2,nodes,n);assert raw.count(header+header)==1
  values=struct.unpack_from('<'+str(2*n)+'d',raw,raw.index(header+header)+24);assert values[:n]==values[n:] and all(map(math.isfinite,values))
 if case['implicit']:
  header=(4,nodes,solute,1,hys,case['bottom'],1,0);assert struct.unpack('<16i',raw[-96:-32])==header+header
  values=struct.unpack('<4d',raw[-32:]);assert values[:2]==values[2:] and all(map(math.isfinite,values))
def checkpoint(path,meta,case,expected,external=False):
 with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
  q=json.loads(z.read('checkpoint.json'));binding=q['binding']
  if external:binding={k:v for k,v in binding.items() if k!='external_daily'}
  assert binding==meta['binding'] and physical(q['receipt'],case['kind'])==physical(expected,case['kind'])
  assert all(SHA(z.read(n))==v for n,v in q['files'].items())
  raw=z.read('macro.bin');native(raw,meta,case);original_history(z.read('result.end'),case['kind'],case['hysteresis'])
  return raw,z.read('result.end')
def controls(folder,warm,data,meta,case,refusal_folder=None):
 q=read(folder/'RESULT.json')
 assert q['status']=='ACTUAL_FROST_CALENDAR_COMPILED_NATIVE_SNOW_CDE_ROOT_AND_TRANSACTIONS_PASS_NOT_ADMITTED' and q['accepted_mutant_model_days']==0
 groups=[('native',q['existing_calendar_thermal_refusals']),('extra-native',q['new_snow_private_and_codec_refusals'])]
 assert len(groups[0][1])==(44 if case['kind']=='cde' else 39) and len(groups[1][1])==(39 if case['kind']=='cde' else 35)
 if case['implicit']:
  assert q['root']['accepted_model_days']==0 and len(q['root']['refusals'])==25;groups.append(('root',q['root']['refusals']))
 good=checkpoint(warm/'accepted-column-1-day-4.zip',meta,case,data[3])[0];count=0;refusal_folder=refusal_folder or folder
 for stem,items in groups:
  for item in items:
   target=refusal_folder/stem/item['attack'];errors=list(target.rglob('donor.stderr'));outputs=list(target.rglob('donor.stdout'))
   assert len(errors)==len(outputs)==1 and b'ERROR STOP' in errors[0].read_bytes(),('Original refusal data location',target.path,len(errors),len(outputs))
   text=outputs[0].read_bytes();assert b'HYBRID_READY' not in text and b'HYBRID_DAY_RETURN' not in text
   assert not list(target.rglob('accepted-*.zip')) and (target/'origin/macro.bin').read_bytes()!=good;count+=1
 transactions=[]
 for stem in ('snow-transactions','frost-calendar-transactions'):
  start=4;actual=[];base=folder/stem/'external'
  for stage in ('trial-1','trial-2',''):
   actual.append(checkpoint(base/stage/f'accepted-column-1-day-{start+1}.zip',meta,case,data[start],True))
  assert actual[0]==actual[1]==actual[2]
  checkpoint(folder/stem/'recovered/trial-1'/f'accepted-column-1-day-{start+2}.zip',meta,case,data[start+1],True)
  if stem=='snow-transactions':assert max(data[start]['stock_start_cm'][2],data[start]['stock_end_cm'][2])>0
  transactions.append(dict(start=start,discard_replay_accept_exact=True,recovered_next_day_exact=True))
 return dict(actual_compiled_refusals=count,accepted_mutant_days=0,actual_refusal_data_location=refusal_folder.path,actual_transaction_data_location=folder.path,transactions=transactions)
def case_audit(store,folder_prefix,build_prefix,provider_store,case,producer,opt,controls_prefix=None,refusals_prefix=None):
 folder=ReadView(store,folder_prefix);profile=folder/'science';q=read(profile/'RESULT.json');warm=profile/'trajectory';build=ReadView(store,build_prefix);meta=read(build/'BUILD.json');identity=meta['identity']
 assert q['status']=='ACTUAL_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED' and q['source']==producer and q['duration_days']==case['days'] and q['kind']==case['kind']
 assert q['trajectory']['build_sha256']==SHA((build/'BUILD.json').read_bytes())
 actual_start=meta['project']['start_date'];assert actual_start==(case['start'] or '2002-01-01')
 for key,digest in meta['inputs'].items():assert SHA((folder/'inputs'/key).read_bytes())==digest
 for n,digest in identity['donor_generated'].items():assert SHA((build/n).read_bytes())==digest
 for n,digest in identity['donor_objects'].items():assert SHA(provider_store.get('original-provider-build/swap-obj/'+n))==digest
 suffix='.exe' if any(x.endswith('/day_donor.exe') for x in store.names) else ''
 for role,digest in meta['executable_sha256'].items():assert SHA((build/('day_'+role+suffix)).read_bytes())==digest
 assert '-'+opt in identity['donor_flags'] and '-'+opt in identity['kernel_flags'] and '-ffp-contract=off' in identity['donor_flags'] and '-ffp-contract=off' in identity['kernel_flags']
 from frost_calendar_terminal_water import source as terminal
 assert (build/'terminal_water_receipt.f90').read_text(encoding='cp1252')==terminal()
 selected=q['selection']
 assert all(selected[k]==case[k] for k in ('kind','bottom','implicit','hysteresis','initial'))
 from experimental_project import switches
 values=switches((folder/'inputs/swap.swp').read_text(encoding='cp1252'))
 assert all(values[k]==v for k,v in dict(SWBOTB=case['bottom'],SWKIMPL=case['implicit'],SWHYST=case['hysteresis'],SWINCO=case['initial']).items())
 if case['bottom']==8:
  from time_event_closure import source as event
  from frost_boundary_convergence import historical_clock_source as plate_timecontrol_source
  parent=provider_store.get('original-provider-build/swap-selected/timecontrol.f90')
  assert (build/'timecontrol.f90').read_bytes().replace(b'\r\n',b'\n')==plate_timecontrol_source(event(parent))
 from frost_boundary_convergence import require_convergence
 require_convergence(profile)
 scientific=budgets(warm,case['kind'],case['days']);assert scientific==q['independent_original_budgets']
 data=[json.loads(line) for line in (warm/'daily.jsonl').read_text().splitlines()]
 windows=[(2,4),(19,23),(30,34)] if case['days']==35 else [(2,case['days'])]
 assert [(x['start'],x['end']) for x in q['own']]==windows
 cuts={case['days']}|{x for pair in windows for x in pair}
 assert {int(p.stem.rsplit('-',1)[1]) for p in warm.glob('accepted-column-1-day-*.zip')}==cuts
 for day in cuts:checkpoint(warm/f'accepted-column-1-day-{day}.zip',meta,case,data[day-1])
 for start,end in windows:
  cold=profile/('own-'+str(start));rows=[json.loads(line) for line in (cold/'daily.jsonl').read_text().splitlines()]
  assert [physical(x,case['kind']) for x in rows]==[physical(x,case['kind']) for x in data[start:end]]
  assert checkpoint(cold/f'accepted-column-1-day-{end}.zip',meta,case,rows[-1])==checkpoint(warm/f'accepted-column-1-day-{end}.zip',meta,case,data[end-1])
  compare(warm/'original',cold/'original',identity['original_output'],start,end,actual_start)
 result=dict(case=case,actual_compiler_source=producer,actual_controller_source=q['actual_controller_source'],compiler=identity['compiler'],optimization=opt,science=scientific,native_samples=len(cuts),exact_cold_windows=len(windows),BUILD_sha256=SHA((build/'BUILD.json').read_bytes()))
 if case['days']==35:result['controls']=controls(ReadView(store,controls_prefix) if controls_prefix else folder/'controls',warm,data,meta,case,ReadView(store,refusals_prefix) if refusals_prefix else None)
 return result

