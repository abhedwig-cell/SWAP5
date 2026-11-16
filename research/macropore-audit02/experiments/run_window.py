"""Research observer using an independently verified frozen host and original binding.
Instrumented binaries are NOT published as source-bound native packages.
"""
import argparse,contextlib,json,sys,time,threading
from pathlib import Path
p=argparse.ArgumentParser()
for n in ['workspace','output']:p.add_argument('--'+n,type=Path,required=True)
p.add_argument('--cut',type=int,required=True);p.add_argument('--end',type=int,required=True)
p.add_argument('--donor',type=Path);p.add_argument('--checkpoint',type=Path,required=True)
p.add_argument('--publish',action='store_true')
a=p.parse_args();assert 0<a.end-a.cut<=14
sys.path.insert(0,str(a.workspace/'frozen/app/hybrid_water'))
import daily_host as h
from daily_coupling import validate_bundle
m,case=validate_bundle(a.workspace/'O2/build',a.workspace/'provider/generic-reference',h.ANDELST)
a.output.mkdir(parents=True)
receipt=h.verify_checkpoint(a.checkpoint,a.cut,m['binding'],a.output/'origin')
workers=[];old=h.start_process

def start(*args,**kw):
 r=old(*args,**kw);workers.append(r[0]);return r
h.start_process=start
original_send=h.send
def send(worker,message):
 if not a.publish and message==f"{a.end} -1":message=f"{a.end} {a.end+35795}"
 return original_send(worker,message)
h.send=send

def stop():
 for w in workers:
  if w.poll() is None:w.kill()
timer=threading.Timer(20,stop);started=time.perf_counter();timer.start();rows=[]
try:
 with contextlib.ExitStack() as s:
  host=h.DailyHost(s,a.donor or h.executable(a.workspace/'O2/build','day_donor'),h.executable(a.workspace/'O2/build','day_kernel'),case,a.output,
    [h.ColumnStart(day=a.cut,origin=a.output/'origin',receipt=receipt,name='original')],runtime=True,checkpoint_enabled=True,binding=m['binding'] if a.publish else None)
  for day in range(a.cut+1,a.end+1):rows.append(host.step(1,checkpoint=a.publish))
  host.close()
finally:
 timer.cancel();stop()
 for w in workers:w.wait(timeout=5)
 (a.output/'RESULT.json').write_text(json.dumps({'seconds':time.perf_counter()-started,'rows':rows,'donor_sha256':h.sha(a.donor or h.executable(a.workspace/'O2/build','day_donor'))},indent=2)+'\n')
print(json.dumps({'days':[x['day'] for x in rows],'seconds':time.perf_counter()-started}))
