"""Original day35 reconstruction and complete rollback, with weather option off/on."""
import argparse,hashlib,json,os,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--proof',type=Path,required=True);a=ap.parse_args();p=a.proof.resolve()
 out=p/'controller-weather-controls';out.mkdir();events=[]
 def run(cmd,label,cwd=ROOT):
  cmd=list(map(str,cmd));start=time.perf_counter();r=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=180,env={**os.environ,'OMP_NUM_THREADS':'1'})
  for k in ['stdout','stderr']:(out/(label+'.'+k)).write_bytes(getattr(r,k))
  events.append(dict(command=cmd,returncode=r.returncode,seconds=time.perf_counter()-start,label=label))
  (out/'result.json').write_text(json.dumps(dict(status='RUNNING'if r.returncode==0 else'FAILED',events=events),indent=2)+'\n');r.check_returncode();return r
 py=[sys.executable,'-B'];weather=p/'season-O2-4x/input/weather.999'
 run(py+[ROOT/'tests/fmig431/build_weather_surface_controls.py','--build',p/'weather-O2','--output',p/'restart-build','--weather',weather,'--kind','wet-restart'],'build-restart')
 run(py+[ROOT/'tests/fmig431/build_weather_surface_controls.py','--build',p/'on-build-O2','--output',p/'on-restart-build','--weather',weather,'--kind','wet-restart'],'build-on-restart')
 for build,label in [('restart-build','restart-native'),('on-restart-build','on-restart-native')]:
  run(py+[ROOT/'benchmarks/performance/run_perf01_weather_bound.py','--build',p/build,'--output',p/label,'--budget','.001','--expected-rain-mm','908','--restart'],'run-'+label)
 run(py+[ROOT/'tests/fmig431/build_weather_surface_controls.py','--build',p/'weather-O2','--output',p/'off-rollback-build','--weather',weather,'--kind','rollback'],'build-off-rollback')
 run(py+[ROOT/'tests/fmig431/build_weather_surface_controls.py','--build',p/'on-build-O2','--output',p/'rollback-build','--weather',weather,'--kind','rollback'],'build-on-rollback')
 for build,label in [('off-rollback-build','off-rollback-native'),('rollback-build','rollback-native')]:
  target=p/label;target.mkdir();cmd=[p/build/'weather',p/build/'weather.999','.001','97','64','continuous','original']
  r=run(cmd,label,target);assert b'WEATHER_SURFACE_ROLLBACK_PASS'in r.stdout
  for k in ['stdout','stderr']:(target/k).write_bytes(getattr(r,k))
  (target/'RESULT.json').write_text(json.dumps(dict(status='PASS',returncode=0,command=list(map(str,cmd)),raw_sha256={k:hashlib.sha256(getattr(r,k)).hexdigest()for k in ['stdout','stderr']}),indent=2)+'\n')
 assert(p/'restart-native/stdout').read_bytes()==(p/'season-O2-4x/native/stdout').read_bytes()
 assert(p/'on-restart-native/stdout').read_bytes()==(p/'on-season-O2-4x/native/stdout').read_bytes()
 (out/'result.json').write_text(json.dumps(dict(status='CURRENT_DAY35_RESTART_AND_COMPLETE_ROLLBACK_OFF_ON_PASS',events=events),indent=2)+'\n')
 print('CURRENT_DAY35_RESTART_AND_COMPLETE_ROLLBACK_OFF_ON_PASS')
if __name__=='__main__':main()
