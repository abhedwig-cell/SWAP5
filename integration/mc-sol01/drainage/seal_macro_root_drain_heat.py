"""Seal joint production runtime and real unchanged predecessor output."""
import base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;D=Path('integration/mc-sol01/drainage');BASE='53db6ca034c988dddaa66172036ae70fd5772630';sha=lambda b:hashlib.sha256(b).hexdigest();f={};excluded={}
def folder(prefix,path):
 for p in sorted(path.rglob('*')):
  if not p.is_file():continue
  b=p.read_bytes();name=prefix+'/'+str(p.relative_to(path))
  if p.suffix in ['.o','.mod','.a','.tmp']or b[:4]==b'\x7fELF':excluded[name]=dict(bytes=len(b),sha256=sha(b));continue
  f[name]=b
for opt in ['O0','O2']:
 for mode in ['root','drain','joint']:folder(opt+'-'+mode,W/('root-drain-final-'+opt+'-'+mode))
 folder('preserve-'+opt,W/('root-drain-preserve-'+opt))
 for trace in [0,1]:
  name='replay-rutter-static-'+str(trace)+'.stdout';f['prior-'+opt+'/'+name]=(W/('initial-thermal2-'+opt)/name).read_bytes()
 build=W/('root-drain-dev4-O0'if opt=='O0'else'root-drain-O2')
 for name in ['build-complete.json','rebuild-events.json']:f['runtime-'+opt+'/'+name]=(build/name).read_bytes()
folder('counter',W/'root-drain-counter');f['parent/owner.json']=(W/'final-initial-owner.json').read_bytes();f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
for name in ['root-drain-root-dev','root-drain-root-dev2','root-drain-root-dev3','root-drain-drain-dev','root-drain-joint-dev','root-drain-joint-dev2','root-drain-joint-dev3']:folder('development/'+name,W/name)
for p in sorted(W.glob('root-drain-*.log')):f['development/'+p.name]=p.read_bytes()
inputs=set()
for opt in ['O0','O2']:
 for mode in ['root','drain','joint']:inputs.update(json.loads(f[opt+'-'+mode+'/RESULT.json'])['input_sha256'])
 inputs.update(json.loads(f['preserve-'+opt+'/RESULT.json'])['input_sha256'])
paths=['MACRO_ROOT_DRAIN_HEAT_CONTRACT.md','seal_macro_root_drain_heat.py','qualify_macro_trace.py','probe_macro_heat_predecessor.py'];inputs.update(['integration/audits/verify_macro_root_drain_heat_current.py','integration/audits/verify_native_macro_initial_current.py',*[str(D/p)for p in paths]])
for p in sorted(inputs):f['executed/'+p]=(ROOT/p).read_bytes()
f['executed-hashes.json']=(json.dumps({p:sha(f['executed/'+p])for p in sorted(inputs)},indent=2)+'\n').encode();f['raw-hashes.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())if p.endswith(('.stdout','.stderr'))},indent=2)+'\n').encode();f['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode();m=runpy.run_path(str(ROOT/'integration/audits/verify_macro_root_drain_heat_current.py'));result=m['validate'](f);f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode();stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as t:
 for p,b in sorted(f.items()):info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=stream.getvalue();cap=D/'MACRO_ROOT_DRAIN_HEAT_EVIDENCE.tar.xz.b64';(ROOT/cap).write_bytes(base64.b64encode(raw));p=ROOT/D/'MACRO_ROOT_DRAIN_HEAT_STATUS.json';s=json.loads(p.read_bytes());delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--',*m['SCIENCE']],cwd=ROOT,text=True).splitlines()};posts={p:sha((ROOT/p).read_bytes())for p in set(delta)|{str(D/p)for p in paths}};s.update(stage='RUNTIME_QUALIFIED_PENDING_CANONICAL_ADMISSION',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,scientific_delta=delta,postimages=posts,evidence=dict(path=str(cap),sha256=sha(raw),bytes=len(raw),members=len(f)),qualification=result,blockers=['Actual canonical merge and postimage verification'],remaining_migration_blockers=['Native full SWSOLU0 application orchestration using actual112-node/five-domain source inputs and active root/drainage/heat runtime','Coupled file restart and historical seasonal execution evidence'],next_action='Admit bounded runtime composition; connect full native source application and file restart',recovery_point='Six positive native O0/O2 runtime configurations, exact typed restart/rollback,24 additional joint atomic controls and original rootless output exact',last_reconciled_upstream=BASE,authority_paths=[str(D/'MACRO_ROOT_DRAIN_HEAT_CONTRACT.md'),str(D/'NATIVE_MACRO_INITIAL_ADMISSION.json')],test_paths=[str(D/'qualify_macro_trace.py'),'tests/nut-sol/macro_root_drain_heat_checks.inc'],dependency_surface=sorted(inputs))
p.write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(evidence=s['evidence'],qualification=result),indent=2))
