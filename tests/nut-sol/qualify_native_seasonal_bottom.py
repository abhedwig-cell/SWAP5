"""Native seasonal SWBOTB2 composition, retained Reference defaults and restart."""
import argparse,base64,csv,gzip,hashlib,json,runpy,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader(p.open())]
def main():
 ap=argparse.ArgumentParser()
 ap.add_argument('--bundle',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--long',action='store_true');a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 bundle=a.bundle.resolve();meta=json.loads((bundle/'bundle.json').read_text());opt=meta['optimization']
 old=runpy.run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['capsule']()
 report=dict(status='RUNNING',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=opt,events=[],cases={},
  sources={p:sha(ROOT/p)for p in ['app/solute_crop/read_swp_project.f90','app/solute_project/main.f90','tools/solute/run_project.py','tools/solute/build_project.py',str(Path(__file__).relative_to(ROOT))]})
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,valid=True):
  t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=ROOT,capture_output=True,timeout=2400);i=len(report['events'])
  (out/f'{i:03}.stdout').write_bytes(r.stdout);(out/f'{i:03}.stderr').write_bytes(r.stderr)
  report['events'].append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode,expected_success=valid));save()
  if (r.returncode==0)!=valid:raise RuntimeError(str(cmd)+'\n'+r.stderr.decode(errors='replace')[-2000:])
 def fixture(name,long=False):
  case=out/name;case.mkdir();(case/'Crop Data').mkdir();(case/'Weather Data').mkdir()
  swp=old['daily/'+opt+'/dry/input.swp'].decode();crp=old['daily/'+opt+'/dry/crop.crp'].decode()
  swp+="\nSWBOTB=2\nSW2=1\nSINAVE=0.\nSINAMP=0.\nSINMAX=150.\nPONDMX=1000.\nRSRO=.001\nRSROEXP=1.\nPATHATM='Weather Data'\nPATHCROP='Crop Data'\n"
  if not long:
   (case/'Weather Data/weather.met').write_bytes(old['daily/'+opt+'/dry/weather.met']);(case/'Crop Data/crop.crp').write_text(crp)
  else:
   swp=swp.replace('TSTART=27-feb-2024','TSTART=01-jan-1998').replace('TEND=05-mar-2024','TEND=26-apr-1999').replace("METFIL='weather.met'","METFIL='History'")
   swp=swp.replace("28-feb-2024 03-mar-2024 'crop' 1","01-mar-1998 30-jun-1998 'first' 1\n01-sep-1998 30-nov-1998 'second' 1\n01-feb-1999 26-apr-1999 'first' 1")
   swp=swp.replace('1 1 1.0 2\n2 2 2.0 2','1 1 40.0 4\n2 2 80.0 8').replace('RDS=3.','RDS=100.').replace('KSATFIT=.00475,.008','KSATFIT=10.,2.').replace('HTB=0.,-75.,-3.,-90.','HTB=0.,-100.,-120.,-200.').replace('PONDMX=1000.','PONDMX=.5').replace('SINAVE=0.','SINAVE=-.01')
   crp=crp.replace('LCC=4','LCC=100').replace('RDTB=0.,1.,1.,2.,2.,3.','RDTB=0.,10.,1.,60.,2.,100.')
   (case/'Crop Data/first.crp').write_text(crp);(case/'Crop Data/second.crp').write_text(crp.replace('LCC=100','LCC=70').replace('RDCTB=0.,2.,.5,1.,1.,0.','RDCTB=0.,1.,.5,2.,1.,1.').replace('HLIM3L=-1000.','HLIM3L=-300.').replace('SWOXYGEN=0','SWOXYGEN=1\nHLIM1=0.\nHLIM2U=-10.\nHLIM2L=-20.'))
   for suffix in ['998','999']:(case/('Weather Data/History.'+suffix)).write_bytes(gzip.decompress((ROOT/('tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.'+suffix+'.gz')).read_bytes()))
  (case/'project.swp').write_text(swp);return case,swp
 for name,amp,long in [('default',0,False),('seasonal',.001,False)]+([('cross_year',.005,True)]if a.long else[]):
  case,swp=fixture(name,long);source=case/'project.swp';source.write_text(swp.replace('SINAMP=0.','SINAMP='+str(float(amp))))
  common=[sys.executable,ROOT/'tools/solute/run_project.py',source,'--bundle',bundle]
  if long:common+=['--temporal-tolerance','0.001','--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
  for target,extra in [('full',[]),('split',['--stop-after','365'if long else'3']),('resumed',['--restart',case/'split'])]:run(common+['--output',case/target]+extra)
  for p in ['state.csv','endpoint.csv','restart.bin']:assert (case/'full'/p).read_bytes()==(case/'resumed'/p).read_bytes(),(name,p)
  budget=rows(case/'full/budget.csv');assert len(budget)==(481 if long else 8)
  split=365 if long else 3;assert rows(case/'resumed/budget.csv')==budget[split:]
  text=(case/'full/input.nml').read_text()
  audit=json.loads(base64.b64decode(''.join(l.split('=',1)[1]for l in text.splitlines()if l.startswith('! native_project_audit_base64='))))
  for i,d in enumerate(budget):
   assert abs(d['water_residual_cm'])<1e-10 and abs(d['solute_residual_mg_cm2'])<1e-10
   for substance,unit in [('water','cm'),('solute','mg_cm2')]:assert abs(d[substance+'_end_'+unit]-d[substance+'_start_'+unit]-d[substance+'_in_'+unit]+d[substance+'_out_'+unit])<1e-10
   if amp:
    rain=float(audit['prepared_periods'][0]['rain'][i]['rain_cm_day'])
    gross=d['water_end_cm']-d['water_start_cm']-rain+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['runoff_cm']+d['actual_transpiration_cm']-d['bottom_up_cm'];assert abs(gross)<1e-10
    assert abs(d['bottom_up_cm'])<=((.015 if long else amp)+1e-14)
  if name=='default':
   for p in ['state.csv','endpoint.csv','restart.bin','budget.csv']:assert(case/'full'/p).read_bytes()==old['daily/'+opt+'/dry/full/'+p],p
  if name=='seasonal':assert min(d['bottom_up_cm']for d in budget)<0<max(d['bottom_up_cm']for d in budget)
  report['cases'][name]=dict(days=len(budget),water_max_residual=max(abs(d['water_residual_cm'])for d in budget),solute_max_residual=max(abs(d['solute_residual_mg_cm2'])for d in budget),restart_exact=True,original_Andelst_model=False)
  if amp:
   source.write_text(source.read_text().replace('SINMAX=150.','SINMAX=151.'));run(common+['--output',case/'forbidden-restart','--restart',case/'split'],False);assert not(case/'forbidden-restart').exists()
  save()
 report['status']='SEASONAL_BOTTOM_COMPOSITION_PASS';save();print(json.dumps(report['cases']))
if __name__=='__main__':main()
