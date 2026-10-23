"""Relink unchanged PR1401 water driver with sealed current native providers."""
import argparse,base64,hashlib,io,json,subprocess,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser();ap.add_argument('--bundle',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
out=a.output.resolve();out.mkdir();bundle=json.loads((a.bundle/'bundle.json').read_text());m=json.loads((Path(bundle['exe']).parent/'build-complete.json').read_text());opt=bundle['optimization'];sha=lambda b:hashlib.sha256(b).hexdigest()
for p,h in m['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h
for p,h in m['reused_artifact_sha256'].items():assert sha(Path(p).read_bytes())==h
capsule=ROOT/'integration/mc-sol01/fct_accepted_trace/EVIDENCE.tar.xz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(capsule.read_bytes())))as t:prior={e.name:t.extractfile(e).read()for e in t.getmembers()if e.isfile()}
events=[]
def run(cmd):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=120);idx=len(events)
 for k in ['stdout','stderr']:(out/f'{idx:03}.{k}').write_bytes(getattr(r,k))
 events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.perf_counter()-t));assert r.returncode==0,r.stderr.decode()
driver=ROOT/'integration/mc-sol01/fct_accepted_trace/water_driver.f90'
flags=[f for f in m['flags']if not f.startswith('-J')]+['-J'+str(out)]
objects=[p for p in m['reused_artifact_sha256']if p.endswith('.o')];archives=[p for p in m['reused_artifact_sha256']if p.endswith('/libttutil.a')]
run(m['compiler_command']+flags+[driver,*objects,*archives,'-o',out/'water'])
for n in [40,80,160]:
 for factor in [.8,1.2]:
  name=f'water-{opt}-{n}-{factor}.txt';run([out/'water',n,factor,out/name]);assert(out/name).read_bytes()==prior['water/'+name]
(out/'result.json').write_text(json.dumps(dict(status='SIX_CURRENT_WATER_TRACES_EXACT_TO_PR1401',optimization=opt,events=events,driver_sha256=sha(driver.read_bytes()),current_provider_inputs=m['input_sha256'],prior_capsule_sha256=sha(base64.b64decode(capsule.read_bytes())),replay_policy='72 unchanged replay inputs inherit only because all 12 consumed water traces are byte-exact'),indent=2)+'\n')
print('SIX_CURRENT_WATER_TRACES_EXACT_TO_PR1401')
