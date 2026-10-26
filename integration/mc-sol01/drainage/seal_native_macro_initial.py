"""Seal source MACROINIT, actual typed consumer and bounded thermal preservation."""
import base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;D=Path('integration/mc-sol01/drainage');BASE='9118712678cd305e9bbe96bc0a1ad8e6a51ada15';sha=lambda b:hashlib.sha256(b).hexdigest();f={};excluded={}
def folder(prefix,path):
 for p in sorted(path.rglob('*')):
  if not p.is_file():continue
  b=p.read_bytes();name=prefix+'/'+str(p.relative_to(path))
  if p.suffix in ['.o','.mod','.a','.tmp']or b[:4]==b'\x7fELF':excluded[name]=dict(bytes=len(b),sha256=sha(b));continue
  f[name]=b
folder('initial',W/'macro-initial-proof5');folder('geometry',W/'initial-geometry-controls')
for opt in ['O0','O2']:
 folder('thermal-'+opt,W/('initial-thermal2-'+opt))
 for trace in [0,1]:
  name='replay-rutter-static-'+str(trace)+'.stdout';f['prior-thermal-'+opt+'/'+name]=(W/('heat-final2-'+opt)/name).read_bytes()
 for name in ['build-complete.json','rebuild-events.json']:f['runtime-'+opt+'/'+name]=(W/('initial-runtime2-'+opt)/name).read_bytes()
 f['runtime-'+opt+'/module-identities.json']=(json.dumps({p.name:sha(p.read_bytes())for p in sorted((W/('initial-runtime2-'+opt)).glob('*.mod'))},indent=2)+'\n').encode()
f['parent/owner.json']=(W/'final-macro-geometry-owner.json').read_bytes();f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
for name in ['macro-initial-proof','macro-initial-proof2','macro-initial-proof3','macro-initial-proof4','macro-initial-dev-O0','macro-initial-dev2-O0','macro-initial-dev3-O0']:folder('development/'+name,W/name)
for p in sorted(W.glob('macro-initial*.log')):f['development/'+p.name]=p.read_bytes()
for name in ['macro-initial-native-dev3.stdout','macro-initial-native-dev3.stderr']:f['development/'+name]=(W/name).read_bytes()
inputs=set(json.loads(f['initial/RESULT.json'])['input_sha256'])|set(json.loads(f['geometry/RESULT.json'])['input_sha256'])
for opt in ['O0','O2']:inputs.update(json.loads(f['thermal-'+opt+'/RESULT.json'])['input_sha256'])
paths=['NATIVE_MACRO_INITIAL_CONTRACT.md','seal_native_macro_initial.py','qualify_native_macro_initial.py','verify_source_continuation.py','rebuild_covered_macro.py'];inputs.update(['integration/audits/verify_native_macro_initial_current.py','integration/audits/verify_native_macro_geometry_current.py',*[str(D/p)for p in paths]])
for p in sorted(inputs):f['executed/'+p]=(ROOT/p).read_bytes()
f['executed-hashes.json']=(json.dumps({p:sha(f['executed/'+p])for p in sorted(inputs)},indent=2)+'\n').encode();f['raw-hashes.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())if p.endswith(('.stdout','.stderr'))},indent=2)+'\n').encode();f['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode()
m=runpy.run_path(str(ROOT/'integration/audits/verify_native_macro_initial_current.py'));result=m['validate'](f);f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode();stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as t:
 for p,b in sorted(f.items()):info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=stream.getvalue();cap=D/'NATIVE_MACRO_INITIAL_EVIDENCE.tar.xz.b64';(ROOT/cap).write_bytes(base64.b64encode(raw));p=ROOT/D/'NATIVE_MACRO_INITIAL_STATUS.json';s=json.loads(p.read_bytes());delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--',*m['SCIENCE']],cwd=ROOT,text=True).splitlines()};posts={p:sha((ROOT/p).read_bytes())for p in set(delta)|{str(D/p)for p in paths}|{str(D/'qualify_native_macro_geometry.py')}};s.update(stage='INITIALIZATION_QUALIFIED_PENDING_CANONICAL_ADMISSION',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,scientific_delta=delta,postimages=posts,evidence=dict(path=str(cap),sha256=sha(raw),bytes=len(raw),members=len(f)),qualification=result,blockers=['Actual canonical merge and postimage verification'],remaining_migration_blockers=['Native full SWSOLU0 application orchestration of source initial macro state with active roots, response drainage and numeric heat','Coupled file restart and short distinguishing112-node/five-domain advance, then historical seasonal evidence'],next_action='Admit source initialization unit; continue full water composition without reopening NUT/SOL or changing accepted source reference differences',recovery_point='Original MACROINIT and typed initial stocks checked at O0/O2; prior thermal output exact',last_reconciled_upstream=BASE,relevant_paths=sorted(delta),authority_paths=[str(D/'NATIVE_MACRO_INITIAL_CONTRACT.md'),str(D/'NATIVE_MACRO_GEOMETRY_ADMISSION.json')],test_paths=[str(D/'qualify_native_macro_initial.py'),'tests/nut-sol/test_native_macro_initial.f90'],dependency_surface=sorted(inputs))
p.write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(evidence=s['evidence'],qualification=result),indent=2))
