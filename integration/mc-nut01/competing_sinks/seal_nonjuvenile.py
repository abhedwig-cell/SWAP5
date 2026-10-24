"""Bind current nonjuvenile raw evidence and preserve historical capsules."""
from pathlib import Path
import base64,hashlib,io,json,runpy,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[3];UNIT=Path(__file__).resolve().parent;W=ROOT.parent;sha=lambda b:hashlib.sha256(b).hexdigest();evidence={}
for label,folder in [('daily','nut-nonjuvenile-03'),('runtime','nut-nonjuvenile-joint-01'),('default','nut-nonjuvenile-default-01'),('hist','nut-nonjuvenile-hist-01')]:
 directory=W/folder;json.loads((directory/'result.json').read_bytes());files={};excluded={}
 for p in directory.rglob('*'):
  if not p.is_file():continue
  key=('current/'if label in ['daily','runtime']else'')+str(p.relative_to(directory))
  with p.open('rb')as h:magic=h.read(4)
  if p.suffix in ['.o','.mod']or magic==b'\x7fELF':excluded[key]=dict(sha256=sha(p.read_bytes()),bytes=p.stat().st_size)
  else:files[key]=p.read_bytes()
 if label=='daily':
  for failed in ['nut-nonjuvenile-01','nut-nonjuvenile-02']:
   for p in (W/failed).rglob('*'):
    if p.is_file()and p.suffix in ['.json','.stdout','.stderr','.f90']:files['failed/'+failed+'/'+str(p.relative_to(W/failed))]=p.read_bytes()
 files['excluded-build-artifacts.json']=json.dumps(excluded,indent=2).encode();files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in files.items()},indent=2).encode();out=io.BytesIO()
 with tarfile.open(fileobj=out,mode='w:xz')as t:
  for p,b in sorted(files.items()):
   m=tarfile.TarInfo(p);m.size=len(b);t.addfile(m,io.BytesIO(b))
 raw=out.getvalue();dest=UNIT/('NONJUVENILE_'+label.upper()+'.tar.xz.b64');dest.write_bytes(base64.b64encode(raw));evidence[label]=dict(path=str(dest.relative_to(ROOT)),sha256=sha(raw),bytes=len(raw),members=len(files))
n=runpy.run_path(str(ROOT/'integration/audits/verify_nut_nonjuvenile.py'));science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics'];delta={s.split('\t')[1]:s.split('\t')[0]for s in subprocess.check_output(['git','diff','--name-status',n['BASE'],'HEAD','--',*science],cwd=ROOT,text=True).splitlines()}
paths=set(delta)|set(json.loads((UNIT/'QUALIFIED_INPUTS.json').read_bytes())['postimages'])|{str(p.relative_to(ROOT))for p in UNIT.iterdir()if p.suffix in ['.md','.py','.json']and p.name!='NONJUVENILE_INPUTS.json'}
r=dict(base=n['BASE'],science_paths=science,scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in sorted(paths)},evidence=evidence,status='CURRENT_EVIDENCE_BOUND_PENDING_OWNER_GATES',canonically_admitted=False,full_mc_nut01_closed=False);(UNIT/'NONJUVENILE_INPUTS.json').write_text(json.dumps(r,indent=2)+'\n');print({k:v['bytes']for k,v in evidence.items()})
