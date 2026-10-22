"""Current Reference substep roots and exact admitted daily-mode preservation."""
import argparse,base64,csv,hashlib,io,json,subprocess,sys,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def rows(p):return [{k:float(v) for k,v in r.items()} for r in csv.DictReader(p.open())]
def main():
 ap=argparse.ArgumentParser()
 for opt in ['O0','O2']:
  for kind in ['crop-reader','root-reader','column']:ap.add_argument('--'+kind+'-'+opt,type=Path,required=True)
 ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 r=json.loads((ROOT/STATUS).read_text())['swp_water_successor']['daily_meteo_successor']['etref_successor']['simple_crop_preparation_successor']['root_joint_successor']
 raw=base64.b64decode((ROOT/r['evidence']['path']).read_bytes())
 assert sha(raw)==r['evidence']['decoded_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as archive:
  members=archive.getmembers();assert all(m.isfile() and '..' not in Path(m.name).parts and not m.name.startswith('/') for m in members)
  files={m.name:archive.extractfile(m).read() for m in members}
 manifest=json.loads(files.pop('MANIFEST.json'));assert set(files)==set(manifest)
 assert all(sha(files[p])==h for p,h in manifest.items())
 prior=json.loads(files['qualified/result.json']);assert prior['status']=='NATIVE_CROP_ROOT_JOINT_O0_O2_PASS'
 inputs=['tests/nut-sol/qualify_root_substep_daily.py','tools/solute/run_crop_daily.py','tools/solute/run_column.py']
 report={'status':'RUNNING','baseline_capsule_sha256':sha(raw),'inputs':{p:sha((ROOT/p).read_bytes()) for p in inputs},'events':[],
         'builds':{},'cases':{},'exact_default_files':0,'fresh_restarts':0,'mode_restart_rejections':0}
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd,valid=True):
  t=time.perf_counter();cp=subprocess.run(list(map(str,cmd)),cwd=cwd,input=b'',capture_output=True,timeout=180)
  i=len(report['events'])
  for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(cp,stream))
  report['events'].append({'command':list(map(str,cmd)),'cwd':str(cwd),'returncode':cp.returncode,'expected_success':valid,'seconds':time.perf_counter()-t});save()
  assert (cp.returncode==0)==valid,(cmd,cp.stdout[-3000:],cp.stderr[-3000:])
 for opt in ['O0','O2']:
  folder=out/opt;folder.mkdir();binaries={kind:getattr(args,kind.replace('-','_')+'_'+opt).resolve() for kind in ['crop-reader','root-reader','column']}
  report['builds'][opt]={}
  for kind,exe in binaries.items():
   build=json.loads((exe.parent/'build-complete.json').read_text());assert build['status']=='BUILT' and sha(exe.read_bytes())==build['executable_sha256']
   assert all(sha((ROOT/p).read_bytes())==h for p,h in build['input_sha256'].items())
   assert all(sha((exe.parent/p).read_bytes())==h for p,h in build['generated_input_sha256'].items())
   report['builds'][opt][kind]=build
  for name in ['dry','drought','oxygen','ponded','rain','no-salt-uptake','linear','maturity']:
   case=folder/name;case.mkdir();prefix='qualified/'+opt+'/'+name+'/'
   for f in ['input.swp','crop.crp','weather.met']:(case/f).write_bytes(files[prefix+f])
   common=[sys.executable,ROOT/'tools/solute/run_crop_daily.py','--crop-reader',binaries['crop-reader'],'--root-reader',binaries['root-reader'],
           '--exe',binaries['column'],'--swp',case/'input.swp','--crop',case/'crop.crp','--met',case/'weather.met']
   if name=='ponded':common+=['--initial-pond-cm','.5']
   run(common+['--output',case/'daily'],case)
   for f in ['state.csv','endpoint.csv','restart.bin','budget.csv']:
    assert (case/'daily'/f).read_bytes()==files[prefix+'full/'+f],(opt,name,f,'daily default changed')
    report['exact_default_files']+=1
   for target,extra in [('full',[]),('split',['--stop-after','3']),('resumed',['--restart',case/'split'])]:
    run(common+['--substep-root-stress','--output',case/target]+extra,case)
   for f in ['state.csv','endpoint.csv','restart.bin']:assert (case/'full'/f).read_bytes()==(case/'resumed'/f).read_bytes()
   budget=rows(case/'full/budget.csv');assert len(budget)==8 and rows(case/'resumed/budget.csv')==budget[3:]
   rain=prior['cases'][opt+'-'+name]['rain_cm']
   for i,d in enumerate(budget):
    for substance,unit in [('water','cm'),('solute','mg_cm2')]:
     residual=d[f'{substance}_end_{unit}']-d[f'{substance}_start_{unit}']-d[f'{substance}_in_{unit}']+d[f'{substance}_out_{unit}']
     assert abs(residual)<1e-10 and abs(d[f'{substance}_residual_{unit}'])<1e-10
    gross=d['water_end_cm']-d['water_start_cm']-rain[i]+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['runoff_cm']+d['actual_transpiration_cm']
    assert abs(gross)<1e-10
    assert -1e-15<=d['actual_transpiration_cm']<=d['potential_transpiration_cm']+1e-12
    assert abs(d['potential_transpiration_cm']-d['actual_transpiration_cm']-d['drought_reduction_cm']-d['oxygen_reduction_cm'])<1e-12
   assert sum(d['actual_transpiration_cm'] for d in budget)>0
   if name=='drought':assert sum(d['drought_reduction_cm'] for d in budget)>0
   if name=='oxygen':assert sum(d['oxygen_reduction_cm'] for d in budget)>0
   if name=='no-salt-uptake':assert abs(budget[-1]['solute_end_mg_cm2']-budget[0]['solute_start_mg_cm2'])<1e-10
   assert budget[0]['actual_transpiration_cm']==budget[-1]['actual_transpiration_cm']==0.
   if name=='maturity':assert all(d['actual_transpiration_cm']==0. for d in budget[2:])
   if name=='dry':
    run(common+['--restart',case/'split','--output',case/'forbidden-mode-change'],case,False)
    assert not (case/'forbidden-mode-change').exists();report['mode_restart_rejections']+=1
   report['cases'][opt+'-'+name]={'budget':budget,'rain_cm':rain,'restart_sha256':sha((case/'full/restart.bin').read_bytes()),
                                'daily_exact':True,'fresh_exact':True}
   report['fresh_restarts']+=1;save()
 report.update(status='ROOT_SUBSTEP_DAILY_O0_O2_MASS_RESTART_DEFAULT_EXACT_PASS',full_historical_migration=False)
 save();print(json.dumps({k:v for k,v in report.items() if k not in ['events','builds','inputs','cases']}))
if __name__=='__main__':main()
