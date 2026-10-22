"""Native SWP-led rotations with original Andelst weather, hard mass and restart."""
import argparse,base64,csv,gzip,hashlib,io,json,runpy,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
WEATHER='tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def rows(p):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader(p.open())]
def audit(p):
 encoded=''.join(l.split('=',1)[1]for l in p.read_text().splitlines()if l.startswith('! native_project_audit_base64='))
 return json.loads(base64.b64decode(encoded))
def main():
 ap=argparse.ArgumentParser()
 for opt in ['O0','O2']:ap.add_argument('--bundle-'+opt,type=Path,required=True)
 ap.add_argument('--output',type=Path,required=True);ap.add_argument('--short-only',action='store_true')
 ap.add_argument('--optimization',choices=['O0','O2'],nargs='+',default=['O0','O2'])
 ap.add_argument('--solute-transport',choices=['reference','implicit_upwind'],default='reference')
 ap.add_argument('--grid',choices=['coarse','refined'],default='refined');a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 old=runpy.run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['capsule']()
 paths=['tests/nut-sol/qualify_native_project.py','tests/nut-sol/qualify_native_simple_crop.py','tools/solute/run_project.py','tools/solute/run_column.py',
        'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64',WEATHER+'998.gz',WEATHER+'999.gz']
 report=dict(status='RUNNING',inputs={p:sha((ROOT/p).read_bytes())for p in paths},events=[],bundles={},cases={},invalid_inputs=0,exact_single_files=0,fresh_restarts=0,original_exact_values=0)
 report.update(solute_transport=a.solute_transport,grid=a.grid,optimizations=a.optimization)
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd,valid=True):
  t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,input=b'',timeout=1800);i=len(report['events'])
  for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
  report['events'].append(dict(command=list(map(str,cmd)),cwd=str(cwd),returncode=r.returncode,expected_success=valid,seconds=time.perf_counter()-t));save()
  if (r.returncode==0)!=valid:
   report['status']='FAILED';save()
   raise AssertionError((cmd,r.stdout[-2000:],r.stderr[-3000:]))
  return r
 for opt in a.optimization:
  bundle=getattr(a,'bundle_'+opt).resolve();meta=json.loads((bundle/'bundle.json').read_text());report['bundles'][opt]=meta
  for path,h in meta['executable_sha256'].items():assert sha(Path(path).read_bytes())==h
  folder=out/opt;folder.mkdir()
  original_source,original_sha=runpy.run_path(str(ROOT/'tests/nut-sol/qualify_native_simple_crop.py'))['oracle']()
  report['original_fixed_sha256']=original_sha;(folder/'original.f90').write_text(original_source)
  column_meta=json.loads((Path(meta['exe']).parent/'build-complete.json').read_text())
  archives=[p for p in column_meta['reused_artifact_sha256']if p.endswith('/libttutil.a')];assert len(archives)==1
  original=folder/'original'
  run(column_meta['compiler_command']+['-'+opt,'-std=legacy','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace',
      '-ffpe-trap=invalid,zero,overflow','-J'+str(folder),folder/'original.f90',archives[0],'-o',original],folder)
  for name in (['single']if a.short_only else ['single','annual1998','cross_year']):
   case=folder/name;case.mkdir();(case/'Crop Data').mkdir();(case/'Weather Data').mkdir()
   swp=old['daily/'+opt+'/dry/input.swp'].decode();crp=old['daily/'+opt+'/dry/crop.crp'].decode()
   swp+='\nSWBOTB=2\nSW2=1\nSINAVE=0.\nSINAMP=0.\nSINMAX=1.\nPONDMX=1000.\nRSRO=.001\nRSROEXP=1.\nPATHATM=\'Weather Data\'\nPATHCROP=\'Crop Data\'\n'
   if name=='single':
    weather=old['daily/'+opt+'/dry/weather.met'];(case/'Weather Data/Weather.MET').write_bytes(weather)
    swp=swp.replace("METFIL='weather.met'","METFIL='Weather.MET'")
    (case/'Crop Data/Crop.CRP').write_text(crp);days=8;split=3
   else:
    days=365 if name=='annual1998' else 481;split=180 if name=='annual1998' else 365
    swp=swp.replace('TSTART=27-feb-2024','TSTART=01-jan-1998').replace('TEND=05-mar-2024','TEND='+('31-dec-1998'if name=='annual1998'else'26-apr-1999'))
    swp=swp.replace("METFIL='weather.met'","METFIL='History'")
    swp=swp.replace("28-feb-2024 03-mar-2024 'crop' 1","01-mar-1998 30-jun-1998 'first' 1\n01-sep-1998 30-nov-1998 'second' 1"+(''if name=='annual1998'else"\n01-feb-1999 26-apr-1999 'first' 1"))
    # Same120cm physical profile, original LDIS=.01/.02cm (NOT1/2cm).
    # Refined, not proven spatially resolved:2cm upper,<=3.9cm lower cells.
    # Both this41-cell grid and the retained12-cell grid reject negatives.
    mesh='1 1 40.0 4\n2 2 80.0 8'if a.grid=='coarse'else'1 1 40.0 20\n2 2 2.0 1\n3 2 78.0 20'
    swp=swp.replace('1 1 1.0 2\n2 2 2.0 2',mesh).replace('RDS=3.','RDS=100.')
    swp=swp.replace('KSATFIT=.00475,.008','KSATFIT=10.,2.').replace('HTB=0.,-75.,-3.,-90.','HTB=0.,-100.,-120.,-200.')
    swp=swp.replace('PONDMX=1000.','PONDMX=.5').replace('SINAVE=0.','SINAVE=-.01')
    crp=crp.replace('LCC=4','LCC=100').replace('RDTB=0.,1.,1.,2.,2.,3.','RDTB=0.,10.,1.,60.,2.,100.')
    (case/'Crop Data/First.CRP').write_text(crp)
    (case/'Crop Data/Second.CRP').write_text(crp.replace('LCC=100','LCC=70').replace('RDCTB=0.,2.,.5,1.,1.,0.','RDCTB=0.,1.,.5,2.,1.,1.').replace('HLIM3L=-1000.','HLIM3L=-300.').replace('SWOXYGEN=0','SWOXYGEN=1\nHLIM1=0.\nHLIM2U=-10.\nHLIM2L=-20.'))
    for suffix in (['998']if name=='annual1998'else['998','999']):
     (case/('Weather Data/History.'+suffix)).write_bytes(gzip.decompress((ROOT/(WEATHER+suffix+'.gz')).read_bytes()))
   source=case/'Project.SWP';source.write_text(swp)
   common=[sys.executable,ROOT/'tools/solute/run_project.py',source,'--bundle',bundle]
   if a.solute_transport!='reference':common+=['--solute-transport',a.solute_transport]
   for target,extra in [('full',[]),('split',['--stop-after',str(split)]),('resumed',['--restart',case/'split'])]:
    run(common+['--output',case/target]+extra,case)
   for f in ['state.csv','endpoint.csv','restart.bin']:assert (case/'full'/f).read_bytes()==(case/'resumed'/f).read_bytes()
   budget=rows(case/'full/budget.csv');assert len(budget)==days and rows(case/'resumed/budget.csv')==budget[split:]
   info=audit(case/'full/input.nml');assert info['days']==days
   # Complete original fixed.f90 and original ETpot, not a translated formula.
   oracle_case=case/'oracle';oracle_case.mkdir();document=(case/'full/input.nml').read_text()
   for key,h in info['original_sources'].items():
    raw=base64.b64decode(''.join(l.split('=',1)[1]for l in document.splitlines()if l.startswith('! '+key+'_base64=')))
    assert sha(raw)==h
    filename='input.swp'if key=='original_swp'else('weather-'if key.startswith('met_')else'crop-')+key.split('_')[1]+('.met'if key.startswith('met_')else'.crp')
    (oracle_case/filename).write_bytes(raw)
   run([meta['project_reader'],'input.swp','prepare'],oracle_case)
   for p in info['prepared_periods']:
    index=str(p['index']);run([original,'period-'+index+'.swp','crop-'+index+'.crp','weather.met'],oracle_case)
    expected=rows(oracle_case/'original.csv');actual=[{k:float(v)for k,v in r.items()}for r in p['plan']]
    assert actual==expected,(opt,name,index,'original fixed/ETpot differs')
    report['original_exact_values']+=len(actual)*9
    (oracle_case/'original.csv').rename(oracle_case/('original-'+index+'.csv'))
   rain=[float(r['rain_cm_day'])for r in info['prepared_periods'][0]['rain']]
   for i,d in enumerate(budget):
    for substance,unit in [('water','cm'),('solute','mg_cm2')]:
     residual=d[f'{substance}_end_{unit}']-d[f'{substance}_start_{unit}']-d[f'{substance}_in_{unit}']+d[f'{substance}_out_{unit}']
     assert abs(residual)<1e-10 and abs(d[f'{substance}_residual_{unit}'])<1e-10
    gross=d['water_end_cm']-d['water_start_cm']-rain[i]+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['runoff_cm']+d['actual_transpiration_cm']+(.01 if name!='single' else 0.)
    assert abs(gross)<1e-10,(opt,name,i,gross)
    assert abs(d['potential_transpiration_cm']-d['actual_transpiration_cm']-d['drought_reduction_cm']-d['oxygen_reduction_cm'])<1e-12
    if info['profile_index'][i]==0:assert d['actual_transpiration_cm']==0.
   assert sum(d['actual_transpiration_cm']for d in budget)>0
   if name=='single'and a.solute_transport=='reference':
    for f in ['state.csv','endpoint.csv','restart.bin','budget.csv']:
     assert (case/'full'/f).read_bytes()==old['daily/'+opt+'/dry/full/'+f],('single preservation',f)
     report['exact_single_files']+=1
   elif name!='single':
    assert info['periods']==(2 if name=='annual1998' else 3)
    assert max(info['profile_index'])==info['periods']
    assert all(any(float(r['active'])==1 for r in p['plan'])for p in info['prepared_periods'])
    assert sum(d['runoff_cm']for d in budget)>0
    assert sum(d['solute_out_mg_cm2']for d in budget)>0
   report['cases'][opt+'-'+name]=dict(days=days,budget=budget,rain_cm=rain,profiles=info['profile_index'],
    restart_sha256=sha((case/'full/restart.bin').read_bytes()),historical_weather=name!='single',original_Andelst_model=False)
   report['fresh_restarts']+=1;save()
  # Reject activated unsupported physics and input changes without publishing output.
  base=folder/'single'
  for label,old_text,new_text in [('drainage','SWBOTB=2','SWDRA=1\nSWBOTB=2'),('boundary','SWBOTB=2','SWBOTB=1'),
      ('runoff_exponent','RSROEXP=1.','RSROEXP=2.'),('seasonal_bottom','SINAMP=0.','SINAMP=.1'),
      ('pm','SWETR=1','SWETR=0'),('overlap',"28-feb-2024 03-mar-2024 'crop' 1","28-feb-2024 03-mar-2024 'crop' 1\n01-mar-2024 03-mar-2024 'crop' 1")]:
   bad=base/('invalid-'+label+'.swp');bad.write_text((base/'Project.SWP').read_text().replace(old_text,new_text));target=base/('forbidden-'+label)
   run([sys.executable,ROOT/'tools/solute/run_project.py',bad,'--bundle',bundle,'--output',target],base,False)
   assert not target.exists();report['invalid_inputs']+=1
  changed=base/'Crop Data/Crop.CRP';changed.write_text(changed.read_text()+'\n* future original-source change\n')
  target=base/'forbidden-restart'
  run([sys.executable,ROOT/'tools/solute/run_project.py',base/'Project.SWP','--bundle',bundle,'--output',target,'--restart',base/'split'],base,False)
  assert not target.exists();report['invalid_inputs']+=1
 report['status']=('NATIVE_PROJECT_SHORT_PASS'if a.short_only else'NATIVE_PROJECT_HISTORICAL_WEATHER_ANNUAL_PASS')+'_'+a.solute_transport.upper()
 report['optimizations']=a.optimization
 save();print(json.dumps({k:v for k,v in report.items()if k not in ['events','cases','inputs','bundles']}))
if __name__=='__main__':main()
