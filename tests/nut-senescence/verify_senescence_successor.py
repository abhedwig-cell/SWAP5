#!/usr/bin/env python3
"""Strict simultaneous forcing successor; complete raw native proof, no copied PASS."""
from pathlib import Path
import ast,argparse,base64,struct,zlib,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='e22a677146ef49d14bd6dd6e72b78f60e340bcab'
STATUS='integration/audits/MC_NUT01_SENESCENCE_CYCLE_STATUS.json'
CHANGED={'src/crop/mod_crop_soil_n_day.f90','src/crop/mod_crop_soil_n_material_day.f90','src/adapter/mod_crop_soil_n_joint_restart_file.f90','tests/nut-material-environment/verify_material_environment_successor.py','tests/nut-material-environment/check_material_environment_controls.py','tests/nut-environment/check_environment_controls.py','tests/crop-co2/verify_co2_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'}
MARKERS={'test_material_addition':'MATERIAL_LITERAL_12_CASES_WHOLE_N_OM_THRESHOLDS_8_INVALID=PASS','test_material_day':'MATERIAL_REAL_WOFOST81_LITERAL_EIGHT_POOLS_ATOMIC_RETRY_REPLAY_EMPTY=PASS','test_material_joint':'MATERIAL_ACTUAL_RICHARDS_WOFOST81_LITERAL_ATOMIC_REPLAY_OPAQUE_DISK=PASS','test_material_environment_day':'MATERIAL_ENVIRONMENT_DAY_LITERAL_5_30_ATOMIC_7_INVALID_ABA_EMPTY=PASS','test_material_environment_joint':'MATERIAL_ENVIRONMENT_RICHARDS_LITERAL_5_30_ATOMIC_STALE_OPAQUE_DISK=PASS'}
MARKERS.update({'test_senescence_mapping':'SENESCENCE_SOURCE_MAPPING_LITERAL_3_ORGANS_8_INVALID_ZERO=PASS','test_senescence_day':'SENESCENCE_REAL_DAY_DELAYED_3_ORGANS_LITERAL_WHOLE_N_ROLLBACK_REPLAY=PASS','test_senescence_joint':'SENESCENCE_ACTUAL_RICHARDS_DELAYED_LITERAL_ATOMIC_PENDING_OPAQUE_DISK=PASS'})
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;s=json.loads((ROOT/STATUS).read_text())
 check(s['baseline']==BASE,'unknown baseline');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty scientific surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected={p:'A'for p in s['added_blobs']};expected.update({p:'M'for p in CHANGED})
 check(rows==expected,'foreign simultaneous forcing delta');check(set(s['changed_blobs'])==CHANGED,'incomplete changed surface')
 for p,h in {**s['added_blobs'],**s['changed_blobs']}.items():check(g('rev-parse','HEAD:'+p)==h==blob((ROOT/p).read_bytes()),'unknown postimage '+p)
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'immutable reference changed')
 return dict(baseline=BASE,source_tree=g('rev-parse','HEAD:src'),current_source_tree=g('rev-parse','HEAD:src'),senescence_successor=True,qualified=False,admitted=False)
def capsule(record):
 raw=base64.b64decode((ROOT/record['path']).read_bytes());check(sha(raw)==record['sha256'],'capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  members=a.getmembers();check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in members),'unsafe member')
  check(len({m.name for m in members})==len(members),'duplicate member');d={m.name:a.extractfile(m).read()for m in members}
 manifest=json.loads(d.pop('MANIFEST.json'));check(set(manifest)==set(d),'manifest coverage')
 for p,h in manifest.items():check(sha(d[p])==h,'raw digest '+p)
 return d
def read_evidence():return capsule(json.loads((ROOT/STATUS).read_text())['evidence'])
def baseline_root():
 root=ROOT.parent/('senescence-baseline-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'baseline moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip(),'dirty baseline')
 return root
def baseline_command(path,extra=()):
 root=baseline_root();p=subprocess.run([sys.executable,'-B',str(root/path),*extra],cwd=root,check=True,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 return json.loads(p.stdout)
def validate_events(d,prefix,source,mode):
 r=json.loads(d[prefix+'result.json']);events=json.loads(d[prefix+'events.json'])
 check(r['status']=='PASS'and r['mode']==mode,'unfinished science');check(r['source_tree']==source['source_tree'],'stale source')
 for p,h in r['input_sha256'].items():
  check(not Path(p).is_absolute()and '..'not in Path(p).parts,'unsafe input');check(sha((ROOT/p).read_bytes())==h,'scientific input drift '+p)
 check({p for p in CHANGED if p.startswith('src/')and(mode=='joint'or mode=='day'and p.startswith('src/crop/'))}<=r['input_sha256'].keys(),'untested changed production')
 check('src/process/mod_crop_senescence_residue.f90'in r['input_sha256'],'untested pending producer')
 old=capsule(json.loads((ROOT/'integration/audits/MC_NUT01_MATERIAL_ENVIRONMENT_STATUS.json').read_text())['evidence'])
 prior=json.loads(old['result.json']);check(r['authority']==prior['authority'],'historical authority changed')
 check('controlled_reuse'not in r,'unexpected provider/native reuse')
 expected=set(MARKERS)if mode=='joint'else {'test_material_addition','test_senescence_mapping','test_material_day','test_material_environment_day','test_senescence_day'}if mode=='day'else {'test_material_addition','test_senescence_mapping'}
 for opt in ['O0','O2']:
  row=r['runs'][opt];check(row['production_providers']==(263 if mode=='joint'else 44 if mode=='day'else 3),'closure drift')
  check(set(row['drivers'])==expected,'driver coverage')
  builds=[e for e in events if e['category']=='compile'and '-'+opt in e['command']]
  check(len(builds)>=row['production_providers'],'missing fresh provider build')
  compiled={'src/'+e['command'][e['command'].index('-c')+1].split('/src/',1)[1]for e in builds if '/src/'in e['command'][e['command'].index('-c')+1]}
  check(compiled=={p for p in r['input_sha256']if p.startswith('src/')},'fresh production provider coverage')
  for name,entry in row['drivers'].items():
   check(MARKERS[name]in entry['stdout'],'native science missing '+name)
   es=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==name]
   check(len(es)==(32 if name=='test_senescence_joint'else 21 if name.endswith('_joint')else 1),'native execution coverage '+name)
   check(d[prefix+es[0]['stdout_file']].decode()==entry['stdout'],'raw native identity '+name)
   if not name.endswith('_joint'):continue
   check(len(set(entry['decoder_negatives']))==(30 if name=='test_senescence_joint'else 19),'decoder coverage')
   for e in es[2:]:check(b'INVALID_DISK=PASS'in d[prefix+e['stdout_file']],'decoder rejection absent')
   stem={'test_material_joint':'','test_material_environment_joint':'environment-','test_senescence_joint':'senescence-'}[name]
   check(sha(d[prefix+opt+'/'+stem+'restart.bin'])==entry['restart_sha256'],'restart initial payload drift')
   if name=='test_senescence_joint':
    required={'pending_clock','pending_nan','pending_negative_DM','pending_tiny_DM','pending_orphan_N','pending_negative_N','pending_excess_N','pending_invalid_age','pending_unincorporable_N','pending_oversize_DM','pending_silent_legacy_tag'}
    check(set(entry['decoder_negatives'])==set(prior['runs'][opt]['drivers']['test_material_joint']['decoder_negatives'])|required,'pending semantic decoder coverage')
   if name!='test_senescence_joint':check(d[prefix+opt+'/'+stem+'restart.bin.empty-original']==d[prefix+opt+'/'+stem+'restart.bin.empty-material'],'empty forced route identity')
   for path in ['expected.bin','fresh.bin','expected.bin.opaque']:check(sha(d[prefix+opt+'/'+stem+path])==entry['endpoint_sha256'],'continuation endpoint mismatch')
   check(entry['endpoint_sha256']==r['runs']['O0']['drivers'][name]['endpoint_sha256'],'optimization endpoint drift')
   if name!='test_senescence_joint':
    for path in ['restart.bin','expected.bin','fresh.bin','expected.bin.opaque','restart.bin.empty-original','restart.bin.empty-material']:check(d[prefix+opt+'/'+stem+path]==old[opt+'/'+stem+path],'incumbent material endpoint changed '+stem+path)
  if mode!='process':
   management=d[prefix+opt+'/management_soil.f90'].decode()
   start=management.index('! Mineralisation, but Nminer is negative in case of immobilisation');end=management.index('      Call Wofost_SoilBalanceCheck',start)
   check(management[start:end].encode()in d[prefix+opt+'/literal_crop_exchange.f90'],'literal uptake block replaced')
  script=ast.parse((ROOT/'tests/nut-senescence/run_senescence.py').read_text())
  wrapper=next(ast.literal_eval(n.value)for n in script.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='oracle'for t in n.targets))
  check(d[prefix+opt+'/material_oracle.inc']==wrapper.encode(),'material literal wrapper replaced')
  for name,h in r['authority'].items():
   expected_hash='a17a727e35c453a17be599eede2c501b36baf921b9937edd6b0309dcb26d9696'if name=='wofost_soil_orgmatn.f90'and mode!='process'else h
   check(sha(d[prefix+opt+'/'+name])==expected_hash,'literal source changed '+name)
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed scientific event')
  if e['category']in ['compile','driver_compile']:
   check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked compilation')
  for stream in ['stdout','stderr']:check(sha(d[prefix+e[stream+'_file']])==e[stream+'_sha256'],'event digest drift')
 if mode=='joint':check(r['incumbent_endpoints_identical']is True,'original profile not preserved')
 return r
def validate_incumbent(d,source):
 prefix='incumbent/';r=json.loads(d[prefix+'result.json']);events=json.loads(d[prefix+'events.json']);primary=json.loads(d['result.json']);pe=json.loads(d['events.json'])
 check(r['status']=='PHYSICAL_PASS_NOT_ADMITTED'and r['direct_only']is False,'incumbent incomplete')
 check(r['source_tree']==source['source_tree']and r['compiler']==primary['compiler'],'incumbent source/compiler drift')
 check(r['all_incumbent_endpoints_identical']is True,'incumbent identity absent')
 reuse=r['controlled_reuse'];check(reuse['primary_result_sha256']==sha(d['result.json'])and reuse['compiler']==r['compiler']and reuse['native_results_reused']is False,'unbound incumbent reuse')
 for p,h in r['input_sha256'].items():check(not Path(p).is_absolute()and '..'not in Path(p).parts and sha((ROOT/p).read_bytes())==h,'incumbent input drift '+p)
 names={'test_crop_soil_day','test_environment_day','test_environment_joint','test_crop_soil_joint','test_reactive_joint','test_mineral_joint'}
 markers={'test_environment_day':'DAILY_ENVIRONMENT_LITERAL_SUPPLY_ROLLBACK_IDENTITY=PASS','test_crop_soil_day':'CROP_SOIL_REAL_WOFOST81_LITERAL_SUPPLY_FIXATION_LOSS_ROLLBACK_REPLAY=PASS','test_environment_joint':'DAILY_ENVIRONMENT_ACTUAL_RICHARDS_LITERAL_ROLLBACK_OPAQUE_DISK=PASS','test_crop_soil_joint':'CROP_SOIL_ACTUAL_RICHARDS_WOFOST81_LITERAL_ROLLBACK_OPAQUE_DISK=PASS','test_reactive_joint':'REACTIVE_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS','test_mineral_joint':'MINERAL_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS'}
 original=capsule(json.loads((ROOT/'integration/audits/MC_NUT01_DAILY_ENVIRONMENT_STATUS.json').read_text())['evidence'])
 artifacts=json.loads(d['incumbent/BUILD_ARTIFACTS.json'])
 for opt in ['O0','O2']:
  row=r['runs'][opt];check(set(row['drivers'])==names,'incumbent driver missing')
  reused=reuse['providers'][opt]
  primary_compiled={'src/'+e['command'][e['command'].index('-c')+1].split('/src/',1)[1]for e in pe if e['category']=='compile'and '-'+opt in e['command']and '/src/'in e['command'][e['command'].index('-c')+1]}
  check(set(reused)<=primary_compiled,'unbuilt reuse')
  for p,entry in reused.items():
   check(entry['source_sha256']==r['input_sha256'][p]==primary['input_sha256'][p],'stale reused provider')
   check(entry['object_sha256']==artifacts[opt][p],'reused object drift')
  compiled={'src/'+e['command'][e['command'].index('-c')+1].split('/src/',1)[1]for e in events if e['category']=='compile'and '-'+opt in e['command']and '/src/'in e['command'][e['command'].index('-c')+1]}
  check(not compiled&set(reused)and compiled|set(reused)=={p for p in r['input_sha256']if p.startswith('src/')},'incumbent provider coverage')
  check(row['production_providers']==len(compiled|set(reused)),'incumbent closure drift')
  for name,entry in row['drivers'].items():
   for category in ['driver_compile','link']:
    es=[e for e in events if e['category']==category and '-'+opt in e['command']and any(Path(x).name==name+('.f90'if category=='driver_compile'else'')for x in e['command'])]
    check(len(es)==1,'incumbent fresh driver/link absent '+name)
   es=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==name]
   check(bool(es),'incumbent native absent '+name)
   check(markers[name]in entry['stdout']and d[prefix+es[0]['stdout_file']].decode()==entry['stdout'],'incumbent native marker/raw')
   if not name.endswith('_joint'):check(len(es)==1,'incumbent direct native missing');continue
   count=18 if name in ['test_environment_joint','test_crop_soil_joint']else 10
   check(len(es)==count+2 and len(set(entry['decoder_negatives']))==count,'incumbent decoder coverage')
   check(es[0]['command'][1]=='write'and es[1]['command'][1]=='resume','incumbent fresh continuation absent')
   check(d[prefix+es[1]['stdout_file']].decode()==entry['fresh_stdout'],'incumbent fresh stdout drift')
   for e in es[2:]:check(b'INVALID_DISK=PASS'in d[prefix+e['stdout_file']],'incumbent decoder rejection absent')
   for suffix in ['-expected.bin','-fresh.bin','-expected.bin.opaque']:
    path=opt+'/'+name+suffix
    check(sha(d[prefix+path])==entry['endpoint_sha256']and d[prefix+path]==original[opt+'/'+name+'-expected.bin'],'incumbent endpoint drift')
   check(sha(d[prefix+opt+'/'+name+'-restart.bin'])==entry['restart_sha256'],'incumbent restart drift')
   check(entry['endpoint_sha256']==r['runs']['O0']['drivers'][name]['endpoint_sha256'],'incumbent optimization drift')
  for name,h in r['authority'].items():
   expected='a17a727e35c453a17be599eede2c501b36baf921b9937edd6b0309dcb26d9696'if name=='wofost_soil_orgmatn.f90'else h
   check(sha(d[prefix+opt+'/'+name])==expected,'incumbent literal source drift')
  check(d[prefix+opt+'/literal_crop_exchange.f90']==original[opt+'/literal_crop_exchange.f90'],'incumbent literal wrapper changed')
  body=d[prefix+opt+'/management_soil.f90'];a=body.index(b'! Mineralisation, but Nminer is negative in case of immobilisation');b=body.index(b'      Call Wofost_SoilBalanceCheck',a)
  check(sha(body[a:b])==r['literal_uptake_extraction']['block_sha256']and body[a:b]in d[prefix+opt+'/literal_crop_exchange.f90'],'incumbent literal uptake drift')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'incumbent failed event')
  if e['category']in ['compile','driver_compile']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'incumbent unchecked build')
  for stream in ['stdout','stderr']:check(sha(d[prefix+e[stream+'_file']])==e[stream+'_sha256'],'incumbent raw digest drift')
 recovery=r.get('execution_recovery')
 if recovery:
  check(0<recovery['completed_events_retained']<len(events)and bool(recovery['unchanged_build_artifacts']),'unbound permission recovery')
 return r
def validate(d,source):
 validate_incumbent(d,source)
 result=validate_events(d,'',source,'joint');validate_events(d,'direct/',source,'day');validate_events(d,'process/',source,'process')
 body=d['authority/swap.f90'];check(sha(body)=='39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a','source-order authority')
 text=body.decode().lower();positions=[text.index('call soilmanagement('+str(i)+')')for i in [2,5,3,4]]
 check(positions==sorted(positions),'historical one-day order drift')
 for opt in ['O0','O2']:
  check(d[opt+'/senescence-restart.bin'][:8]==b'S5NC0002','pending native profile not exercised')
  for prefix in ['', 'environment-']:check(d[opt+'/'+prefix+'restart.bin'][:8]==b'S5NC0001','inactive native format changed')
 probe=json.loads(d['pending_probe/result.json'])
 check(probe['status']=='PASS'and probe['new_native_execution']is True and probe['primary_result_sha256']==sha(d['result.json']),'unfinished pending chemistry native probe')
 check(probe['source_tree']==source['source_tree'],'stale pending probe source')
 for p,h in probe['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'pending probe input drift')
 for opt in ['O0','O2']:
  row=probe['runs'][opt];raw=d[opt+'/senescence-restart.bin'];bad=bytearray(raw);pos=len(raw)-84
  dm=struct.unpack_from('<3d',raw,pos+8);n=struct.unpack_from('<3d',raw,pos+32)
  check(dm[0]*.09+n[1]*.5+n[2]<=sum(n),'probe must fit crop loss ledger')
  struct.pack_into('<d',bad,pos+32,dm[0]*.09);struct.pack_into('<d',bad,pos+40,n[1]*.5);struct.pack_into('<I',bad,len(bad)-4,zlib.crc32(bad[:-4]))
  check(bytes(bad)==d['pending_probe/'+opt+'-invalid-source-mixture.bin'],'wrong discriminating pending probe')
  check(row['returncode']==0 and row['executable_sha256_before']==row['executable_sha256_after']==json.loads(d['native/ARTIFACTS.json'])[opt],'pending native artifact drift')
  check(row['original_payload_sha256']==sha(raw)and row['mutant_sha256']==sha(bad),'pending native payload binding')
  check(sha(d['pending_probe/'+opt+'.stdout'])==row['stdout_sha256']and b'INVALID_DISK=PASS'in d['pending_probe/'+opt+'.stdout'],'pending native rejection absent')
 return result
def verify_qualification():
 source=verify_source();validate(read_evidence(),source)
 baseline_command('tests/nut-material-environment/verify_material_environment_successor.py')
 return {**source,'qualified':True,'highest':'NOT_SELECTED_POLICY'}
def incumbent(mode='qualification'):
 verify_qualification();return {**baseline_command('tests/nut-material-environment/verify_material_environment_successor.py',['--incumbent',mode]),'senescence_successor':True,'senescence_source_tree':git('rev-parse','HEAD:src')}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--incumbent',choices=['source','physical','qualification']);a=p.parse_args()
 print(json.dumps(incumbent(a.incumbent)if a.incumbent else verify_source()if a.source_only else verify_qualification(),indent=2))
