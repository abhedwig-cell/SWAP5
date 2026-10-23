"""Single actual normal/wet CPU observations; no portable speed claim."""
import argparse,json,resource,shutil,subprocess,time
from pathlib import Path
def main():
 p=argparse.ArgumentParser();p.add_argument('--exe',type=Path,required=True);p.add_argument('--normal',type=Path,required=True);p.add_argument('--wet',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();r={}
 for label,source,days in [('normal',a.normal,481),('wet',a.wet,97)]:
  stage=out/label;stage.mkdir()
  for name in ['input.swp','input.nml']:shutil.copy2(source/name,stage/name)
  cmd=[str(a.exe.resolve()),'input.nml','-',str(days),'input.swp'];before=resource.getrusage(resource.RUSAGE_CHILDREN);t=time.perf_counter();cp=subprocess.run(cmd,cwd=stage,capture_output=True,timeout=300);wall=time.perf_counter()-t;after=resource.getrusage(resource.RUSAGE_CHILDREN)
  for stream in ['stdout','stderr']:(stage/stream).write_bytes(getattr(cp,stream))
  assert cp.returncode==(0 if label=='normal'else 1)
  if label=='normal':
   for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:assert(stage/name).read_bytes()==(source/name).read_bytes(),name
  else:assert(stage/'diagnostic-rejected.bin').read_bytes()==(source/'diagnostic-rejected.bin').read_bytes()
  r[label]=dict(command=cmd,returncode=cp.returncode,wall_seconds=wall,user_cpu_seconds=after.ru_utime-before.ru_utime,system_cpu_seconds=after.ru_stime-before.ru_stime,complete_days=481 if label=='normal'else 6,temporal_tolerance=.001)
 (out/'result.json').write_text(json.dumps(dict(status='ACTUAL_CPU_OBSERVATIONS_NOT_A_SPEED_COMPARISON',runs=r),indent=2)+'\n');print(json.dumps(r))
if __name__=='__main__':main()
