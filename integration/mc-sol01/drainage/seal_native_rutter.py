"""Seal source-bound ETref, original crop preparation and Rutter component proof."""
import base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;D=Path('integration/mc-sol01/drainage');BASE='e15d5ffd1b28701eb96da7ae817f85c47a15a597';sha=lambda b:hashlib.sha256(b).hexdigest();f={};excluded={}
def folder(prefix,path):
 for p in sorted(path.rglob('*')):
  if not p.is_file():continue
  b=p.read_bytes();name=prefix+'/'+str(p.relative_to(path))
  if p.suffix in ['.o','.mod','.a']or b[:4]==b'\x7fELF':excluded[name]=dict(bytes=len(b),sha256=sha(b));continue
  f[name]=b
for prefix,path in [('et','native-rutter-et2'),('reader','native-rutter-reader2'),('source','native-rutter-source3')]:folder(prefix,W/path)
f['parent/owner.json']=(W/'actual-heat-owner.json').read_bytes();f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())),mode='r:gz')as t:
 for n in ['MOD_meteo.f90','MOD_cropdevelopment.f90']:f['original/'+n]=t.extractfile('SWAP/'+n).read()
for p in sorted(W.glob('native-rutter*.log')):f['development/'+p.name]=p.read_bytes()
folder('development/failed-et',W/'native-rutter-et')
inputs=set()
for label in ['et','reader','source']:inputs.update(json.loads(f[label+'/RESULT.json'])['input_sha256'])
paths=['NATIVE_RUTTER_CONTRACT.md','seal_native_rutter.py','verify_source_continuation.py','qualify_native_rutter_reader.py','qualify_native_rutter_et.py','qualify_native_rutter_source.py']
inputs.update(['integration/audits/verify_native_rutter_current.py','integration/audits/verify_macro_heat_current.py',*[str(D/p)for p in paths]])
for p in sorted(inputs):f['executed/'+p]=(ROOT/p).read_bytes()
f['executed-hashes.json']=(json.dumps({p:sha(f['executed/'+p])for p in sorted(inputs)},indent=2)+'\n').encode();f['raw-hashes.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())if p.endswith(('.stdout','.stderr'))},indent=2)+'\n').encode();f['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode()
m=runpy.run_path(str(ROOT/'integration/audits/verify_native_rutter_current.py'));result=m['validate'](f);f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode();stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as t:
 for p,b in sorted(f.items()):info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=stream.getvalue();cap=D/'NATIVE_RUTTER_EVIDENCE.tar.xz.b64';(ROOT/cap).write_bytes(base64.b64encode(raw));p=ROOT/D/'NATIVE_RUTTER_STATUS.json';s=json.loads(p.read_bytes());delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--',*m['SCIENCE']],cwd=ROOT,text=True).splitlines()};posts={p:sha((ROOT/p).read_bytes())for p in set(delta)|{str(D/p)for p in paths}}
s.update(stage='QUALIFIED_PENDING_CANONICAL_ADMISSION',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,scientific_delta=delta,postimages=posts,evidence=dict(path=str(cap),sha256=sha(raw),bytes=len(raw),members=len(f)),qualification=result,blockers=['Actual canonical merge and exact postimage verification'],remaining_migration_blockers=['Native original SWMACRO configuration and bootstrap','Native whole-water SWSOLU0 Rutter/macro/heat/root/drainage dispatch and file restart'],next_action='Admit original forcing preparation; continue original macro bootstrap without repeating accepted ET/Rutter component proof',recovery_point='O0/O2 original ETpot864 cases, two original crops and481-day detailed-source composition')
p.write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(evidence=s['evidence'],qualification=result),indent=2))
