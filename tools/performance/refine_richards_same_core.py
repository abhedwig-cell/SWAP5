#!/usr/bin/env python3
"""Repeat an actual same-output current/recent Richards pair on one CPU.

Requires the original revision audit manifests and executables; no compile or test
result is inherited. Each native process executes all original driver assertions.
"""
import argparse
import hashlib,json,os,subprocess,time,resource,re
from pathlib import Path
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--source-dir',required=True);ap.add_argument('--output-dir',required=True);ap.add_argument('--repeat',type=int,default=20);ap.add_argument('--core',type=int)
args=ap.parse_args()
if args.repeat<1:ap.error('repeat must be positive')
p=Path(args.source_dir).resolve();out=Path(args.output_dir).resolve();out.mkdir(parents=True,exist_ok=False)
control=json.loads((p/'CONTROL.json').read_text());expected=next(r['stdout_sha256'] for r in control['runs'] if r['revision']=='current' and r['horizon']=='30')
bins={n:p/n/'trajectory' for n in ['current','recent']}
if any(b.is_symlink() or hashlib.sha256(b.read_bytes()).hexdigest()!=control['builds'][n]['executable_sha256'] for n,b in bins.items()):raise ValueError('compiled identity mismatch')
if any(r['stdout_sha256']!=expected for r in control['runs'] if r['revision'] in bins and r['horizon']=='30'):raise ValueError('original pair not physically identical')
files=set(bins.values())
for b in bins.values():
 text=subprocess.check_output(['ldd',str(b)],text=True)
 for value in re.findall(r'(?:=>\s*|^\s*)(/\S+)',text,re.M):
  q=Path(value)
  if q.is_file():files.add(q.resolve())
def identity():return {str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(files)}
ids=identity();core=args.core if args.core is not None else max(os.sched_getaffinity(0))
if core not in os.sched_getaffinity(0):ap.error('core not allowed')
records=[];failure=None
try:
 for repeat in range(args.repeat):
  for name in (['recent','current'] if repeat%2==0 else ['current','recent']):
   before=resource.getrusage(resource.RUSAGE_CHILDREN);start=time.monotonic()
   cp=subprocess.run([str(bins[name]),'30'],cwd=p,capture_output=True,preexec_fn=lambda:os.sched_setaffinity(0,{core}))
   elapsed=time.monotonic()-start;after=resource.getrusage(resource.RUSAGE_CHILDREN);sha=hashlib.sha256(cp.stdout).hexdigest();label=f'{repeat:02d}-{name}'
   (out/(label+'.stderr')).write_bytes(cp.stderr)
   if cp.returncode or sha!=expected:
    (out/(label+'.stdout')).write_bytes(cp.stdout);raise ValueError('scientific output FAIL '+label)
   specimen=out/'trajectory.stdout'
   if not specimen.exists():specimen.write_bytes(cp.stdout)
   os.link(specimen,out/(label+'.stdout'))
   line=next(l for l in cp.stderr.decode().splitlines() if l.startswith('RICHARDS_SOLVER_TIME CPU='));cpu,wall=line.split('CPU=')[1].split('WALL=')
   records.append({'repeat':repeat,'revision':name,'exit':cp.returncode,'wall_seconds':elapsed,'user_cpu_seconds':after.ru_utime-before.ru_utime,'system_cpu_seconds':after.ru_stime-before.ru_stime,'solver_cpu_seconds':float(cpu),'solver_wall_seconds':float(wall),'stdout_sha256':sha})
 if identity()!=ids:raise ValueError('binary/runtime library identity drift')
except (OSError,ValueError,StopIteration) as e:failure=str(e)
x={'head':control['head'],'source_control':str(p/'CONTROL.json'),'core':core,'before_after_binary_and_runtime_library_sha256':ids,'records':records,'equivalent':failure is None,'failure':failure,'scope':str(args.repeat)+' alternating pairs, same 30-day physical fixture and actual existing executables, one fixed CPU; original hashes retained without tolerance adaptation'}
(out/'CONTROL.json').write_text(json.dumps(x,indent=2)+'\n');print('PINNED_CORE_EQUIVALENT='+str(x['equivalent']),flush=True)

raise SystemExit(0 if x['equivalent'] else 1)
