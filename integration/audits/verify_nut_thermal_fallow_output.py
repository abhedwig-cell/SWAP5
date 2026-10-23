"""Accepted-temperature retired/fallow output, source/heat identity and cold preservation."""
from pathlib import Path
import base64,hashlib,io,json,runpy,struct,subprocess,tarfile,zlib
ROOT=Path(__file__).resolve().parents[2]
BASE='f4ef44cb20cfb73ae7a582487790a4eb0292b144'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
PARENT='integration/audits/verify_nut_saved_output.py'
PERF='integration/performance/verify_weather_composed_successor.py'
SELF='integration/audits/verify_nut_thermal_fallow_output.py'
KEY='thermal_fallow_successor_20261022'
COMPOSITION_BASE='53010691c79d3e132914ce372059cf873d88b96d'
RETRY='integration/performance/verify_weather_line_search_successor.py'
GEN='src/adapter/mod_crop_n_saved_generation.f90'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def historical(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))['extended_output_component_20261021'][KEY]
def initial_projection(path=PARENT):
 text=historical(path).decode();condition="'postimages' in json.loads((ROOT/'"+STATUS+"').read_text())['extended_output_component_20261021'].get('"+KEY+"',{})"
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  offset=text.index('\n',text.index('def '+name+'('))+1
  indent=text[offset:offset+len(text[offset:])-len(text[offset:].lstrip(' '))]
  text=text[:offset]+indent+"if "+condition+":return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[offset:]
 return text.encode()
def initial_source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record(reader);require(r['baseline']==BASE,'saved baseline')
 for p,h in {**r['qualified_input_sha256'],**r['postimages']}.items():require(sha(reader(p))==h,'saved postimage '+p)
 require(reader(PARENT)==projection(),'original harvest owner assertions')
 require(reader(PERF)==projection(PERF),'original weather owner assertions')
 current=json.loads(reader(STATUS));current['extended_output_component_20261021'].pop(KEY)
 require(current==json.loads(historical(STATUS)),'unrelated NUT authority')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty saved-output science')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}if changed is None else changed
 require(delta==r['scientific_delta'],'foreign saved-output science')
 require(all(k=='A'or p in [PARENT,PERF,'src/adapter/mod_crop_n_saved_generation.f90'] for p,k in delta.items()),'changed incumbent physical implementation')
 return r
def composition_bytes(p):return subprocess.check_output(['git','show',COMPOSITION_BASE+':'+p],cwd=ROOT)
def projection(path=PARENT):
 if path==PERF:return composition_bytes(PERF)
 text=composition_bytes(path).decode()
 condition="'postimages' in json.loads((ROOT/'"+STATUS+"').read_text())['extended_output_component_20261021'].get('"+KEY+"',{})"
 names=[('source','reader,changed'),('verify',''),('self_test','')]
 if path==RETRY:names.append(('fsi35_successors',''))
 for name,args in names:
  offset=text.index('\n',text.index('def '+name+'('))+1
  indent=text[offset:offset+len(text[offset:])-len(text[offset:].lstrip(' '))]
  target='retry_source'if path==RETRY and name=='source'else name
  text=text[:offset]+indent+"if "+condition+":return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+target+"']("+args+")\n"+text[offset:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('cycle_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_cycle_output.py'))['source'](reader,changed)
 r=record(reader);require(r['baseline']==BASE and r['composition_baseline']==COMPOSITION_BASE,'thermal fallow exact baseline')
 for p,h in {**r['qualified_input_sha256'],**r['postimages']}.items():require(sha(reader(p))==h,'saved postimage '+p)
 for p in [PARENT,PERF,RETRY]:require(reader(p)==projection(p),'original owner assertions '+p)
 current=json.loads(reader(STATUS));current['extended_output_component_20261021'].pop(KEY)
 require(current==json.loads(composition_bytes(STATUS)),'unrelated NUT authority')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty thermal fallow science')
 git('merge-base','--is-ancestor',COMPOSITION_BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',COMPOSITION_BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(delta==r['scientific_delta'],'foreign thermal fallow science')
 require(all(k=='A' or p in [PARENT,RETRY,GEN]for p,k in delta.items()),'changed incumbent physical implementation')
 if changed is not None:
  for p in changed:
   if p not in delta:require(subprocess.run(['git','cat-file','-e',COMPOSITION_BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'unknown caller source '+p)
 return r
def retry_source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 source(reader,changed)
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def fsi35_successors():
 source();retry=runpy.run_path(str(ROOT/RETRY));rows={p:dict(v)for p,v in retry['record']()['frozen_fsi35_successors'].items()}
 for p,row in rows.items():
  if p in retry['PRODUCTION']:row['canonical_blob']=git('rev-parse','HEAD:'+p)
  require(row['canonical_blob']==git('rev-parse','HEAD:'+p),'stale FSI35 successor '+p)
 return rows
def capsule():
 r=record();p=ROOT/r['evidence_index'];require(sha(p.read_bytes())==r['evidence_index_sha256'],'saved index')
 index=json.loads(p.read_text());raw=base64.b64decode(b''.join((p.parent/'evidence.tar.xz.b64').read_bytes().split()),validate=True)
 require(sha(raw)==index['decoded_sha256'],'saved capsule')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as a:
  ms=a.getmembers();require(len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'saved member safety')
  f={m.name:a.extractfile(m).read()for m in ms}
 require(f.keys()==index['members'].keys()and all(sha(v)==index['members'][p]for p,v in f.items()),'saved member inventory')
 return f
def validate(f):
 validate_current_build(f)
 def js(p):return json.loads(f[p])
 def envelope(raw):
  require(raw[:8]==b'S5NS0001','saved envelope magic')
  n=struct.unpack_from('<i',raw,8)[0]
  require(n+88==len(raw)and zlib.crc32(raw[:-4])==struct.unpack_from('<I',raw,len(raw)-4)[0],'saved envelope length crc')
  return struct.unpack_from('<9d',raw,12),raw[84:-4]
 r=js('thermal/result.json');c=js('component/result.json');prior=js('PREDECESSOR.json')
 require(r['status']=='THERMAL_SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_ATOMIC_FRESH_PASS','saved actual proof')
 require(c['status']=='SAVED_RESIDUE_COMPONENT_SOURCE_EXACT_O0_O2_PASS','saved source oracle')
 require(r['results']['O0']==r['results']['O2']and c['results']['O0']==c['results']['O2'],'saved optimization drift')
 require('checks=6808 reports=234'in c['results']['O0'],'source-exact case census')
 require(sha(f['thermal/driver.f90'])==r['generated_driver_sha256'],'saved generated driver')
 require(sha(f['thermal/thermal_fallow_proof.inc'])==r['generated_helper_sha256'],'thermal fallow helper')
 preservation=js('preservation.json')
 require(js('cold/result.json')['results']==preservation['cold_previous_results'],'cold saved-output drift')
 require(r['incumbent_default_sha256']==preservation['thermal_previous_physical'],'incumbent thermal physical drift')
 require(r['original_wofostnut_sha256']=='071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2','source harvest authority')
 for name,h in r['original_fragment_sha256'].items():require(sha(f['thermal/'+name])==h,'literal harvest addition fragment')
 for prefix in ['component','thermal']:
  es=js(prefix+'/events.json');require(all(e['returncode']==0 for e in es),'failed saved execution')
  for e in es:
   for stream in ['stdout','stderr']:require(prefix+'/'+e[stream]in f,'missing saved raw stream')
 es=js('thermal/events.json')
 for category,count in [('provider_compile',10),('actual_native',2),('original_fresh',2),('phase_roundtrip',12),('phase_fresh_fallow',12),('fallow_fresh',4),('invalid_generation',36),('invalid_live_generation',36),('invalid_identity',4),('invalid_heat_identity',8),('crash_reconstruction',4)]:
  require(sum(e['category']==category for e in es)==count,'saved process census '+category)
 for opt in ['O0','O2']:
  b='thermal/'+opt+'/'
  require(f[b+'endpoint']==f[b+'fresh'],'saved incumbent restart drift')
  require(sha(f[b+'endpoint'])==r['incumbent_default_sha256'][opt],'saved incumbent endpoint receipt')
  for label,delayed in [('saved',False),('deferred',True)]:
   p=b+'endpoint.stages.'+label
   require(f[p+'.before-stage']==f[p+'.failed-stage'],'failed initial capture published')
   memory=None
   for phase in ['1','2','3']:
    stage=f[p+'.phase-'+phase];v,inner=envelope(stage)
    require(v[0]==2.0 and any(x>0 for x in v[1:5]),'nontrivial harvest diagnostic memory')
    if memory is None:memory=v
    require(v==memory,'harvest phase changes saved values')
    require(stage==f[p+'.replay-'+phase]==f[b+label+'-roundtrip-'+phase],'saved phase replay/roundtrip leak')
    require(f[p+'.actual-'+phase]==f[p+'.manual-'+phase],'saved phase changes physical owner')
    if phase!='1':require(f[p+'.failed-'+phase]==f[p+'.phase-'+str(int(phase)-1)],'failed phase publication')
    for day in ['3','4']:
     require(f[b+label+'-continue-'+phase+'.day-'+day]==f[p+'.day-'+day],'fresh phase/fallow continuation drift')
   for day in ['3','4']:
    before=f[p+'.before-day-'+day];after=f[p+'.day-'+day];v,inner=envelope(after)
    require(v[0]==float(day)and all(x==0 for x in v[1:]),'fallow does not replace saved values')
    for fail in ['failed-day-','bad-roots-','nan-day-','environment-day-','material-day-','absent-roots-day-','absent-heat-day-']:require(before==f[p+'.'+fail+day],'failed day publication '+fail)
    for label2 in ['replay-day-','view-day-','view-memory-']:require(after==f[p+'.'+label2+day],'saved fallback/view state leak')
    require(f[p+'.actual-day-'+day]==f[p+'.manual-day-'+day],'saved reporting changes physical fallow')
    require(sha(after)==r['results'][opt]['generations'][label][day],'saved generation receipt')
   require(f[b+label+'-day3-continue.day-4']==f[p+'.day-4'],'fresh accepted fallow continuation drift')
   require(f[p+'.phase-3']==f[p+'.phase-3.before-invalid']==f[p+'.phase-3.after-invalid'],'invalid read alters live authority')
  for day in ['3','4']:
   require(f[b+'endpoint.stages.saved.actual-day-'+day]==f[b+'endpoint.stages.deferred.actual-day-'+day],'report cadence changes physics')
  for phase,wanted in [('before','2'),('after','3')]:
   p=b+'crash-'+phase+'/'
   require(f[p+'generation']==f[p+'recovered']==f[b+'endpoint.stages.saved.phase-'+wanted],'partial crash generation')
   crash=js(p+'result.json');require(crash['returncode']==-9 and crash['complete'],'saved crash did not execute')
   require(sha(f[p+'generation'])==r['results'][opt]['crashes'][phase]['sha256'],'saved crash receipt')
 require(prior['qualified']and prior['controls']==34 and prior['source_tree']==git('rev-parse',BASE+':src'),'exact admitted predecessor')
 require(r['thermal_selected']and r['crash_selected']and not r['full_work_unit_closed'],'saved scope')
 return dict(qualified=True,status='THERMAL_SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_QUALIFIED',literal_checks_per_optimization=6808,literal_reports_per_optimization=234,independent_phase_roundtrips=12,independent_phase_fallow_progressions=12,fresh_fallow_progressions=4,invalid_generations=36,invalid_live_generations=36,identity_rejections=4,heat_identity_rejections=8,process_crashes=4,original_temperature_exact=True,incumbent_physics_unchanged=True,full_mc_nut01_closed=False)
def cold_validate(f):
 old=runpy.run_path(str(ROOT/PARENT));prior=old['capsule']()
 prior.update({p.replace('cold/','physical/',1):v for p,v in f.items()if p.startswith('cold/')})
 return old['validate'](prior)
def verify():
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('cycle_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_cycle_output.py'))['verify']()
 source();f=capsule();r=validate(f);r['cold_preservation']=cold_validate(f)
 old=runpy.run_path(str(ROOT/PARENT));r['incumbent_saved_output']=old['validate'](old['capsule']())
 prior=verify_current_predecessor(json.loads(f['preservation.json'])['fsi35_original_native_body_sha256'])
 r['incumbent_root_substep']=prior
 for key in ['current_calendar_nut','current_concurrent_nut','frozen_daily_predecessor']:r[key]=prior[key]
 return r
def self_test():
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('cycle_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_cycle_output.py'))['self_test']()
 source();f=capsule();validate(f);cold_validate(f);controls=[]
 def reject(name,fn):
  try:fn()
  except(ValueError,KeyError,AssertionError,UnicodeError,struct.error):controls.append(name);return
  raise ValueError('saved corruption accepted '+name)
 for p in ['src/runtime/mod_fmr_crop_soil_n_thermal_fallow.f90','src/adapter/mod_crop_soil_n_thermal_saved_output.f90','src/adapter/mod_crop_ext_saved_residue.f90','src/adapter/mod_crop_n_saved_generation.f90','src/adapter/mod_crop_soil_n_saved_harvest.f90','src/adapter/mod_crop_soil_n_saved_output.f90','src/crop/mod_crop_soil_n_day.f90','src/runtime/mod_fmr_serialized_reference_backend.f90',PARENT,PERF,RETRY]:
  reject('source '+p,lambda p=p:source(lambda x:(ROOT/x).read_bytes()+(b'!'if x==p else b'')))
 for p in ['component/result.json','thermal/result.json','thermal/driver.f90','thermal/O0/saved-roundtrip-1','thermal/O2/deferred-continue-3.day-4','PREDECESSOR.json','build/cold/result.json','build/thermal/result.json','build/cold/0000.stdout','build/thermal/driver.f90']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in ['thermal/O0/endpoint.stages.saved.failed-stage','thermal/O2/endpoint.stages.deferred.manual-day-3','thermal/O0/endpoint.stages.saved.view-memory-4','thermal/O2/endpoint.stages.saved.phase-3.after-invalid','thermal/O0/crash-after/recovered','thermal/O0/endpoint.stages.saved.environment-day-3']:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 for p in ['cold/O0/endpoint.stages.saved.day-3','cold/O2/endpoint.stages.deferred.manual-day-4']:
  bad=dict(f);bad[p]+=b'!';reject('cold drift '+p,lambda bad=bad:cold_validate(bad))
 bad=dict(record()['scientific_delta']);bad['src/foreign_saved.f90']='A';reject('foreign science',lambda:source(changed=bad))
 retry=runpy.run_path(str(ROOT/RETRY));rf=retry['capsule']()
 for p in ['on-season-O2-4x/native/stdout','season-O0-4x/native/stdout','root-substep-transaction/0001.stdout','nut-owner/thermal/O2/output.restart.environment-after','saved-owner/physical/O2/deferred-continue-3.day-4','on-restart-native/stdout']:
  bad=dict(rf);bad.pop(p);reject('retry missing '+p,lambda bad=bad:retry_physics(bad))
 return controls
def initial_verify_current_predecessor(native_body_sha256):
    # Preserve the admitted PERF01 raw assertions and public FSI35 source continuity.
    perf = runpy.run_path(str(ROOT / PERF))
    record, evidence = perf['record'], perf['evidence']
    PROOF, ROOT_PARENT, PHYSICAL_BASE = perf['PROOF'], perf['ROOT_PARENT'], perf['PHYSICAL_BASE']
    HARVEST_PARENT, SAVED_PARENT, RUNNER = perf['HARVEST_PARENT'], perf['SAVED_PARENT'], perf['RUNNER']
    inherited = record()['fsi35_native_inheritance']
    require(inherited['candidate'] == '48d61aafcc152122de0f6e43b3e1fe3bcddbf0cb', 'native inheritance origin')
    marker = b'# Historical F-CI58P/F-SI35 authorities remain immutable evidence.'
    current_body = (ROOT / RUNNER).read_bytes()
    previous_body = subprocess.check_output(['git', 'show', BASE + ':' + RUNNER], cwd=ROOT)
    require(current_body[current_body.index(marker):] == previous_body[previous_body.index(marker):], 'changed original FSI35 native body')
    require(sha(previous_body[previous_body.index(marker):]) == native_body_sha256, 'original/public native source continuity')
    for p, h in inherited['input_sha256'].items():
        require(sha((ROOT / p).read_bytes()) == h and
                sha(subprocess.check_output(['git', 'show', BASE + ':' + p], cwd=ROOT)) == h,
                'changed inherited FSI35 compiled input ' + p)
    import io
    receipt = (ROOT / inherited['receipt']).read_bytes()
    require(sha(receipt) == '3812d0f0ffa054e854c7e454f8bac320b03fe17104ca77fafcfb4a17988cb77f', 'original native receipt identity')
    with tarfile.open(fileobj=io.BytesIO(receipt), mode='r:xz') as t:
        terminal = json.loads(t.extractfile('fsi35/RESULT.json').read())
        stdout = t.extractfile('fsi35/stdout').read()
        require(terminal['status'] == 'PASS' and terminal['returncode'] == 0 and
                sha(stdout) == terminal['raw_sha256']['stdout'] and
                b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS' in stdout, 'original native terminal proof')
    require(subprocess.check_output([inherited['compiler_command'], '--version'], text=True) == terminal['compiler'],
            'inherited native compiler changed')
    for p, h in inherited['toolchain_sha256'].items():
        require(sha(Path(p).read_bytes()) == h, 'inherited native compiler bytes changed')
    files = evidence()
    checker = runpy.run_path(str(ROOT / PROOF))
    # This controller is not compiled or executed by the scientific drivers.
    # Pin its current exact additive dispatch separately in source(); retain
    # only its recorded controller snapshot for the immutable physical capsule.
    def physical_reader(p):
        return files['current-source/' + p] if p == ROOT_PARENT else (ROOT / p).read_bytes()
    current = checker['verify'](files, physical_reader)
    prior = json.loads(files['frozen-canonical-owner.json'])
    require(prior['qualified'] and prior['controls'] == record()['frozen_owner_controls'] and
            prior['current_source_tree'] == git('rev-parse', PHYSICAL_BASE + ':src'), 'complete frozen original canonical owner')
    concurrent = record()['harvest_evidence']
    raw = (ROOT / concurrent['path']).read_bytes()
    require(sha(raw) == concurrent['sha256'] and len(raw) == concurrent['bytes'], 'current harvest receipt identity')
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as t:
        ms = t.getmembers()
        require(len(ms) == concurrent['members'] == len({m.name for m in ms}) and
                all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms), 'harvest receipt inventory')
        hf = {m.name: t.extractfile(m).read() for m in ms}
    inventory = json.loads(hf.pop('MANIFEST.json'))
    require(set(hf) == set(inventory) and all(sha(hf[p]) == h for p, h in inventory.items()), 'harvest receipt bytes')
    harvest_owner = runpy.run_path(str(ROOT / HARVEST_PARENT))
    harvest = harvest_owner['validate'](hf)
    native_harvest = json.loads(hf['harvest/result.json'])
    for p, h in native_harvest['input_sha256'].items():
        require(sha((ROOT / p).read_bytes()) == h, 'current harvest executed input ' + p)
    frozen_latest = json.loads(hf['FROZEN_LATEST.json'])
    frozen_controls = json.loads(hf['FROZEN_LATEST_CONTROLS.json'])
    require(frozen_latest['qualified'] and frozen_latest['status'] == 'HARVEST_OUTPUT_PHASE_O0_O2_QUALIFIED' and
            len(frozen_controls) == 18, 'complete frozen latest harvest owner')
    saved_record = record()['saved_evidence']
    raw = (ROOT / saved_record['path']).read_bytes()
    require(sha(raw) == saved_record['sha256'] and len(raw) == saved_record['bytes'], 'current saved-output receipt identity')
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as t:
        ms = t.getmembers()
        require(len(ms) == saved_record['members'] == len({m.name for m in ms}) and
                all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms), 'saved receipt inventory')
        sf = {m.name: t.extractfile(m).read() for m in ms}
    inventory = json.loads(sf.pop('MANIFEST.json'))
    require(set(sf) == set(inventory) and all(sha(sf[p]) == h for p, h in inventory.items()), 'saved receipt bytes')
    saved = runpy.run_path(str(ROOT / SAVED_PARENT))['validate'](sf)
    for prefix in ['component', 'physical']:
        for p, h in json.loads(sf[prefix + '/result.json'])['input_sha256'].items():
            if p == 'src/adapter/mod_crop_n_saved_generation.f90':
                require(h == sha(historical(p)), 'frozen saved codec preimage')
                codec_authority = json.loads((ROOT / STATUS).read_text())['extended_output_component_20261021'][KEY]
                require(sha((ROOT / p).read_bytes()) == codec_authority['qualified_input_sha256'][p], 'fresh qualified saved codec')
            else:
                require(sha((ROOT / p).read_bytes()) == h, 'current saved executed input ' + p)
    frozen_saved = json.loads(sf['FROZEN_LATEST.json'])
    require(frozen_saved['qualified'] and frozen_saved['status'] == 'SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_QUALIFIED' and
            len(json.loads(sf['FROZEN_LATEST_CONTROLS.json'])) == 19, 'complete frozen saved-output owner')
    # All earlier owner fields remain available to their existing callers.
    return {**prior, 'weather_successor': current, 'current_harvest_output': harvest, 'current_saved_output': saved,
            'frozen_latest_owner': '0be6037b /18 controls', 'current_source_tree': git('rev-parse', 'HEAD:src'),
            'source_tree': git('rev-parse', 'HEAD:src'), 'qualified': True,
            'qualification_scope': 'CURRENT_BOUNDED_WEATHER_SOL_ROOT_SUBSTEP_NUT_CALENDAR_COMPOSITION',
            'canonically_admitted': False, 'fsi35_native': record().get('fsi35_native', 'PENDING')}

def validate_current_build(f):
 cold=json.loads(f['build/cold/result.json']);heat=json.loads(f['build/thermal/result.json'])
 saved=json.loads(f['cold/result.json']);thermal=json.loads(f['thermal/result.json'])
 require(cold['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS' and heat['status']=='THERMAL_OUTPUT_ACTUAL_O0_O2_RESTART_ATOMIC_PASS','fresh complete build status')
 require(saved['cold_proof_sha256']==thermal['cold_proof_sha256']==sha(f['build/cold/result.json']),'complete fresh cold source chain')
 require(thermal['thermal_proof_sha256']==sha(f['build/thermal/result.json']),'complete fresh heat source chain')
 for prefix,r in [('build/cold',cold),('build/thermal',heat)]:
  require(sha(f[prefix+'/driver.f90'])==r['generated_driver_sha256'],'fresh generated driver '+prefix)
  es=json.loads(f[prefix+'/events.json']);require(all(e['returncode']==0 for e in es),'fresh build native failure '+prefix)
  for e in es:
   for stream in ['stdout','stderr']:require(prefix+'/'+e[stream]in f,'missing fresh build raw '+prefix)
 return True
def retry_physics(files=None):
 retry=runpy.run_path(str(ROOT/RETRY));files=retry['capsule']()if files is None else files
 assessment=json.loads(files['ASSESSMENT.json'])
 # The frozen codec preimage qualifies only its immutable predecessor run.
 # Fresh complete cold/thermal runs independently bind the new codec postimage.
 def physical_reader(p):
  if p==GEN:
   before=composition_bytes(p);require(sha(before)==assessment['current_inputs'][p],'codec predecessor identity')
   require(sha((ROOT/p).read_bytes())==record()['qualified_input_sha256'][p],'fresh codec identity')
   return before
  return (ROOT/p).read_bytes()
 return runpy.run_path(str(ROOT/retry['CHECKER']))['verify'](files,physical_reader)
def verify_current_predecessor(native_body_sha256):
 retry=runpy.run_path(str(ROOT/RETRY));proof=retry_physics();f=capsule()
 frozen=json.loads(f['retry/PREDECESSOR.json'])
 require(frozen['canonical']==COMPOSITION_BASE and frozen['owner']['qualified'] and len(frozen['controls'])==15,'complete exact retry predecessor')
 require(frozen['owner']['current_source_tree']==git('rev-parse',COMPOSITION_BASE+':src'),'retry predecessor source tree')
 require(frozen['owner']['fsi35_native']=='PASS','predecessor native absent')
 native=retry['record']()['native_fsi35'];raw=(ROOT/native['receipt']).read_bytes()
 require(sha(raw)==native['sha256'],'current native receipt identity')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  terminal=json.loads(t.extractfile('RESULT.json').read());stdout=t.extractfile('stdout').read()
 require(terminal['status']=='PASS' and terminal['returncode']==0 and sha(stdout)==terminal['raw_sha256']['stdout'] and b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in stdout,'native terminal')
 for p,h in terminal['input_sha256'].items():require(sha((ROOT/p).read_bytes())==h,'native compiled input '+p)
 require(Path('/workspace/scratch/4112bba79f91/compiler-bin/gfortran').read_bytes()==f['compiler/wrapper.sh'],'compiler wrapper identity')
 perf=runpy.run_path(str(ROOT/PERF))
 for p,h in perf['record']()['fsi35_native_inheritance']['toolchain_sha256'].items():require(sha(Path(p).read_bytes())==h,'compiler executable identity '+p)
 compiler=f['compiler/version.txt'].decode()
 require(subprocess.check_output(['/workspace/scratch/4112bba79f91/compiler-bin/gfortran','--version'],text=True)==compiler==terminal['compiler'],'native compiler identity')
 return {**frozen['owner'],'line_search_retry':proof,'current_source_tree':git('rev-parse','HEAD:src'),'source_tree':git('rev-parse','HEAD:src'),'qualified':True,'canonically_admitted':False,'qualification_scope':'CURRENT_RETRY_WEATHER_ROOT_NUT_THERMAL_FALLOW_COMPOSITION'}


if __name__=='__main__':print(json.dumps(verify(),indent=2))
