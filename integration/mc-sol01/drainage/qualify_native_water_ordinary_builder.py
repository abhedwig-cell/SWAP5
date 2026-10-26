"""Actual unchanged default builder versus exact canonical predecessor body."""
import hashlib,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;BASE='72839916e6498b95ab4cb9e120df5a6868e2f20d';P='tools/solute/build_project.py';sha=lambda b:hashlib.sha256(b).hexdigest()
out=W/'native-water-ordinary-proof';out.mkdir();old=subprocess.check_output(['git','show',BASE+':'+P],cwd=ROOT);(out/'predecessor.py').write_bytes(old)
current=W/'native-water-ordinary-bundle';prior=W/'native-water-ordinary-prior';physical=W/'native-water-source-O2'
argv=sys.argv;sys.argv=[str(ROOT/P),'--physical-build',str(physical),'--output',str(prior),'--optimization','O2'];start=time.monotonic()
try:exec(compile(old,str(out/'predecessor.py'),'exec'),{'__name__':'__main__','__file__':str(ROOT/P)})
finally:sys.argv=argv
seconds=time.monotonic()-start;a=json.loads((current/'bundle.json').read_bytes());b=json.loads((prior/'bundle.json').read_bytes());exact={}
for key in ['project_reader','crop_reader','root_reader','exe']:
 x=Path(a[key]);y=Path(b[key]);assert x.read_bytes()==y.read_bytes(),key;exact[key]=sha(x.read_bytes())
 m=json.loads((x.parent/'build-complete.json').read_bytes());n=json.loads((y.parent/'build-complete.json').read_bytes());assert m['input_sha256']==n['input_sha256']
for name,folder in [('current',current),('predecessor',prior)]:
 for p in folder.rglob('build-complete.json'):
  target=out/name/p.relative_to(folder);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(p.read_bytes())
 (out/(name+'-bundle.json')).write_bytes((folder/'bundle.json').read_bytes())
r=dict(status='DEFAULT_PROJECT_BUILDER_PREDECESSOR_EXACT',baseline=BASE,predecessor_source_sha256=sha(old),current_source_sha256=sha((ROOT/P).read_bytes()),exact_executables=exact,seconds=seconds,native_water=False,physics_reexecuted=False)
(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
