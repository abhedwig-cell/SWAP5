"""Resume exact completed command prefix after a generated ELF lost its mode.

All original scientific assertions run. Completed process receipts keep their
original commands, outputs and costs; remaining processes execute freshly.
"""
from pathlib import Path
import ast,hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_HIST_RESULT_DIR']).resolve()
source=ROOT/'tests/nut-crop/run_hist_complete.py'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
prior=json.loads((OUT/'events.json').read_text())
assert prior and all(e['returncode']==0 for e in prior)
for e in prior:
 for stream in ['stdout','stderr']:assert (OUT/e[stream]).is_file()
for e in prior:
 c=e['command']
 if '-c'in c:
  p=Path(c[c.index('-c')+1])
  if p.is_relative_to(ROOT):
   assert p.read_bytes()==subprocess.check_output(['git','show','e8b96829:'+str(p.relative_to(ROOT))],cwd=ROOT)
artifacts={str(p.relative_to(OUT)):sha(p)for p in OUT.rglob('*')if p.suffix in ['.o','.mod']}
original_outputs={n:(OUT/n).read_bytes()for e in prior for n in [e['stdout'],e['stderr']]}
control=dict(original_runner_sha256=sha(source),prefix_events=prior,artifacts=artifacts,
             reason='Generated current native ELF permission lost between two actual process continuations; physics/providers unchanged',
             prefix_receipts_are_prior_completed_execution=True)
(OUT/'COMMAND_RECOVERY_PREIMAGE.json').write_text(json.dumps(control,indent=2)+'\n')
cursor=0
namespace={'__file__':str(source),'__name__':'hist_permission_recovery'}
def resume(args,b,category):
 global cursor
 c=list(map(str,args));i=cursor;cursor+=1
 events=namespace['events']
 if i<len(prior):
  e=prior[i]
  assert e['command']==c and e['category']==category, 'nonidentical completed command prefix'
  events.append(e)
  return original_outputs[e['stdout']].decode()
 exe=Path(c[0])
 if exe.is_file()and exe.is_relative_to(OUT)and exe.read_bytes()[:4]==b'\x7fELF':exe.chmod(0o755)
 t=time.perf_counter();p=subprocess.run(c,cwd=b,capture_output=True)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
 events.append(dict(command=c,category=category,returncode=p.returncode,seconds=time.perf_counter()-t,
                    stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if p.returncode:raise RuntimeError(p.stdout.decode()+p.stderr.decode())
 return p.stdout.decode()
text=source.read_text();node=next(n for n in ast.parse(text).body if isinstance(n,ast.FunctionDef)and n.name=='run')
lines=text.splitlines(True);lines[node.lineno-1:node.end_lineno]=['run=_resume_run\n']
text=''.join(lines).replace('OUT.mkdir(exist_ok=False)','OUT.mkdir(exist_ok=True)',1)
text=text.replace('b=OUT/opt;b.mkdir()','b=OUT/opt;b.mkdir(exist_ok=True)',1)
namespace['_resume_run']=resume
import sys
sys.path.insert(0,str(ROOT/'tests/nut-crop'))
exec(compile(text,str(source),'exec'),namespace)
assert cursor>len(prior),'no remaining native execution'
assert all(sha(OUT/p)==h for p,h in artifacts.items()),'completed provider artifact drift'
(OUT/'COMMAND_RECOVERY.json').write_text(json.dumps(dict(prefix_events=len(prior),fresh_events=cursor-len(prior),
    original_runner_sha256=sha(source),adapter_sha256=sha(Path(__file__)),all_original_assertions_completed=True),indent=2)+'\n')
print('HIST_EXACT_COMMAND_PREFIX_RECOVERY_PASS')
