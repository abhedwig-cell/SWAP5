"""Seal independent real-provider qualification and original BBC preservation."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;HERE=Path(__file__).resolve().parent
BASE='9be9a09b9c890a8240490d1f72a99c14c0cf72f8';sha=lambda b:hashlib.sha256(b).hexdigest();files={};excluded={}
for opt in ['O0','O2']:
 folder=W/('macro-robin-qualified-'+opt)
 for p in sorted(folder.rglob('*')):
  if not p.is_file()or p.is_symlink()or any('.pending-'in part for part in p.parts):continue
  b=p.read_bytes();key='oracle-'+opt+'/'+str(p.relative_to(folder))
  if p.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):excluded[key]=dict(bytes=len(b),sha256=sha(b));continue
  files[key]=b
 for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:files['retained-'+opt+'/'+name]=(W/('retained/native-'+opt+'/full')/name).read_bytes()
files['parent.json']=(W/'macro-parent-owner.json').read_bytes()
files['EXCLUDED.json']=json.dumps(excluded,sort_keys=True).encode()
files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in files.items()},sort_keys=True).encode()
stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as t:
 for p,b in sorted(files.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;m.mode=0o644;t.addfile(m,io.BytesIO(b))
b=stream.getvalue();path=HERE/'ANDELST_QUALIFICATION_EVIDENCE.tar.xz.b64';path.write_bytes(base64.b64encode(b))
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
delta={l.split('\t')[1]:l.split('\t')[0]for l in subprocess.check_output(['git','diff','--name-status',BASE,'--',*science],cwd=ROOT,text=True).splitlines()}
# New owner and test must already be staged before obtaining the exact delta.
paths=set(delta)|{str(Path(__file__).relative_to(ROOT)),'integration/mc-sol01/drainage/qualify_andelst_composition.py','integration/mc-sol01/drainage/ANDELST_COMPOSITION_CONTRACT.md','integration/mc-sol01/drainage/probe_andelst_cauchy_macro.py','integration/mc-sol01/drainage/seal_andelst_cauchy_macro.py','integration/mc-sol01/drainage/ANDELST_COMPOSITION_RESULT.json'}
r=dict(baseline=BASE,implemented=True,persisted=True,tested=True,qualified=False,canonically_admitted=False,
 scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in sorted(paths)},
 evidence=dict(path=str(path.relative_to(ROOT)),sha256=sha(b),bytes=len(b),members=len(files)),
 selected=['real frozen-Cauchy/macropore independent54 O0/O2','exact inherited12 original-BBC Rutter/Boesten/macro runs','fresh current BBC481 and365 restart','current source/raw corruption controls','original FSI35'],
 not_selected=['highest low-air','RossFast expansion','new1e-6','full moving FCI','unchanged NUT/FCT process rebuild'],
 next_action='Current owner and source/raw controls, original FSI35, docs and exact actual merge before bounded admission')
(HERE/'ANDELST_COMPOSITION_QUALIFICATION.json').write_text(json.dumps(r,indent=2)+'\n');print(r['evidence'])
