"""Controlled stable-provider reuse after a driver-only failure; no cached native PASS."""
from pathlib import Path
import hashlib,json,os,shlex,shutil,subprocess,time
ROOT=Path(__file__).resolve().parents[2];BASE=Path(os.environ['B112_REUSE_STABLE']).resolve();OUT=Path(os.environ['CROP_N_RESULT_DIR']).resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
result=json.loads((BASE/'result.json').read_text());prior=json.loads((BASE/'events.json').read_text());FC=shlex.split(os.environ['FC'])
for path,digest in result['input_sha256'].items():assert sha(ROOT/path)==digest,path
# Original runner completed the default,1253,1260 gates before the new driver.
assert result['status']=='REPRODUCTIVE_PHYSICAL_PASS_NOT_ADMITTED'
cut=next(i for i,e in enumerate(prior)if any('test_b112_retained_joint'in x for x in e['command']))
events=prior[:cut];assert all(e['returncode']==0 for e in events)
for e in events:
 for stream in ['stdout','stderr']:
  p=BASE/e[stream+'_file'];assert sha(p)==e[stream+'_sha256'];shutil.copyfile(p,OUT/p.name)
artifacts={}
for opt in ['O0','O2']:
 shutil.copytree(BASE/opt,OUT/opt)
 for p in (BASE/opt).iterdir():
  if p.suffix in ['.mod','.o']:artifacts[str(p)]=sha(p);assert sha(OUT/opt/p.name)==sha(p)
result['controlled_b112_reuse']={'provider_result_sha256':sha(BASE/'result.json'),'artifacts':artifacts,'failed_new_driver_not_reused':True,'retained_incumbent_execution_events':len(events)}
flags=next(e['command'][len(FC):-4]for e in events if e['category']=='compile'and '-O2'in e['command']);flags=[x.replace(str(BASE),str(OUT))for x in flags]
more=[OUT/'O2'/Path(e['command'][-1]).name for e in events if e['category']=='compile'and '-O2'in e['command']and('reproductive-provider-'in e['command'][-1]or e['command'][-1].endswith(('wofost_soil_amendments.f90.o','wofost_soil_cropresidues.f90.o')))]
def cmd(args,cwd,category):
 args=list(map(str,args));t=time.perf_counter();r=subprocess.run(args,cwd=cwd,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(category=category,command=args,returncode=r.returncode,seconds=time.perf_counter()-t,stdout_file=f'{i:04d}.stdout',stderr_file=f'{i:04d}.stderr',stdout_sha256=hashlib.sha256(r.stdout).hexdigest(),stderr_sha256=hashlib.sha256(r.stderr).hexdigest()));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError('retained failed event '+str(i)+' '+r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
ns={'OUT':OUT,'cmd':cmd,'FC':FC,'sha':sha,'flags':flags,'events':events}
result['input_sha256'][str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__))
