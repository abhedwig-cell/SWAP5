"""Exact CI-only successor authority; production and original scientific assertions fixed."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[3]
STATUS='integration/audits/MC_SOL01_SURFACE_AGE03_CI_STATUS.json'
SURFACE=['src','tests','tools','reference','.github','integration/audits/surface_age_ci','integration/audits/surface_age_longrun/verify.py']
def check(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())
def verify_source():
 s=record();base=s['baseline'];git('merge-base','--is-ancestor',base,'HEAD')
 check(not git('status','--porcelain','--',*SURFACE),'dirty CI successor surface')
 check(not git('diff',base,'HEAD','--','src','reference'),'CI successor changed production/reference')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',base,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in s['postimages'].items()},'foreign CI successor delta')
 for p,v in s['postimages'].items():check(sha((ROOT/p).read_bytes())==v['sha256'],'unqualified CI successor '+p)
 return dict(ci_successor=True,production_changed=False,qualified=False)
def evidence():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes());check(sha(raw)==e['decoded_sha256'],'CI evidence integrity')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();check(len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'unsafe CI capsule');f={m.name:t.extractfile(m).read()for m in ms}
 manifest=json.loads(f.pop('MANIFEST.json'));check(set(f)==set(manifest),'CI evidence inventory')
 for p,h in manifest.items():check(sha(f[p])==h,'CI evidence member '+p)
 return f
def validate(f):
 r=json.loads(f['result.json']);check(r['status']=='THREE_EXISTING_CI_ROUTES_LOCAL_PASS','unfinished CI science')
 check(r['execution_commit']==record()['execution_commit'],'unbound CI execution')
 for p,h in r['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'stale CI science input '+p)
 required={'fci51':'FCI51P_SUCCESSOR_O0_O2_PRESERVATION=PASS','fci58':'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS','fgc':'F_GC_CLOSEOUT_FIXED_INTERFACE_GATE_PASS'}
 check({e['case']for e in r['events']}==set(required),'missing CI route')
 for e in r['events']:
  check(e['returncode']==0,'failed CI science')
  for stream in ['stdout','stderr']:check(e[stream]in f,'missing CI raw stream')
  text=f[e['stdout']].decode();check(required[e['case']]in text,'missing original CI final assertion '+e['case'])
 # Every declared compiler invocation is recorded by the local compiler wrapper.
 ee=json.loads(f['compiler-events.json']);check(ee and all(e['returncode']==0 for e in ee),'failed/unrecorded compiler')
 for opt in ['-O0','-O2']:check(any(opt in e['args']and'-c'in e['args']for e in ee),'missing optimization build')
 return dict(qualified=True,three_routes=True,production_changed=False)
def verify_qualification():return {**verify_source(),**validate(evidence())}
if __name__=='__main__':
 import sys
 print(json.dumps(verify_source()if '--source-only'in sys.argv else verify_qualification(),indent=2))
