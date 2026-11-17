"""Four storm days, identical own prehistory, explicit diagnostic time caps."""
from pathlib import Path
import contextlib,csv,hashlib,importlib.util,json,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('mixtures',ROOT/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from irrigation_pulse_time import POLICY
OUT=Path('C:/SWAP5-testing/day215-cause01');PRIOR=Path('C:/SWAP5-testing/irrigation-pulse-time01');PROVIDER=Path('C:/SWAP5-RC2/provider');P=PROVIDER/'build'
BUILD=Path('C:/SWAP5-testing/irrigation-pulse-time01-composed/water-surface-history-O2-build')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return list(csv.DictReader(x for x in p.read_text(encoding='cp1252').splitlines() if x and not x.startswith('*')))
def command(cmd,cwd):
 r=subprocess.run([str(x) for x in cmd],cwd=cwd,capture_output=True,text=True,timeout=30)
 if r.returncode:raise RuntimeError(r.stdout+r.stderr)
 return list(map(str,cmd))
def render(source,clock,cap,donor):
 anchor='gwl, gwlm1, dt, t1900';assert source.count(anchor)==1
 source=source.replace(anchor,anchor+', dtmax'+('' if donor else ', h, theta'))
 anchor='         call TimeControl(2)';assert source.count(anchor)==1
 if cap is not None:source=source.replace(anchor,f'         if(t1900>={clock:.0f}d0)then\n            dtmax={cap:.17g}d0;dt=min(dt,dtmax)\n         endif\n'+anchor)
 anchor='      call integral(3)';assert source.count(anchor)==1
 return source.replace(anchor,anchor+f"\n      if(t1900>={clock:.0f}d0)write(*,'(a,*(1x,es25.17e3))') 'GWL_STORM_STEP',t1900,dt,gwl,h(1:numnod),theta(1:numnod)\n")
def main():
 OUT.mkdir(parents=True,exist_ok=False);project=m.e.load(PRIOR/'inputs/water-surface-history',time_step_policy=POLICY);meta,case=m.validate_bundle(BUILD,PROVIDER,project);m.user_prepare.validate(PROVIDER)
 reference=rows(PRIOR/'finish-controls/water-surface-history-original431/result_output.csv');qualified=rows(PRIOR/'water-surface-history-O2-full/original/result_output.csv');qualified_daily=m.rows(PRIOR/'water-surface-history-O2-full')
 result=dict(source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),baseline='fd162a1ea22c41e798a431f39957aaff9c173e46',provider_sha256=sha(PROVIDER/'PREPARED.json'),policy=POLICY,diagnostic_only=True,tolerances_changed=False,science='NOT_QUALIFIED',profiles={})
 def save():(OUT/'RESULT.json').write_text(json.dumps(result,indent=2))
 for name,cap in (('nominal',None),('dt004',0.004),('dt0004',0.0004)):
  record=result['profiles'][name]={};clock=project.start_clock+211
  for donor in (False,True):
   kind='swap5' if donor else 'original';build=OUT/(name+'-'+kind+'-build')
   if donor:shutil.copytree(BUILD,build)
   else:build.mkdir()
   original=(BUILD/'swap.f90' if donor else P/'swap-selected/swap.f90');source=build/'swap.f90';source.write_text(render(original.read_text(encoding='cp1252'),clock,cap,donor),encoding='cp1252')
   flags=meta['identity']['donor_flags'];compile=command(['gfortran',*flags,'-I',P/'swap-obj','-I',P/'ttutil-obj','-c',source],build)
   objects=[build/x.name if (build/x.name).exists() else x for x in sorted((P/'swap-obj').glob('*.o'))];exe=build/('day_donor.exe' if donor else 'original_diagnostic.exe')
   link=command(['gfortran','-o',exe,*objects,*([build/'hybrid_step_budget.o'] if donor else []),P/'ttutil-obj/libttutil.a'],build)
   out=OUT/(name+'-'+kind);data=[]
   if donor:
    out.mkdir()
    def trial():
     with contextlib.ExitStack() as stack:
      host=m.h.DailyHost(stack,exe,BUILD/'day_kernel.exe',case,out,[m.h.ColumnStart('original',0,None,None)],runtime=True,model=project.model,project=project)
      with (out/'daily.jsonl').open('w') as j:
       for _ in range(215):
        row=host.step(1);data.append(row);j.write(json.dumps(row)+'\n');assert row['committed']
      host.close()
    _,seconds=m.bounded(30,trial);budgets=m.check(data);actual=rows(out/'original/result_output.csv');assert m.physical(data[:211])==m.physical(qualified_daily[:211]);assert actual[:212]==qualified[:212]
    if cap is None:assert actual==qualified[:216] and m.physical(data)==m.physical(qualified_daily[:215])
   else:
    shutil.copytree(PRIOR/'finish-controls/water-surface-history-literal-input',out)
    p=out/'swap.swp';s=p.read_text(encoding='cp1252');assert 'TEND = 2004-12-31' in s;p.write_text(s.replace('TEND = 2004-12-31','TEND = 2002-08-03'),encoding='cp1252');start=time.perf_counter()
    with (out/'stdout').open('wb') as log:r=subprocess.run([str(exe),'./swap.swp'],cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=20)
    seconds=time.perf_counter()-start;assert (out/'swap.ok').exists();actual=rows(out/'result_output.csv');assert actual[:212]==reference[:212]
    if cap is None:assert actual==reference[:216]
    budgets=None
   assert len(actual)==216
   record[kind]=dict(seconds=seconds,source_original_sha256=sha(original),diagnostic_source_sha256=sha(source),executable_sha256=sha(exe),compile=compile,link=link,own_initial211_rows_exact=True,budgets=budgets,day212through215=actual[212:216],native_admission=False)
   save();print(name,kind,round(seconds,3),actual[215]['GWL'],flush=True)
  record['GWL_differences_cm']=[float(a['GWL'])-float(b['GWL']) for a,b in zip(record['swap5']['day212through215'],record['original']['day212through215'])];save();print('DELTAS',name,record['GWL_differences_cm'],flush=True)
 result['status']='BOUNDED_STORM_REFINEMENT_WITH_EXACT_OWN_PREHISTORY_COMPLETE';save()
if __name__=='__main__':main()
