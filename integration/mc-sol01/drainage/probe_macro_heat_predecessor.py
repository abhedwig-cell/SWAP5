"""Run the exact qualified thermal driver against the unchanged baseline objects."""
import argparse,hashlib,json,os,resource,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];BASE='043e92ac319d3a3b8ca40b57e995be60db91679a';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--baseline',default=BASE);p.add_argument('--build',type=Path,required=True);p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();BASE=a.baseline;out=a.output.resolve();out.mkdir();b=json.loads((a.build/'build-complete.json').read_text())
for p,h in b['input_sha256'].items():assert hashlib.sha256(subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)).hexdigest()==h,p
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
objects=[e['command'][-1]for e in b['events']if e['category']=='compile'][:-1];driver=a.proof.resolve()/'replay.f90';target=out/'replay.f90';target.write_bytes(driver.read_bytes());flags=[x for x in b['flags']if not x.startswith('-J')];exe=out/'replay';events=[]
for label,cmd in [('link',b['compiler_command']+flags+['-J'+str(out),str(target),*objects,str(a.build/'libttutil.a'),'-o',str(exe)]),('native',[str(exe)])]:
 t=time.monotonic();r=subprocess.run(cmd,cwd=out,capture_output=True,env=dict(os.environ,WU05_MIGMAC10='1',WU05_MIGMAC10_RUTTER='1',WU05_MIGMAC02_DYNAMIC='3',MACRO_TRACE_ON='0'))
 for name in ['stdout','stderr']:(out/(label+'.'+name)).write_bytes(getattr(r,name))
 events.append(dict(label=label,command=cmd,returncode=r.returncode,seconds=time.monotonic()-t))
 if label=='link':assert r.returncode==0,r.stderr.decode()
 else:assert r.returncode!=0 and b'A9 FMR top-input active serialized trial'in r.stderr
(out/'RESULT.json').write_text(json.dumps(dict(status='EXACT_DRIVER_BASELINE_REJECTION',baseline=BASE,driver_sha256=sha(target),events=events,baseline_source_sha256=b['input_sha256']),indent=2)+'\n')
print('EXACT_DRIVER_BASELINE_REJECTION')
