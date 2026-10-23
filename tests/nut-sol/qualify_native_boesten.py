"""Actual SWP SWREDU2 native composition; original physical Boesten owner."""
import argparse,base64,csv,hashlib,json,runpy,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def rows(p):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader(p.open())]
def main():
 p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--historical-fixture',type=Path);p.add_argument('--limit',type=int);a=p.parse_args()
 out=a.output.resolve();out.mkdir();bundle=a.bundle.resolve();meta=json.loads((bundle/'bundle.json').read_text());opt=meta['optimization'];old=runpy.run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['capsule']();events=[];cases={}
 report=dict(status='RUNNING',optimization=opt,events=events,cases=cases,source={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in ['app/solute_project/main.f90','app/solute_crop/read_swp_project.f90','tools/solute/run_project.py',str(Path(__file__).relative_to(ROOT))]})
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,valid=True):
  t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=ROOT,capture_output=True,timeout=1800);idx=len(events)
  for stream in ['stdout','stderr']:(out/f'{idx:03}.{stream}').write_bytes(getattr(r,stream))
  events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.perf_counter()-t,expected_success=valid));save();assert(r.returncode==0)==valid,r.stderr.decode()[-2000:];return r
 for name in ['short']+(['historical']if a.historical_fixture else[]):
  case=out/name;case.mkdir()
  if name=='short':
   for folder in ['crop data','weather data']:(case/folder).mkdir()
   swp=old['daily/'+opt+'/dry/input.swp'].decode()+"\nSWBOTB=2\nSW2=1\nSINAVE=0.\nSINAMP=0.\nSINMAX=150.\nPONDMX=1.\nRSRO=.001\nRSROEXP=1.\nPATHATM='weather data'\nPATHCROP='crop data'\n"
   (case/'crop data/crop.crp').write_bytes(old['daily/'+opt+'/dry/crop.crp']);(case/'weather data/weather.met').write_bytes(old['daily/'+opt+'/dry/weather.met']);days=8;split=3
  else:
   src=a.historical_fixture.resolve();swp=(src/'project.swp').read_text()
   for folder in ['crop data','weather data']:shutil.copytree(src/folder,case/folder)
   days=481;split=365
  coefficient=.35 if name=='short'else .79
  swp=swp.replace('SWREDU=0','SWREDU=2\nCOFREDBO='+repr(coefficient));(case/'project.swp').write_text(swp)
  common=[sys.executable,ROOT/'tools/solute/run_project.py',case/'project.swp','--bundle',bundle,'--temporal-tolerance','.001','--solute-transport','implicit_upwind','--surface-exfiltration','historical_zero']
  if name=='historical':common+=['--water-conductivity','picard_continuous']
  n=min(days,a.limit)if a.limit else days;split=min(split,max(1,n//2))if n<days else split
  for label,args in [('full',['--stop-after',str(n)]),('split',['--stop-after',str(split)]),('resumed',['--stop-after',str(n),'--restart',case/'split'])]:run(common+['--output',case/label]+args)
  for f in ['state.csv','endpoint.csv','restart.bin']:assert(case/'full'/f).read_bytes()==(case/'resumed'/f).read_bytes(),f
  assert(case/'full/restart.bin').read_bytes()[:8]==b'S5MJ0003'
  data=rows(case/'full/budget.csv');assert len(data)==n and rows(case/'resumed/budget.csv')==data[split:]
  document=(case/'full/input.nml').read_text();audit=json.loads(base64.b64decode(''.join(l.split('=',1)[1]for l in document.splitlines()if l.startswith('! native_project_audit_base64='))))
  assert abs(audit['boesten_cofred']-coefficient)<1e-15
  for i,d in enumerate(data):
   for kind,unit in [('water','cm'),('solute','mg_cm2')]:
    assert abs(d[kind+'_residual_'+unit])<1e-10
    assert abs(d[kind+'_end_'+unit]-d[kind+'_start_'+unit]-d[kind+'_in_'+unit]+d[kind+'_out_'+unit])<1e-10
   rain=d.get('rain_supplied_cm',float(audit['prepared_periods'][0]['rain'][i]['rain_cm_day']))
   assert abs(d['water_end_cm']-d['water_start_cm']-rain+d['runoff_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['actual_transpiration_cm']-d.get('bottom_up_cm',0.))<1e-10
  for row in rows(case/'full/state.csv'):
   assert min(row[k]for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0.
  cases[name]=dict(days=n,declared_days=days,complete_period=n==days,restart_exact=True,water_max_residual=max(abs(d['water_residual_cm'])for d in data),solute_max_residual=max(abs(d['solute_residual_mg_cm2'])for d in data),original_Andelst_model=False);save()
  (case/'project.swp').write_text(swp.replace('COFREDBO='+repr(coefficient),'COFREDBO='+repr(coefficient+.01)));run(common+['--output',case/'forbidden','--restart',case/'split'],False);assert not(case/'forbidden').exists();(case/'project.swp').write_text(swp)
 report['status']='NATIVE_BOESTEN_ROOT_SOLUTE_V3_RESTART_PASS';save();print(json.dumps(cases))
if __name__=='__main__':main()
