"""Small actual F-KT endpoint contract and incumbent interval preservation.

No copied kernel, physics admission, persistent second state owner or large
native project is substituted for this direct production-interface gate.
"""
import argparse,hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir()
fc=a.compiler.resolve();mapping={}
for s in (ROOT/'src').rglob('*.f90'):
 for n in re.findall(r'^\s*module\s+(\w+)\s*$',s.read_text(),re.M|re.I):mapping[n.lower()]=s
drivers=[ROOT/'tests/dataqual15_hupsel/test_kernel_endpoint_event.f90',ROOT/'tests/fkt/test_fkt22_kernel_trajectory_transport.f90']
ordered=[];seen=set()
def visit(s):
 if s in seen:return
 seen.add(s)
 for n in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',s.read_text(),re.M|re.I):
  if n.lower()in mapping and mapping[n.lower()]!=s:visit(mapping[n.lower()])
 ordered.append(s)
for s in drivers:visit(s)
providers=[s for s in ordered if s not in drivers];events=[];results={}
for opt in ('O0','O2'):
 b=out/opt;b.mkdir();flags=['-'+opt,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
 def run(cmd,label):
  start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=b,capture_output=True,timeout=60);i=len(events);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr);events.append(dict(command=list(map(str,cmd)),label=label,seconds=time.monotonic()-start,returncode=r.returncode));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,(label,r.stdout.decode(errors='replace'),r.stderr.decode(errors='replace'));return r.stdout.decode().replace('\r\n','\n')
 objects=[]
 for i,s in enumerate(providers):
  obj=b/f'{i}.o';run([fc,*flags,'-c',s,'-o',obj],'compile');objects.append(obj)
 results[opt]={}
 for i,s in enumerate(drivers):
  exe=b/(str(i)+'.exe');run([fc,*flags,s,*objects,'-o',exe],'link')
  stdout=run([exe],'native');assert 'PASS'in stdout
  results[opt][s.relative_to(ROOT).as_posix()]=dict(stdout=stdout,executable_sha256=sha(exe))
assert {k:v['stdout']for k,v in results['O0'].items()}=={k:v['stdout']for k,v in results['O2'].items()}
report=dict(status='ACTUAL_KERNEL_ENDPOINT_AND_INCUMBENT_INTERVAL_O0_O2_PASS_NOT_PHYSICS_ADMISSION',compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0],provider_count=len(providers),source_sha256={s.relative_to(ROOT).as_posix():sha(s)for s in ordered},results=results,cost_seconds={label:sum(e['seconds']for e in events if e['label']==label)for label in ('compile','link','native')},production_event_admission=False)
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
