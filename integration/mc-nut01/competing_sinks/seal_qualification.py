"""Seal fresh original HIST and bind all current partition evidence."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,tarfile,runpy
ROOT=Path(__file__).resolve().parents[3];UNIT=Path(__file__).resolve().parent;W=ROOT.parent;sha=lambda b:hashlib.sha256(b).hexdigest()
hist=W/'nut-partition-hist-01';result=json.loads((hist/'result.json').read_bytes());assert result['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'
f={};excluded={}
for p in hist.rglob('*'):
 if not p.is_file():continue
 key=str(p.relative_to(hist))
 with p.open('rb')as h:magic=h.read(4)
 if p.suffix in ['.o','.mod']or magic==b'\x7fELF':excluded[key]=dict(sha256=sha(p.read_bytes()),bytes=p.stat().st_size)
 else:f[key]=p.read_bytes()
f['excluded-build-artifacts.json']=json.dumps(excluded,indent=2).encode();f['external-literal/literal.f90']=(W/'nut-partition-literal-01/literal.f90').read_bytes();f['MANIFEST.json']=json.dumps({p:sha(b)for p,b in f.items()},indent=2).encode();out=io.BytesIO()
with tarfile.open(fileobj=out,mode='w:xz')as t:
 for p,b in sorted(f.items()):
  m=tarfile.TarInfo(p);m.size=len(b);t.addfile(m,io.BytesIO(b))
b=out.getvalue();(UNIT/'HIST_EVIDENCE.tar.xz.b64').write_bytes(base64.b64encode(b));evidence=dict(hist=dict(path=str((UNIT/'HIST_EVIDENCE.tar.xz.b64').relative_to(ROOT)),sha256=sha(b),bytes=len(b),members=len(f)))
for key,name in [('daily','DAILY_STATUS.json'),('runtime','RUNTIME_STATUS.json')]:evidence[key]=json.loads((UNIT/name).read_bytes())['evidence']
evidence['default']=json.loads((UNIT/'RUNTIME_STATUS.json').read_bytes())['default_evidence']
evidence['component']=json.loads((UNIT/'CANDIDATE_STATUS.json').read_bytes())['evidence']
n=runpy.run_path(str(ROOT/'integration/audits/verify_nut_partition.py'));base=n['BASE'];delta={l.split('\t')[1]:l.split('\t')[0]for l in subprocess.check_output(['git','diff','--name-status',base,'HEAD','--',*n['SCIENCE']],cwd=ROOT,text=True).splitlines()}
paths=set(delta)|{str(p.relative_to(ROOT))for p in UNIT.iterdir()if p.suffix in ['.py','.md','.json']and p.name!='QUALIFIED_INPUTS.json'}
paths|=set(json.loads((ROOT/'integration/mc-sol01/drainage/DAY470_CURRENT_STATUS.json').read_bytes())['postimages'])
r=dict(base=base,scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in sorted(paths)},evidence=evidence,status='EVIDENCE_BOUND_PENDING_OWNER_GATES',canonically_admitted=False,full_mc_nut01_closed=False,historical_predecessor_sources=n['CHANGED'][1:],scope='Explicit juvenile equal-priority top/crop partition. Fresh current HIST78/runtime4+8/default30+60; all predecessor assertion bodies retained with explicit historical source identities. Owning controls and actual merge are separate gates.')
(UNIT/'QUALIFIED_INPUTS.json').write_text(json.dumps(r,indent=2)+'\n');print(evidence['hist'])
