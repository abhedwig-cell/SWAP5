"""Bounded corrected-original loop with the existing strict water-step owner.

Not literal B0 or an independently qualified universal physical reference.
Original daily/output control is retained; the admitted strict HeadCalc is shared
explicitly. Its legacy BALDEV is an independently summed balance observation.
"""
from pathlib import Path
import argparse,json,shutil,subprocess,time
from run import m
from candidate_saturation import csvrows
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--corrected',type=Path,required=True);p.add_argument('--common',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--include-fine',action='store_true');a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=a.reference_work/'build';actual=a.corrected/'water-surface-history-O2-build';meta=json.loads((actual/'BUILD.json').read_text());result={'kind':'CORRECTED_ORIGINAL_CONTROL_SHARED_STRICT_HEADCALC_DIAGNOSTIC_NOT_LITERAL_B0','shared_physical_headcalc':True,'water_guard_cm':1e-10,'tolerances_changed':False,'science':'NOT_QUALIFIED','profiles':{}}
 for label,cap in [('dt0001',.0001),('dt000025',.000025)]+([('dt00000625',.00000625)] if a.include_fine else []):
  build=out/(label+'-build');build.mkdir();source=build/'swap.f90';s=(ref/'swap-selected/swap.f90').read_text(encoding='cp1252');prefix=(actual/'swap.f90').read_text().split('end module hybrid_day_window')[0]+'end module hybrid_day_window\n';s=prefix+s;s=s.replace('use swap_exchange\n','use swap_exchange\nuse hybrid_day_window,only:budget_enabled,budget_total,budget_step,budget_start\n');s=s.replace('gwl, gwlm1, dt, t1900','gwl, gwlm1, dt, dtmax, t1900');anchor='         call TimeControl(2)';assert s.count(anchor)==1;s=s.replace(anchor,f'         budget_enabled=.true.;budget_total=0d0;budget_step=0d0;budget_start=t1900\n         dtmax={cap:.17f}d0;dt=min(dt,dtmax)\n'+anchor);anchor='         if (.NOT.fldecdt) call SoilWater(2)';assert s.count(anchor)==1;s=s.replace(anchor,'         if(.not.fldecdt)budget_total=budget_total+budget_step\n'+anchor);source.write_text(s,encoding='cp1252')
  flags=meta['identity']['donor_flags'];cmds=[['gfortran',*flags,'-I',str(build),'-I',str(actual),'-I',str(ref/'swap-obj'),'-I',str(ref/'ttutil-obj'),'-J',str(build),'-c',str(source)]]
  exe=build/'strict_original.exe';cmds.append(['gfortran','-o',str(exe),*[str(build/'swap.o' if x.name=='swap.o' else actual/'headcalc.o' if x.name=='headcalc.o' else x) for x in sorted((ref/'swap-obj').glob('*.o'))],str(actual/'hybrid_step_budget.o'),str(ref/'ttutil-obj/libttutil.a')])
  for cmd in cmds:
   r=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
  folder=out/label;folder.mkdir()
  for f in (a.common/'original').iterdir():
   if f.is_file() and (f.suffix.lower() in ('.swp','.met','.crp','.dra','.ru','.cmd','.inp') or f.name in ('restart.end','macro.bin')):shutil.copy2(f,folder/f.name)
  start=time.perf_counter()
  try:
   with (folder/'strict.stdout').open('wb') as f:r=subprocess.run([str(exe),'./swap.swp'],cwd=folder,stdout=f,stderr=subprocess.STDOUT,timeout=20)
  except subprocess.TimeoutExpired:
   result['profiles'][label]=dict(status='CENSORED_AT_20_SECONDS_NOT_QUALIFIED',seconds=time.perf_counter()-start,commands=cmds,executable_sha256=m.sha(exe));(out/'RESULT.json').write_text(json.dumps(result,indent=2));return
  rows=csvrows(folder/'result_output.csv');assert r.returncode==100 and len(rows)==4 and (folder/'swap.ok').exists();res=dict(seconds=time.perf_counter()-start,commands=cmds,source_sha256=m.sha(source),headcalc_sha256=m.sha(actual/'headcalc.f90'),executable_sha256=m.sha(exe),initial=rows[0],day364=rows[2],maximum_absolute_original_BALDEV_cm=max(abs(float(v['BALDEV'])) for v in rows[1:]));result['profiles'][label]=res;(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(label,res['seconds'],rows[2]['GWL'],res['maximum_absolute_original_BALDEV_cm'],flush=True)
if __name__=='__main__':main()
