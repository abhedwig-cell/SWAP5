"""Capture accepted target steps, checking that observation leaves its output exact."""
from pathlib import Path
import argparse,contextlib,json,shutil,subprocess
from run import m,POLICY
def main():
 p=argparse.ArgumentParser();p.add_argument('--provider',type=Path,required=True);p.add_argument('--prior',type=Path,required=True);p.add_argument('--candidate-build',type=Path,required=True);p.add_argument('--control',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=a.provider/'build';build=out/'build';shutil.copytree(a.candidate_build,build);src=build/'swap.f90';s=src.read_text();anchor='      call SoilWater(3)';assert s.count(anchor)==1;s=s.replace(anchor,'''      if(t1900>=37618d0)then
       block
        integer,save::grid_unit=0
        if(grid_unit==0)open(newunit=grid_unit,file='accepted-grid.txt',status='new',action='write')
        write(grid_unit,'(*(g0,1x))')t1900,dt
       end block
      endif
'''+anchor);src.write_text(s);meta=json.loads((build/'BUILD.json').read_text());commands=[['gfortran',*meta['identity']['donor_flags'],'-I',str(build),'-I',str(ref/'swap-obj'),'-I',str(ref/'ttutil-obj'),'-J',str(build),'-c',str(src)]];exe=build/'grid_capture.exe';objects=[build/v.name if (build/v.name).exists() else v for v in sorted((ref/'swap-obj').glob('*.o'))];commands.append(['gfortran','-o',str(exe),*map(str,objects),str(build/'hybrid_step_budget.o'),str(ref/'ttutil-obj/libttutil.a')])
 for cmd in commands:
  r=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
 project=m.e.load(a.prior/'inputs/water-surface-history',time_step_policy=POLICY);folder=out/'candidate';folder.mkdir();data=[]
 def trial():
  with contextlib.ExitStack() as stack:
   host=m.h.DailyHost(stack,exe,m.h.executable(build,'day_kernel'),a.prior/'inputs/water-surface-history',folder,[m.h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding={**meta['binding'],'grid_capture':m.sha(src)},model=project.model,project=project)
   with (folder/'daily.jsonl').open('w') as f:
    for d in range(1,366):
     row=host.step(1,checkpoint=d==362);data.append(row);f.write(json.dumps(row)+'\n')
   host.close()
 _,seconds=m.bounded(30,trial);assert m.physical(data)==m.physical(m.rows(a.control)[:365]);m.check(data);grid=folder/'original/accepted-grid.txt';steps=[tuple(map(float,s.split())) for s in grid.read_text().splitlines()];assert steps and steps[0][0]==37618 and all(dt>0 for _,dt in steps);result=dict(status='GRID_OBSERVER_PHYSICAL_EXACT',seconds=seconds,steps=len(steps),grid_sha256=m.sha(grid),commands=commands,source_sha256=m.sha(src),executable_sha256=m.sha(exe));(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps({k:v for k,v in result.items() if k!='commands'}))
if __name__=='__main__':main()
