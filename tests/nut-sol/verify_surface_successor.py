#!/usr/bin/env python3
"""Exact additive surface route and independently source-bound Fortran evidence."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
BASE='f8eca95ba623dc18db0110cd1b84af46857c8b9b'
STATUS='integration/audits/MC_SOL01_SURFACE_INPUT_STATUS.json'
CAPSULE_SHA='4293d22d3a572337d367ad5e84e83ef1e1dec127b704559bb6d35ce5d6068338'
GUARDS={'tests/crop-co2/verify_co2_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'}
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def sha(raw):return hashlib.sha256(raw).hexdigest()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def validate_delta(rows,tree,s):
 expected={p:'A' for p in s['added_blobs']};expected.update({p:'M' for p in GUARDS})
 check(rows==expected,'foreign surface dependency delta')
 check(set(s['guard_blobs'])==GUARDS,'surface guard coverage')
 for p,h in {**s['added_blobs'],**s['guard_blobs']}.items():check(tree.get(p)==h,'unqualified surface postimage '+p)
def verify_source():
 s=json.loads((ROOT/STATUS).read_text());check(s['baseline']==BASE,'wrong surface baseline')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 check(not git('status','--porcelain','--','src','tests','tools','reference'),'dirty surface dependencies')
 rows={r.split('\t')[1]:r.split('\t')[0] for r in git('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 tree={r.split('\t')[1]:r.split('\t')[0].split()[2] for r in git('ls-tree','-r','HEAD').splitlines()}
 validate_delta(rows,tree,s)
 for p,h in {**s['added_blobs'],**s['guard_blobs']}.items():check(blob((ROOT/p).read_bytes())==h,'dirty surface postimage '+p)
 check(git('rev-parse','HEAD:reference')==git('rev-parse',BASE+':reference'),'surface reference mutation')
 return dict(baseline=BASE,source_tree=git('rev-parse','HEAD:src'),qualified=False,admitted=False)
def read_evidence():
 s=json.loads((ROOT/STATUS).read_text());raw=base64.b64decode((ROOT/s['evidence']['path']).read_bytes())
 check(sha(raw)==s['evidence']['sha256']==CAPSULE_SHA,'surface capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as a:
  members=a.getmembers();check(all(m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts for m in members),'unsafe surface capsule')
  check(len({m.name for m in members})==len(members),'duplicate surface evidence')
  data={m.name:a.extractfile(m).read() for m in members}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(manifest)==set(data),'incomplete surface manifest')
 for p,h in manifest.items():check(sha(data[p])==h,'surface member drift '+p)
 return data
def validate_evidence(data):
 s=json.loads((ROOT/STATUS).read_text());r=json.loads(data['stable/result.json']);events=json.loads(data['stable/events.json'])
 check(r['status']=='PHYSICAL_PASS_NOT_ADMITTED','unfinished surface qualification')
 check(r['baseline']==s['execution_commit'],'wrong surface execution')
 check(r['authority_sha256']=='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2','wrong surface authority')
 check(r['literal_lines']==[[346,355],[361,432],[442,442],[455,455]],'different surface literal source')
 for p,h in r['input_sha256'].items():
  check(not Path(p).is_absolute() and '..' not in Path(p).parts,'unsafe surface input')
  check(sha((ROOT/p).read_bytes())==h,'stale surface physical input '+p)
 production={p for p in s['added_blobs'] if p.startswith('src/')}
 check(production<=r['input_sha256'].keys(),'untested surface production')
 for opt in ('O0','O2'):
  row=r['runs'][opt]
  check(row['process_provider_count']==2,'surface process closure')
  check('SURFACE_LITERAL_150_UNITS_BALANCE_INVALID_CUTOFF=PASS' in row['process_stdout'],'surface process absent')
  check('SURFACE_JOINT_ATOMIC_BALANCE_LITERAL_RESTART=PASS' in row['physical_stdout'],'surface joint absent')
  check(row['physical_stdout'].count('SURFACE_ACTUAL_LITERAL_FOURTEEN_NEGATIVES_REPLAY=PASS')==2,'surface signed trajectories incomplete')
  check(sha(data['stable/'+opt+'/literal_age.f90'])==row['oracle_sha256'],'surface process oracle drift')
  check(sha(data['stable/'+opt+'/expected.bin'])==sha(data['stable/'+opt+'/fresh.bin'])==row['endpoint_sha256']==row['fresh_sha256'],'surface restart endpoint drift')
  compiles=[e for e in events if e['category']=='physical_compile' and '-'+opt in e['command']]
  check(len(compiles)==row['physical_provider_count']+1,'surface compile coverage')
  for p in production:check(sum(str(e['command'][e['command'].index('-c')+1]).endswith('/'+p) for e in compiles)==1,'surface provider not compiled '+p)
  for e in compiles:check('-fcheck=all' in e['command'] and '-ffpe-trap=invalid,zero,overflow' in e['command'],'surface runtime checks removed')
  natives=[e for e in events if e['category']=='physical_native' and '/'+opt+'/' in e['command'][0]]
  check(len(row['restart_negatives'])==10 and len(natives)==12,'surface restart negatives incomplete')
  check(natives[0]['command'][1]=='write' and natives[1]['command'][1]=='resume','surface native identity')
  check(data['stable/'+natives[0]['stdout']].decode()==row['physical_stdout'],'surface raw assertions drift')
  check(b'SURFACE_JOINT_FRESH_PROCESS=PASS' in data['stable/'+natives[1]['stdout']],'surface fresh process absent')
  for e in natives[2:]:check(b'MATRIX_JOINT_INVALID_FILE=PASS' in data['stable/'+e['stdout']],'surface decoder negative absent')
  process=[e for e in events if e['category']=='process_native' and '/'+opt+'/' in e['command'][0]]
  check(len(process)==1 and data['stable/'+process[0]['stdout']].decode()==row['process_stdout'],'surface raw process drift')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed surface command')
  for stream in ('stdout','stderr'):check('stable/'+e[stream] in data,'surface raw stream absent')
 check(r['runs']['O0']['endpoint_sha256']==r['runs']['O2']['endpoint_sha256'],'surface O0/O2 drift')
 return r
def verify_qualification():
 source=verify_source();validate_evidence(read_evidence());return {**source,'qualified':True,'highest':'NOT_SELECTED_POLICY'}
def incumbent_mineral():
 verify_qualification()
 base=ROOT.parent/'surface-incumbent-f8eca95b'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'wrong surface incumbent')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=base,text=True).strip(),'dirty surface incumbent')
 p=subprocess.run([sys.executable,'-B','tests/nut-sol/verify_age_successor.py','--incumbent-mineral'],cwd=base,check=True,capture_output=True,text=True,
  env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 return json.loads(p.stdout)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--incumbent-mineral',action='store_true');a=p.parse_args()
 print(json.dumps(incumbent_mineral() if a.incumbent_mineral else verify_source() if a.source_only else verify_qualification(),indent=2))
