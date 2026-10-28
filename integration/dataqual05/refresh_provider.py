"""Recompile only a private diagnostic label change after a checked cold build.

This deliberately refuses any other source delta or public-interface change;
source events, prior identities and actual rebuild costs are retained.
"""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PROVIDER='src/solver/mod_b110_dynamic_top_boundary_provider.f90';sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('build',type=Path);a=p.parse_args();folder=a.build.resolve();meta=folder/'build-complete.json';data=json.loads((meta if meta.exists()else folder/'build.json').read_bytes())
changed=[x for x,h in data['input_sha256'].items()if sha((ROOT/x).read_bytes())!=h];assert changed==[PROVIDER],changed
previous=subprocess.check_output(['git','show','16c71232d64d92cdb313a99c12b31bcae4a92617:'+PROVIDER],cwd=ROOT)
assert sha(previous)==data['input_sha256'][PROVIDER]
assert (ROOT/PROVIDER).read_bytes()==previous.replace(b"    else\n      result%route = 'ponded-head-linear-runoff'",b"    else if(request%runoff_exponent/=1.0_real64)then\n      result%route='ponded-head-power-runoff'\n    else\n      result%route = 'ponded-head-linear-runoff'")
events=[]
for event in data['events']:
 cmd=event['command']
 if event['category']=='link'or(event['category']=='compile'and str(ROOT/PROVIDER)in cmd):
  start=time.monotonic();cp=subprocess.run(cmd,cwd=folder,capture_output=True);cp.check_returncode()
  events.append(dict(command=cmd,seconds=time.monotonic()-start,returncode=cp.returncode,stdout=cp.stdout.decode(),stderr=cp.stderr.decode()))
assert len(events)==2
assert all(sha((folder/x).read_bytes())==h for x,h in data['generated_input_sha256'].items())
data['refresh']=dict(reason='private result route label only; exact source replacement checked',previous_source_sha256=data['input_sha256'][PROVIDER],events=events,reused_providers=193)
data['input_sha256'][PROVIDER]=sha((ROOT/PROVIDER).read_bytes());data.update(status='BUILT',provider_count=194,executable_sha256=sha((folder/'swap5_solute_column').read_bytes()))
meta.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps(data['refresh']))
