"""Actual checked O2 CPU observations for the qualified prefix and wet failure."""
import argparse,csv,json,resource,shutil,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--exe',type=Path,required=True);p.add_argument('--normal',type=Path,required=True);p.add_argument('--wet',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();runs={}
for label,source,days,rc in [('normal',a.normal,469,0),('wet',a.wet,97,1)]:
 stage=out/label;stage.mkdir()
 for name in ['input.nml','input.swp']:shutil.copy2(source/name,stage/name)
 cmd=[str(a.exe.resolve()),'input.nml','-',str(days),'input.swp'];before=resource.getrusage(resource.RUSAGE_CHILDREN);t=time.perf_counter();r=subprocess.run(cmd,cwd=stage,capture_output=True,timeout=300);wall=time.perf_counter()-t;after=resource.getrusage(resource.RUSAGE_CHILDREN)
 for k in ['stdout','stderr']:(stage/k).write_bytes(getattr(r,k))
 assert r.returncode==rc
 for name in (['budget.csv','state.csv','endpoint.csv','restart.bin']if rc==0 else['budget.csv','diagnostic-rejected.bin','diagnostic-partial-candidate.bin']):assert(stage/name).read_bytes()==(source/name).read_bytes(),name
 runs[label]=dict(returncode=r.returncode,requested_days=days,complete_days=len(list(csv.DictReader((stage/'budget.csv').open()))),user_cpu_seconds=after.ru_utime-before.ru_utime,system_cpu_seconds=after.ru_stime-before.ru_stime,wall_seconds=wall,command=cmd,temporal_tolerance=.001)
(out/'result.json').write_text(json.dumps(dict(status='ACTUAL_CPU_NOT_GENERAL_SPEED_CLAIM',runs=runs),indent=2)+'\n');print(json.dumps(runs))
