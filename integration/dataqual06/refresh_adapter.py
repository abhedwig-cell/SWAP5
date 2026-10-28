"""Rebuild the only private adapter input-validation correction, preserving evidence."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];TARGET='src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90'
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('build',type=Path);a=p.parse_args();folder=a.build.resolve();meta=folder/'build-complete.json';data=json.loads(meta.read_bytes());changed=[x for x,h in data['input_sha256'].items()if sha((ROOT/x).read_bytes())!=h];assert changed==[TARGET],changed
prior=subprocess.check_output(['git','show','6966ac1ec:'+TARGET],cwd=ROOT);assert sha(prior)==data['input_sha256'][TARGET]
# The public type/bind interfaces are byte-exact; only evaluate's guard changed.
current=(ROOT/TARGET).read_bytes();mark=b'  subroutine b110_dynamic_solver_top_evaluate';assert current.split(mark)[0]==prior.split(mark)[0]
(folder/'pre-refresh-build.json').write_text(json.dumps(data,indent=2)+'\n');events=[]
for e in data['events']:
 cmd=e['command']
 if e['category']=='link'or(e['category']=='compile'and str(ROOT/TARGET)in cmd):
  start=time.monotonic();cp=subprocess.run(cmd,cwd=folder,capture_output=True);cp.check_returncode();events.append(dict(command=cmd,seconds=time.monotonic()-start,returncode=cp.returncode,stdout=cp.stdout.decode(),stderr=cp.stderr.decode()))
assert len(events)==2
assert all(sha((folder/x).read_bytes())==h for x,h in data['generated_input_sha256'].items())
data['refresh']=dict(reason='private finite-input checks before trapped comparisons; same public interface',previous_sha256=sha(prior),events=events,reused_providers=193)
data['input_sha256'][TARGET]=sha(current);data['executable_sha256']=sha((folder/'swap5_solute_column').read_bytes());meta.write_text(json.dumps(data,indent=2)+'\n')
