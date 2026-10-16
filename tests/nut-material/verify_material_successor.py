#!/usr/bin/env python3
"""Exact additive material scope and source/native qualification; fail closed."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2];BASE='dca8cbd87ceff62406d0d1a38447b7a7bc8fbd1c'
PEER='48e6aeb15a66dfd11a85de39dc6f8229842d1fd1' # actual independently admitted canonical peer
QUALIFIED_SOURCE='5a1ca7561fcb2005a89f1d7506678425dc115e71'
COMPAT_SOURCE='afac3e7194c1d800eda6e31bcb001f720dbcbb93'
ENV_SOURCE='83f559ee097415e436a33fc9a531de93d382b99a'
REQUALIFIED={'src/crop/mod_crop_soil_n_day.f90','src/process/mod_b111_soil_n_reactive_owner.f90','src/runtime/mod_fmr_crop_soil_n_joint_application.f90'}
STATUS='integration/audits/MC_NUT01_MATERIAL_CYCLE_STATUS.json'
CHANGED=['tests/nut-environment/verify_environment_successor.py','tests/nut-crop/verify_crop_supply_successor.py','tests/crop-co2/verify_co2_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh']
MARKERS={'test_material_addition':'MATERIAL_LITERAL_12_CASES_WHOLE_N_OM_THRESHOLDS_8_INVALID=PASS','test_material_day':'MATERIAL_REAL_WOFOST81_LITERAL_EIGHT_POOLS_ATOMIC_RETRY_REPLAY_EMPTY=PASS','test_material_joint':'MATERIAL_ACTUAL_RICHARDS_WOFOST81_LITERAL_ATOMIC_REPLAY_OPAQUE_DISK=PASS'}
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def sha(b):return hashlib.sha256(b).hexdigest()
def verify_source(git_reader=None):
 if (ROOT/'integration/audits/MC_NUT01_MATERIAL_ENVIRONMENT_STATUS.json').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-material-environment'));import verify_material_environment_successor as successor
  return successor.verify_source(git_reader=git if git_reader is None else git_reader)
 g=git if git_reader is None else git_reader
 s=json.loads((ROOT/STATUS).read_text());g('merge-base','--is-ancestor',PEER,'HEAD')
 check(s['baseline']==BASE,'unknown baseline')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty dependency surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',PEER,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected={p:'A'for p in s['added_blobs']};expected.update({p:'M'for p in CHANGED})
 check(rows==expected,'foreign material delta');check(set(s['changed_blobs'])==set(CHANGED),'changed guard coverage')
 for p,h in {**s['added_blobs'],**s['changed_blobs']}.items():check(g('rev-parse','HEAD:'+p)==h==blob((ROOT/p).read_bytes()),'unknown postimage '+p)
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'reference mutation')
 check(all(not p.startswith('src/')or kind=='A'for p,kind in rows.items()),'existing production mutation')
 return dict(baseline=BASE,source_tree=QUALIFIED_SOURCE,current_source_tree=g('rev-parse','HEAD:src'),compatibility_source_tree=COMPAT_SOURCE,canonical_peer=PEER,material_successor=True,qualified=False,admitted=False)
def capsule(record):
 raw=base64.b64decode((ROOT/record['path']).read_bytes());check(sha(raw)==record['sha256'],'capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe capsule')
  check(len({m.name for m in ms})==len(ms),'duplicate capsule member');data={m.name:a.extractfile(m).read()for m in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(data)==set(manifest),'manifest coverage')
 for p,h in manifest.items():check(sha(data[p])==h,'raw member drift '+p)
 return data
def read_evidence():return capsule(json.loads((ROOT/STATUS).read_text())['evidence'])
def baseline_owner(mode=None):
 root=ROOT.parent/('nut-material-peer-'+PEER[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),PEER],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==PEER,'baseline moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip(),'dirty baseline')
 args=[sys.executable,'-B',str(root/'tests/nut-crop/verify_crop_supply_successor.py')]
 if mode:args+=['--incumbent',mode]
 p=subprocess.run(args,cwd=root,capture_output=True,text=True,check=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 return json.loads(p.stdout)
def input_compatible(p,h,compat):
 current=sha((ROOT/p).read_bytes())
 if not compat and p in REQUALIFIED:
  original=sha(subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT))
  peer=sha(subprocess.check_output(['git','show',PEER+':'+p],cwd=ROOT))
  check(h==original and current==peer,'unqualified changed imported provider '+p)
 else:check(current==h,'material input drift '+p)
def validate(data,source,compat=False):
 r=json.loads(data['result.json']);events=json.loads(data['events.json'])
 check(r['status']=='PASS'and r['mode']=='joint','unfinished joint material science')
 check(r['source_tree']==source['source_tree'],'stale material source')
 check(r['authority']['management_soil.f90']=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b','wrong calendar authority')
 for p,h in r['input_sha256'].items():input_compatible(p,h,compat)
 s=json.loads((ROOT/STATUS).read_text());check({p for p in s['added_blobs']if p.startswith('src/')}<=r['input_sha256'].keys(),'untested material production')
 if not compat:
  reuse=r['controlled_reuse'];check(reuse['prior_execution']=='6d5ff12e26a467dde4404c54472dbc30384f077e','unknown reused execution')
  check(reuse['native_results_reused']is False and reuse['artifacts_before']==reuse['artifacts_after'],'provider or native reuse violation')
  check(len(reuse['artifacts_before'])>=500,'incomplete shared provider audit')
  prior=json.loads(data['retained/physical-first/events.json']);compiles=[e for e in prior if e['category']=='compile']
  check(len(compiles)>=260 and all(e['returncode']==0 for e in compiles),'missing original provider build')
  check(sha(data['retained/physical-first/events.json'])==reuse['prior_events_sha256'],'wrong original build events')
  for p,h in reuse['reused_input_sha256'].items():
   check(h==(r['input_sha256'][p]if p in r['input_sha256']else sha(data['O0/'+p])),'changed reused source')
  for e in compiles:check('-O0'in e['command']and '-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked reused build')
 else:
  check('controlled_reuse'not in r,'compatibility requires fresh ABI build')
  for opt in ['O0','O2']:
   builds=[e for e in events if e['category']=='compile'and '-'+opt in e['command']]
   check(len(builds)>=260,'missing fresh compatibility build')
 for opt in ['O0','O2']:
  row=r['runs'][opt];check(row['production_providers']==(260 if compat else 259),'unexpected joint closure')
  check(set(row['drivers'])==set(MARKERS),'missing material driver')
  for d,marker in MARKERS.items():
   entry=row['drivers'][d];check(marker in entry['stdout'],'missing material science '+d)
   es=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==d]
   check(bool(es)and data[es[0]['stdout_file']].decode()==entry['stdout'],'native result identity '+d)
   if d!='test_material_joint':check(len(es)==1,'direct native coverage');continue
   check(entry['empty_batch_identity']is True,'empty batch incumbent not preserved')
   check(data[opt+'/restart.bin.empty-original']==data[opt+'/restart.bin.empty-material'],'empty batch endpoint drift')
   check(len(set(entry['decoder_negatives']))==19 and len(es)==21,'decoder native coverage')
   for e in es[2:]:check(b'INVALID_DISK=PASS'in data[e['stdout_file']],'missing material decoder rejection')
   for p in ['expected.bin','fresh.bin','expected.bin.opaque']:check(sha(data[opt+'/'+p])==entry['endpoint_sha256'],'joint continuation mismatch')
   check(entry['endpoint_sha256']==r['runs']['O0']['drivers'][d]['endpoint_sha256'],'O0 O2 endpoint drift')
  for p,h in r['authority'].items():
   raw=data[opt+'/'+p]
   if p=='wofost_soil_orgmatn.f90':check(sha(raw)=='a17a727e35c453a17be599eede2c501b36baf921b9937edd6b0309dcb26d9696','R1 reference drift')
   else:check(sha(raw)==h,'material literal source drift '+p)
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed material event')
  for stream in ['stdout','stderr']:check(sha(data[e[stream+'_file']])==e[stream+'_sha256'],'raw material event drift')
  if e['category']in ['compile','driver_compile']:
   build=Path(next(a[2:]for a in e['command']if a.startswith('-J')))
   check('-'+build.name in e['command']and '-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked material compile')
 for prefix,count,mode in [('small_process',2,'process'),('small_day',42 if compat else 41,'day')]:
  small=json.loads(data[prefix+'/result.json']);ev=json.loads(data[prefix+'/events.json'])
  check(small['status']=='PASS'and small['mode']==mode and small['source_tree']==source['source_tree'],'unfinished small material closure')
  for p,h in small['input_sha256'].items():input_compatible(p,h,compat)
  for opt in ['O0','O2']:
   check(small['runs'][opt]['production_providers']==count,'small closure drift')
   for d,entry in small['runs'][opt]['drivers'].items():
    check(MARKERS[d]in entry['stdout'],'small science absent')
    native=[e for e in ev if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==d]
    check(len(native)==1 and data[prefix+'/'+native[0]['stdout_file']].decode()==entry['stdout'],'small native coverage')
  for e in ev:
   check(e['returncode']==0,'failed small event')
   if e['category']in ['compile','driver_compile']:
    check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked small compilation')
   for stream in ['stdout','stderr']:check(sha(data[prefix+'/'+e[stream+'_file']])==e[stream+'_sha256'],'small raw drift')
 return r
def read_compat():return capsule(json.loads((ROOT/STATUS).read_text())['coexistence_evidence'])
def validate_compat(data,original,source):
 binding=json.loads(data['ORIGINAL_BINDING.json'])
 check(binding['primary_result_sha256']==sha(original['result.json'])and binding['compatibility_source_tree']==COMPAT_SOURCE,'wrong compatibility primary binding')
 check(binding['native_results_reused']is False and binding['provider_artifacts_reused']is False and binding['persistent_endpoints_byte_identical']is True,'compatibility not freshly rebuilt')
 r=validate(data,{**source,'source_tree':COMPAT_SOURCE},compat=True)
 old=json.loads(original['result.json'])
 for opt in ['O0','O2']:
  check(r['runs'][opt]['drivers']['test_material_joint']['endpoint_sha256']==old['runs'][opt]['drivers']['test_material_joint']['endpoint_sha256'],'default endpoint changed after optional environment ABI')
  for path in ['restart.bin','expected.bin','fresh.bin','expected.bin.opaque','restart.bin.empty-original','restart.bin.empty-material']:
   check(data[opt+'/'+path]==original[opt+'/'+path],'physical compatibility bytes differ '+path)
 return r
def validate_prior(full):
 r=json.loads(full['RESULT.json'])
 check(r['status']=='PASS'and r['returncode']==0 and r['terminal_marker']and not r['changed_inputs'],'missing prior terminal preservation')
 check(sha(full['moving.stdout'])==r['stdout_sha256']and sha(full['moving.stderr'])==r['stderr_sha256'],'prior preservation raw drift')
def validate_peer():
 record=json.loads(git('show',PEER+':integration/audits/MC_NUT01_DAILY_ENVIRONMENT_STATUS.json'))
 evidence=capsule(record['evidence']);r=json.loads(evidence['result.json'])
 check(r['source_tree']==ENV_SOURCE and r['status']=='PHYSICAL_PASS_NOT_ADMITTED','unfinished peer science')
 for p,h in r['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'peer science input drift '+p)
 check(record.get('preserved') is True and record.get('qualified') is True,'peer not preserved')
 full=capsule(record['full_preservation']['evidence']);validate_prior(full)
def verify_qualification():
 if (ROOT/'integration/audits/MC_NUT01_MATERIAL_ENVIRONMENT_STATUS.json').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-material-environment'));import verify_material_environment_successor as successor
  return successor.verify_qualification()
 source=verify_source();original=read_evidence();validate(original,source);validate_compat(read_compat(),original,source)
 old=json.loads(git('show',BASE+':integration/audits/MC_NUT01_CROP_SUPPLY_STATUS.json'))
 full=capsule(old['full_preservation']['evidence']);validate_prior(full)
 validate_peer();baseline_owner();return {**source,'qualified':True,'highest':'NOT_SELECTED_POLICY'}
def incumbent(mode='qualification'):
 if (ROOT/'integration/audits/MC_NUT01_MATERIAL_ENVIRONMENT_STATUS.json').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-material-environment'));import verify_material_environment_successor as successor
  return successor.incumbent(mode)
 verify_qualification();return {**baseline_owner(mode),'material_successor':True,'material_source_tree':git('rev-parse','HEAD:src')}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--incumbent',choices=['source','physical','qualification']);a=p.parse_args()
 print(json.dumps(incumbent(a.incumbent)if a.incumbent else verify_source()if a.source_only else verify_qualification(),indent=2))
