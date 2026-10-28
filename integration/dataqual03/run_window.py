"""Diagnostic origin-state handoff; authentic old binding, no restart promotion."""
import argparse,json,shutil,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--seconds',type=float,default=20);a=p.parse_args();a.output.mkdir()
b=json.loads((a.bundle/'bundle.json').read_text());source=Path('/workspace/scratch/9be0a7c91534/dataqual02-checkpoint');m=json.loads((source/'manifest.json').read_text());events=[]
for enabled in [False,True]:
 d=a.output/('on'if enabled else'off');d.mkdir()
 for f in ['input.nml','input.swp','macro.nml','restart.bin']:shutil.copyfile(source/f,d/f)
 original=(d/'restart.bin').read_bytes();cmd=[b['exe'],'input.nml','restart.bin','3','input.swp','macro.nml',m['binding_sha256'],'2.5140000000028522','anchored-cauchy','0.0001','experimental','source-surface-demand']
 if enabled:cmd+=['perched-jacobian']
 start=time.monotonic();censored=False;code=None
 with(d/'stdout').open('wb')as so,(d/'stderr').open('wb')as se:
  try:cp=subprocess.run(cmd,cwd=d,stdin=subprocess.DEVNULL,stdout=so,stderr=se,timeout=a.seconds);code=cp.returncode
  except subprocess.TimeoutExpired:censored=True
 assert (d/'restart.bin').read_bytes()==original
 r=dict(policy=enabled,command=cmd,returncode=code,censored=censored,seconds=time.monotonic()-start,origin_binding=m['binding_sha256'],origin_state_only=True,new_restart_qualified=False)
 events.append(r);(a.output/'RESULT.json').write_text(json.dumps(events,indent=2)+'\n');print(json.dumps(r),flush=True)
