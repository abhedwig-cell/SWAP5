"""Seal the final concurrent NUT empty-pool and isolated FCT-sinks replay."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;W=ROOT.parent
BASE='f33adbe938368449e97aa14301c40d13440a65c1'
sha=lambda b:hashlib.sha256(b).hexdigest();files={};excluded={}
def add(k,p):files[k]=Path(p).read_bytes()
def folder(label,p):
 for f in sorted(p.rglob('*')):
  if f.is_symlink()or not f.is_file()or'__pycache__'in f.parts:continue
  raw=f.read_bytes();k=label+'/'+str(f.relative_to(p))
  if f.suffix in ['.o','.mod','.a']or raw.startswith(b'\x7fELF'):excluded[k]=dict(sha256=sha(raw),bytes=len(raw));continue
  files[k]=raw
folder('hist',W/'day470-final-hist');folder('joint',W/'day470-final-joint')
add('frozen.json',W/'day470-final-frozen.json')
add('host/initial-owner-missing-toolchain.stderr',W/'day470-final-owner.stderr')
add('prior-hist.json','/workspace/scratch/281436eb488f/nut-empty-hist-01/result.json')
add('prior-joint.json','/workspace/scratch/281436eb488f/nut-empty-joint-02/result.json')
frozen=json.loads(files['frozen.json']);assert frozen['owner']['qualified']and len(frozen['controls'])==198
folder('unqualified-toolchain-identity/sinks',W/'day470-final-sinks')
folder('sinks/current',W/'day470-final-sinks2');r=json.loads(files['sinks/current/execution.json']);assert r['status']=='EXECUTED'
files['sinks/ROUNDS.json']=b'["current"]'
files['sinks/current/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',r['baseline']],cwd=ROOT)
for p,h in r['inputs'].items():
 raw=(ROOT/p).read_bytes();assert sha(raw)==h;files['sinks/current/source/'+p]=raw
checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
files['sinks/validation/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',checkpoint],cwd=ROOT)
files['sinks/validation/identity.json']=json.dumps(dict(commit=checkpoint)).encode()
for p in ['verify.py','seal.py']:add('sinks/validation/'+p,ROOT/'integration/mc-sol01/fct_sinks'/p)
files['sinks/PRESERVATION.json']=json.dumps(dict(qualified=True,controls=198,pulse_controls=8,scope='Frozen canonical owner; current pulse replay remains in EVIDENCE_DAY470_CURRENT')).encode()
files['EXCLUDED.json']=json.dumps(excluded,indent=2).encode()
files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in files.items()},sort_keys=True,indent=2).encode()
b=io.BytesIO()
with tarfile.open(fileobj=b,mode='w:xz',preset=6)as t:
 for p,raw in sorted(files.items()):
  m=tarfile.TarInfo(p);m.size=len(raw);m.mode=0o644;m.mtime=0;t.addfile(m,io.BytesIO(raw))
raw=b.getvalue();(HERE/'EVIDENCE_DAY470_FINAL.tar.xz.b64').write_bytes(base64.b64encode(raw))
r=json.loads((HERE/'DAY470_STATUS.json').read_text());r['baseline']=BASE;r['last_reconciled_head']=BASE
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
delta=subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--',*science],cwd=ROOT,text=True)
r['scientific_delta']={s.split('\t')[1]:s.split('\t')[0]for s in delta.splitlines()}
paths=set(r['scientific_delta'])|{'integration/mc-sol01/drainage/seal_day470.py','integration/mc-sol01/drainage/seal_day470_current.py','integration/mc-sol01/drainage/seal_day470_final.py'}
r['postimages']={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
r['final_evidence']=dict(path='integration/mc-sol01/drainage/EVIDENCE_DAY470_FINAL.tar.xz.b64',sha256=sha(raw),bytes=len(raw),members=len(files))
r.update(current_NUT_coupled_runs=26,current_NUT_process_restarts=52,frozen_predecessor_controls=198,current_reconciliation='PR1414 current78 HIST plus26 coupled runs/52 process restarts freshly executed. PR1415 current162 process and48 Richards sink cases freshly executed. Earlier PR1412 and PR1411 replay preserved in separate capsule. Native194 compiled input bytes unchanged; full481 O0/O2 and restart evidence preserved unchanged.',next_action='Validate current source-bound owner and raw controls; publish exact composed tree and merge PR1413.')
(HERE/'DAY470_STATUS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['final_evidence']))
