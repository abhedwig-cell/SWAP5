"""Persist executed raw evidence; no model execution or altered assertions."""
import base64,csv,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
WORK=Path('/workspace/scratch/40264571eb43')
BASE='eb4288359e8208bb2fb03b22c622a68315836455'
sha=lambda b:hashlib.sha256(b).hexdigest()
files={};excluded={}
def add(name,p):files[name]=Path(p).read_bytes()
def folder(name,path):
 for p in sorted(Path(path).rglob('*')):
  if p.is_symlink()or not p.is_file():continue
  relative=p.relative_to(path)
  if any(part.startswith('__pycache__')for part in relative.parts)or p.name.startswith('inputrd$'):continue
  raw=p.read_bytes();key=name+'/'+str(relative)
  if p.suffix in ['.o','.mod','.a']or raw.startswith(b'\x7fELF'):excluded[key]=dict(sha256=sha(raw),bytes=len(raw));continue
  files[key]=raw
add('frozen-current.json',WORK/'day470-current-frozen-owner.json')
add('frozen-parent.py',ROOT/'integration/audits/verify_nut_resonant_pool.py')
files['frozen-parent.py']=subprocess.check_output(['git','show',BASE+':integration/audits/verify_nut_resonant_pool.py'],cwd=ROOT)
folder('direct',WORK/'day470-direct-final')
folder('preimage470',WORK/'drain-day470-debug')
add('prior469/restart.bin',WORK/'drain-qualified469-O2/full/restart.bin')
add('fsi35/stdout',WORK/'day470-fsi35-recovered2.stdout');add('fsi35/stderr',WORK/'day470-fsi35-recovered2.stderr')
folder('fsi35/authority',WORK/'day470-authority');add('fsi35/dispatch.f90',WORK/'day470-fsi35-authority.f90');add('fsi35/recovered-native.sh',WORK/'day470-incumbent-solver/fsi35-native.sh')
for opt in ['O0','O2']:
 native=WORK/('day470-481-O0'if opt=='O0'else'day470-481c-O2')
 folder('native-'+opt,native)
 build=WORK/('day470-native-'+opt)
 folder('build-'+opt,build)
 old=WORK/('drain-preserve-boesten2-O0'if opt=='O0'else'drain-preserve-boesten-O2')/'historical/full'
 for name in ['state.csv','endpoint.csv','restart.bin','budget.csv']:add('prior-ordinary-'+opt+'/'+name,old/name)
 keep=WORK/('day470-preserve-'+opt);folder('preserve-'+opt,keep)
 rejected=next(p for p in (keep/'wet').glob('wet.pending-*')if not p.is_symlink())
 for p in rejected.iterdir():
  if p.is_file()and not p.name.startswith('inputrd$'):add('preserve-'+opt+'/wet/rejected/'+p.name,p)
 folder('trace-'+opt,WORK/('day470-fct-trace-'+opt))
folder('nut-current/hist',WORK/'day470-resonant-hist');folder('nut-current/joint',WORK/'day470-resonant-joint2')
folder('nut-earlier/hist',WORK/'day470-nut-hist2');folder('nut-earlier/joint',WORK/'day470-nut-joint')
folder('cpu',WORK/'day470-cpu')
for label,dirname in [('joint','day470-fct-joint'),('reactive','day470-fct-reactive')]:
 p=WORK/dirname;r=json.loads((p/'execution.json').read_text());folder('research-'+label+'/current',p)
 files['research-'+label+'/ROUNDS.json']=b'["current"]'
 files['research-'+label+'/PRESERVATION.json']=json.dumps(dict(qualified=True,controls=134,scope='Executed frozen134 ancestor proof; current physics is independently rebuilt')).encode()
 files['research-'+label+'/current/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',r['baseline']],cwd=ROOT)
 for name,h in r['inputs'].items():
  raw=(ROOT/name).read_bytes();assert sha(raw)==h;files['research-'+label+'/current/source/'+name]=raw
for name in ['day470-frozen-owner.json','day470-current-frozen-owner.json','day470-cpu.log','day470-fsi35-recovered.stderr','day470-fsi35-recovered.stdout']:
 add('rounds/'+name,WORK/name)
# Retain failed test selections and host permission failures; never relabel them.
for name in ['day470-direct','day470-direct2','day470-direct3','day470-direct4','day470-direct5','day470-481-O2','day470-481b-O2']:
 folder('not-qualified/'+name,WORK/name)
files['EXCLUDED.json']=json.dumps(excluded,sort_keys=True,indent=2).encode()
files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in files.items()},sort_keys=True,indent=2).encode()
buffer=io.BytesIO()
with tarfile.open(fileobj=buffer,mode='w:xz',preset=6)as t:
 for p,b in sorted(files.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;m.mtime=0;t.addfile(m,io.BytesIO(b))
raw=buffer.getvalue();(HERE/'EVIDENCE_DAY470.tar.xz.b64').write_bytes(base64.b64encode(raw))
record=json.loads((HERE/'DAY470_STATUS.json').read_text())
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
delta=subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--',*science],cwd=ROOT,text=True)
record['scientific_delta']={s.split('\t')[1]:s.split('\t')[0]for s in delta.splitlines()}
postimages=set(record['scientific_delta'])|{str(Path(__file__).relative_to(ROOT))}
record['postimages']={p:sha((ROOT/p).read_bytes())for p in sorted(postimages)}
record['evidence']=dict(path='integration/mc-sol01/drainage/EVIDENCE_DAY470.tar.xz.b64',sha256=sha(raw),bytes=len(raw),members=len(files))
(HERE/'DAY470_STATUS.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record['evidence']))
