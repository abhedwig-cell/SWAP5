"""One final convergence discriminator, fixed five-day horizon and 20/30s caps."""
import contextlib,importlib.util,json,re,shutil,subprocess,time
from refine import ROOT,OUT,OLD,sha,rows
spec=importlib.util.spec_from_file_location('mixtures',ROOT/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def main():
 case=OUT/'dt00004-input';shutil.copytree(OLD/'inputs/water-surface-history',case)
 p=case/'swap.swp';s,n=re.subn(r'(?m)^(\s*DTMAX\s*=\s*)[\d.]+',r'\g<1>0.00004',p.read_text(encoding='cp1252'));assert n==1;p.write_text(s,encoding='cp1252')
 original=OUT/'dt00004-original';shutil.copytree(case,original);p=original/'swap.swp';s=p.read_text(encoding='cp1252');s=s.replace('TEND = 2004-12-31','TEND = 2002-01-05');p.write_text(s,encoding='cp1252')
 exe=OLD/'../nonexistent';exe=__import__('pathlib').Path('C:/SWAP5-RC2/provider/build/swap_b0_gfortran.exe');start=time.perf_counter()
 with (original/'stdout').open('wb') as log:r=subprocess.run([str(exe),'./swap.swp'],cwd=original,stdout=log,stderr=subprocess.STDOUT,timeout=20)
 ref=rows(original/'result_output.csv');assert len(ref)==6 and (original/'swap.ok').exists();result={'dtmax':0.00004,'original':dict(seconds=time.perf_counter()-start,returncode=r.returncode,executable_sha256=sha(exe),end=ref[-1]),'profiles':{}}
 for opt in ('O2','O0'):
  project=m.e.load(case);build=OUT/('current-'+opt+'-trace-build');plain=OUT/('current-'+opt+'-build');output=OUT/('finest-'+opt);output.mkdir();data=[]
  def trial():
   with contextlib.ExitStack() as stack:
    host=m.h.DailyHost(stack,build/'day_donor.exe',plain/'day_kernel.exe',case,output,[m.h.ColumnStart('original',0,None,None)],runtime=True,model=project.model,project=project)
    with (output/'daily.jsonl').open('w') as j:
     for _ in range(5):
      row=host.step(1);data.append(row);j.write(json.dumps(row)+'\n');assert row['committed']
    host.close()
  _,seconds=m.bounded(30,trial);budgets=m.check(data);csv=rows(output/'original/result_output.csv');last=csv[-1]
  result['profiles'][opt]=dict(seconds=seconds,budgets=budgets,end=last,day5_delta={k:float(last[k])-float(ref[-1][k]) for k in ('GWL','WTOT','RUNOFF','DRN')},firstday_delta_GWL_cm=float(csv[1]['GWL'])-float(ref[1]['GWL']))
  (OUT/'FINEST.json').write_text(json.dumps(result,indent=2));print(opt,seconds,result['profiles'][opt]['day5_delta'],flush=True)
 assert result['profiles']['O0']['end']==result['profiles']['O2']['end']
if __name__=='__main__':main()
