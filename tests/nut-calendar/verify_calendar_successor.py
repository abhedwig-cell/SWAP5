#!/usr/bin/env python3
"""Exact additive calendar, original authority and actual raw native proof."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile,math
ROOT=Path(__file__).resolve().parents[2];BASE='e22a677146ef49d14bd6dd6e72b78f60e340bcab'
STATUS='integration/audits/MC_NUT01_AMENDMENT_CALENDAR_STATUS.json'
GUARDS={'tests/nut-material-environment/verify_material_environment_successor.py','tests/crop-co2/verify_co2_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'}
PRODUCTION={'src/process/mod_b111_amendment_calendar.f90','src/crop/mod_crop_soil_n_calendar_day.f90','src/runtime/mod_fmr_crop_soil_n_calendar_application.f90'}
MARKERS={'test_calendar_day':'CALENDAR_REAL_WOFOST81_LITERAL_EVENT_NONE_ATOMIC_RETRY_REPLAY=PASS','test_calendar_joint':'CALENDAR_RICHARDS_LITERAL_EVENTS_NOEVENT_ATOMIC_RESTART=PASS'}
AUTHORITY='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def status():return json.loads((ROOT/STATUS).read_text())
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;s=status()
 check(s['baseline']==BASE,'unknown calendar baseline');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty calendar dependencies')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected={p:'A'for p in s['added_blobs']};expected.update({p:'M'for p in GUARDS})
 check(set(s['changed_blobs'])==GUARDS and rows==expected,'foreign calendar delta')
 check({p for p in s['added_blobs']if p.startswith('src/')}==PRODUCTION,'calendar production scope')
 for p,h in {**s['added_blobs'],**s['changed_blobs']}.items():check(g('rev-parse','HEAD:'+p)==h==blob((ROOT/p).read_bytes()),'unknown calendar postimage '+p)
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'reference mutation')
 check(g('rev-parse','HEAD:src')==s['source_tree'],'wrong calendar source')
 return dict(baseline=BASE,source_tree=s['source_tree'],current_source_tree=s['source_tree'],calendar_successor=True,qualified=False,admitted=False)
def capsule(record):
 raw=base64.b64decode((ROOT/record['path']).read_bytes());check(sha(raw)==record['sha256'],'calendar capsule digest')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe member')
  check(len({m.name for m in ms})==len(ms),'duplicate member');d={m.name:a.extractfile(m).read()for m in ms}
 check(len(ms)==record['members']and len(raw)==record['decoded_bytes'],'capsule dimensions')
 manifest=json.loads(d.pop('MANIFEST.json'));check(set(d)==set(manifest),'manifest coverage')
 for p,h in manifest.items():check(sha(d[p])==h,'raw member digest '+p)
 return d
def read_evidence():return capsule(status()['evidence'])
def inputs(r,source):
 check(r['status']=='PASS'and r['source_tree']==source['source_tree'],'unfinished/stale calendar science')
 for p,h in r['input_sha256'].items():
  check(not Path(p).is_absolute()and '..'not in Path(p).parts,'unsafe input')
  check(sha((ROOT/p).read_bytes())==h,'calendar input drift '+p)
def events(data,prefix,rows,reference_negative=False):
 for e in rows:
  expected=7 if reference_negative and e['category']=='reference_reject'else 0
  check(e['returncode']==expected and math.isfinite(e['seconds'])and e['seconds']>=0,'failed calendar event')
  for stream in ['stdout','stderr']:check(sha(data[prefix+e[stream+'_file']])==e[stream+'_sha256'],'calendar raw log drift')
  if e['category']in ['compile','driver_compile']:
   check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked calendar compilation')
   check(any(x in e['command']for x in ['-O0','-O2']),'missing calendar optimization')
def validate(data,source):
 r=json.loads(data['result.json']);ev=json.loads(data['events.json']);inputs(r,source)
 check(r['mode']=='joint'and 'controlled_reuse'not in r,'not fresh actual calendar composition')
 check(PRODUCTION<=set(r['input_sha256']),'untested calendar production')
 check(r['authority']['management_soil.f90']==AUTHORITY,'calendar original authority')
 for opt in ['O0','O2']:
  row=r['runs'][opt];check(row['production_providers']==263 and set(row['drivers'])==set(MARKERS),'calendar composition closure/coverage')
  builds=[e for e in ev if e['category']=='compile'and '-'+opt in e['command']]
  check(len(builds)>=263,'fresh calendar ABI build missing')
  for name,marker in MARKERS.items():
   entry=row['drivers'][name];native=[e for e in ev if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==name]
   check(len(native)==(21 if name.endswith('_joint')else 1),'calendar actual native coverage')
   check(marker in entry['stdout']and data[native[0]['stdout_file']].decode()==entry['stdout'],'calendar native literal assertions')
   if not name.endswith('_joint'):continue
   check(len(set(entry['decoder_negatives']))==19 and entry['empty_batch_identity']is True,'calendar decoder/empty proof missing')
   for e in native[2:]:check(b'INVALID_DISK=PASS'in data[e['stdout_file']],'calendar decoder failed rejection')
   for p in ['expected.bin','fresh.bin','expected.bin.opaque']:check(sha(data[opt+'/'+p])==entry['endpoint_sha256'],'calendar continuation mismatch')
   check(sha(data[opt+'/restart.bin'])==entry['restart_sha256'],'calendar restart mismatch')
   check(entry['endpoint_sha256']==r['runs']['O0']['drivers'][name]['endpoint_sha256'],'calendar O0 O2 endpoint drift')
  for a,b in [('restart.bin.empty-original','restart.bin.empty-material'),('restart.bin.noevent-calendar','restart.bin.noevent-original'),('restart.bin.initial','restart.bin.rejected')]:
   check(data[opt+'/'+a]==data[opt+'/'+b],'calendar no-event/rollback full bytes')
  for p,h in r['authority'].items():
   want='a17a727e35c453a17be599eede2c501b36baf921b9937edd6b0309dcb26d9696'if p=='wofost_soil_orgmatn.f90'else h
   check(sha(data[opt+'/'+p])==want,'calendar compiled original source drift '+p)
 events(data,'',ev)
 small=json.loads(data['small_day/result.json']);sev=json.loads(data['small_day/events.json']);inputs(small,source)
 check(small['mode']=='day','small calendar route missing')
 for opt in ['O0','O2']:
  row=small['runs'][opt];check(row['production_providers']==44 and set(row['drivers'])=={'test_calendar_day'},'small calendar closure')
  native=[e for e in sev if e['category']=='native'and '/'+opt+'/'in e['command'][0]]
  check(len(native)==1 and MARKERS['test_calendar_day']in row['drivers']['test_calendar_day']['stdout']and data['small_day/'+native[0]['stdout_file']].decode()==row['drivers']['test_calendar_day']['stdout'],'small calendar native assertions')
 events(data,'small_day/',sev)
 tiny=json.loads(data['contract/result.json']);tev=json.loads(data['contract/events.json']);inputs(tiny,source)
 check(tiny['authority_sha256']==AUTHORITY,'tiny original source drift')
 for opt in ['O0','O2']:
  row=tiny['runs'][opt];check(row['production_providers']==3,'tiny calendar closure')
  ns=[e for e in tev if e['category']=='native'and '/'+opt+'/'in e['command'][0]]
  rs=[e for e in tev if e['category']=='reference_reject'and '/'+opt+'/'in e['command'][0]]
  check(len(ns)==len(rs)==1,'tiny calendar native/reference rejection coverage')
  check(data['contract/'+ns[0]['stdout_file']].decode()==row['stdout']and 'CALENDAR_LITERAL_TRIGGER_CASES=241'in row['stdout']and 'CALENDAR_REAL_UNITS_INDEX_SORT_DOMAIN_15_INVALID_EMPTY=PASS'in row['stdout'],'tiny literal calendar assertions')
  check(b'LEGACY_UNSORTED_CALENDAR_REJECT=PASS'in data['contract/'+rs[0]['stdout_file']],'original unsorted source not executed')
  check(sha(data['contract/'+opt+'/management_soil.f90'])==AUTHORITY and sha(data['contract/'+opt+'/literal_calendar.f90'])==tiny['oracle_sha256'],'tiny literal compiled source changed')
 events(data,'contract/',tev,True)
 return r
def baseline_owner():
 root=ROOT.parent/('calendar-baseline-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'calendar baseline moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip(),'calendar baseline dirty')
 p=subprocess.run([sys.executable,'-B','tests/nut-material-environment/verify_material_environment_successor.py'],cwd=root,check=True,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 return json.loads(p.stdout)
def verify_prior():
 prior=json.loads(git('show',BASE+':integration/audits/MC_NUT01_MATERIAL_ENVIRONMENT_STATUS.json'))
 raw=capsule(prior['evidence']);r=json.loads(raw['result.json'])
 for p,h in r['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'incumbent scientific input changed '+p)
 full=capsule(prior['full_preservation']['evidence']);r=json.loads(full['RESULT.json'])
 check(r['status']=='PASS'and r['returncode']==0 and r['terminal_marker']and not r['changed_inputs'],'prior terminal preservation missing')
 check(sha(full['moving.stdout'])==r['stdout_sha256']and sha(full['moving.stderr'])==r['stderr_sha256'],'prior raw preservation drift')
def verify_qualification():
 source=verify_source();validate(read_evidence(),source);verify_prior();baseline_owner()
 return {**source,'qualified':True,'highest':'NOT_SELECTED_POLICY'}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');a=p.parse_args()
 print(json.dumps(verify_source()if a.source_only else verify_qualification(),indent=2))
