"""Compare independent day145 restart to rejected day146 committed state."""
import json,subprocess,time
from pathlib import Path
p=Path('/tmp/perf01-historical-4x-v1');d=p/'head-stop145';d.mkdir(exist_ok=True)
for n in ['input.nml','input.swp']:(d/n).write_bytes((p/'head'/n).read_bytes())
t=time.perf_counter();r=subprocess.run(['/tmp/perf01-historical-current-v2/project','input.nml','-','145','input.swp'],cwd=d,capture_output=True,timeout=120)
for k in ['stdout','stderr']:(d/k).write_bytes(getattr(r,k))
assert r.returncode==0
same=(d/'restart.bin').read_bytes()==(p/'head/diagnostic-rejected.bin').read_bytes()
record=dict(status='DAY146_REJECTION_COMMITTED_CHECK',seconds=time.perf_counter()-t,returncode=r.returncode,day145_restart_equals_day146_rejected_committed=same)
(p/'ROLLBACK_CHECK.json').write_text(json.dumps(record,indent=2)+'\n');assert same
