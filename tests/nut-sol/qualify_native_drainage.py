"""Real native DRAMET3/DIVDRA composition, budgets and source-bound restart."""
import argparse,csv,hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def rows(p):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader(p.open())]
def main():
 p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--fixture',type=Path,required=True);p.add_argument('--drainage',type=Path,required=True);p.add_argument('--days',type=int,default=481);a=p.parse_args()
 out=a.output.resolve();out.mkdir();case=out/'project';case.mkdir();events=[]
 for folder in ['crop data','weather data']:shutil.copytree(a.fixture/folder,case/folder)
 swp=(a.fixture/'project.swp').read_text();assert 'SWDRA'not in swp.upper()
 (case/'project.swp').write_text(swp+"\nSWDRA=1\nDRFIL='swap'\nPATHDRAIN=' '\n")
 original=a.drainage.read_bytes();(case/'swap.dra').write_bytes(original)
 common=[sys.executable,ROOT/'tools/solute/run_project.py',case/'project.swp','--bundle',a.bundle,'--temporal-tolerance','.001',
  '--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
 report=dict(status='RUNNING',events=events,original_drainage_sha256=hashlib.sha256(original).hexdigest(),days=a.days,full_original_Andelst=False)
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(args,valid=True):
  t=time.perf_counter();r=subprocess.run(list(map(str,common+args)),cwd=ROOT,capture_output=True,timeout=1800);i=len(events)
  for stream in ['stdout','stderr']:(out/f'{i:03}.{stream}').write_bytes(getattr(r,stream))
  events.append(dict(command=list(map(str,common+args)),returncode=r.returncode,seconds=time.perf_counter()-t,expected_success=valid));save()
  assert(r.returncode==0)==valid,r.stderr.decode()[-2500:]
 split=365 if a.days>365 else max(1,a.days//2)
 for label,args in [('full',['--stop-after',str(a.days)]),('split',['--stop-after',str(split)]),('resumed',['--stop-after',str(a.days),'--restart',out/'split'])]:run(['--output',out/label]+args)
 for f in ['state.csv','endpoint.csv','restart.bin']:assert(out/'full'/f).read_bytes()==(out/'resumed'/f).read_bytes(),f
 data=rows(out/'full/budget.csv');assert len(data)==a.days and rows(out/'resumed/budget.csv')==data[split:]
 for d in data:
  assert abs(d['water_residual_cm'])<1e-10 and abs(d['solute_residual_mg_cm2'])<1e-10
  physical=d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['runoff_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['actual_transpiration_cm']-d['bottom_up_cm']+d['drainage_cm']
  assert abs(physical)<1e-10,physical
  assert d['drainage_cm']>=0.
 assert sum(d['drainage_cm']for d in data)>0.,'drainage must actually execute'
 for r in rows(out/'full/state.csv'):assert min(r[k]for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0.
 # Change future original table data only: current state cannot resume under
 # a different immutable source, even before the modified future date.
 changed=original.replace(b'1999-12-31  -75.0',b'1999-12-31  -74.0');assert changed!=original
 (case/'swap.dra').write_bytes(changed);run(['--output',out/'forbidden','--restart',out/'split'],False)
 assert not(out/'forbidden').exists();(case/'swap.dra').write_bytes(original)
 report.update(status='NATIVE_DRAMET3_DIVDRA_RESTART_PASS',restart_exact=True,drainage_cm=sum(d['drainage_cm']for d in data),
  max_water_residual=max(abs(d['water_residual_cm'])for d in data),max_solute_residual=max(abs(d['solute_residual_mg_cm2'])for d in data))
 save();print(json.dumps(report))
if __name__=='__main__':main()
