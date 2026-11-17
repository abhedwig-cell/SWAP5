"""Short explicit-input temporal discrimination on source-bound donor images."""
from pathlib import Path
import contextlib,importlib.util,json,re,shutil,sys,time
from refine import ROOT,OUT,OLD,sha,rows
spec=importlib.util.spec_from_file_location('mixtures',ROOT/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def main():
 result={};ref=json.loads((OUT/'RESULT.json').read_text())
 for opt in ('O0','O2'):
  for name,dt in [('dt004',0.004),('dt0004',0.0004)]:
   key=opt+'-'+name;case=OUT/(key+'-input');shutil.copytree(OLD/'inputs/water-surface-history',case)
   p=case/'swap.swp';s,n=re.subn(r'(?m)^(\s*DTMAX\s*=\s*)[\d.]+',lambda x:x[1]+str(dt),p.read_text(encoding='cp1252'));assert n==1;p.write_text(s,encoding='cp1252')
   project=m.e.load(case);build=OUT/('current-'+opt+'-trace-build');plain=OUT/('current-'+opt+'-build');output=OUT/(key+'-trial');output.mkdir();data=[]
   def trial():
    with contextlib.ExitStack() as stack:
     host=m.h.DailyHost(stack,build/'day_donor.exe',plain/'day_kernel.exe',case,output,[m.h.ColumnStart('original',0,None,None)],runtime=True,model=project.model,project=project)
     with (output/'daily.jsonl').open('w') as j:
      for _ in range(5):
       row=host.step(1);data.append(row);j.write(json.dumps(row)+'\n');assert row['committed']
     host.close()
   _,seconds=m.bounded(30,trial);budgets=m.check(data);csv=rows(output/'original/result_output.csv');r=ref['runs'][name]['end'];last=csv[-1]
   result[key]=dict(dtmax=dt,seconds=seconds,diagnostic_input_sha256={p.name:sha(p) for p in case.iterdir() if p.is_file()},donor_sha256=sha(build/'day_donor.exe'),kernel_sha256=sha(plain/'day_kernel.exe'),budgets=budgets,end=last,day5_delta={k:float(last[k])-float(r[k]) for k in ('GWL','WTOT','RUNOFF','DRN')},tolerances_changed=False)
   (OUT/'SWAP5_REFINEMENT.json').write_text(json.dumps(result,indent=2));print(key,seconds,result[key]['day5_delta'],flush=True)
if __name__=='__main__':main()
