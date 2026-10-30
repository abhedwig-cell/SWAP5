"""Run exact-bound original Grassgrowth, capture selected atomic checkpoints."""
import argparse,csv,hashlib,json,shutil,struct,subprocess,time,zlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--end',type=int,required=True);p.add_argument('--restart',type=Path);p.add_argument('--capture',type=int,nargs='*',default=[]);p.add_argument('--timeout',type=int,default=7200);a=p.parse_args()
b=a.bundle.resolve();out=a.output.resolve();out.mkdir();sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();build=json.loads((b/'BUILD.json').read_text());exe=b/'swap5_grass_startup'
assert sha(exe)==build['executable_sha256'];exe.chmod(exe.stat().st_mode|0o100);assert all(sha(Path(s))==h for s,h in build['source_sha256'].items())
for n,h in build['original_inputs_sha256'].items():
 f=b/'original-interval'/n;assert sha(f)==h;shutil.copyfile(f,out/n)
shutil.copyfile(b/'original-interval/application.binding',out/'application.binding')
origin=None
if a.restart:
 origin=a.restart.resolve();shutil.copyfile(origin,out/'restart-origin.bin')
cmd=[str(exe),str(a.end),'retain-step','100000']+([str(origin)]if origin else[]);t=time.monotonic();captured=set();capture_seconds={};censored=False
last_clock=None
def capture():
 global last_clock
 try:
  data=(out/'checkpoint.bin').read_bytes();assert zlib.crc32(data[:-4])==struct.unpack('=I',data[-4:])[0];pos=8
  for i in range(6):n=struct.unpack_from('=i',data,pos)[0];pos+=4+n
  nodes,clock=struct.unpack_from('=id',data,pos);assert nodes==113 and clock==int(clock)
  if clock in a.capture and clock not in captured:
   (out/f'checkpoint-{int(clock)}.bin').write_bytes(data);captured.add(clock);capture_seconds[int(clock)]=time.monotonic()-t
  if clock!=last_clock:
   last_clock=clock
   (out/'PROGRESS.json').write_text(json.dumps(dict(status='RUNNING',completed_days=int(clock),elapsed_seconds=time.monotonic()-t,checkpoint_sha256=hashlib.sha256(data).hexdigest(),capture_seconds=capture_seconds),indent=2)+'\n')
   if int(clock)%10==0:print('ORIGINAL_CHECKPOINT',int(clock),round(time.monotonic()-t,2),flush=True)
 except (FileNotFoundError,AssertionError,struct.error):pass
with (out/'stdout').open('wb')as so,(out/'stderr').open('wb')as se:
 (out/'LAUNCH.json').write_text(json.dumps(dict(command=cmd,source_sha256=build['source_sha256'],executable_sha256=sha(exe),restart_sha256=sha(origin)if origin else None),indent=2)+'\n')
 proc=subprocess.Popen(cmd,cwd=out,stdout=so,stderr=se)
 while proc.poll() is None:
  capture()
  if time.monotonic()-t>a.timeout:proc.kill();proc.wait();censored=True;break
  time.sleep(.03)
 capture()
rows=list(csv.DictReader((out/'budget.csv').open()))if(out/'budget.csv').exists()else[]
report=dict(status='CENSORED'if censored else('COMPLETED'if proc.returncode==0 else'FAILED'),command=cmd,returncode=proc.returncode,censored=censored,seconds=time.monotonic()-t,requested_days=a.end,completed_days=int(rows[-1]['day'])if rows else 0,captured=sorted(captured),capture_seconds=capture_seconds,source_sha256=build['source_sha256'],executable_sha256=sha(exe),maximum_water_residual_cm=max((abs(float(r['residual_cm']))for r in rows),default=None),maximum_heat_accounting_residual_j_cm2=max((abs(float(r['heat_residual_j_cm2']))for r in rows),default=None),last_stdout=(out/'stdout').read_text().splitlines()[-3:],files={f.name:sha(f)for f in out.iterdir()if f.is_file()})
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k not in ['source_sha256','files']}))
# PROGRESS is observational; only RESULT records an observed terminal exit.
