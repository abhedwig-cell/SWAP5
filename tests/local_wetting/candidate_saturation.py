"""Refine only the same late three-day interval in the actual SWAP5 worker.

Diagnostic caps never become a new production policy or reference qualification.
"""
from pathlib import Path
import argparse,contextlib,json,shutil,subprocess,csv
from run import m,POLICY

def csvrows(p):return list(csv.DictReader(s for s in p.read_text(encoding='cp1252').splitlines() if s and not s.startswith('*')))
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--prior',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=a.reference_work/'build';name='water-surface-history-O2';original=a.prior/(name+'-build');meta=json.loads((original/'BUILD.json').read_text());project=m.e.load(a.prior/'inputs/water-surface-history',time_step_policy=POLICY);old=m.rows(a.prior/(name+'-full'));result={'kind':'SAME_LATE_INTERVAL_CANDIDATE_ACCURACY_DIAGNOSTIC_NOT_NEW_POLICY','tolerances_changed':False,'profiles':{}}
 for label,cap in [('dt0001',.0001),('dt000025',.000025)]:
  build=out/(label+'-build');shutil.copytree(original,build);src=build/'swap.f90';s=src.read_text(encoding='cp1252');s=s.replace('gwl, gwlm1, dt, t1900','gwl, gwlm1, dt, dtmax, t1900');anchor='         call TimeControl(2)';assert s.count(anchor)==1;s=s.replace(anchor,f'         if(t1900>=37618d0)then\n            dtmax={cap:.17f}d0;dt=min(dt,dtmax)\n         endif\n'+anchor);src.write_text(s,encoding='cp1252');commands=[['gfortran',*meta['identity']['donor_flags'],'-I',str(build),'-I',str(ref/'swap-obj'),'-I',str(ref/'ttutil-obj'),'-J',str(build),'-c',str(src)]]
  objects=[build/x.name if (build/x.name).exists() else x for x in sorted((ref/'swap-obj').glob('*.o'))];exe=build/'late_cap.exe';commands.append(['gfortran','-o',str(exe),*map(str,objects),str(build/'hybrid_step_budget.o'),str(ref/'ttutil-obj/libttutil.a')])
  for cmd in commands:
   r=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
  folder=out/label;folder.mkdir();data=[]
  def trial():
   with contextlib.ExitStack() as stack:
    binding={**meta['binding'],'diagnostic_late_cap':{'source':m.sha(src),'exe':m.sha(exe),'dtmax':cap}}
    host=m.h.DailyHost(stack,exe,build/'day_kernel.exe',a.prior/'inputs/water-surface-history',folder,[m.h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=project.model,project=project)
    with (folder/'daily.jsonl').open('w') as f:
     for d in range(1,366):
      row=host.step(1,checkpoint=d==365);data.append(row);f.write(json.dumps(row)+'\n');assert row['committed']
    host.close()
  _,seconds=m.bounded(30,trial);assert m.physical(data[:362])==m.physical(old[:362]);budget=m.check(data)
  result['profiles'][label]=dict(seconds=seconds,exact_own_first362_days=True,commands=commands,source_sha256=m.sha(src),executable_sha256=m.sha(exe),budgets=budget,day364=data[363],csv_day364=csvrows(folder/'original/result_output.csv')[364])
  (out/'RESULT.json').write_text(json.dumps(result,indent=2));print(label,seconds,data[363]['groundwater_cm'],flush=True)
if __name__=='__main__':main()
