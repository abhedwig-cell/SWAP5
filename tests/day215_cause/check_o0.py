"""Single O0 confirmation of the isolated four-day finest diagnostic."""
import contextlib,json,shutil,subprocess
from run import ROOT,OUT,PRIOR,PROVIDER,P,m,POLICY,render,command,sha,rows
def main():
 original=__import__('pathlib').Path('C:/SWAP5-testing/irrigation-pulse-time01-composed/water-surface-history-O0-build');project=m.e.load(PRIOR/'inputs/water-surface-history',time_step_policy=POLICY);meta,case=m.validate_bundle(original,PROVIDER,project)
 build=OUT/'dt0004-swap5-O0-build';shutil.copytree(original,build);source=build/'swap.f90';source.write_text(render((original/'swap.f90').read_text(encoding='cp1252'),project.start_clock+211,0.0004,True),encoding='cp1252')
 compile=command(['gfortran',*meta['identity']['donor_flags'],'-I',P/'swap-obj','-I',P/'ttutil-obj','-c',source],build);exe=build/'day_donor.exe';objects=[build/x.name if (build/x.name).exists() else x for x in sorted((P/'swap-obj').glob('*.o'))];link=command(['gfortran','-o',exe,*objects,build/'hybrid_step_budget.o',P/'ttutil-obj/libttutil.a'],build)
 out=OUT/'dt0004-swap5-O0';out.mkdir();data=[]
 def trial():
  with contextlib.ExitStack() as stack:
   host=m.h.DailyHost(stack,exe,original/'day_kernel.exe',case,out,[m.h.ColumnStart('original',0,None,None)],runtime=True,model=project.model,project=project)
   with (out/'daily.jsonl').open('w') as j:
    for _ in range(215):
     row=host.step(1);data.append(row);j.write(json.dumps(row)+'\n');assert row['committed']
   host.close()
 _,seconds=m.bounded(30,trial);budgets=m.check(data);assert m.physical(data[:211])==m.physical(m.rows(PRIOR/'water-surface-history-O0-full')[:211])
 actual=rows(out/'original/result_output.csv');prior=rows(OUT/'dt0004-swap5/original/result_output.csv');r=dict(source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),seconds=seconds,budgets=budgets,first211_own_physical_rows_exact=True,diagnostic_source_sha256=sha(source),executable_sha256=sha(exe),compile=compile,link=link,day215_GWL_cm=float(actual[215]['GWL']),day212through215_O0_minus_O2_GWL_cm=[float(x['GWL'])-float(y['GWL']) for x,y in zip(actual[212:216],prior[212:216])],native_admission=False)
 (OUT/'O0_CHECK.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2)[:600])
if __name__=='__main__':main()
