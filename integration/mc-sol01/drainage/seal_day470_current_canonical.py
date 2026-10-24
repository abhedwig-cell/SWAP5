"""Seal current affected NUT/disk execution and immutable native input identity."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;W=ROOT.parent
BASE='2de14588d192197d547d5287384e0317ad7514b2';files={};excluded={}
sha=lambda b:hashlib.sha256(b).hexdigest()
def add(k,p):files[k]=Path(p).read_bytes()
def folder(label,p):
 for f in sorted(p.rglob('*')):
  if f.is_symlink()or not f.is_file()or'__pycache__'in f.parts:continue
  raw=f.read_bytes();k=label+'/'+str(f.relative_to(p))
  if f.suffix in ['.o','.mod','.a']or raw.startswith(b'\x7fELF'):excluded[k]=dict(sha256=sha(raw),bytes=len(raw));continue
  files[k]=raw
folder('hist',W/'day470-current-hist2');folder('joint',W/'day470-current-joint');folder('failed/default-stack-hist',W/'day470-current-hist')
add('failed/default-stack.log',W/'day470-current-hist.log');folder('compiler-contract',W/'day470-compiler-contract')
add('frozen.json',W/'day470-current-frozen.json');add('fsi35.json',W/'day470-current-fsi35-registry.json');add('native-identity.json',W/'day470-current-native-identity.json')
files['frozen-commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/mc-nut01/crop_only_depletion/COMPOSITION.tar.xz.b64').read_bytes())),mode='r:xz')as t:
 for label in ['hist','joint']:files['prior-'+label+'.json']=t.extractfile(label+'/result.json').read()
folder('disk/round1',W/'day470-current-sink-disk');r=json.loads(files['disk/round1/execution.json']);assert r['status']=='EXECUTED'
files['disk/ROUNDS.json']=b'["round1"]';files['disk/round1/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',r['baseline']],cwd=ROOT)
for p,h in r['inputs'].items():
 raw=(ROOT/p).read_bytes();assert sha(raw)==h;files['disk/round1/source/'+p]=raw
frozen=json.loads(files['frozen.json']);assert frozen['owner']['qualified']and len(frozen['controls'])==316
files['disk/PRESERVATION.json']=json.dumps(dict(qualified=True,controls=316,result=frozen['owner'],control_labels=frozen['controls'],scope='Pristine exact canonical predecessor; repaired-source NUT/native proof is separate')).encode()
for p in ['verify.py','seal.py']:add('disk/validation/'+p,ROOT/'integration/mc-sol01/fct_sink_restart'/p)
files['EXCLUDED.json']=json.dumps(excluded).encode();files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in files.items()},sort_keys=True).encode()
b=io.BytesIO()
with tarfile.open(fileobj=b,mode='w:xz',preset=6)as t:
 for p,raw in sorted(files.items()):
  m=tarfile.TarInfo(p);m.size=len(raw);m.mode=0o644;m.mtime=0;t.addfile(m,io.BytesIO(raw))
raw=b.getvalue();path=HERE/'EVIDENCE_DAY470_CANONICAL.tar.xz.b64';path.write_bytes(base64.b64encode(raw))
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
delta=subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--',*science],cwd=ROOT,text=True)
d={s.split('\t')[1]:s.split('\t')[0]for s in delta.splitlines()}
paths=set(d)|{str(p.relative_to(ROOT))for p in [HERE/'reconcile_day470_recovery.py',Path(__file__)]}
record=dict(work_unit='HIST-INTEGRATION01 current canonical day470 composition',baseline=BASE,implemented=True,persisted=True,tested=True,qualified=False,canonically_admitted=False,
 qualification_owner='integration/audits/verify_saturated_picard_current.py',scientific_delta=d,postimages={p:sha((ROOT/p).read_bytes())for p in sorted(paths)},
 evidence=dict(path=str(path.relative_to(ROOT)),sha256=sha(raw),bytes=len(raw),members=len(files)),current_HIST_processes=78,current_coupled_runs=30,current_process_restarts=60,
 frozen_predecessor_controls=316,source_unchanged_native_days=481,compiler='GNU Fortran13.3.0-6ubuntu2~24.04.1; private extraction; cold654 compiles; stack64MiB',
 selection='Affected current HIST/crop exhaustion/restart and new extracting-sink disk consumer; preserve original native481 and three FCT numerical proofs only after exact compiled-input checks.',
 not_selected=['highest low-air','RossFast expansion','new1e-6','unrelated full FCI'],next_action='Execute current owner, corruption controls, original FSI35 and exact latest merge postimage; admission receipt only after actual merge.')
(HERE/'DAY470_CURRENT_STATUS.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record['evidence']))
