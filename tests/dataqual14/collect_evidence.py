"""Persist actual original active-grass runs, components, failures and source binding."""
import hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];W=ROOT.parent;OUT=ROOT/'integration/dataqual14';sha=lambda b:hashlib.sha256(b).hexdigest()
files={}
folders=['dq14-final-O0','dq14-final-O2','dq14-qualification-O0','dq14-qualification-O2','dq14-root-oracle','dq14-runtime-preservation-final','dq14-reference','dq14-original-year-O2','dq14-stressed-prefix-O2','dq14-stressed-suffix-O2','dq14-distinct-roots-prefix-O2','dq14-distinct-roots-suffix-O2','dq14-active-O0','dq14-active-O2','dq14-runtime-preservation']
for folder in folders:
 p=W/folder
 for f in p.rglob('*'):
  if f.is_file() and not f.is_symlink() and (f.suffix in ['.json','.csv','.f90','.stdout','.stderr'] or f.name in ['stdout','stderr','checkpoint.bin','application.binding','input.swp','swap.swp','grass.crp','input.met','260.met','swap.bbc','swap.dra']):
   files[folder+'/'+str(f.relative_to(p))]=f.read_bytes()
for f in [W/'dq13-groundwater-runtime-verified/context.f90',W/'dq13-reference431/BUILD.json']:
 files['external/'+f.name]=f.read_bytes()
files['discovery/backend-before-zero-root-guard.f90']=subprocess.check_output(['git','show','2c7051cc:src/runtime/mod_fmr_serialized_reference_backend.f90'],cwd=ROOT)
with tarfile.open(ROOT/'integration/dataqual13/EVIDENCE.tar.xz') as t:
 for n in ['components/dq13-grass-water-O2/full/budget.csv','components/dq13-grass-month-O2/budget.csv','components/dq13-grass-year-O2/budget.csv']:
  files['inherited/'+n]=t.extractfile(n).read()
s=json.loads((OUT/'STATUS.json').read_text());paths=subprocess.check_output(['git','diff','--name-only',s['baseline'],'HEAD'],text=True,cwd=ROOT).splitlines()
s['source_sha256']={p:sha((ROOT/p).read_bytes()) for p in paths if p.startswith(('src/','app/','tools/','tests/')) and (ROOT/p).is_file()}
for f in (ROOT/'tests/dataqual14').glob('*.py'):s['source_sha256'][str(f.relative_to(ROOT))]=sha(f.read_bytes())
files['MANIFEST.json']=json.dumps({n:sha(b)for n,b in sorted(files.items())},indent=2).encode()
with tarfile.open(OUT/'EVIDENCE.tar.xz','w:xz') as t:
 for n,b in sorted(files.items()):
  info=tarfile.TarInfo(n);info.size=len(b);info.mtime=0;t.addfile(info,io.BytesIO(b))
s['evidence_sha256']=sha((OUT/'EVIDENCE.tar.xz').read_bytes());(OUT/'STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print('EVIDENCE_COLLECTED',len(files),(OUT/'EVIDENCE.tar.xz').stat().st_size)
