"""Execute the selected existing physical assertion bodies on current providers."""
import argparse,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True)
 p.add_argument('--stage',choices=['column','weather'],required=True);p.add_argument('--optimization',choices=['O0','O2'])
 p.add_argument('--daily-O0',type=Path);p.add_argument('--daily-O2',type=Path);a=p.parse_args()
 proof=a.proof.resolve();out=proof/('controller-'+a.stage+('-'+a.optimization if a.optimization else ''));out.mkdir(exist_ok=False)
 events=[]
 def run(script,args,label):
  command=[sys.executable,'-B',str(ROOT/script),*map(str,args)]
  start=time.perf_counter();r=subprocess.run(command,cwd=ROOT,capture_output=True)
  for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
  events.append(dict(command=command,returncode=r.returncode,seconds=time.perf_counter()-start,label=label))
  (out/'result.json').write_text(json.dumps(dict(status='RUNNING'if r.returncode==0 else'FAILED',events=events),indent=2)+'\n')
  r.check_returncode()
 if a.stage=='column':
  builds=[v for opt in ['O0','O2']for v in ['--build-'+opt,proof/('column-'+opt)]]
  for script,label in [('test_column_input','incumbent-final'),('qualify_swp_reader','chemistry'),('qualify_swp_water','water')]:
   run('tests/nut-sol/'+script+'.py',[*builds,'--output',proof/label],label)
  daily=[v for opt in ['O0','O2']for v in ['--reader-'+opt,getattr(a,'daily_'+opt),'--column-'+opt,proof/('column-'+opt)/'swap5_solute_column']]
  assert a.daily_O0 and a.daily_O2
  for script,label in [('qualify_swp_daily','daily-proof'),('qualify_swp_etref','etref-final')]:
   run('tests/nut-sol/'+script+'.py',[*daily,'--output',proof/label],label)
  crop=[v for opt in ['O0','O2']for v in ['--crop-reader-'+opt,proof/('project-'+opt)/'read_crop/swap5_read_crop',
   '--root-reader-'+opt,proof/('project-'+opt)/'read_root/swap5_read_root','--column-'+opt,proof/('project-'+opt)/'shared/swap5_solute_column']]
  baseline=[v for opt in ['O0','O2']for v in ['--baseline-column-'+opt,proof/('column-'+opt)/'swap5_solute_column']]
  run('tests/nut-sol/qualify_crop_root_joint.py',[*crop,*baseline,'--output',proof/'crop-joint-final'],'crop-joint-final')
  columns=[v for opt in ['O0','O2']for v in ['--column-'+opt,proof/('project-'+opt)/'shared/swap5_solute_column']]
  run('tests/nut-sol/qualify_crop_root_transaction.py',[*columns,'--output',proof/'crop-transaction'],'crop-transaction')
  run('tests/fmig431/qualify_weather_canonical_trace.py',[v for opt in ['O0','O2']for v in ['--column-'+opt,proof/('project-'+opt)/'shared']]+['--output',proof/'trace'],'trace')
 else:
  assert a.optimization;opt=a.optimization;build=proof/('weather-'+opt)
  for script,label in [('qualify_weather_warm_start','focused'),('qualify_weather_surface_repair','original-weather'),('preserve_weather_surface_default','default')]:
   run('tests/fmig431/'+script+'.py',['--build',build,'--output',proof/(label+'-'+opt)],label+'-'+opt)
  run('benchmarks/performance/select_perf01_line_search_retry.py',['--build',build,'--output',proof/('on-build-'+opt)],'on-build-'+opt)
  run('benchmarks/performance/relink_perf01_warm_weather.py',['--build',build,'--output',proof/('warm-build-'+opt)],'warm-build-'+opt)
  for mode,b in [('off',build),('on',proof/('on-build-'+opt)),('warm',proof/('warm-build-'+opt))]:
   for rain in [1,4]:
    label=('season'if mode=='off'else mode+'-season')+'-'+opt+'-'+str(rain)+'x'
    run('benchmarks/performance/run_perf01_warm_weather.py',['--build',b,'--output',proof/label,'--rain',rain],label)
 (out/'result.json').write_text(json.dumps(dict(status='CURRENT_SELECTED_'+a.stage.upper()+'_PRESERVATION_PASS',events=events),indent=2)+'\n')
 print('CURRENT_SELECTED_'+a.stage.upper()+'_PRESERVATION_PASS')
if __name__=='__main__':main()
