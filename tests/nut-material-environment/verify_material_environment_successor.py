#!/usr/bin/env python3
"""Strict simultaneous forcing successor; complete raw native proof, no copied PASS."""
from pathlib import Path
import ast,argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='fb311dabd16266409deb394c381fe26086a64d03'
STATUS='integration/audits/MC_NUT01_MATERIAL_ENVIRONMENT_STATUS.json'
CHANGED={'src/crop/mod_crop_soil_n_material_day.f90','src/runtime/mod_fmr_crop_soil_n_material_application.f90','tests/nut-material/verify_material_successor.py','tests/nut-material/check_material_controls.py'}
MARKERS={'test_material_addition':'MATERIAL_LITERAL_12_CASES_WHOLE_N_OM_THRESHOLDS_8_INVALID=PASS','test_material_day':'MATERIAL_REAL_WOFOST81_LITERAL_EIGHT_POOLS_ATOMIC_RETRY_REPLAY_EMPTY=PASS','test_material_joint':'MATERIAL_ACTUAL_RICHARDS_WOFOST81_LITERAL_ATOMIC_REPLAY_OPAQUE_DISK=PASS','test_material_environment_day':'MATERIAL_ENVIRONMENT_DAY_LITERAL_5_30_ATOMIC_7_INVALID_ABA_EMPTY=PASS','test_material_environment_joint':'MATERIAL_ENVIRONMENT_RICHARDS_LITERAL_5_30_ATOMIC_STALE_OPAQUE_DISK=PASS'}
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def verify_source(git_reader=None):
 if (ROOT/'integration/audits/MC_NUT01_AMENDMENT_CALENDAR_STATUS.json').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-calendar'));import verify_calendar_successor as calendar
  result=calendar.verify_source(git_reader=git if git_reader is None else git_reader)
  return {**result,'source_tree':'232ecd0c3eb03c9ddedf74e70baf65cfaf4b8bd3'}
 g=git if git_reader is None else git_reader;s=json.loads((ROOT/STATUS).read_text())
 check(s['baseline']==BASE,'unknown baseline');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty scientific surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected={p:'A'for p in s['added_blobs']};expected.update({p:'M'for p in CHANGED})
 check(rows==expected,'foreign simultaneous forcing delta');check(set(s['changed_blobs'])==CHANGED,'incomplete changed surface')
 for p,h in {**s['added_blobs'],**s['changed_blobs']}.items():check(g('rev-parse','HEAD:'+p)==h==blob((ROOT/p).read_bytes()),'unknown postimage '+p)
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'immutable reference changed')
 return dict(baseline=BASE,source_tree=g('rev-parse','HEAD:src'),current_source_tree=g('rev-parse','HEAD:src'),material_environment_successor=True,qualified=False,admitted=False)
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
 root=ROOT.parent/('material-environment-baseline-'+BASE[:12])
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
 check({p for p in CHANGED if p.startswith('src/')and(mode=='joint'or p.startswith('src/crop/'))}<=r['input_sha256'].keys(),'untested production')
 old=capsule(json.loads((ROOT/'integration/audits/MC_NUT01_MATERIAL_CYCLE_STATUS.json').read_text())['coexistence_evidence'])
 prior=json.loads(old['result.json']);check(r['authority']==prior['authority'],'historical authority changed')
 check('controlled_reuse'not in r,'unexpected provider/native reuse')
 expected=set(MARKERS)if mode=='joint'else {'test_material_addition','test_material_day','test_material_environment_day'}
 for opt in ['O0','O2']:
  row=r['runs'][opt];check(row['production_providers']==(260 if mode=='joint'else 42),'closure drift')
  check(set(row['drivers'])==expected,'driver coverage')
  builds=[e for e in events if e['category']=='compile'and '-'+opt in e['command']]
  check(len(builds)>=row['production_providers'],'missing fresh provider build')
  compiled={'src/'+e['command'][e['command'].index('-c')+1].split('/src/',1)[1]for e in builds if '/src/'in e['command'][e['command'].index('-c')+1]}
  check(compiled=={p for p in r['input_sha256']if p.startswith('src/')},'fresh production provider coverage')
  for name,entry in row['drivers'].items():
   check(MARKERS[name]in entry['stdout'],'native science missing '+name)
   es=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==name]
   check(len(es)==(21 if name.endswith('_joint')else 1),'native execution coverage '+name)
   check(d[prefix+es[0]['stdout_file']].decode()==entry['stdout'],'raw native identity '+name)
   if not name.endswith('_joint'):continue
   check(len(set(entry['decoder_negatives']))==19,'decoder coverage')
   for e in es[2:]:check(b'INVALID_DISK=PASS'in d[prefix+e['stdout_file']],'decoder rejection absent')
   stem=''if name=='test_material_joint'else'environment-'
   check(d[prefix+opt+'/'+stem+'restart.bin.empty-original']==d[prefix+opt+'/'+stem+'restart.bin.empty-material'],'empty forced route identity')
   for path in ['expected.bin','fresh.bin','expected.bin.opaque']:check(sha(d[prefix+opt+'/'+stem+path])==entry['endpoint_sha256'],'continuation endpoint mismatch')
   check(entry['endpoint_sha256']==r['runs']['O0']['drivers'][name]['endpoint_sha256'],'optimization endpoint drift')
   if name=='test_material_joint':
    for path in ['restart.bin','expected.bin','fresh.bin','expected.bin.opaque','restart.bin.empty-original','restart.bin.empty-material']:check(d[prefix+opt+'/'+path]==old[opt+'/'+path],'original material endpoint changed '+path)
  management=d[prefix+opt+'/management_soil.f90'].decode()
  start=management.index('! Mineralisation, but Nminer is negative in case of immobilisation');end=management.index('      Call Wofost_SoilBalanceCheck',start)
  check(management[start:end].encode()in d[prefix+opt+'/literal_crop_exchange.f90'],'literal uptake block replaced')
  script=ast.parse((ROOT/'tests/nut-material-environment/run_material_environment.py').read_text())
  wrapper=next(ast.literal_eval(n.value)for n in script.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='oracle'for t in n.targets))
  check(d[prefix+opt+'/material_oracle.inc']==wrapper.encode(),'material literal wrapper replaced')
  for name,h in r['authority'].items():
   expected_hash='a17a727e35c453a17be599eede2c501b36baf921b9937edd6b0309dcb26d9696'if name=='wofost_soil_orgmatn.f90'else h
   check(sha(d[prefix+opt+'/'+name])==expected_hash,'literal source changed '+name)
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed scientific event')
  if e['category']in ['compile','driver_compile']:
   check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked compilation')
  for stream in ['stdout','stderr']:check(sha(d[prefix+e[stream+'_file']])==e[stream+'_sha256'],'event digest drift')
 if mode=='joint':check(r['original_material_endpoints_identical']is True,'original profile not preserved')
 return r
def validate(d,source):
 result=validate_events(d,'',source,'joint');validate_events(d,'direct/',source,'day');return result
def verify_qualification():
 if (ROOT/'integration/audits/MC_NUT01_AMENDMENT_CALENDAR_STATUS.json').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-calendar'));import verify_calendar_successor as calendar
  calendar.verify_qualification()
  return {**verify_source(),'qualified':True,'highest':'NOT_SELECTED_POLICY'}
 source=verify_source();validate(read_evidence(),source)
 baseline_command('tests/nut-material/verify_material_successor.py')
 return {**source,'qualified':True,'highest':'NOT_SELECTED_POLICY'}
def incumbent(mode='qualification'):
 verify_qualification();return {**baseline_command('tests/nut-material/verify_material_successor.py',['--incumbent',mode]),'material_environment_successor':True,'material_environment_source_tree':git('rev-parse','HEAD:src')}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--incumbent',choices=['source','physical','qualification']);a=p.parse_args()
 print(json.dumps(incumbent(a.incumbent)if a.incumbent else verify_source()if a.source_only else verify_qualification(),indent=2))
