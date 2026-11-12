"""Bounded same-platform daily-host cost attribution; never changes process physics.

Wall buckets overlap (receive includes core wait and transcript IO); worker CPU
is a different clock and is not summed into wall buckets. cProfile is diagnostic.
"""
import argparse,cProfile,ctypes,json,os,pstats,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--bundle',type=Path,required=True);p.add_argument('--reference',type=Path,required=True)
p.add_argument('--output',type=Path,required=True);p.add_argument('--project',choices=['grass','hupsel','saltfarm'],required=True)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();events={};workers=[]
real_start=h.start_process;real_receive=h.receive;real_send=h.send
stats=dict(log_write_seconds=0.,log_flush_seconds=0.,log_writes=0,log_flushes=0,log_characters=0,launch_seconds=0.,send_seconds=0.)
class Transcript:
 def __init__(self,stream):self.stream=stream
 def write(self,text):
  t=time.perf_counter();r=self.stream.write(text);stats['log_write_seconds']+=time.perf_counter()-t;stats['log_writes']+=1;stats['log_characters']+=len(text);return r
 def flush(self):
  t=time.perf_counter();r=self.stream.flush();stats['log_flush_seconds']+=time.perf_counter()-t;stats['log_flushes']+=1;return r
 def __getattr__(self,key):return getattr(self.stream,key)
def start(stack,command,directory,name):
 t=time.perf_counter()
 if os.name!='nt':command=['/usr/bin/time','-o',str(a.output/(name+'-cpu.txt')),'-f','%U %S %e',*map(str,command)]
 process,log=real_start(stack,command,directory,name);stats['launch_seconds']+=time.perf_counter()-t;workers.append((name,process));return process,Transcript(log)
def receive(process,log,prefixes):
 t=time.perf_counter()
 try:return real_receive(process,log,prefixes)
 finally:
  key=','.join(sorted(prefixes));bucket=events.setdefault(key,dict(calls=0,wall_seconds=0.));bucket['calls']+=1;bucket['wall_seconds']+=time.perf_counter()-t
def send(process,text):
 t=time.perf_counter()
 try:return real_send(process,text)
 finally:stats['send_seconds']+=time.perf_counter()-t
h.start_process=start;h.receive=receive;h.send=send
model={'grass':h.GRASSGROWTH,'hupsel':h.HUPSEL,'saltfarm':h.SALTFARM}[a.project]
sys.path.insert(0,str(ROOT/'tools/solute'));import run_water
sys.argv=['run_water.py','--no-macro-release','--model',model.model,'--reference-work',str(a.reference.resolve()),'--build-bundle',str(a.bundle.resolve()),'--output',str(a.output/'full')]
prof=cProfile.Profile();beg=time.perf_counter();prof.enable()
try:code=run_water.main();assert code==0
finally:
 prof.disable();elapsed=time.perf_counter()-beg;prof.dump_stats(str(a.output/'profile.pstats'))
 with (a.output/'profile.txt').open('w') as f:pstats.Stats(prof,stream=f).sort_stats('cumulative').print_stats(45)
cpus={}
for name,process in workers:
 if os.name=='nt':
  from ctypes import wintypes
  creation,exit,kernel,user=(wintypes.FILETIME() for _ in range(4))
  get=ctypes.windll.kernel32.GetProcessTimes;get.argtypes=[wintypes.HANDLE,*([ctypes.POINTER(wintypes.FILETIME)]*4)];get.restype=wintypes.BOOL
  assert get(int(process._handle),ctypes.byref(creation),ctypes.byref(exit),ctypes.byref(kernel),ctypes.byref(user))
  seconds=lambda v:((v.dwHighDateTime<<32)+v.dwLowDateTime)/1e7
  cpus[name]=dict(user_seconds=seconds(user),system_seconds=seconds(kernel))
 else:
  vals=(a.output/(name+'-cpu.txt')).read_text().split();cpus[name]=dict(user_seconds=float(vals[0]),system_seconds=float(vals[1]),wall_seconds=float(vals[2]))
result=dict(project=a.project,instrumented_wall_seconds=elapsed,worker_cpu=cpus,wall_buckets=stats,receive_wall=events,
 caveat='Receive includes Fortran/core wait and log IO; CPU and wall not additive. Compiler/profile confounding excluded only within each platform cohort. cProfile overhead means these are diagnostic, not headline benchmark times.')
(a.output/'COSTS.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
