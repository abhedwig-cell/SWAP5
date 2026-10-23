"""Resume unchanged HIST runner after a stack-limited native attempt.

Replay completed command receipts after verifying their compiled inputs and
artifacts. Re-execute the failed event and every subsequent event with 64 MiB
stack. Run every original scientific assertion. Retain the failed attempt.
"""
from pathlib import Path
import ast,hashlib,json,os,resource,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_HIST_RESULT_DIR']).resolve()
recipe=ROOT/'tests/nut-crop/run_hist_complete.py'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
prior=json.loads((OUT/'events.json').read_text())
assert prior[-1]['returncode']==-11 and all(e['returncode']==0 for e in prior[:-1])
assert prior[-1]['category']=='native'
(OUT/'stack_limited_events.json').write_text(json.dumps(prior,indent=2)+'\n')
(OUT/'stack_limited_stdout').write_bytes((OUT/prior[-1]['stdout']).read_bytes())
(OUT/'stack_limited_stderr').write_bytes((OUT/prior[-1]['stderr']).read_bytes())
prior=prior[:-1]
inputs={}
for e in prior:
 c=e['command']
 if '-c'in c:
  p=Path(c[c.index('-c')+1]);inputs[str(p)]=sha(p)
artifacts={str(p):sha(p)for p in OUT.rglob('*')if p.suffix in ['.o','.mod']}
receipts={e[s]:(OUT/e[s]).read_bytes()for e in prior for s in ['stdout','stderr']}
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
ns=dict(__file__=str(recipe),__name__='nut_limits_hist_stack_recovery');cursor=0

def run(args,b,category):
 global cursor
 cmd=list(map(str,args));i=cursor;cursor+=1
 if i<len(prior):
  e=prior[i];assert e['command']==cmd and e['category']==category,'command prefix drift'
  for path,h in inputs.items():assert sha(Path(path))==h,'compiled source changed'
  ns['events'].append(e);return receipts[e['stdout']].decode()
 start=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True)
 e=dict(command=cmd,category=category,returncode=r.returncode,seconds=time.perf_counter()-start)
 for s in ['stdout','stderr']:
  name=f'{i:04d}.{s}';(OUT/name).write_bytes(getattr(r,s));e[s]=name
 ns['events'].append(e);(OUT/'events.json').write_text(json.dumps(ns['events'],indent=2)+'\n')
 if r.returncode:raise RuntimeError(str(e)+r.stdout.decode(errors='replace')+r.stderr.decode(errors='replace'))
 return r.stdout.decode()
text=recipe.read_text();node=next(n for n in ast.parse(text).body if isinstance(n,ast.FunctionDef)and n.name=='run')
lines=text.splitlines(True);lines[node.lineno-1:node.end_lineno]=['run=_resume_run\n']
text=''.join(lines).replace('OUT.mkdir(exist_ok=False)','OUT.mkdir(exist_ok=True)',1)
text=text.replace('b=OUT/opt;b.mkdir()','b=OUT/opt;b.mkdir(exist_ok=True)',1)
ns['_resume_run']=run
sys.path.insert(0,str(ROOT/'tests/nut-crop'))
exec(compile(text,str(recipe),'exec'),ns)
assert all(sha(Path(p))==h for p,h in inputs.items()),'compiled inputs changed'
assert all(sha(Path(p))==h for p,h in artifacts.items()),'reused objects changed'
receipt=dict(original_runner_sha256=sha(recipe),recovery_runner_sha256=sha(Path(__file__)),
 compiled_input_sha256=inputs,artifact_sha256=artifacts,completed_prefix=len(prior),
 fresh_events=cursor-len(prior),stack_bytes=64*1024*1024,all_original_assertions_completed=True,
 failed_attempt_retained=True)
(OUT/'STACK_RECOVERY.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('HIST_LIMITS_EXACT_PREFIX_STACK_RECOVERY_PASS')
