"""Fail-closed scoped thermal evidence; does not grant broad owner admission."""
from pathlib import Path
import argparse,base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/MC_NUT01_ACCEPTED_THERMAL_STATUS.json'
BASE='cd64c5044a29643a068c6151720f76b2e70f570d'
MODIFIED={'src/adapter/mod_crop_soil_n_joint_restart_file.f90','src/runtime/mod_fmr_b111_reactive_n_joint_application.f90','src/runtime/mod_fmr_serialized_reference_backend.f90'}
GUARDS={'tests/nut-input/verify_input_successor.py','tests/nut-input/check_input_controls.py','tests/crop-co2/verify_co2_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'}
ADDED={'src/process/mod_soil_n_profile_temperature.f90','src/runtime/mod_fmr_soil_n_accepted_temperature.f90','src/runtime/mod_fmr_crop_soil_n_thermal_application.f90'}
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def source(git_reader=None):
 g=git if git_reader is None else git_reader
 s=json.loads((ROOT/STATUS).read_text());check(s['baseline']==BASE,'baseline')
 g('merge-base','--is-ancestor',BASE,'HEAD')
 check(s['source_tree']==g('rev-parse','HEAD:src'),'source tree')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty scientific surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 check(rows=={**{p:'A'for p in s['added_blobs']},**{p:'M'for p in s['changed_blobs']}},'foreign or missing delta')
 check(set(s['changed_blobs'])==MODIFIED|GUARDS,'shared delta')
 check({p for p in s['added_blobs']if p.startswith('src/')}==ADDED,'production additions')
 check(all(p in ADDED or p.startswith('tests/nut-thermal/')for p in s['added_blobs']),'foreign addition')
 for p,h in {**s['added_blobs'],**s['changed_blobs']}.items():
  check(g('rev-parse','HEAD:'+p)==h,'unbound postimage '+p)
  raw=(ROOT/p).read_bytes();check(hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==h,'dirty postimage '+p)
 return s
def read(s):
 e=s['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes())
 check(len(raw)==e['decoded_bytes']and sha(raw)==e['sha256'],'capsule identity')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe member')
  d={m.name:a.extractfile(m).read()for m in ms};check(len(ms)==e['members']==len(d),'member count or duplicate')
 manifest=json.loads(d.pop('MANIFEST.json'));check(set(d)==set(manifest),'manifest coverage')
 for p,h in manifest.items():check(sha(d[p])==h,'raw drift '+p)
 return d
def inputs(d,r,key,prefix=''):
 for p,h in r[key].items():
  check(not Path(p).is_absolute()and '..'not in Path(p).parts,'unsafe input')
  raw=d[prefix+'drivers/'+Path(p).name]if p.startswith('generated/')else(ROOT/p).read_bytes()
  check(sha(raw)==h,'stale input '+p)
def events(d,prefix):
 es=json.loads(d[prefix+'events.json'])
 for i,e in enumerate(es):
  check(e['returncode']==0 and e['seconds']>=0,'failed selected event')
  check('reused_from_event'not in e,'final build must be fresh')
  if e['category']in ['compile','driver_compile']:
   check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked compile')
  for stream in ['stdout','stderr']:
   p=e.get(stream+'_file',str(i)+'.'+stream)
   check(prefix+p in d,'missing raw '+p)
   if stream+'_sha256'in e:check(sha(d[prefix+p])==e[stream+'_sha256'],'raw event digest')
 return es
def validate(d,s):
 check(sha(d[s['execution_bundle']['member']])==s['execution_bundle']['sha256'],'execution history bundle')
 prior=json.loads((ROOT/'integration/audits/MC_NUT01_AMENDMENT_INPUT_STATUS.json').read_text())['evidence']
 raw=base64.b64decode((ROOT/prior['path']).read_bytes());check(sha(raw)==prior['sha256'],'baseline capsule')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  for opt in ['O0','O2']:
   for suffix,h in s['baseline_native_sha256'][opt].items():
    old=a.extractfile('joint/'+opt+'/manual-'+suffix).read()
    check(sha(old)==h,'baseline native receipt')
 p=json.loads(d['profile/result.json']);check(p['status']=='PASS'and p['providers']==1 and p['fixtures']==23,'small driver coverage')
 check(p['authority_sha256']=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'and p['literal_body_sha256']=='b3fb17c4c0e29d8935a962911c8a9e5134bf7b5fdcd3c19f82228a602dfc1429','literal source authority')
 check(p['source_tree']==s['source_tree'],'stale reducer source');inputs(d,p,'inputs')
 pe=events(d,'profile/');check(len(pe)==8,'small build/run count')
 for i,e in enumerate(pe):
  if e['category']=='native':check(b'NUT_THERMAL_LITERAL_PROFILE=PASS'in d['profile/'+str(i)+'.stdout'],'literal native assertions')
 for opt in ['O0','O2']:
  es=[e for e in pe if '/'+opt+'/'in' '.join(e['command'])]
  check({e['category']for e in es}=={'compile','driver_compile','link','native'},'small O0/O2')
 r=json.loads(d['joint/result.json']);check(r['status']=='PASS'and r['source_tree']==s['source_tree'],'unfinished/stale physical composition')
 inputs(d,r,'input_sha256','joint/');gen=json.loads(d['joint/GENERATION.json']);inputs(d,gen,'inputs')
 check(sha(d['joint/executed_runner.py'])==gen['runner_sha256'],'executed runner')
 check(sha(d['joint/drivers/test_thermal_joint.f90'])==gen['generated_driver_sha256'],'generated driver')
 es=events(d,'joint/')
 expected={'test_calendar','test_calendar_day','test_calendar_joint','test_thermal_joint'}
 production={p for p in r['input_sha256']if p.startswith('src/')}
 check(ADDED<=production and MODIFIED<=production,'missing thermal/shared provider')
 for opt in ['O0','O2']:
  row=r['runs'][opt];check(set(row['drivers'])==expected,'missing physical driver')
  check(row['production_providers']==len(production),'provider closure')
  compiles=[e for e in es if e['category']=='compile'and '-'+opt in e['command']]
  compiled={'src/'+e['command'][e['command'].index('-c')+1].split('/src/',1)[1]for e in compiles if '/src/'in e['command'][e['command'].index('-c')+1]}
  check(compiled==production,'incomplete fresh provider compilation')
  for name in expected:
   for category in ['driver_compile','link']:
    check(sum(e['category']==category and '-'+opt in e['command']and any(Path(x).name==name+('.f90'if category=='driver_compile'else'')for x in e['command'])for e in es)==1,'missing driver/link')
  for name,prefix in [('test_calendar_joint',''),('test_thermal_joint','thermal-')]:
   natives=[e for e in es if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==name]
   check(len(natives)==4,'physical native execution count')
   check(set(row['drivers'][name])=={'manual','calendar'},'manual/calendar coverage')
   for profile,entry in row['drivers'][name].items():
    for mode,key in [('write','stdout'),('resume','fresh_stdout')]:
     actual=[e for e in natives if e['command'][1]==mode and e['command'][-1]==profile]
     check(len(actual)==1 and d['joint/'+actual[0]['stdout_file']].decode()==entry[key],'physical raw native binding')
    marker='THERMAL_'if prefix else'CALENDAR_'
    check(marker+'ACTUAL_RICHARDS_DELAYED_LITERAL_ATOMIC_PENDING_OPAQUE_DISK=PASS'in entry['stdout'],'physical assertions absent')
    check('FRESH_PROCESS_CONTINUATION=PASS'in entry['fresh_stdout'],'fresh continuation absent')
    for suffix,key in [('restart.bin','restart_sha256'),('expected.bin','endpoint_sha256'),('fresh.bin','endpoint_sha256'),('expected.bin.opaque','endpoint_sha256')]:
     raw=d['joint/'+opt+'/'+prefix+profile+'-'+suffix]
     check(sha(raw)==entry[key],'native endpoint identity')
     check(raw==d['joint/'+opt+'/'+prefix+'manual-'+suffix],'manual/calendar mismatch')
     if prefix:check(raw[:8]==b'S5NC0004','thermal pending tag')
     else:check(sha(raw)==s['baseline_native_sha256'][opt][suffix],'BASE native drift')
    check(entry['endpoint_sha256']==r['runs']['O0']['drivers'][name][profile]['endpoint_sha256'],'O0/O2 endpoint drift')
 policy=json.loads(d['policy/result.json']);check(policy['status']=='PASS'and policy['cases']==14,'backend seam coverage')
 check(policy['composition_result_sha256']==sha(d['joint/result.json']),'policy build binding')
 check(policy['generated_driver_sha256']==sha(d['policy/test_trace_policy.f90']),'policy driver binding')
 policy_events=events(d,'policy/');check(len(policy_events)==6,'policy build/run count')
 for i,e in enumerate(policy_events):
  if e['category']=='native':check(b'THERMAL_TRACE_EXPLICIT_POLICY=PASS'in d['policy/'+str(i)+'.stdout'],'policy native assertions')
 for opt in ['O0','O2']:
  raw=d['policy/'+opt+'-initial.bin']
  check(raw[:8]==b'S5NC0003'and sha(raw)==policy['initial_native_sha256'][opt],'native no-pending profile')
 restart=json.loads(d['restart/results.json']);check(restart['status']=='PASS'and restart['cases']==22,'native negative coverage')
 check(len(restart['results'])==22,'native negative count')
 for e in restart['results']:
  prefix='restart/'+e['opt']+'-'+e['case'];check(e['returncode']==0,'failed corruption probe')
  for suffix,key in [('.bin','input_sha256'),('.stdout','stdout_sha256'),('.stderr','stderr_sha256')]:
   check(sha(d[prefix+suffix])==e[key],'negative raw digest')
  check(b'CROP_SOIL_INVALID_DISK=PASS'in d[prefix+'.stdout'],'atomic negative assertion absent')
 return dict(status='SCOPED_THERMAL_SCIENCE_PASS',qualified_scope='literal reduction and actual thermal Richards/crop/N/pending/opaque/native continuation',source_tree=s['source_tree'],full_fci='NOT_SELECTED',canonical_admission=False)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--source-only',action='store_true');args=parser.parse_args()
 s=source();print(json.dumps(dict(status='SOURCE_PASS',source_tree=s['source_tree'])if args.source_only else validate(read(s),s),indent=2))
