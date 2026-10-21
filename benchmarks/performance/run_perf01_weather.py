"""Bounded native observation; includes failures and process resources."""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import time

ap=argparse.ArgumentParser()
ap.add_argument('--build',type=Path,required=True)
ap.add_argument('--output',type=Path,required=True)
ap.add_argument('--budget',type=float,required=True)
ap.add_argument('--days',type=int,default=97)
ap.add_argument('--windows',type=int,default=64)
ap.add_argument('--timeout',type=float,default=180)
ap.add_argument('--restart',action='store_true')
ap.add_argument('--profile',choices=['original','sensitive'],default='original')
a=ap.parse_args()
b=a.build.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
build=json.loads((b/'BUILD.json').read_text())
exe=b/'weather'
assert build['status']=='BUILT' and hashlib.sha256(exe.read_bytes()).hexdigest()==build['executable_sha256']
cpu=min(os.sched_getaffinity(0))
command=['taskset','-c',str(cpu),str(exe),str(b/'weather.999'),str(a.budget),str(a.days),str(a.windows),
         'restart' if a.restart else 'continuous',a.profile]
record=dict(status='RUNNING',command=command,head_budget_cm=a.budget,days=a.days,windows_per_day=a.windows,
            executable_sha256=build['executable_sha256'],timeout=a.timeout)
(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
def limit():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_STACK,(resource.RLIM_INFINITY,resource.RLIM_INFINITY))
start=time.monotonic()
with (out/'stdout').open('wb') as so,(out/'stderr').open('wb') as se:
    p=subprocess.Popen(command,cwd=out,stdout=so,stderr=se,preexec_fn=limit)
    expired=False
    while True:
        pid,status,usage=os.wait4(p.pid,os.WNOHANG)
        if pid:break
        if time.monotonic()-start>a.timeout:
            expired=True;p.kill();pid,status,usage=os.wait4(p.pid,0);break
        time.sleep(.02)
    p.returncode=os.waitstatus_to_exitcode(status)
record.update(returncode=p.returncode,timed_out=expired,user_seconds=usage.ru_utime,system_seconds=usage.ru_stime,
              wall_seconds=time.monotonic()-start,max_rss_kib=usage.ru_maxrss)
if (out/'daily.csv').exists():
    records=list(csv.DictReader((out/'daily.csv').open()))
    record['completed_days']=len(records)
record['status']='COMPLETE_NATIVE_OBSERVATION' if p.returncode==0 and not expired and record.get('completed_days')==a.days else 'FAILED_OR_CENSORED'
record['raw_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.name!='RESULT.json'}
(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record),flush=True)
