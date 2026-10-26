"""Seal bounded native source water/restart proof and retain failed/censored work."""
import base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;D=Path('integration/mc-sol01/drainage');BASE='72839916e6498b95ab4cb9e120df5a6868e2f20d';sha=lambda b:hashlib.sha256(b).hexdigest();f={};excluded={}
def folder(prefix,path):
 assert path.is_dir(),path
 for p in sorted(path.rglob('*')):
  if not p.is_file():continue
  name=prefix+'/'+str(p.relative_to(path))
  if p.suffix in ['.o','.mod','.a']:
   excluded[name]=dict(bytes=p.stat().st_size,sha256=sha(p.read_bytes()));continue
  b=p.read_bytes()
  if b[:4]==b'\x7fELF':excluded[name]=dict(bytes=len(b),sha256=sha(b));continue
  f[name]=b
folder('ordinary-builder',W/'native-water-ordinary-proof');folder('proof',W/'native-water-proof3');folder('initial',W/'native-water-initial-preserve2')
for opt in ['O0','O2']:
 for name in [opt+'.nml',opt+'-consumer.stdout']:f['prior-initial/'+name]=(W/'macro-initial-proof5'/name).read_bytes()
 for mode in ['joint','rootless']:
  folder('preserve-'+opt+'-'+mode,W/('native-water-current-'+opt+'-'+mode))
  prior=W/('root-drain-final-'+opt+'-joint'if mode=='joint'else'root-drain-preserve-'+opt)
  for trace in ([1]if mode=='joint'else[0,1]):
   name='replay-rutter-static-'+str(trace)+'.stdout';f['prior-'+opt+'-'+mode+'/'+name]=(prior/name).read_bytes()
 for name in ['build-complete.json','rebuild-events.json']:f['runtime-'+opt+'/'+name]=(W/('native-water-source-'+opt)/name).read_bytes()
 folder('bundle-'+opt,W/('native-water-bundle-source-'+opt))
f['parent/owner.json']=(W/'final-root-drain-owner.json').read_bytes();f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
for name in ['native-water-day1-dev','native-water-day1-dev2','native-water-two-dev','native-water-resume-dev','native-water-two-debug4','native-water-two-debug5','native-water-five-O0','native-water-five-O2','native-water-pond-five-O0','native-water-pond-five-O2','native-water-proof1','native-water-proof2','native-water-initial-preserve']:
 folder('development/'+name,W/name)
for p in sorted(W.glob('native-water-*.log')):f['development/logs/'+p.name]=p.read_bytes()
inputs=set(json.loads(f['proof/RESULT.json'])['input_sha256'])
for opt in ['O0','O2']:
 for mode in ['joint','rootless']:inputs.update(json.loads(f['preserve-'+opt+'-'+mode+'/RESULT.json'])['input_sha256'])
inputs.update(json.loads(f['initial/RESULT.json'])['input_sha256'])
paths=['NATIVE_WATER_APPLICATION_CONTRACT.md','seal_native_macro_water.py','qualify_native_water_ordinary_builder.py','verify_source_continuation.py']
inputs.update(['integration/audits/verify_native_macro_water_current.py','integration/audits/verify_macro_root_drain_heat_current.py',*[str(D/p)for p in paths]])
for p in sorted(inputs):f['executed/'+p]=(ROOT/p).read_bytes()
f['executed-hashes.json']=(json.dumps({p:sha(f['executed/'+p])for p in sorted(inputs)},indent=2)+'\n').encode()
f['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode()
f['sealed-raw-hashes.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode()
m=runpy.run_path(str(ROOT/'integration/audits/verify_native_macro_water_current.py'));result=m['validate'](f)
f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode();stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as t:
 for p,b in sorted(f.items()):info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=stream.getvalue();cap=D/'NATIVE_WATER_APPLICATION_EVIDENCE.tar.xz.b64';(ROOT/cap).write_bytes(base64.b64encode(raw));p=ROOT/D/'NATIVE_WATER_APPLICATION_STATUS.json';s=json.loads(p.read_bytes())
delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--',*m['SCIENCE']],cwd=ROOT,text=True).splitlines()}
s.update(stage='SHORT_NATIVE_APPLICATION_QUALIFIED_PENDING_ADMISSION',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in set(delta)|{str(D/p)for p in paths}},evidence=dict(path=str(cap),sha256=sha(raw),bytes=len(raw),members=len(f)),qualification=result,blockers=['Actual canonical merge and postimage verification'],remaining_migration_blockers=['Seasonal original macro/Rutter/heat execution remains unqualified; five-day120s trials censored near1.92day','Original431 trajectory equivalence, arbitrary in-window restart and variable surface-conductivity projects remain excluded'],next_action='Admit bounded first1.054day native application and exact event/day file restart; address longer source route only with an explicit cost/scientific selection',recovery_point='Original112/five-domain O0/O2 short production, positive direct macro/root/rapid, independent supplied-source budget and four exact fresh-process restarts;14 invalid file controls',last_reconciled_upstream=BASE,dependency_surface=sorted(inputs),authority_paths=[str(D/'NATIVE_WATER_APPLICATION_CONTRACT.md'),str(D/'MACRO_ROOT_DRAIN_HEAT_ADMISSION.json')],test_paths=['tests/nut-sol/qualify_native_macro_water.py','tests/nut-sol/test_native_macro_initial.f90','tests/nut-sol/macro_trace_checks.inc'])
p.write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(evidence=s['evidence'],qualification=result),indent=2))
