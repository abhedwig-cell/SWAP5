"""Seal isolated original geometry preparation and real production consumer proof."""
import base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;D=Path('integration/mc-sol01/drainage');BASE='69885373cc8b15e33a5e970aaf189ca70dcb7da4';sha=lambda b:hashlib.sha256(b).hexdigest();f={};excluded={}
def folder(prefix,path):
 for p in sorted(path.rglob('*')):
  if not p.is_file():continue
  b=p.read_bytes();name=prefix+'/'+str(p.relative_to(path))
  if p.suffix in ['.o','.mod','.a']or b[:4]==b'\x7fELF':excluded[name]=dict(bytes=len(b),sha256=sha(b));continue
  f[name]=b
folder('geometry',W/'macro-geometry-proof');f['parent/owner.json']=(W/'actual-native-rutter-owner.json').read_bytes();f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
for p in sorted(W.glob('*macro*geometry*.log')):f['development/'+p.name]=p.read_bytes()
for name in ['macro-reader-O0','macro-reader2-O0']:folder('development/'+name,W/name)
inputs=set(json.loads(f['geometry/RESULT.json'])['input_sha256']);paths=['NATIVE_MACRO_BOOTSTRAP_CONTRACT.md','seal_native_macro_geometry.py','qualify_native_macro_geometry.py','verify_source_continuation.py'];inputs.update(['integration/audits/verify_native_macro_geometry_current.py','integration/audits/verify_native_rutter_current.py',*[str(D/p)for p in paths]])
for p in sorted(inputs):f['executed/'+p]=(ROOT/p).read_bytes()
f['executed-hashes.json']=(json.dumps({p:sha(f['executed/'+p])for p in sorted(inputs)},indent=2)+'\n').encode();f['raw-hashes.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())if p.endswith(('.stdout','.stderr'))},indent=2)+'\n').encode();f['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode();m=runpy.run_path(str(ROOT/'integration/audits/verify_native_macro_geometry_current.py'));result=m['validate'](f);f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode();stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as t:
 for p,b in sorted(f.items()):info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=stream.getvalue();cap=D/'NATIVE_MACRO_GEOMETRY_EVIDENCE.tar.xz.b64';(ROOT/cap).write_bytes(base64.b64encode(raw));p=ROOT/D/'NATIVE_MACRO_BOOTSTRAP_STATUS.json';s=json.loads(p.read_bytes());delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--',*m['SCIENCE']],cwd=ROOT,text=True).splitlines()};posts={p:sha((ROOT/p).read_bytes())for p in set(delta)|{str(D/p)for p in paths}};s.update(stage='GEOMETRY_QUALIFIED_PENDING_CANONICAL_ADMISSION',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,scientific_delta=delta,postimages=posts,evidence=dict(path=str(cap),sha256=sha(raw),bytes=len(raw),members=len(f)),qualification=result,blockers=['Actual canonical merge and postimage verification'],remaining_migration_blockers=['Source-derived Parlange sorptivity coefficients: original SWSORP1 overrides dummy SORPMAX/SORPALFA inputs','Complete original dynamic/shrinkage/rapid initial state and full macro/heat/root/drainage dispatch/file restart'],next_action='Admit original geometry unit. Continue actual MACROINIT dependencies jointly; never use source dummy sorptivity as computed coefficients',recovery_point='Original112-node/five-domain high-precision geometry O0/O2 and production consumer exact')
p.write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(evidence=s['evidence'],qualification=result),indent=2))
