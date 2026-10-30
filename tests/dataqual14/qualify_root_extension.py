import argparse,hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];W=ROOT.parent;sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();ref=W/'dq13-reference431/providers';driver=ROOT/'tests/dataqual14/root_extension_oracle.f90';mapping={}
for s in(ROOT/'src').rglob('*.f90'):
 for n in re.findall(r'^\s*module\s+(\w+)\s*$',s.read_text(),re.M|re.I):mapping[n.lower()]=s
order=[];seen=set()
def visit(s):
 if s in seen:return
 seen.add(s)
 for n in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',s.read_text(),re.M|re.I):
  if n.lower()in mapping:visit(mapping[n.lower()])
 order.append(s)
visit(driver);order.remove(driver);events=[]
def run(cmd,cwd=out):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),capture_output=True,cwd=cwd,timeout=60);events.append(dict(command=list(map(str,cmd)),seconds=time.monotonic()-t,returncode=r.returncode));(out/'EVENTS.json').write_text(json.dumps(events,indent=2));(out/(str(len(events))+'.stderr')).write_bytes(r.stderr);assert r.returncode==0,r.stderr.decode()+r.stdout.decode();return r.stdout
for opt in ['O0','O2']:
 f=out/opt;f.mkdir();flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-I'+str(f),'-J'+str(f),'-I'+str(ref/'swobj')];objects=[]
 for i,s in enumerate(order):
  obj=f/(str(i)+'.o');run([a.compiler,*flags,'-c',s,'-o',obj]);objects.append(obj)
 run([a.compiler,*flags,driver,*objects,*list((ref/'swobj').glob('*.o')),ref/'ttobj/libttutil.a','-o',f/'test'])
 raw=run([f/'test']);(f/'stdout').write_bytes(raw);assert b'ORIGINAL_SWRD2_ACTIVE_ROOT_PASS'in raw;print(opt,raw.decode(),flush=True)
(out/'RESULT.json').write_text(json.dumps(dict(status='ORIGINAL_SWRD2_ACTIVE_ROOT_PASS',source_sha256={str(s.relative_to(ROOT)):sha(s)for s in order+[driver]},original_routine='Unmodified compiled original update_rootextension; original constants NIHIL1e-10,TINY1e-3,SMALL1e-6.',events=events),indent=2))
