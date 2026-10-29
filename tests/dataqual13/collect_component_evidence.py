"""Persist source-bound component and actual original Grassgrowth evidence."""
import hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; W=ROOT.parent; OUT=ROOT/'integration/dataqual13'
sha=lambda b:hashlib.sha256(b).hexdigest()
with tarfile.open(OUT/'EVIDENCE.tar.xz','r:xz') as t:
 files={m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile() and m.name!='MANIFEST.json'}
folders=['dq13-grass-admitted-O0','dq13-grass-admitted-O2','dq13-grass-water-O0','dq13-grass-water-O2','dq13-grass-month-O2','dq13-grass-year-O2','dq13-root-oxygen-density-final','dq13-oxygen-respiration-final','dq13-grass-solar-qualified','dq13-duration-interception-final','dq13-runtime-preservation-final','dq13-crop-preservation-root-oxygen','dq13-grass-growth-root-oxygen','dq13-grass-qualification-O0','dq13-grass-qualification-O2','dq13-grass-final-O0','dq13-grass-final-O2','dq13-grass-original-30day-O2','dq13-grass-original-365day-O2','dq13-reference-grass-precise','dq13-grass-original-5day-O2','dq13-grass-original-final-O0']
for folder in folders:
 p=W/folder
 for f in p.rglob('*'):
  if f.is_file() and not any(x in ['build','mod','obj','providers','original-interval'] for x in f.relative_to(p).parts) and (f.suffix in ['.json','.csv','.stdout','.stderr','.f90'] or f.name in ['stdout','stderr','application.binding','checkpoint.bin','input.swp','grass.crp','input.met','swap.bbc','swap.dra']):
   files['components/'+folder+'/'+str(f.relative_to(p))]=f.read_bytes()
s=json.loads((OUT/'STATUS.json').read_text())
paths=subprocess.check_output(['git','diff','--name-only',s['baseline'],'HEAD','--','src','app','tests/dataqual13','tools/solute'],cwd=ROOT,text=True).splitlines()
s['source_sha256']={p:sha((ROOT/p).read_bytes()) for p in paths if (ROOT/p).is_file()}
for p in ['tests/dataqual13/collect_component_evidence.py','tests/dataqual13/verify_component_evidence.py']:s['source_sha256'][p]=sha((ROOT/p).read_bytes())
files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in sorted(files.items())},indent=2).encode()
with tarfile.open(OUT/'EVIDENCE.tar.xz','w:xz') as t:
 for name,b in sorted(files.items()):
  i=tarfile.TarInfo(name);i.size=len(b);i.mtime=0;t.addfile(i,io.BytesIO(b))
s['evidence_sha256']=sha((OUT/'EVIDENCE.tar.xz').read_bytes());(OUT/'STATUS.json').write_text(json.dumps(s,indent=2)+'\n')
print('EVIDENCE_COLLECTED',len(files),(OUT/'EVIDENCE.tar.xz').stat().st_size)
