"""Small executable calling real heat and transaction contracts, without legacy backend."""
import argparse, hashlib, json, re, subprocess, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir(exist_ok=False)
 sources=list(ROOT.glob('src/**/*.f90'))+list((ROOT/'tests/dataqual15/research').glob('*.f90'))
 providers={};uses={}
 for s in sources:
  text=s.read_text(encoding='utf-8');uses[s]=re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',text,re.M|re.I)
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',text,re.M|re.I):providers[name.lower()]=s
 ordered=[];seen=set()
 def visit(s):
  if s in seen:return
  seen.add(s)
  for name in uses[s]:
   if name.lower() in providers:visit(providers[name.lower()])
  ordered.append(s)
 visit(ROOT/'tests/dataqual15/research/native_feedback_component.f90')
 report=dict(optimization=a.optimization,baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),sources={},events=[])
 def run(cmd,label):
  t=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=60)
  (out/(label+'.stdout')).write_bytes(cp.stdout);(out/(label+'.stderr')).write_bytes(cp.stderr)
  report['events'].append(dict(label=label,seconds=time.monotonic()-t,returncode=cp.returncode))
  (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
  assert cp.returncode==0,(label,cp.stderr.decode(errors='replace'))
  return cp.stdout.decode()
 for key in ['tests/dataqual15/research/native_coupled_restart.inc','app/support/restart_publish.c','tests/dataqual15/qualify_native_feedback_component.py']:
  report['sources'][key]=subprocess.check_output(['git','rev-parse','HEAD:'+key],cwd=ROOT,text=True).strip()
 objects=[]
 for i,s in enumerate(ordered):
  key=s.relative_to(ROOT).as_posix();assert not subprocess.check_output(['git','diff','HEAD','--',key],cwd=ROOT)
  report['sources'][key]=subprocess.check_output(['git','rev-parse','HEAD:'+key],cwd=ROOT,text=True).strip()
  obj=out/(str(i)+'.o');run(['gfortran','-'+a.optimization,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-fbacktrace','-J'+str(out),'-I'+str(out),'-I'+str(ROOT/'tests/dataqual15/research'),'-c',s,'-o',obj],'compile-'+str(i));objects.append(obj)
 obj=out/'publish.o';run(['gcc','-O2','-c',ROOT/'app/support/restart_publish.c','-o',obj],'compile-publish');objects.append(obj)
 exe=out/'component.exe';run(['gfortran',*objects,'-o',exe],'link');stdout=run([exe],'execute')
 assert 'NATIVE_FEEDBACK_TRANSACTION_COMPONENT_PASS' in stdout
 report.update(status='PASS',compile_closure=len(ordered),stdout=stdout,executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest())
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(stdout)
if __name__=='__main__':main()
