"""Actual complete POSIX writer: precommit failures and postcommit dirsync refusal."""
import argparse,json,os,subprocess
from pathlib import Path
import matrix_thermal_native_policy as policy
from matrix_thermal_native_windows import build

def main():
 p=argparse.ArgumentParser();p.add_argument('--candidate',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert os.name=='posix';policy.guard();base=a.candidate.resolve();out=a.output.resolve();out.mkdir(parents=True);events=[]
 for opt in ('O0','O2'):
  directory=out/opt;directory.mkdir();exe=build(base,opt,directory,a.compiler.resolve());old=(base/'physical'/opt/'2/restart.bin').read_bytes();goodpath=base/'physical'/opt/'2/full.bin';good=goodpath.read_bytes()
  for kind,value in [('logical',1),('logical',2),*[('io',i) for i in (2,3,4,5,6)]]:
   case=directory/(kind+'-'+str(value));case.mkdir();target=case/'authority';after=case/'after';target.write_bytes(old);env=dict(os.environ,OMP_NUM_THREADS='1',MTPUB_TARGET=str(target));env['MT_BAD_LOGICAL' if kind=='logical' else 'MTPUB_FAIL']=str(value)
   cmd=[str(exe),'probe-writer',str(goodpath),str(target),'2','1.0',str(after)];cp=subprocess.run(cmd,cwd=case,env=env,capture_output=True,timeout=180);index=len(events)
   for stream in ('stdout','stderr'):(out/(str(index)+'.'+stream)).write_bytes(getattr(cp,stream))
   # Stage6 is a reported failure AFTER replacement, exactly as the original
   # combined matrix restart contract requires. It must never become success.
   assert cp.returncode==0 and b'WRITE_STATUS=1' in cp.stdout,(cp.stdout,cp.stderr)
   replaced=kind=='io' and value==6;assert target.read_bytes()==(good if replaced else old) and after.read_bytes()==good
   events.append(dict(kind=kind,value=value,optimization=opt,returncode=cp.returncode,stdout=str(index)+'.stdout',stderr=str(index)+'.stderr',published=replaced,reported_failure=True));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
 (out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_COMPLETE_POSIX_WRITER_PRECOMMIT_AND_POSTCOMMIT_FAILURE_CONTRACT_PASS',events=events,production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
if __name__=='__main__':main()
