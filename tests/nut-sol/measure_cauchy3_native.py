"""Measured BBC normal/wet observations; wet rejection never means qualification."""
import argparse,csv,json,resource,shutil,subprocess,time
from pathlib import Path
def main():
 p=argparse.ArgumentParser();p.add_argument('--exe',type=Path,required=True);p.add_argument('--normal',type=Path,required=True);p.add_argument('--wet',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir();runs={}
 for label,source,expected in [('normal',a.normal,0),('wet',a.wet,1)]:
  stage=out/label;stage.mkdir()
  for name in ['input.nml','input.swp']:shutil.copy2(source/name,stage/name)
  cmd=[str(a.exe.resolve()),'input.nml','-', '97','input.swp'];before=resource.getrusage(resource.RUSAGE_CHILDREN);t=time.perf_counter();r=subprocess.run(cmd,cwd=stage,capture_output=True,timeout=300);elapsed=time.perf_counter()-t;after=resource.getrusage(resource.RUSAGE_CHILDREN)
  for stream in ['stdout','stderr']:(stage/stream).write_bytes(getattr(r,stream))
  assert r.returncode==expected
  data=list(csv.DictReader((stage/'budget.csv').open()));assert len(data)==(97 if expected==0 else 3)
  runs[label]=dict(command=cmd,returncode=r.returncode,complete_days=len(data),user_cpu_seconds=after.ru_utime-before.ru_utime,system_cpu_seconds=after.ru_stime-before.ru_stime,wall_seconds=elapsed,qualified=expected==0)
 (out/'result.json').write_text(json.dumps(dict(status='ACTUAL_CPU_NOT_GENERAL_SPEED_CLAIM',runs=runs),indent=2)+'\n')
if __name__=='__main__':main()
