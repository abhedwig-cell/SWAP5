"""Seal focused live composition; do not overwrite either prior owner capsule."""
import hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STATUS=ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_STATUS.json'
BASE='03c1c7a41d66924e2d974275cd14d4bdc4101047';TYPED='3cdebc0c52121a477fe605d092529b0c2cb1254e'
sha=lambda b:hashlib.sha256(b).hexdigest()
f={}
def add(group,folder):
 folder=Path(folder)
 for p in sorted(folder.rglob('*')):
  if p.is_file()and not p.is_symlink()and p.suffix not in ['.o','.mod','.a','.pyc','.tmp']:
   b=p.read_bytes()
   if not b.startswith(b'\x7fELF'):f[group+'/'+str(p.relative_to(folder))]=b
def main():
 for group,name in [('nut/hist','singular-hist'),('nut/joint','singular-joint'),('nut/rejection-probe-05','rejection-probe'),('fct_reactive','fct-reactive'),('fct_pulse_restart','fct-disk')]:add(group,'/tmp/perf01-owner-current-'+name)
 for name,ref,prefix in [('typed',TYPED,'/tmp/perf01-owner-frozen-typed-remap-'),('canonical',BASE,'/tmp/perf01-owner-03c-')]:
  for key in ['verify.json','verify.stderr','controls.json','controls.stderr']:f['frozen/'+name+'/'+key]=Path(prefix+key).read_bytes()
  f['frozen/'+name+'/commit.raw']=subprocess.check_output(['git','cat-file','commit',ref],cwd=ROOT)
 for key in ['verify.json','verify.stderr']:
  f['retained-validator-failure/typed-worktree-'+key]=Path('/tmp/perf01-owner-frozen-typed-'+key).read_bytes()
 f['frozen/canonical/fsi35.json']=Path('/tmp/perf01-owner-03c-fsi35.json').read_bytes()
 for key in ['stdout','stderr']:f['retained-validator-failure/fsi35-stale-registry.'+key]=Path('/tmp/perf01-live-fsi35.'+key).read_bytes()
 for kind in ['fct_reactive','fct_pulse_restart']:
  r=json.loads(f[kind+'/execution.json']);f[kind+'/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',r['baseline']],cwd=ROOT)
  for p,h in r['inputs'].items():
   b=(ROOT/p).read_bytes();assert sha(b)==h;f[kind+'/source/'+p]=b
 for report in ['nut/hist/result.json','nut/joint/result.json']:
  for p,h in json.loads(f[report])['input_sha256'].items():
   b=(ROOT/p).read_bytes();assert sha(b)==h;f['source/'+p]=b
 old=Path('/tmp/perf01-owner-nut-hist-v2');current=Path('/tmp/perf01-owner-current-singular-hist')
 reuse={str(p.relative_to(old)):sha(p.read_bytes())for p in old.rglob('*')if p.suffix in ['.o','.mod']}
 f['reuse-objects.json']=json.dumps(reuse,indent=2).encode()
 n=runpy.run_path(str(ROOT/'integration/audits/verify_nut_singular_pool.py'));capsule=n['capsule']();excluded=json.loads(capsule['excluded-build-artifacts.json'])
 for p in current.rglob('*'):
  if p.suffix in ['.o','.mod']and p.is_file():excluded['hist/'+str(p.relative_to(current))]=dict(sha256=sha(p.read_bytes()),bytes=p.stat().st_size)
 f['nut/excluded-build-artifacts.json']=json.dumps(excluded,indent=2).encode()
 # Every linked joint module/object remains bound to the fresh HIST result.
 for opt,v in json.loads(f['nut/joint/result.json'])['builds'].items():
  for p,h in v['objects_and_modules'].items():assert sha(Path(p).read_bytes())==h
 for p,h in json.loads(f['nut/rejection-probe-05/inputs.json']).items():assert sha(Path(p).read_bytes())==h
 science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
 delta={l.split('\t')[1]:l.split('\t')[0]for l in subprocess.check_output(['git','diff','--name-status',BASE,'--',*science],cwd=ROOT,text=True).splitlines()}
 r=json.loads(STATUS.read_text());canonical=json.loads((ROOT/'integration/mc-nut01/singular_assimilation/STATUS.json').read_text())
 paths=set(canonical['incumbent_inputs'])|set(canonical['postimages'])|set(r['owner_postimages'])|set(delta)
 paths|={str(Path(__file__).relative_to(ROOT)),'benchmarks/performance/qualify_perf01_live_probe.py','benchmarks/performance/replay_perf01_frozen_owner.py'}
 postimages={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
 f['MANIFEST.json']=json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2).encode()
 path=ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261024_LIVE_EVIDENCE.tar.xz'
 with tarfile.open(path,'w:xz')as t:
  for p,b in sorted(f.items()):m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;t.addfile(m,io.BytesIO(b))
 r['live_composition']=dict(base=BASE,typed_predecessor=TYPED,scientific_delta=delta,postimages=postimages,
  evidence=dict(path=str(path.relative_to(ROOT)),sha256=sha(path.read_bytes()),bytes=path.stat().st_size,members=len(f)),
  status='PERSISTED_EXECUTION_COMPLETE_AUDIT_PENDING',canonically_admitted=False,
  scope='Current original NUT528 direct inherited exact inputs, HIST78 fresh, joint22/44 fresh, FCT reactive24/24 fresh and pulse36/disk24 fresh; native194 unchanged inheritance; historical241/179 controls explicitly separate')
 r.update(status='LIVE_CANONICAL_EXECUTION_COMPLETE_AUDIT_PENDING',qualified=False,canonically_admitted=False,
  last_reconciled_head=BASE,next_action='Complete current original science/raw/source controls, bounded FSI35, docs; publish and verify actual merge')
 STATUS.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['live_composition']['evidence']))
if __name__=='__main__':main()
