"""Seal only the live-canonical reconciliation; original481-day proof is immutable."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;W=ROOT.parent
BASE='03c1c7a41d66924e2d974275cd14d4bdc4101047';sha=lambda b:hashlib.sha256(b).hexdigest();files={};excluded={}
def add(k,p):files[k]=Path(p).read_bytes()
def folder(label,p):
 for f in sorted(p.rglob('*')):
  if f.is_symlink()or not f.is_file()or'__pycache__'in f.parts:continue
  raw=f.read_bytes();k=label+'/'+str(f.relative_to(p))
  if f.suffix in ['.o','.mod','.a']or raw.startswith(b'\x7fELF'):excluded[k]=dict(sha256=sha(raw),bytes=len(raw));continue
  files[k]=raw
folder('hist',W/'day470-latest-hist2');folder('joint',W/'day470-latest-joint')
add('frozen.json',W/'day470-latest-frozen.json');add('frozen-reactive.json',W/'day470-latest-frozen-reactive.json')
add('prior-hist.json','/workspace/scratch/281436eb488f/nut-singular-hist-02/result.json')
add('prior-joint.json','/workspace/scratch/281436eb488f/nut-singular-joint-01/result.json')
folder('pulse/current',W/'day470-latest-pulse2');p=W/'day470-latest-pulse2';r=json.loads((p/'execution.json').read_text());assert r['status']=='EXECUTED'
files['pulse/ROUNDS.json']=b'["current"]'
files['pulse/current/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',r['baseline']],cwd=ROOT)
old=json.loads(files['frozen-reactive.json']);assert len(old['controls'])==8
proof=json.loads(files['frozen.json']);assert len(proof['controls'])==179 and proof['owner']['qualified']
files['pulse/PRESERVATION.json']=json.dumps(dict(qualified=True,controls=179,reactive_controls=8,scope='Exact canonical frozen owner; current matched source and physics checked separately')).encode()
for name,h in r['inputs'].items():
 raw=(ROOT/name).read_bytes();assert sha(raw)==h;files['pulse/current/source/'+name]=raw
add('host/launch_checked.py',W/'day470_launch_checked.py')
folder('failed/pulse',W/'day470-latest-pulse');folder('failed/hist',W/'day470-latest-hist')
files['EXCLUDED.json']=json.dumps(excluded,indent=2).encode();files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in files.items()},sort_keys=True,indent=2).encode()
b=io.BytesIO()
with tarfile.open(fileobj=b,mode='w:xz',preset=6)as t:
 for p,raw in sorted(files.items()):
  m=tarfile.TarInfo(p);m.size=len(raw);m.mode=0o644;m.mtime=0;t.addfile(m,io.BytesIO(raw))
raw=b.getvalue();(HERE/'EVIDENCE_DAY470_CURRENT.tar.xz.b64').write_bytes(base64.b64encode(raw))
record=json.loads((HERE/'DAY470_STATUS.json').read_text());record['baseline']=BASE;record['last_reconciled_head']=BASE
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
delta=subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--',*science],cwd=ROOT,text=True)
record['scientific_delta']={s.split('\t')[1]:s.split('\t')[0]for s in delta.splitlines()}
paths=set(record['scientific_delta'])|{'integration/mc-sol01/drainage/seal_day470.py','integration/mc-sol01/drainage/seal_day470_current.py'}
record['postimages']={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
record['current_evidence']=dict(path='integration/mc-sol01/drainage/EVIDENCE_DAY470_CURRENT.tar.xz.b64',sha256=sha(raw),bytes=len(raw),members=len(files))
record.update(current_NUT_coupled_runs=22,current_NUT_process_restarts=44,frozen_predecessor_controls=179,current_reconciliation='PR1412 two organic modules and rejection fixture explicitly archived for previous proof; current78 HIST plus22 coupled runs/44 process restarts freshly executed. PR1411 pulse/disk freshly compiled and executed. Native194 inputs unchanged and previous481-day raw remains authoritative.',metadata_successor={'head':BASE,'qualified_native_head':'fbe5d8aaead594123cd9ca8dfec24efda9262e3f','native_numerical_rerun':'NOT_SELECTED_UNCHANGED_COMPILED_INPUTS','current_NUT_and_pulse':'FRESH_EXECUTION'})
(HERE/'DAY470_STATUS.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record['current_evidence']))
